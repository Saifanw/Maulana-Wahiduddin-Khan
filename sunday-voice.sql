-- Run ONCE in Supabase: SQL Editor > New query > paste > Run.
-- (Run sunday-setup.sql, sunday-admin.sql and sunday-upgrade.sql first if you have not already.)
-- Adds voice messages (record or upload audio) to "Share your learning".

-- 1) New columns on the learnings table
alter table public.sunday_learnings add column if not exists audio_path text;
alter table public.sunday_learnings add column if not exists audio_seconds integer;

-- 2) Text is now optional when a voice message is attached
alter table public.sunday_learnings drop constraint if exists sunday_learnings_body_check;
alter table public.sunday_learnings add constraint sunday_learnings_body_check check (char_length(body) <= 4000);

alter table public.sunday_learnings drop constraint if exists sunday_learnings_content_check;
alter table public.sunday_learnings add constraint sunday_learnings_content_check
  check (char_length(body) >= 2 or audio_path is not null);

alter table public.sunday_learnings drop constraint if exists sunday_learnings_audio_secs_check;
alter table public.sunday_learnings add constraint sunday_learnings_audio_secs_check
  check (audio_seconds is null or audio_seconds between 0 and 3600);

-- the audio file must live inside the author's own folder
alter table public.sunday_learnings drop constraint if exists sunday_learnings_audio_owner_check;
alter table public.sunday_learnings add constraint sunday_learnings_audio_owner_check
  check (audio_path is null or audio_path like author_id::text || '/%');

-- 3) Rebuild the feed view so it includes the new columns
drop view if exists public.sunday_learning_feed;
create view public.sunday_learning_feed as
  select l.*, coalesce(nullif(p.display_name,''), nullif(u.raw_user_meta_data->>'full_name',''), 'Member') as author_name
  from public.sunday_learnings l
  left join public.profiles p on p.id = l.author_id
  left join auth.users u on u.id = l.author_id;
grant select on public.sunday_learning_feed to anon, authenticated;

-- 4) Storage bucket for the voice messages (public read, 10 MB max, audio only)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('sunday-voice', 'sunday-voice', true, 10485760, array['audio/*'])
  on conflict (id) do update set public = true, file_size_limit = 10485760, allowed_mime_types = array['audio/*'];

drop policy if exists "voice read" on storage.objects;
drop policy if exists "voice insert own" on storage.objects;
drop policy if exists "voice delete own" on storage.objects;
drop policy if exists "voice admin delete" on storage.objects;

create policy "voice read" on storage.objects for select
  using (bucket_id = 'sunday-voice');
create policy "voice insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'sunday-voice' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "voice delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'sunday-voice' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "voice admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'sunday-voice' and exists (select 1 from public.sunday_admins a where a.user_id = auth.uid()));
