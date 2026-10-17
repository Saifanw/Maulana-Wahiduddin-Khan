-- Run ONCE in Supabase: SQL Editor > New query > paste > Run.
-- (Run sunday-setup.sql, sunday-admin.sql, sunday-upgrade.sql, sunday-voice.sql and sunday-hinglish.sql first if you have not already.)
-- Adds LIKES and REPLIES under every shared learning (text or voice).

-- 1) Tables
create table if not exists public.sunday_likes(
  learning_id uuid not null references public.sunday_learnings(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  session_id text,
  created_at timestamptz not null default now(),
  primary key (learning_id, user_id)
);
create index if not exists sunday_likes_user_idx on public.sunday_likes(user_id);

create table if not exists public.sunday_replies(
  id uuid primary key default gen_random_uuid(),
  learning_id uuid not null references public.sunday_learnings(id) on delete cascade,
  session_id text,
  author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists sunday_replies_session_idx on public.sunday_replies(session_id, created_at);
create index if not exists sunday_replies_learning_idx on public.sunday_replies(learning_id, created_at);

-- 2) session_id is always copied from the learning (cannot be faked)
create or replace function public.sunday_social_session() returns trigger language plpgsql as $$
begin
  new.session_id := (select session_id from public.sunday_learnings where id = new.learning_id);
  if new.session_id is null then raise exception 'This learning no longer exists.'; end if;
  return new;
end $$;
drop trigger if exists sunday_likes_sess_t on public.sunday_likes;
create trigger sunday_likes_sess_t before insert on public.sunday_likes for each row execute function public.sunday_social_session();
drop trigger if exists sunday_replies_sess_t on public.sunday_replies;
create trigger sunday_replies_sess_t before insert on public.sunday_replies for each row execute function public.sunday_social_session();

-- 3) Spam guard for replies: max 10 per user per 5 minutes
create or replace function public.sunday_replies_rate() returns trigger language plpgsql as $$
begin
  if (select count(*) from public.sunday_replies where author_id = new.author_id and created_at > now() - interval '5 minutes') >= 10 then
    raise exception 'Too many replies in a short time. Please wait a few minutes.';
  end if;
  return new;
end $$;
drop trigger if exists sunday_replies_rate_t on public.sunday_replies;
create trigger sunday_replies_rate_t before insert on public.sunday_replies for each row execute function public.sunday_replies_rate();

-- 4) Permissions
alter table public.sunday_likes enable row level security;
alter table public.sunday_replies enable row level security;
drop policy if exists "read likes" on public.sunday_likes;
drop policy if exists "add own like" on public.sunday_likes;
drop policy if exists "remove own like" on public.sunday_likes;
create policy "read likes" on public.sunday_likes for select using (true);
create policy "add own like" on public.sunday_likes for insert to authenticated with check (auth.uid() = user_id);
create policy "remove own like" on public.sunday_likes for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "read replies" on public.sunday_replies;
drop policy if exists "add own reply" on public.sunday_replies;
drop policy if exists "delete own reply" on public.sunday_replies;
drop policy if exists "admin delete any reply" on public.sunday_replies;
create policy "read replies" on public.sunday_replies for select using (true);
create policy "add own reply" on public.sunday_replies for insert to authenticated with check (auth.uid() = author_id);
create policy "delete own reply" on public.sunday_replies for delete to authenticated using (auth.uid() = author_id);
create policy "admin delete any reply" on public.sunday_replies for delete to authenticated
  using (exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));

-- 5) Views the page reads
drop view if exists public.sunday_reply_feed;
create view public.sunday_reply_feed as
  select r.*, coalesce(nullif(p.display_name,''), nullif(u.raw_user_meta_data->>'full_name',''), 'Member') as author_name
  from public.sunday_replies r
  left join public.profiles p on p.id = r.author_id
  left join auth.users u on u.id = r.author_id;

drop view if exists public.sunday_learning_stats;
create view public.sunday_learning_stats as
  select l.id as learning_id, l.session_id,
    (select count(*) from public.sunday_likes k where k.learning_id = l.id)::int as likes,
    (select count(*) from public.sunday_replies r where r.learning_id = l.id)::int as replies
  from public.sunday_learnings l;

grant select on public.sunday_likes, public.sunday_replies, public.sunday_reply_feed, public.sunday_learning_stats to anon, authenticated;
grant insert, delete on public.sunday_likes, public.sunday_replies to authenticated;
