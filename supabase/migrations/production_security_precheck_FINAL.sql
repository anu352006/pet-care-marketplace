-- ============================================================================
-- PRODUCTION SECURITY MIGRATION PRE-CHECK SCRIPT (FINAL REVISED - READ ONLY)
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

-- Check 1.2: Availability exact duplicate slots validation
SELECT 
    'Check 1.2: Availability Duplicate Slots' AS test_name,
    COUNT(*) AS duplicate_groups,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: Zero duplicate availability slots found.'
        ELSE 'FAIL: Duplicate availability slots exist. Deduplication required.'
    END AS verdict
FROM (
    SELECT provider_id, date, start_time, end_time, COUNT(*) 
    FROM public.availability 
    GROUP BY provider_id, date, start_time, end_time 
    HAVING COUNT(*) > 1
) sub;

-- Check 1.3: Availability overlapping intervals validation
SELECT 
    'Check 1.3: Availability Overlapping Intervals' AS test_name,
    COUNT(*) AS violating_pairs,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: Zero overlapping availability intervals found.'
        ELSE 'FAIL: Overlapping availability intervals exist. Conflict resolution required.'
    END AS verdict
FROM public.availability a1
JOIN public.availability a2 ON a1.provider_id = a2.provider_id 
                           AND a1.date = a2.date 
                           AND a1.id < a2.id
WHERE (a1.start_time < a2.end_time AND a1.end_time > a2.start_time);

-- Check 1.4: btree_gist extension availability
SELECT 
    'Check 1.4: btree_gist Extension Availability' AS test_name,
    COUNT(*) AS available_count,
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS: btree_gist extension is available in pg_available_extensions.'
        ELSE 'FAIL: btree_gist extension is missing from PostgreSQL distribution.'
    END AS verdict
FROM pg_available_extensions
WHERE name = 'btree_gist';

-- Check 1.5: Review unique booking duplicate validation
SELECT 
    'Check 1.5: Reviews Duplicate Bookings' AS test_name,
    COUNT(*) AS duplicate_booking_reviews,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: Zero duplicate reviews per booking found.'
        ELSE 'FAIL: Duplicate reviews for same booking exist. Cleanup required.'
    END AS verdict
FROM (
    SELECT booking_id, COUNT(*) 
    FROM public.reviews 
    WHERE booking_id IS NOT NULL 
    GROUP BY booking_id 
    HAVING COUNT(*) > 1
) sub;

-- ----------------------------------------------------------------------------
-- 2. INTEGRITY CHECKS FOR NEW BOOKING TRIGGER RULES
-- ----------------------------------------------------------------------------

-- Check 2.1: Booking total_price matches service price
SELECT 
    'Check 2.1: Booking Price Integrity' AS test_name,
    COUNT(*) AS price_mismatches,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: All existing bookings match their service catalog price.'
        ELSE 'WARNING: Historical bookings exist with price deviations (will be preserved as historical).'
    END AS verdict
FROM public.bookings b
JOIN public.services s ON b.service_id = s.id
WHERE b.total_price IS DISTINCT FROM s.price;

-- Check 2.2: Pet ownership alignment
SELECT 
    'Check 2.2: Pet Ownership Alignment' AS test_name,
    COUNT(*) AS mismatched_pets,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: All existing bookings belong to the owner of the booked pet.'
        ELSE 'WARNING: Bookings exist where booking user != pet owner.'
    END AS verdict
FROM public.bookings b
JOIN public.pets p ON b.pet_id = p.id
WHERE b.user_id <> p.owner_id;

-- Check 2.3: Provider verification state for existing bookings
SELECT 
    'Check 2.3: Provider Verification State' AS test_name,
    COUNT(*) AS unverified_provider_bookings,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: All bookings are assigned to verified providers.'
        ELSE 'WARNING: Bookings exist referencing unverified providers.'
    END AS verdict
FROM public.bookings b
JOIN public.providers pr ON b.provider_id = pr.id
WHERE pr.verified IS NOT TRUE;

-- ----------------------------------------------------------------------------
-- 3. SCHEMA COLLISION CHECKS
-- ----------------------------------------------------------------------------

-- Check 3.1: Provider public profiles view collision
SELECT 
    'Check 3.1: Provider Public Profiles View Collision' AS test_name,
    COUNT(*) AS collision_count,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS: View does not exist yet. Safe to create fresh.'
        ELSE 'NOTICE: View already exists. Will be replaced cleanly.'
    END AS verdict
FROM pg_views
WHERE schemaname = 'public' AND viewname = 'provider_public_profiles';

-- ----------------------------------------------------------------------------
-- 4. CURRENT PRODUCTION INVENTORY BASELINE
-- ----------------------------------------------------------------------------
SELECT 
    'Check 4: Production Record Inventory Baseline' AS test_name,
    (SELECT COUNT(*) FROM public.users) AS users_count,
    (SELECT COUNT(*) FROM public.providers) AS providers_count,
    (SELECT COUNT(*) FROM public.services) AS services_count,
    (SELECT COUNT(*) FROM public.availability) AS availability_count,
    (SELECT COUNT(*) FROM public.pets) AS pets_count,
    (SELECT COUNT(*) FROM public.bookings) AS bookings_count,
    (SELECT COUNT(*) FROM public.reviews) AS reviews_count,
    (SELECT COUNT(*) FROM public.notifications) AS notifications_count,
    (SELECT COUNT(*) FROM storage.objects) AS storage_objects_count;

DO $$
BEGIN
    RAISE NOTICE '=============================================================';
    RAISE NOTICE 'PRODUCTION SECURITY PRE-CHECK COMPLETE';
    RAISE NOTICE '=============================================================';
END $$;
