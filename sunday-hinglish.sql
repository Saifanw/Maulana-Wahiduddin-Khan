-- Run once in Supabase SQL editor: allows Hinglish ('hn') as a comment language.
alter table public.sunday_learnings drop constraint if exists sunday_learnings_lang_check;
alter table public.sunday_learnings add constraint sunday_learnings_lang_check check (lang in ('en','hi','ur','hn'));
