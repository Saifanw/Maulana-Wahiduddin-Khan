-- Run once in Supabase: SQL Editor > New query > Run
create table if not exists public.sunday_admins(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.sunday_admins enable row level security;
drop policy if exists "admin sees self" on public.sunday_admins;
create policy "admin sees self" on public.sunday_admins for select to authenticated using (user_id = auth.uid());

create table if not exists public.sunday_sessions(
  id text primary key,
  date date not null,
  title jsonb not null default '{}',
  source text not null default '',
  source_url text not null default '',
  article jsonb not null default '{}',
  youtube text not null default '',
  omeri jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.sunday_sessions enable row level security;
drop policy if exists "read sessions" on public.sunday_sessions;
drop policy if exists "admin add sessions" on public.sunday_sessions;
drop policy if exists "admin edit sessions" on public.sunday_sessions;
drop policy if exists "admin delete sessions" on public.sunday_sessions;
create policy "read sessions" on public.sunday_sessions for select using (true);
create policy "admin add sessions" on public.sunday_sessions for insert to authenticated with check (exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));
create policy "admin edit sessions" on public.sunday_sessions for update to authenticated using (exists (select 1 from public.sunday_admins a where a.user_id = auth.uid())) with check (exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));
create policy "admin delete sessions" on public.sunday_sessions for delete to authenticated using (exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));
grant select on public.sunday_sessions to anon, authenticated;
grant insert, update, delete on public.sunday_sessions to authenticated;
grant select on public.sunday_admins to authenticated;

-- Make YOUR account the admin: replace the email with the admin email you sign in with
insert into public.sunday_admins(user_id) select id from auth.users where email = 'YOUR_EMAIL_HERE' on conflict do nothing;
