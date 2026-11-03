-- ==========================================================
-- SUPABASE STORAGE BUCKET CONFIGURATION & POLICIES
-- Run in Supabase SQL Editor:
-- ==========================================================

-- 1. Create Public Storage Buckets
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('pet-images', 'pet-images', true),
    ('provider-images', 'provider-images', true),
    ('service-images', 'service-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Storage Policies: pet-images
DROP POLICY IF EXISTS "Public can view pet images" ON storage.objects;
CREATE POLICY "Public can view pet images" ON storage.objects
    FOR SELECT USING (bucket_id = 'pet-images');

DROP POLICY IF EXISTS "Authenticated users upload pet images" ON storage.objects;
CREATE POLICY "Authenticated users upload pet images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'pet-images' 
        AND auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "Users can update or delete their pet images" ON storage.objects;
CREATE POLICY "Users can update or delete their pet images" ON storage.objects
    FOR ALL USING (
        bucket_id = 'pet-images'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- 3. Storage Policies: provider-images
DROP POLICY IF EXISTS "Public can view provider images" ON storage.objects;
CREATE POLICY "Public can view provider images" ON storage.objects
    FOR SELECT USING (bucket_id = 'provider-images');

DROP POLICY IF EXISTS "Providers can upload provider images" ON storage.objects;
CREATE POLICY "Providers can upload provider images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'provider-images' 
        AND auth.role() = 'authenticated'
    );

-- 4. Storage Policies: service-images
DROP POLICY IF EXISTS "Public can view service images" ON storage.objects;
CREATE POLICY "Public can view service images" ON storage.objects
    FOR SELECT USING (bucket_id = 'service-images');

DROP POLICY IF EXISTS "Providers can upload service images" ON storage.objects;
CREATE POLICY "Providers can upload service images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'service-images' 
        AND auth.role() = 'authenticated'
    );
