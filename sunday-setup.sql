-- Run once in Supabase: SQL Editor > New query > Run
create table if not exists public.sunday_learnings(
  id uuid primary key default gen_random_uuid(),
  session_id text not null,
  author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 2 and 4000),
  lang text not null default 'en' check (lang in ('en','hi','ur')),
  created_at timestamptz not null default now()
);
create index if not exists sunday_learnings_session_idx on public.sunday_learnings(session_id, created_at desc);
alter table public.sunday_learnings enable row level security;
drop policy if exists "read learnings" on public.sunday_learnings;
drop policy if exists "add own learning" on public.sunday_learnings;
drop policy if exists "delete own learning" on public.sunday_learnings;
create policy "read learnings" on public.sunday_learnings for select using (true);
create policy "add own learning" on public.sunday_learnings for insert to authenticated with check (auth.uid() = author_id);
create policy "delete own learning" on public.sunday_learnings for delete to authenticated using (auth.uid() = author_id);

-- Feed view with the author's display name (uses your existing profiles table)
create or replace view public.sunday_learning_feed as
  select l.*, coalesce(p.display_name,'Member') as author_name
  from public.sunday_learnings l left join public.profiles p on p.id = l.author_id;

grant select on public.sunday_learnings, public.sunday_learning_feed to anon, authenticated;
grant insert, delete on public.sunday_learnings to authenticated;
