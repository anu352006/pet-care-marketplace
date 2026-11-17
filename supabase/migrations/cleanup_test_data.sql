-- ============================================================================
-- SAFE TARGETED CLEANUP SCRIPT: Production Test Records (Fail-Safe PL/pgSQL)
-- File: supabase/migrations/cleanup_test_data.sql
--
-- DO NOT EXECUTE UNTIL EXPLICITLY APPROVED BY USER.
--
-- Guarantees:
-- 1. Pre-validates every single record ID, ownership, and foreign key dependency.
-- 2. Checks exact row counts before and after every single operation.
-- 3. Aborts and rolls back the entire transaction if any precondition fails.
-- 4. Restores Dr. Aarav Sharma's authentic provider description.
-- 5. Zero broad DELETEs, zero trigger disabling, zero risk to real customer data.
-- ============================================================================

DO $$
DECLARE
    -- Verified Target UUIDs
    v_target_review_id     UUID := 'd392467f-1099-499d-a9d0-1887ad5cbe31';
    v_target_booking_id    UUID := 'aa362ac1-f671-42a7-9c29-7185ecf7733f';
    v_target_pet_id        UUID := '73649437-f2be-4e8a-9c2f-fb2fed10abd5';
    v_target_service_id    UUID := '52e1c3ae-dc52-4d43-956e-2d608d599720';
    v_target_provider_id   UUID := 'ab5b99cd-ed3c-4fe6-b26f-45240d49a213';
    v_owner_user_id        UUID := '4fc539a0-2c03-4656-bddb-ad960b90ce19';
    v_provider_user_id     UUID := '5ca2e136-eb1f-4729-b61b-8bb23c54921d';

    -- Authentic Pre-Modification Description
    v_orig_description     TEXT := 'Experienced veterinarian with 12+ years of clinical expertise in canine internal medicine, feline preventative diagnostics, and surgical wellness.';

    -- Diagnostic counters
    v_count INT;
    v_deleted_count INT;
BEGIN
    RAISE NOTICE '--- PHASE 1: PRE-VALIDATING TARGET ROWS & DEPENDENCIES ---';

    -- 1. Validate Test Review exists with exact relationships
    SELECT COUNT(*) INTO v_count
    FROM public.reviews
    WHERE id = v_target_review_id
      AND user_id = v_owner_user_id
      AND booking_id = v_target_booking_id
      AND provider_id = v_target_provider_id;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Test review % not found with expected ownership or relationships (found % rows).', v_target_review_id, v_count;
    END IF;

    -- 2. Validate Test Booking exists with exact relationships
    SELECT COUNT(*) INTO v_count
    FROM public.bookings
    WHERE id = v_target_booking_id
      AND user_id = v_owner_user_id
      AND pet_id = v_target_pet_id
      AND provider_id = v_target_provider_id
      AND booking_notes LIKE '%Bruno LiveTest%';

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Test booking % not found with expected relationships (found % rows).', v_target_booking_id, v_count;
    END IF;

    -- 3. Validate Test Pet exists and has NO OTHER bookings besides the test booking
    SELECT COUNT(*) INTO v_count
    FROM public.pets
    WHERE id = v_target_pet_id
      AND owner_id = v_owner_user_id
      AND name = 'Bruno LiveTest';

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Test pet % not found with expected name or owner (found % rows).', v_target_pet_id, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM public.bookings
    WHERE pet_id = v_target_pet_id
      AND id <> v_target_booking_id;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'SAFETY VIOLATION: Test pet % is referenced by % OTHER non-test bookings! Aborting cleanup.', v_target_pet_id, v_count;
    END IF;

    -- 4. Validate Test Service exists and has ZERO dependent bookings
    SELECT COUNT(*) INTO v_count
    FROM public.services
    WHERE id = v_target_service_id
      AND provider_id = v_target_provider_id
      AND title = 'Advanced Dental Prophylaxis & Scaling';

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Test service % not found with expected provider or title (found % rows).', v_target_service_id, v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM public.bookings
    WHERE service_id = v_target_service_id;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'SAFETY VIOLATION: Test service % is referenced by % bookings! Cannot delete service.', v_target_service_id, v_count;
    END IF;

    -- 5. Validate Provider Record exists with exact ID and user_id
    SELECT COUNT(*) INTO v_count
    FROM public.providers
    WHERE id = v_target_provider_id
      AND user_id = v_provider_user_id;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Target provider % not found with user_id %.', v_target_provider_id, v_provider_user_id;
    END IF;

    RAISE NOTICE 'Pre-validation successful. All 5 records and dependencies confirmed.';
    RAISE NOTICE '--- PHASE 2: EXECUTING SAFE SEQUENTIAL CLEANUP ---';

    -- STEP 1: Delete Test Review
    DELETE FROM public.reviews
    WHERE id = v_target_review_id
      AND user_id = v_owner_user_id
      AND booking_id = v_target_booking_id;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ROLLBACK: Expected exactly 1 review deleted, but % were deleted.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 1 Passed: Review % deleted.', v_target_review_id;

    -- STEP 2: Delete Test Booking
    DELETE FROM public.bookings
    WHERE id = v_target_booking_id
      AND user_id = v_owner_user_id
      AND pet_id = v_target_pet_id;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ROLLBACK: Expected exactly 1 booking deleted, but % were deleted.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 2 Passed: Booking % deleted.', v_target_booking_id;

    -- Immediate FK dependency check on Pet
    SELECT COUNT(*) INTO v_count FROM public.bookings WHERE pet_id = v_target_pet_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'ROLLBACK: Pet % still has % active booking dependencies.', v_target_pet_id, v_count;
    END IF;

    -- STEP 3: Delete Test Pet
    DELETE FROM public.pets
    WHERE id = v_target_pet_id
      AND owner_id = v_owner_user_id;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ROLLBACK: Expected exactly 1 pet deleted, but % were deleted.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 3 Passed: Pet % deleted.', v_target_pet_id;

    -- Immediate FK dependency check on Service
    SELECT COUNT(*) INTO v_count FROM public.bookings WHERE service_id = v_target_service_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'ROLLBACK: Service % still has % active booking dependencies.', v_target_service_id, v_count;
    END IF;

    -- STEP 4: Delete Test Service
    DELETE FROM public.services
    WHERE id = v_target_service_id
      AND provider_id = v_target_provider_id;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ROLLBACK: Expected exactly 1 service deleted, but % were deleted.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 4 Passed: Service % deleted.', v_target_service_id;

    -- STEP 5: Restore Authentic Provider Description
    UPDATE public.providers
    SET description = v_orig_description
    WHERE id = v_target_provider_id
      AND user_id = v_provider_user_id;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ROLLBACK: Expected exactly 1 provider updated, but % were updated.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 5 Passed: Provider % description restored to authentic original text.', v_target_provider_id;

    RAISE NOTICE '--- CLEANUP TRANSACTION COMPLETED SAFELY AND VALIDATED ---';
END $$;
