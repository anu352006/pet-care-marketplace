-- ============================================================================
-- PRODUCTION SECURITY MIGRATION PRE-CHECK SCRIPT (FINAL)
-- Target Project: Production Supabase (Project ID: uuhxfrobjbysasznothx)
-- Mode: 100% READ-ONLY (No data or schema mutations)
-- Purpose: Substantively inspect existing data, policies, functions, views,
--          indexes, constraints, and storage settings prior to migration.
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'STARTING PRODUCTION SECURITY PRE-CHECK (FINAL - READ-ONLY)';
    RAISE NOTICE 'Execution Instant: %', NOW();
    RAISE NOTICE 'Target Supabase Ref: uuhxfrobjbysasznothx';
    RAISE NOTICE '=============================================================';
END $$;

-- ----------------------------------------------------------------------------
-- 1. DATA COMPATIBILITY CHECKS FOR NEW CONSTRAINTS & INDEXES
-- ----------------------------------------------------------------------------

-- Check 1.1: Availability start_time < end_time validation
SELECT 
    'Check 1.1: Availability start_time < end_time' AS test_name,
    COUNT(*) AS violating_rows,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: Zero inverted availability slots found.'
        ELSE 'FAIL: Inverted availability slots exist. Fix required before constraint.'
    END AS verdict
FROM public.availability 
WHERE start_time >= end_time;

-- Check 1.2: Availability duplicate slot check
WITH availability_dupes AS (
    SELECT provider_id, date, start_time, end_time, COUNT(*) AS occurrences
    FROM public.availability
    GROUP BY provider_id, date, start_time, end_time
    HAVING COUNT(*) > 1
)
SELECT 
    'Check 1.2: Availability Duplicate Slot Audit' AS test_name,
    COUNT(*) AS violating_slots,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: Zero duplicate availability slots found.'
        ELSE 'FAIL: Duplicate availability slots found. Resolve duplicates before unique index.'
    END AS verdict
FROM availability_dupes;

-- Check 1.3: Reviews duplicate booking_id check
WITH review_dupes AS (
    SELECT booking_id, COUNT(*) AS occurrences
    FROM public.reviews
    WHERE booking_id IS NOT NULL
    GROUP BY booking_id
    HAVING COUNT(*) > 1
)
SELECT 
    'Check 1.3: Reviews Duplicate Booking Audit' AS test_name,
    COUNT(*) AS violating_reviews,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: Zero duplicate reviews for the same booking.'
        ELSE 'FAIL: Duplicate reviews found for same booking. Resolve before unique index.'
    END AS verdict
FROM review_dupes;

-- ----------------------------------------------------------------------------
-- 2. HISTORICAL BOOKINGS DATA INTEGRITY FOR TRIGGER VALIDATION
-- ----------------------------------------------------------------------------

-- Check 2.1: Price integrity check on historical bookings
SELECT 
    'Check 2.1: Historical Booking Price Integrity' AS test_name,
    COUNT(*) AS price_mismatches,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: All existing bookings match service catalog price.'
        ELSE 'WARNING: Historical price differences exist (will be preserved by trigger).'
    END AS verdict
FROM public.bookings b
JOIN public.services s ON b.service_id = s.id
WHERE b.total_price IS DISTINCT FROM s.price;

-- Check 2.2: Pet ownership verification
SELECT 
    'Check 2.2: Booking Pet Ownership Alignment' AS test_name,
    COUNT(*) AS pet_mismatches,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: All existing bookings have pets matching user_id.'
        ELSE 'WARNING: Bookings found where pet does not belong to booking user.'
    END AS verdict
FROM public.bookings b
JOIN public.pets p ON b.pet_id = p.id
WHERE b.user_id IS DISTINCT FROM p.owner_id;

-- Check 2.3: Provider verification on existing bookings
SELECT 
    'Check 2.3: Booking Provider Verification State' AS test_name,
    COUNT(*) AS unverified_bookings,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: All providers in bookings are verified.'
        ELSE 'WARNING: Bookings exist pointing to unverified providers.'
    END AS verdict
FROM public.bookings b
JOIN public.providers p ON b.provider_id = p.id
WHERE p.verified IS NOT TRUE;

