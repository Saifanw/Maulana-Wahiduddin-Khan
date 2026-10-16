/* Cloudflare Worker: gives every Sunday article its OWN WhatsApp preview (title, first lines, picture).
   Share link looks like  https://YOUR-WORKER.workers.dev/s/2026-10-11
   WhatsApp reads the tags below; real visitors are sent straight to the article page.
   Setup steps are in worker/README.txt */
const SITE_URL     = "https://YOUR-SITE.example/sunday.html";   // full address of sunday.html on your site
const SUPABASE_URL = "https://ibafhumzzkmsiyzxfwyo.supabase.co";
const SUPABASE_KEY = "sb_publishable_iEo94aadvYBxSflTWMcEBg_9-Oqy2R1";   // public (publishable) key
const DEFAULT_IMAGE = SITE_URL.replace(/[^/]*$/, "") + "og-default.jpg";

const esc = s => String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const plain = t => String(t || "").replace(/^##\s+/gm, "").replace(/^>\s?/gm, "").replace(/\*+/g, "").replace(/\s+/g, " ").trim();
const first = (o, order) => { for (const k of order) if (o && o[k] && String(o[k]).trim()) return String(o[k]); return ""; };

export default {
  async fetch(req) {
    const m = new URL(req.url).pathname.match(/^\/s\/([\w-]{4,40})\/?$/);
    if (!m) return Response.redirect(SITE_URL, 302);
    const id = m[1], lg = (new URL(req.url).searchParams.get("l") || "").replace(/[^a-z]/g, "").slice(0, 2), target = SITE_URL + "#w=" + id + (lg ? "&l=" + lg : "");
    let title = "Sunday Discussion | Al-Risala", desc = "Read this week's Al-Risala article in Urdu, Hindi or English.", img = DEFAULT_IMAGE;
    try {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/sunday_sessions?id=eq.${encodeURIComponent(id)}&select=title,article`, {
        headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }, cf: { cacheTtl: 120, cacheEverything: true } });
      const rows = r.ok ? await r.json() : [];
      if (rows[0]) {
        title = first(rows[0].title, [lg, "en", "hn", "hi", "ur"]) || title;
        const body = plain(first(rows[0].article, [lg, "en", "hn", "hi", "ur"]));
        if (body) desc = body.length > 190 ? body.slice(0, 187).replace(/\s+\S*$/, "") + "…" : body;
        title = title.replace(/^[#\s]+/, "");
        // per-language card first (id-hn.jpg), then the old single card (id.jpg)
        for (const name of (lg ? [id + "-" + lg + ".jpg", id + ".jpg"] : [id + ".jpg"])) {
          const card = `${SUPABASE_URL}/storage/v1/object/public/sunday-og/${encodeURIComponent(name)}`;
          const h = await fetch(card, { method: "HEAD" });
          if (h.ok) { const v = Date.parse(h.headers.get("last-modified") || "") || 0; img = card + (v ? "?v=" + v : ""); break; }
        }
      }
    } catch (e) { /* fall back to defaults */ }
    const html = `<!doctype html><html><head><meta charset="utf-8"><title>${esc(title)}</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="${esc(desc)}">
<meta property="og:type" content="article"><meta property="og:site_name" content="Wahiduddin Khan Library">
<meta property="og:title" content="${esc(title)}"><meta property="og:description" content="${esc(desc)}">
<meta property="og:image" content="${esc(img)}"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">
<meta property="og:url" content="${esc(new URL(req.url).href)}">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${esc(title)}"><meta name="twitter:image" content="${esc(img)}">
<meta http-equiv="refresh" content="0;url=${esc(target)}"><link rel="canonical" href="${esc(target)}">
<script>location.replace(${JSON.stringify(target)})</script></head>
<body style="font-family:system-ui;padding:2rem"><a href="${esc(target)}">Open the article</a></body></html>`;
    return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=300" } });
  }
};
