-- Run ONCE in Supabase: SQL Editor > New query > paste > Run.
-- (Run sunday-setup.sql and sunday-admin.sql first if you have not already.)

-- 1) Admin can remove ANY comment (moderation)
drop policy if exists "admin delete any learning" on public.sunday_learnings;
create policy "admin delete any learning" on public.sunday_learnings for delete to authenticated
  using (exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));

-- 2) Comment author name: profiles.display_name, else the name typed at sign-in, else "Member"
create or replace view public.sunday_learning_feed as
  select l.*, coalesce(nullif(p.display_name,''), nullif(u.raw_user_meta_data->>'full_name',''), 'Member') as author_name
  from public.sunday_learnings l
  left join public.profiles p on p.id = l.author_id
  left join auth.users u on u.id = l.author_id;
grant select on public.sunday_learning_feed to anon, authenticated;

-- 3) Spam guard: max 5 comments per user per 10 minutes
create or replace function public.sunday_learnings_rate() returns trigger language plpgsql as $$
begin
  if (select count(*) from public.sunday_learnings where author_id = new.author_id and created_at > now() - interval '10 minutes') >= 5 then
    raise exception 'Too many comments in a short time. Please wait a few minutes.';
  end if;
  return new;
end $$;
drop trigger if exists sunday_learnings_rate_t on public.sunday_learnings;
create trigger sunday_learnings_rate_t before insert on public.sunday_learnings for each row execute function public.sunday_learnings_rate();

-- 4) Storage bucket for the WhatsApp preview cards (public read, admin write)
insert into storage.buckets (id, name, public) values ('sunday-og','sunday-og', true) on conflict (id) do update set public = true;
drop policy if exists "og read" on storage.objects;
drop policy if exists "og admin insert" on storage.objects;
drop policy if exists "og admin update" on storage.objects;
drop policy if exists "og admin delete" on storage.objects;
create policy "og read" on storage.objects for select using (bucket_id = 'sunday-og');
create policy "og admin insert" on storage.objects for insert to authenticated with check (bucket_id = 'sunday-og' and exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));
create policy "og admin update" on storage.objects for update to authenticated using (bucket_id = 'sunday-og' and exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));
create policy "og admin delete" on storage.objects for delete to authenticated using (bucket_id = 'sunday-og' and exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));
