-- Supabase Storage: 기억 썸네일 백업 (사용자별 폴더)
-- Dashboard SQL Editor 또는: supabase db query --linked -f ...

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('memory-images', 'memory-images', false, 524288, ARRAY['image/jpeg'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "memory_images_select_own" ON storage.objects;
DROP POLICY IF EXISTS "memory_images_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "memory_images_update_own" ON storage.objects;
DROP POLICY IF EXISTS "memory_images_delete_own" ON storage.objects;

CREATE POLICY "memory_images_select_own" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'memory-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "memory_images_insert_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'memory-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "memory_images_update_own" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'memory-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "memory_images_delete_own" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'memory-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
