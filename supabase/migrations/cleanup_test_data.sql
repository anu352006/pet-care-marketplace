-- ============================================================================
-- SAFE TARGETED CLEANUP SCRIPT: Production Test Records (Fail-Safe PL/pgSQL v2)
-- File: supabase/migrations/cleanup_test_data.sql
--
-- DO NOT EXECUTE UNTIL EXPLICITLY APPROVED BY USER.
--
-- Enhancements in v2:
-- 1. Explicit Row Locking: Uses SELECT ... FOR UPDATE on all target rows
--    to prevent concurrent modifications or race conditions.
-- 2. Exact Preconditions: Validates exact booking ID, owner ID, pet ID,
--    provider ID, service ID, status = 'COMPLETED', and exact booking_notes.
-- 3. Exact Review Preconditions: Validates review ID, user ID, booking ID,
--    provider ID, service ID, and rating = 5.
-- 4. Provider Description Guard: Asserts current description strictly matches
--    the test-modified string before updating.
-- 5. Foreign Key Dependency Verification: Verifies zero dependent bookings for
--    the service and pet before and after deletions.
-- 6. Post-Cleanup Assertions: Validates all 4 target rows are completely absent
--    and the provider description matches the authentic original text.
-- 7. Transactional Rollback Guarantee: Any failed assertion triggers RAISE EXCEPTION,
--    which instantly aborts the transaction and rolls back all changes.
-- ============================================================================