-- ----------------------------------------------------------------------------
-- 3. VERIFY PUBLIC PROVIDER VIEW EXISTENCE & STATE
-- ----------------------------------------------------------------------------
SELECT 
    'Check 3.1: Provider Public View Existence' AS test_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'provider_public_profiles') 
        THEN 'NOTICE: provider_public_profiles already exists. Definition will be replaced.'
        ELSE 'PASS: provider_public_profiles does not exist yet. Safe to create fresh view.'
    END AS verdict;

-- ----------------------------------------------------------------------------
-- 4. INVENTORY OF POLICIES TARGETED FOR REPLACEMENT
-- ----------------------------------------------------------------------------
SELECT 
    schemaname,
    tablename, 
    policyname, 
    cmd,
    'TARGET FOR REPLACEMENT' AS action
FROM pg_policies 
WHERE schemaname = 'public' 
  AND (
    (tablename = 'users' AND policyname = 'Public users profile read') OR
    (tablename = 'users' AND policyname = 'Users can update own profile' AND with_check IS NULL) OR
    (tablename = 'providers' AND policyname = 'Public can view providers') OR
    (tablename = 'providers' AND policyname = 'Provider can insert own profile') OR
    (tablename = 'providers' AND policyname = 'Provider can update own profile') OR
    (tablename = 'reviews' AND policyname = 'Users can insert reviews')
  )
ORDER BY tablename, policyname;

SELECT 
    schemaname,
    tablename, 
    policyname, 
    cmd,
    'STORAGE POLICY TARGET FOR NAMESPACING' AS action
FROM pg_policies 
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname IN (
    'Authenticated users upload pet images',
    'Providers can upload provider images',
    'Providers can upload service images',
    'Users can update their pet images',
    'Users can delete their pet images',
    'Providers can update own provider images',
    'Providers can delete own provider images',
    'Providers can update own service images',
    'Providers can delete own service images'
  )
ORDER BY policyname;

-- ----------------------------------------------------------------------------
-- 5. FUNCTION & TRIGGER PRE-CHECK
-- ----------------------------------------------------------------------------
SELECT 
    p.proname AS function_name,
    p.prosecdef AS is_security_definer,
    p.proconfig AS search_path,
    CASE 
        WHEN p.proconfig @> ARRAY['search_path=pg_catalog, public, auth'] THEN 'PASS: Secure search_path'
        ELSE 'TARGET FOR REPLACEMENT: Insecure or incomplete search_path'
    END AS status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('is_admin', 'is_provider', 'is_owner', 'handle_new_user')
ORDER BY p.proname;

-- ----------------------------------------------------------------------------
-- 6. STORAGE BUCKET LIMITS PRE-CHECK
-- ----------------------------------------------------------------------------
SELECT 
    id AS bucket_id,
    file_size_limit,
    allowed_mime_types,
    CASE 
        WHEN file_size_limit IS NULL THEN 'TARGET FOR UPDATE: Add 5MB limit'
        ELSE 'CONFIGURED'
    END AS size_status,
    CASE 
        WHEN allowed_mime_types IS NULL THEN 'TARGET FOR UPDATE: Add image MIME whitelist'
        ELSE 'CONFIGURED'
    END AS mime_status
FROM storage.buckets
WHERE id IN ('pet-images', 'provider-images', 'service-images')
ORDER BY id;

-- ----------------------------------------------------------------------------
-- 7. BASELINE ROW COUNTS (PRE-MIGRATION RECORD)
-- ----------------------------------------------------------------------------
SELECT 
  (SELECT COUNT(*) FROM public.users) AS baseline_users,
  (SELECT COUNT(*) FROM public.providers) AS baseline_providers,
  (SELECT COUNT(*) FROM public.services) AS baseline_services,
  (SELECT COUNT(*) FROM public.availability) AS baseline_availability,
  (SELECT COUNT(*) FROM public.pets) AS baseline_pets,
  (SELECT COUNT(*) FROM public.bookings) AS baseline_bookings,
  (SELECT COUNT(*) FROM public.reviews) AS baseline_reviews,
  (SELECT COUNT(*) FROM public.notifications) AS baseline_notifications,
  (SELECT COUNT(*) FROM storage.objects) AS baseline_storage_objects;

DO $$
BEGIN
    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'PRE-CHECK (FINAL) COMPLETED. VERIFY ALL CHECKS PASS.';
    RAISE NOTICE '=============================================================';
END $$;
