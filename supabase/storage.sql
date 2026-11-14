-- ============================================================================
-- SUPABASE STORAGE BUCKET CONFIGURATION & RLS POLICIES (PostgreSQL 15+)
-- Run in: Supabase Dashboard -> SQL Editor -> New query -> Paste & Run
-- (Execute AFTER supabase/schema.sql)
-- ============================================================================

-- Ensure Row Level Security is active on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 1. Create / Ensure Public Storage Buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('pet-images', 'pet-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml']),
    ('provider-images', 'provider-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml']),
    ('service-images', 'service-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml'])
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml'];

-- ==========================================================
-- 2. Storage Policies: pet-images
-- Path Structure: <user_id>/pets/<timestamp>-<filename>.<ext>
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
            auth.uid()::text = (storage.foldername(name))[1] 
            OR auth.uid()::text = owner::text 
            OR (storage.foldername(name))[1] = 'pets'
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Users can update or delete their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their pet images" ON storage.objects;
CREATE POLICY "Users can update their pet images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'pet-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    )
    WITH CHECK (
        bucket_id = 'pet-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Users can delete their pet images" ON storage.objects;
CREATE POLICY "Users can delete their pet images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'pet-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    );

-- ==========================================================
-- 3. Storage Policies: provider-images
-- Path Structure: <user_id>/providers/<timestamp>-<filename>.<ext>
-- ==========================================================
DROP POLICY IF EXISTS "Public can view provider images" ON storage.objects;
CREATE POLICY "Public can view provider images" ON storage.objects
    FOR SELECT USING (bucket_id = 'provider-images');

DROP POLICY IF EXISTS "Providers can upload provider images" ON storage.objects;
CREATE POLICY "Providers can upload provider images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'provider-images' 
        AND auth.role() = 'authenticated'
        AND (
            public.is_provider() 
            OR public.is_admin() 
            OR auth.uid()::text = (storage.foldername(name))[1]
            OR auth.uid()::text = owner::text
            OR (storage.foldername(name))[1] = 'providers'
        )
    );

DROP POLICY IF EXISTS "Providers can update own provider images" ON storage.objects;
CREATE POLICY "Providers can update own provider images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'provider-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    )
    WITH CHECK (
        bucket_id = 'provider-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Providers can delete own provider images" ON storage.objects;
CREATE POLICY "Providers can delete own provider images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'provider-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    );

-- ==========================================================
-- 4. Storage Policies: service-images
-- Path Structure: <user_id>/services/<timestamp>-<filename>.<ext>
-- ==========================================================
DROP POLICY IF EXISTS "Public can view service images" ON storage.objects;
CREATE POLICY "Public can view service images" ON storage.objects
    FOR SELECT USING (bucket_id = 'service-images');

DROP POLICY IF EXISTS "Providers can upload service images" ON storage.objects;
CREATE POLICY "Providers can upload service images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'service-images' 
        AND auth.role() = 'authenticated'
        AND (
            public.is_provider() 
            OR public.is_admin() 
            OR auth.uid()::text = (storage.foldername(name))[1]
            OR auth.uid()::text = owner::text
            OR (storage.foldername(name))[1] = 'services'
        )
    );

DROP POLICY IF EXISTS "Providers can update own service images" ON storage.objects;
CREATE POLICY "Providers can update own service images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'service-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    )
    WITH CHECK (
        bucket_id = 'service-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    );

DROP POLICY IF EXISTS "Providers can delete own service images" ON storage.objects;
CREATE POLICY "Providers can delete own service images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'service-images'
        AND auth.role() = 'authenticated'
        AND (
            auth.uid()::text = owner::text 
            OR auth.uid()::text = (storage.foldername(name))[1] 
            OR public.is_admin()
        )
    );