DO $$
DECLARE
    -- Verified Target UUIDs
    v_target_review_id     UUID := 'd392467f-1099-499d-a9d0-1887ad5cbe31';
    v_target_booking_id    UUID := 'aa362ac1-f671-42a7-9c29-7185ecf7733f';
    v_target_pet_id        UUID := '73649437-f2be-4e8a-9c2f-fb2fed10abd5';
    v_target_service_id    UUID := '52e1c3ae-dc52-4d43-956e-2d608d599720';
    v_target_provider_id   UUID := 'ab5b99cd-ed3c-4fe6-b26f-45240d49a213';
    v_baseline_service_id  UUID := 'abfd51b6-0eb1-4b20-9773-7f7716d254cb';
    v_owner_user_id        UUID := '4fc539a0-2c03-4656-bddb-ad960b90ce19';
    v_provider_user_id     UUID := '5ca2e136-eb1f-4729-b61b-8bb23c54921d';

    -- Exact String Literals for Integrity Guard
    v_expected_notes       TEXT := 'Automated test booking for Bruno LiveTest';
    v_test_modified_desc   TEXT := 'Updated clinic description: Premier veterinary diagnostics and companion wellness center.';
    v_orig_description     TEXT := 'Experienced veterinarian with 12+ years of clinical expertise in canine internal medicine, feline preventative diagnostics, and surgical wellness.';

    -- Diagnostic and Verification Variables
    v_count                INT;
    v_deleted_count        INT;
    v_check_desc           TEXT;
    v_locked_review        RECORD;
    v_locked_booking       RECORD;
    v_locked_pet           RECORD;
    v_locked_service       RECORD;
    v_locked_provider      RECORD;
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'PHASE 1: ROW LOCKING & PRECONDITION VERIFICATION';
    RAISE NOTICE '================================================================';

    -- 1. Lock and Verify Test Review
    SELECT * INTO v_locked_review
    FROM public.reviews
    WHERE id = v_target_review_id
    FOR UPDATE;

    IF v_locked_review.id IS NULL THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Test review % does not exist.', v_target_review_id;
    END IF;

    IF v_locked_review.user_id <> v_owner_user_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Review user_id (%) does not match expected owner (%).', v_locked_review.user_id, v_owner_user_id;
    END IF;

    IF v_locked_review.booking_id <> v_target_booking_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Review booking_id (%) does not match expected booking (%).', v_locked_review.booking_id, v_target_booking_id;
    END IF;

    IF v_locked_review.provider_id <> v_target_provider_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Review provider_id (%) does not match expected provider (%).', v_locked_review.provider_id, v_target_provider_id;
    END IF;

    IF v_locked_review.service_id <> v_baseline_service_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Review service_id (%) does not match expected service (%).', v_locked_review.service_id, v_baseline_service_id;
    END IF;

    IF v_locked_review.rating <> 5 THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Review rating (%) is not 5.', v_locked_review.rating;
    END IF;
    RAISE NOTICE 'Review % verified and locked (rating: 5, user: %)', v_target_review_id, v_owner_user_id;

    -- 2. Lock and Verify Test Booking
    SELECT * INTO v_locked_booking
    FROM public.bookings
    WHERE id = v_target_booking_id
    FOR UPDATE;

    IF v_locked_booking.id IS NULL THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Test booking % does not exist.', v_target_booking_id;
    END IF;

    IF v_locked_booking.user_id <> v_owner_user_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Booking user_id (%) does not match expected owner (%).', v_locked_booking.user_id, v_owner_user_id;
    END IF;

    IF v_locked_booking.pet_id <> v_target_pet_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Booking pet_id (%) does not match expected pet (%).', v_locked_booking.pet_id, v_target_pet_id;
    END IF;

    IF v_locked_booking.provider_id <> v_target_provider_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Booking provider_id (%) does not match expected provider (%).', v_locked_booking.provider_id, v_target_provider_id;
    END IF;

    IF v_locked_booking.service_id <> v_baseline_service_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Booking service_id (%) does not match expected service (%).', v_locked_booking.service_id, v_baseline_service_id;
    END IF;

    IF v_locked_booking.status <> 'COMPLETED' THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Booking status (%) is not COMPLETED.', v_locked_booking.status;
    END IF;

    IF v_locked_booking.booking_notes IS DISTINCT FROM v_expected_notes THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Booking notes ("%") do not exactly match expected ("%").', v_locked_booking.booking_notes, v_expected_notes;
    END IF;
    RAISE NOTICE 'Booking % verified and locked (status: COMPLETED, notes: exact match)', v_target_booking_id;

    -- 3. Lock and Verify Test Pet
    SELECT * INTO v_locked_pet
    FROM public.pets
    WHERE id = v_target_pet_id
    FOR UPDATE;

    IF v_locked_pet.id IS NULL THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Test pet % does not exist.', v_target_pet_id;
    END IF;

    IF v_locked_pet.owner_id <> v_owner_user_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Pet owner_id (%) does not match expected owner (%).', v_locked_pet.owner_id, v_owner_user_id;
    END IF;

    IF v_locked_pet.name <> 'Bruno LiveTest' THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Pet name ("%") is not "Bruno LiveTest".', v_locked_pet.name;
    END IF;

    -- Check for any concurrent non-test bookings referencing this pet
    SELECT COUNT(*) INTO v_count
    FROM public.bookings
    WHERE pet_id = v_target_pet_id
      AND id <> v_target_booking_id;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'CONCURRENCY CONFLICT: Pet % is referenced by % OTHER non-test bookings! Aborting.', v_target_pet_id, v_count;
    END IF;
    RAISE NOTICE 'Pet % verified and locked (owner: %, dependent bookings: exactly 1)', v_target_pet_id, v_owner_user_id;

    -- 4. Lock and Verify Test Service
    SELECT * INTO v_locked_service
    FROM public.services
    WHERE id = v_target_service_id
    FOR UPDATE;

    IF v_locked_service.id IS NULL THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Test service % does not exist.', v_target_service_id;
    END IF;

    IF v_locked_service.provider_id <> v_target_provider_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Service provider_id (%) does not match expected provider (%).', v_locked_service.provider_id, v_target_provider_id;
    END IF;

    IF v_locked_service.title <> 'Advanced Dental Prophylaxis & Scaling' THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Service title ("%") is not "Advanced Dental Prophylaxis & Scaling".', v_locked_service.title;
    END IF;

    -- Check for any bookings referencing this service
    SELECT COUNT(*) INTO v_count
    FROM public.bookings
    WHERE service_id = v_target_service_id;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'CONCURRENCY CONFLICT: Service % is referenced by % bookings! Cannot delete service.', v_target_service_id, v_count;
    END IF;
    RAISE NOTICE 'Service % verified and locked (provider: %, dependent bookings: exactly 0)', v_target_service_id, v_target_provider_id;

    -- 5. Lock and Verify Provider Record and Modified Description
    SELECT * INTO v_locked_provider
    FROM public.providers
    WHERE id = v_target_provider_id
    FOR UPDATE;

    IF v_locked_provider.id IS NULL THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Target provider % does not exist.', v_target_provider_id;
    END IF;

    IF v_locked_provider.user_id <> v_provider_user_id THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Provider user_id (%) does not match expected provider user (%).', v_locked_provider.user_id, v_provider_user_id;
    END IF;

    IF v_locked_provider.description IS DISTINCT FROM v_test_modified_desc THEN
        RAISE EXCEPTION 'PRECONDITION FAILED: Provider current description ("%") does not match expected test-modified text ("%"). Aborting restoration.', 
            v_locked_provider.description, v_test_modified_desc;
    END IF;
    RAISE NOTICE 'Provider % verified and locked (current description: exact test match)', v_target_provider_id;

    RAISE NOTICE '================================================================';
    RAISE NOTICE 'PHASE 2: SAFE SEQUENTIAL DML EXECUTION';
    RAISE NOTICE '================================================================';

    -- STEP 1: Delete Test Review
    DELETE FROM public.reviews
    WHERE id = v_target_review_id
      AND user_id = v_owner_user_id
      AND booking_id = v_target_booking_id
      AND provider_id = v_target_provider_id
      AND service_id = v_baseline_service_id
      AND rating = 5;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Expected 1 review deleted, but % were deleted.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 1 Passed: Review % deleted.', v_target_review_id;

    -- STEP 2: Delete Test Booking
    DELETE FROM public.bookings
    WHERE id = v_target_booking_id
      AND user_id = v_owner_user_id
      AND pet_id = v_target_pet_id
      AND provider_id = v_target_provider_id
      AND service_id = v_baseline_service_id
      AND status = 'COMPLETED';

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Expected 1 booking deleted, but % were deleted.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 2 Passed: Booking % deleted.', v_target_booking_id;

    -- Concurrency check on Pet FK before deletion
    SELECT COUNT(*) INTO v_count FROM public.bookings WHERE pet_id = v_target_pet_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'FOREIGN KEY CONFLICT: Pet % still has % active booking dependencies.', v_target_pet_id, v_count;
    END IF;

    -- STEP 3: Delete Test Pet
    DELETE FROM public.pets
    WHERE id = v_target_pet_id
      AND owner_id = v_owner_user_id
      AND name = 'Bruno LiveTest';

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Expected 1 pet deleted, but % were deleted.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 3 Passed: Pet % deleted.', v_target_pet_id;

    -- Concurrency check on Service FK before deletion
    SELECT COUNT(*) INTO v_count FROM public.bookings WHERE service_id = v_target_service_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'FOREIGN KEY CONFLICT: Service % still has % active booking dependencies.', v_target_service_id, v_count;
    END IF;

    -- STEP 4: Delete Test Service
    DELETE FROM public.services
    WHERE id = v_target_service_id
      AND provider_id = v_target_provider_id
      AND title = 'Advanced Dental Prophylaxis & Scaling';

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Expected 1 service deleted, but % were deleted.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 4 Passed: Service % deleted.', v_target_service_id;

    -- STEP 5: Restore Authentic Provider Description
    UPDATE public.providers
    SET description = v_orig_description
    WHERE id = v_target_provider_id
      AND user_id = v_provider_user_id
      AND description = v_test_modified_desc;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Expected 1 provider updated, but % were updated.', v_deleted_count;
    END IF;
    RAISE NOTICE 'Step 5 Passed: Provider % description restored.', v_target_provider_id;

    RAISE NOTICE '================================================================';
    RAISE NOTICE 'PHASE 3: POST-CLEANUP VERIFICATION & INVARIANT ASSERTIONS';
    RAISE NOTICE '================================================================';

    -- 1. Assert Review is absent
    SELECT COUNT(*) INTO v_count FROM public.reviews WHERE id = v_target_review_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'POST-VERIFICATION FAILED: Review % is still present.', v_target_review_id;
    END IF;

    -- 2. Assert Booking is absent
    SELECT COUNT(*) INTO v_count FROM public.bookings WHERE id = v_target_booking_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'POST-VERIFICATION FAILED: Booking % is still present.', v_target_booking_id;
    END IF;

    -- 3. Assert Pet is absent
    SELECT COUNT(*) INTO v_count FROM public.pets WHERE id = v_target_pet_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'POST-VERIFICATION FAILED: Pet % is still present.', v_target_pet_id;
    END IF;

    -- 4. Assert Service is absent
    SELECT COUNT(*) INTO v_count FROM public.services WHERE id = v_target_service_id;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'POST-VERIFICATION FAILED: Service % is still present.', v_target_service_id;
    END IF;

    -- 5. Assert Provider description strictly matches authentic text
    SELECT description INTO v_check_desc FROM public.providers WHERE id = v_target_provider_id;
    IF v_check_desc IS DISTINCT FROM v_orig_description THEN
        RAISE EXCEPTION 'POST-VERIFICATION FAILED: Provider description does not match authentic text. Found: "%"', v_check_desc;
    END IF;

    RAISE NOTICE 'All 5 post-cleanup invariant assertions passed successfully.';
    RAISE NOTICE 'CLEANUP TRANSACTION VALIDATED: All test records purged, provider restored.';
END $$;
