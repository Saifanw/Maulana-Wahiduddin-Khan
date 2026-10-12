WHATSAPP PREVIEW SETUP (one time, about 10 minutes, free)
=========================================================
Why: WhatsApp ignores everything after "#" in a link and cannot run JavaScript, so a plain
page link always shows the same generic card. This tiny Worker gives each article its own
card (title + first lines + picture) and then sends the reader to the article.

1. Supabase > SQL Editor: run sunday-upgrade.sql once (moderation, name fix, spam guard, preview-image storage).
2. Upload og-default.jpg (included) next to sunday.html on your site.
3. Create a free Cloudflare account > Workers & Pages > Create > "Hello World" Worker > Deploy > Edit code.
   Paste the whole of share-worker.js. At the top, change SITE_URL to the real address of sunday.html. Deploy.
4. Copy the worker address, e.g. https://sunday-share.yourname.workers.dev
5. In sunday.html find   const SHARE_BASE=""   and set it to   "https://sunday-share.yourname.workers.dev/s/"
6. Publish an article as admin. A dialog shows the preview card + WhatsApp button. Done.
   (If WhatsApp shows an old card, add ?v=2 at the end of the link once; WhatsApp caches previews.)
