-- Run this ONCE in Supabase > SQL Editor to allow 10-minute voice messages.
-- (The audio_seconds column already allows up to 60 minutes, so only the file size limit changes.)
update storage.buckets
   set file_size_limit = 26214400   -- 25 MB
 where id = 'sunday-voice';
