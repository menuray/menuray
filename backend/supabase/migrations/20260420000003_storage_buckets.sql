-- ============================================================================
-- Storage buckets
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('menu-photos', 'menu-photos', false, 10485760,  ARRAY['image/jpeg','image/png']::text[]),
  ('dish-images', 'dish-images', true,  5242880,   ARRAY['image/jpeg','image/png','image/webp']::text[]),
  ('store-logos', 'store-logos', true,  2097152,   ARRAY['image/png','image/svg+xml']::text[])
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- menu-photos — private bucket
--   owner INSERT / UPDATE / DELETE / SELECT via path prefix {store_id}/...
-- ============================================================================
CREATE POLICY owner_insert_menu_photos ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_update_menu_photos ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_delete_menu_photos ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_select_menu_photos ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- dish-images — public bucket; public READ is automatic; owners write.
-- ============================================================================
CREATE POLICY owner_insert_dish_images ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_update_dish_images ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_delete_dish_images ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- store-logos — public bucket; public READ is automatic; owners write.
-- ============================================================================
CREATE POLICY owner_insert_store_logos ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_update_store_logos ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_delete_store_logos ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );
