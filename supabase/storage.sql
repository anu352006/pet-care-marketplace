-- ============================================================================
-- SUPABASE STORAGE BUCKET CONFIGURATION & RLS POLICIES (PostgreSQL 15+)
-- Run in: Supabase Dashboard -> SQL Editor -> New query -> Paste & Run
-- ============================================================================

-- Ensure Row Level Security is active on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 1. Ensure Storage Buckets (preserves existing public bucket setting on conflict)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('pet-images', 'pet-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/jpg']),
    ('provider-images', 'provider-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/jpg']),
    ('service-images', 'service-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/jpg'])
ON CONFLICT (id) DO UPDATE SET 
    file_size_limit = COALESCE(storage.buckets.file_size_limit, EXCLUDED.file_size_limit),
    allowed_mime_types = COALESCE(storage.buckets.allowed_mime_types, EXCLUDED.allowed_mime_types);

-- ==========================================================
-- 2. Storage Policies: pet-images
-- Path Structure: <user_id>/pets/<timestamp>-<filename>.<ext>
-- Open to any authenticated user uploading into their own UUID folder
-- ==========================================================
DROP POLICY IF EXISTS "Public can view pet images" ON storage.objects;
CREATE POLICY "Public can view pet images" ON storage.objects
    FOR SELECT USING (bucket_id = 'pet-images');

DROP POLICY IF EXISTS "Authenticated users upload pet images" ON storage.objects;
CREATE POLICY "Authenticated users upload pet images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'pet-images' 
        AND auth.role() = 'authenticated'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Users can update own pet images" ON storage.objects;
CREATE POLICY "Users can update own pet images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'pet-images' 
        AND auth.role() = 'authenticated'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Users can delete own pet images" ON storage.objects;
CREATE POLICY "Users can delete own pet images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'pet-images' 
        AND auth.role() = 'authenticated'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text 
            OR public.is_admin()
        )
    );

-- ==========================================================
-- 3. Storage Policies: provider-images
-- Path Structure: <user_id>/providers/<timestamp>-<filename>.<ext>
-- Restricted to authenticated providers and administrators
-- ==========================================================
DROP POLICY IF EXISTS "Public can view provider images" ON storage.objects;
CREATE POLICY "Public can view provider images" ON storage.objects
    FOR SELECT USING (bucket_id = 'provider-images');

DROP POLICY IF EXISTS "Providers and admins upload provider images" ON storage.objects;
CREATE POLICY "Providers and admins upload provider images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'provider-images' 
        AND auth.role() = 'authenticated'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text) 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Providers and admins update provider images" ON storage.objects;
CREATE POLICY "Providers and admins update provider images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'provider-images' 
        AND auth.role() = 'authenticated'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text) 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Providers and admins delete provider images" ON storage.objects;
CREATE POLICY "Providers and admins delete provider images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'provider-images' 
        AND auth.role() = 'authenticated'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text) 
            OR public.is_admin()
        )
    );

-- ==========================================================
-- 4. Storage Policies: service-images
-- Path Structure: <user_id>/services/<timestamp>-<filename>.<ext>
-- Restricted to authenticated providers and administrators
-- ==========================================================
DROP POLICY IF EXISTS "Public can view service images" ON storage.objects;
CREATE POLICY "Public can view service images" ON storage.objects
    FOR SELECT USING (bucket_id = 'service-images');

DROP POLICY IF EXISTS "Providers and admins upload service images" ON storage.objects;
CREATE POLICY "Providers and admins upload service images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'service-images' 
        AND auth.role() = 'authenticated'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text) 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Providers and admins update service images" ON storage.objects;
CREATE POLICY "Providers and admins update service images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'service-images' 
        AND auth.role() = 'authenticated'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text) 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Providers and admins delete service images" ON storage.objects;
CREATE POLICY "Providers and admins delete service images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'service-images' 
        AND auth.role() = 'authenticated'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text) 
            OR public.is_admin()
        )
    );
