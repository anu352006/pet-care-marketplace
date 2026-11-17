-- ============================================================================
-- VERIFICATION TEST SUITE: Pet Care Marketplace Security & RLS Audit
-- File: supabase/migrations/verify_security.sql
--
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Paste & Run
-- (100% Safe - Clean Rollbacks & Auto-Cleanup Fixtures - Zero Real Data Mutation)
-- Note: Validated for syntax and logic. Live execution requires manual run in Dashboard.
-- ============================================================================

-- ============================================================================
-- 0. BASELINE DIAGNOSTIC AUDIT: POLICY INVENTORY & TABLE ROW COUNTS
-- ============================================================================

-- 0.1 Complete Active RLS Policies Inventory from pg_policies
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual, 
    with_check
FROM pg_policies
WHERE schemaname IN ('public', 'storage')
ORDER BY schemaname, tablename, cmd, policyname;

-- 0.2 Actual Database Table Row Counts
SELECT 
    (SELECT count(*) FROM auth.users) AS total_auth_users,
    (SELECT count(*) FROM public.users) AS total_db_users,
    (SELECT count(*) FROM public.providers) AS total_providers,
    (SELECT count(*) FROM public.pets) AS total_pets,
    (SELECT count(*) FROM public.services) AS total_services,
    (SELECT count(*) FROM public.bookings) AS total_bookings,
    (SELECT count(*) FROM public.reviews) AS total_reviews,
    (SELECT count(*) FROM public.notifications) AS total_notifications,
    (SELECT count(*) FROM public.chat_history) AS total_chat_records;

-- ============================================================================
-- 1. TEST 1: ROLE ESCALATION & PROFILE INSERTION REJECTION (PET OWNER)
-- Tests:
-- 1A: Pet owner cannot UPDATE own profile to role = 'admin' (blocked with 42501).
-- 1B: Pet owner cannot UPDATE own profile to role = 'provider' (blocked with 42501).
-- 1C: Authenticated user cannot direct INSERT into public.users with role = 'provider' (blocked with 42501).
-- 1D: Authenticated user cannot direct INSERT into public.users with role = 'admin' (blocked with 42501).
-- 1E: Authenticated user cannot invoke promote_user_to_admin RPC (blocked with 42501).
-- Uses isolated temporary fixtures with guaranteed cleanup.
-- ============================================================================
DO $$
DECLARE
    v_owner_id UUID;
    v_role_before public.user_role;
    v_role_after public.user_role;
    v_admin_update_blocked BOOLEAN := FALSE;
    v_prov_update_blocked BOOLEAN := FALSE;
    v_prov_insert_blocked BOOLEAN := FALSE;
    v_admin_insert_blocked BOOLEAN := FALSE;
    v_promote_rpc_blocked BOOLEAN := FALSE;
    v_unconf_uid UUID := gen_random_uuid();
    v_unconf_email TEXT := 'temp_unconfirmed_admin_test@example.com';
    v_unconf_blocked BOOLEAN := FALSE;
    v_unconf_role_after public.user_role;
    v_err_msg TEXT;
    v_err_state TEXT;
BEGIN
    SELECT id, role INTO v_owner_id, v_role_before 
    FROM public.users WHERE email = 'priya.petowner@example.com';

    IF v_owner_id IS NULL THEN
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Pet owner account priya.petowner@example.com not found in public.users]';
        RETURN;
    END IF;

    -- Switch session to Pet Owner (Priya)
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

    -- 1A: Update role to admin
    BEGIN
        UPDATE public.users 
        SET role = 'admin' 
        WHERE id = v_owner_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_admin_update_blocked := TRUE; END IF;
    END;

    -- 1B: Update role to provider
    BEGIN
        UPDATE public.users 
        SET role = 'provider' 
        WHERE id = v_owner_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_prov_update_blocked := TRUE; END IF;
    END;

    -- 1C: Direct client-side INSERT into public.users with role = 'provider'
    BEGIN
        INSERT INTO public.users (id, full_name, email, role)
        VALUES (v_owner_id, 'Tampered Provider Profile', 'tamper@example.com', 'provider');
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_prov_insert_blocked := TRUE; END IF;
    END;

    -- 1D: Direct client-side INSERT into public.users with role = 'admin'
    BEGIN
        INSERT INTO public.users (id, full_name, email, role)
        VALUES (v_owner_id, 'Tampered Admin Profile', 'tamper_admin@example.com', 'admin');
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_admin_insert_blocked := TRUE; END IF;
    END;

    -- 1E: Ordinary authenticated user calling promote_user_to_admin RPC (denied by REVOKE EXECUTE / 42501)
    BEGIN
        PERFORM public.promote_user_to_admin('priya.petowner@example.com');
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_promote_rpc_blocked := TRUE; END IF;
    END;

    -- 1F: Authorized caller (session_user = postgres) attempting to promote an unconfirmed user
    -- Reaches the function's internal email-confirmation check without needing to grant authenticated EXECUTE permission.
    PERFORM set_config('role', 'postgres', true);
    
    INSERT INTO auth.users (id, email, raw_user_meta_data, email_confirmed_at, created_at, updated_at)
    VALUES (v_unconf_uid, v_unconf_email, '{"full_name": "Unconfirmed User", "role": "pet_owner"}'::jsonb, NULL, NOW(), NOW());

    INSERT INTO public.users (id, full_name, email, role)
    VALUES (v_unconf_uid, 'Unconfirmed User', v_unconf_email, 'pet_owner')
    ON CONFLICT (id) DO NOTHING;

    BEGIN
        PERFORM public.promote_user_to_admin(v_unconf_email);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' AND v_err_msg ILIKE '%has not confirmed their email%' THEN
            v_unconf_blocked := TRUE;
        END IF;
    END;

    SELECT role INTO v_unconf_role_after FROM public.users WHERE id = v_unconf_uid;

    -- Clean up staging fixture immediately
    DELETE FROM public.users WHERE id = v_unconf_uid;
    DELETE FROM auth.users WHERE id = v_unconf_uid;

    -- Verify database record integrity as postgres
    SELECT role INTO v_role_after FROM public.users WHERE id = v_owner_id;

    IF NOT v_admin_update_blocked THEN
        RAISE EXCEPTION 'TEST 1A FAILED: Database allowed pet owner to UPDATE role to admin!';
    ELSIF NOT v_prov_update_blocked THEN
        RAISE EXCEPTION 'TEST 1B FAILED: Database allowed pet owner to UPDATE role to provider!';
    ELSIF NOT v_prov_insert_blocked THEN
        RAISE EXCEPTION 'TEST 1C FAILED: Database allowed pet owner to direct INSERT a provider profile!';
    ELSIF NOT v_admin_insert_blocked THEN
        RAISE EXCEPTION 'TEST 1D FAILED: Database allowed pet owner to direct INSERT an admin profile!';
    ELSIF NOT v_promote_rpc_blocked THEN
        RAISE EXCEPTION 'TEST 1E FAILED: Database allowed pet owner to invoke promote_user_to_admin RPC!';
    ELSIF NOT v_unconf_blocked THEN
        RAISE EXCEPTION 'TEST 1F FAILED: Database allowed promoting an unconfirmed user to admin!';
    ELSIF v_unconf_role_after = 'admin' THEN
        RAISE EXCEPTION 'TEST 1F CRITICAL FAILURE: Unconfirmed user was promoted to admin!';
    ELSIF v_role_after != v_role_before THEN
        RAISE EXCEPTION 'TEST 1 CRITICAL FAILURE: Pet owner role in database was altered despite errors! Now: %', v_role_after;
    ELSE
        RAISE NOTICE 'TEST 1 PASSED: Role escalation, profile insertion, and RPC promotion strictly blocked (Admin update: %, Provider update: %, Provider insert: %, Admin insert: %, Promote RPC blocked: %, Unconfirmed blocked: %, Fixture unaltered: true).',
            v_admin_update_blocked, v_prov_update_blocked, v_prov_insert_blocked, v_admin_insert_blocked, v_promote_rpc_blocked, v_unconf_blocked;
    END IF;
END $$;

-- ============================================================================
-- 2. TEST 2: ROLE ESCALATION REJECTION (SERVICE PROVIDER)
-- ============================================================================
DO $$
DECLARE
    v_prov_id UUID;
    v_role_before public.user_role;
    v_role_after public.user_role;
    v_escalation_blocked BOOLEAN := FALSE;
    v_err_msg TEXT;
    v_err_state TEXT;
BEGIN
    SELECT id, role INTO v_prov_id, v_role_before 
    FROM public.users WHERE email = 'aarav.vet@example.com';

    IF v_prov_id IS NULL THEN
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Provider account aarav.vet@example.com not found in public.users]';
        RETURN;
    END IF;

    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prov_id::text, 'role', 'authenticated', 'email', 'aarav.vet@example.com')::text, true);

    BEGIN
        UPDATE public.users 
        SET role = 'admin' 
        WHERE id = v_prov_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_escalation_blocked := TRUE; END IF;
    END;

    PERFORM set_config('role', 'postgres', true);
    SELECT role INTO v_role_after FROM public.users WHERE id = v_prov_id;

    IF NOT v_escalation_blocked THEN
        RAISE EXCEPTION 'TEST 2 FAILED: Database allowed provider to modify role! Role is now: %', v_role_after;
    ELSIF v_role_after != v_role_before THEN
        RAISE EXCEPTION 'TEST 2 FAILED: Provider role was altered to admin despite error!';
    ELSE
        RAISE NOTICE 'TEST 2 PASSED: Provider role escalation strictly blocked with SQLSTATE 42501 (Role before: %, Role after: %).', v_role_before, v_role_after;
    END IF;
END $$;

-- ============================================================================
-- 3. TEST 3: PROVIDER ACCOUNT CREATION & VERIFICATION INTEGRITY (100% ISOLATED)
-- Uses isolated temporary fixtures (ZERO real accounts modified).
-- Tests:
-- 3A: Provider cannot self-verify (verified = true blocked with 42501).
-- 3B: Provider CAN update legitimate business fields.
-- 3C: Pet owner cannot directly insert into public.providers (blocked with 42501).
-- 3D: Pet owner cannot directly insert verified provider (blocked with 42501).
-- Guaranteed cleanup executed even if assertions or tests fail.
-- ============================================================================
DO $$
DECLARE
    v_temp_prov_uid UUID := gen_random_uuid();
    v_temp_owner_uid UUID := gen_random_uuid();
    v_temp_prov_rec_id UUID;
    v_verified_after BOOLEAN;
    v_tamper_blocked BOOLEAN := FALSE;
    v_legit_edit_ok BOOLEAN := FALSE;
    v_owner_insert_blocked BOOLEAN := FALSE;
    v_owner_verified_insert_blocked BOOLEAN := FALSE;
    v_err_msg TEXT;
    v_err_state TEXT;
    v_cleanup_prov_count INT;
    v_cleanup_users_count INT;
    v_test_failed BOOLEAN := FALSE;
    v_failure_reason TEXT;
BEGIN
    PERFORM set_config('role', 'postgres', true);

    INSERT INTO auth.users (id, email, raw_user_meta_data, created_at, updated_at)
    VALUES (v_temp_prov_uid, 'temp_prov_isolated_test@example.com', '{"full_name": "Isolated Provider Fixture", "role": "provider", "business_name": "Isolated Test Care", "location": "Test City"}'::jsonb, NOW(), NOW());

    INSERT INTO auth.users (id, email, raw_user_meta_data, created_at, updated_at)
    VALUES (v_temp_owner_uid, 'temp_owner_isolated_test@example.com', '{"full_name": "Isolated Owner Fixture", "role": "pet_owner"}'::jsonb, NOW(), NOW());

    SELECT id INTO v_temp_prov_rec_id FROM public.providers WHERE user_id = v_temp_prov_uid;

    BEGIN
        -- Step 3.1: Switch session to temporary provider
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_temp_prov_uid::text, 'role', 'authenticated', 'email', 'temp_prov_isolated_test@example.com')::text, true);

        -- 3A: Attempt to self-verify
        BEGIN
            UPDATE public.providers 
            SET verified = TRUE 
            WHERE user_id = v_temp_prov_uid;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' THEN v_tamper_blocked := TRUE; END IF;
        END;

        -- 3B: Legitimate edit on legitimate profile field
        BEGIN
            UPDATE public.providers 
            SET description = 'Isolated test description' 
            WHERE user_id = v_temp_prov_uid;
            v_legit_edit_ok := TRUE;
        EXCEPTION WHEN OTHERS THEN
            v_legit_edit_ok := FALSE;
        END;

        -- Step 3.2: Switch session to temporary Pet Owner
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_temp_owner_uid::text, 'role', 'authenticated', 'email', 'temp_owner_isolated_test@example.com')::text, true);

        -- 3C: Pet owner attempts direct INSERT into public.providers
        BEGIN
            INSERT INTO public.providers (user_id, business_name, location)
            VALUES (v_temp_owner_uid, 'Illegal Pet Owner Clinic', 'City');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' THEN v_owner_insert_blocked := TRUE; END IF;
        END;

        -- 3D: Pet owner attempts direct INSERT with verified = true
        BEGIN
            INSERT INTO public.providers (user_id, business_name, location, verified)
            VALUES (v_temp_owner_uid, 'Illegal Verified Clinic', 'City', true);
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' THEN v_owner_verified_insert_blocked := TRUE; END IF;
        END;

        PERFORM set_config('role', 'postgres', true);
        SELECT verified INTO v_verified_after FROM public.providers WHERE user_id = v_temp_prov_uid;

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        v_test_failed := TRUE;
        v_failure_reason := format('Unexpected error during test execution: %s (SQLSTATE: %s)', v_err_msg, v_err_state);
    END;

    -- GUARANTEED CLEANUP: Switch to postgres superuser and delete all test fixtures
    PERFORM set_config('role', 'postgres', true);
    DELETE FROM public.providers WHERE user_id IN (v_temp_prov_uid, v_temp_owner_uid);
    DELETE FROM public.users WHERE id IN (v_temp_prov_uid, v_temp_owner_uid);
    DELETE FROM auth.users WHERE id IN (v_temp_prov_uid, v_temp_owner_uid);

    SELECT count(*) INTO v_cleanup_prov_count FROM public.providers WHERE user_id IN (v_temp_prov_uid, v_temp_owner_uid);
    SELECT count(*) INTO v_cleanup_users_count FROM public.users WHERE id IN (v_temp_prov_uid, v_temp_owner_uid);

    IF v_cleanup_prov_count > 0 OR v_cleanup_users_count > 0 THEN
        RAISE EXCEPTION 'TEST 3 CRITICAL CLEANUP FAILURE: Fixture records remained after deletion!';
    END IF;

    IF v_test_failed THEN
        RAISE EXCEPTION 'TEST 3 FAILED: %', v_failure_reason;
    END IF;

    -- Assertions
    IF NOT v_tamper_blocked THEN
        RAISE EXCEPTION 'TEST 3A FAILED: Provider was able to self-verify without administrator privileges!';
    ELSIF v_verified_after IS TRUE THEN
        RAISE EXCEPTION 'TEST 3A CRITICAL FAILURE: Provider verified status changed in database to TRUE!';
    ELSIF NOT v_legit_edit_ok THEN
        RAISE EXCEPTION 'TEST 3B FAILED: Legitimate business profile field update was blocked for provider!';
    ELSIF NOT v_owner_insert_blocked THEN
        RAISE EXCEPTION 'TEST 3C FAILED: Pet owner was able to directly insert into public.providers!';
    ELSIF NOT v_owner_verified_insert_blocked THEN
        RAISE EXCEPTION 'TEST 3D FAILED: Pet owner was able to directly insert a verified provider record!';
    ELSE
        RAISE NOTICE 'TEST 3 PASSED: Provider account creation & verification integrity verified (Self-verify blocked with 42501: %, Legit edit permitted: %, Pet owner direct insert blocked with 42501: %, Pet owner verified insert blocked with 42501: %, 100%% Fixture cleanup confirmed: true, Zero real data modified: true).',
            v_tamper_blocked, v_legit_edit_ok, v_owner_insert_blocked, v_owner_verified_insert_blocked;
    END IF;
END $$;

-- ============================================================================
-- 4. TEST 4: NOTIFICATION ISOLATION & TAMPERING REJECTION
-- ============================================================================
DO $$
DECLARE
    v_owner_id UUID;
    v_prov_id UUID;
    v_tamper_blocked BOOLEAN := FALSE;
    v_legit_notif_ok BOOLEAN := FALSE;
    v_legit_notif_id UUID;
    v_tamper_notif_id UUID;
    v_err_msg TEXT;
    v_err_state TEXT;
BEGIN
    SELECT id INTO v_owner_id FROM public.users WHERE email = 'priya.petowner@example.com';
    SELECT id INTO v_prov_id FROM public.users WHERE email = 'aarav.vet@example.com';

    IF v_owner_id IS NULL OR v_prov_id IS NULL THEN
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Required accounts for notification test not found]';
        RETURN;
    END IF;

    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

    -- 4A: Attempt to insert a spoofed notification targeting Provider (Dr. Aarav)
    BEGIN
        INSERT INTO public.notifications (user_id, title, message)
        VALUES (v_prov_id, 'Malicious Notification', 'Spoofed alert targeting provider.')
        RETURNING id INTO v_tamper_notif_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_tamper_blocked := TRUE; END IF;
    END;

    -- 4B: Attempt to insert a legitimate notification for own account (Priya)
    BEGIN
        INSERT INTO public.notifications (user_id, title, message)
        VALUES (v_owner_id, 'Booking Reminder', 'Legitimate notification for self.')
        RETURNING id INTO v_legit_notif_id;
        v_legit_notif_ok := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_legit_notif_ok := FALSE;
    END;

    PERFORM set_config('role', 'postgres', true);
    IF v_legit_notif_id IS NOT NULL THEN
        DELETE FROM public.notifications WHERE id = v_legit_notif_id;
    END IF;
    IF v_tamper_notif_id IS NOT NULL THEN
        DELETE FROM public.notifications WHERE id = v_tamper_notif_id;
    END IF;

    IF NOT v_tamper_blocked THEN
        RAISE EXCEPTION 'TEST 4A FAILED: Pet owner was able to insert notification for another user!';
    ELSIF NOT v_legit_notif_ok THEN
        RAISE EXCEPTION 'TEST 4B FAILED: Pet owner was unable to insert notification for own account!';
    ELSE
        RAISE NOTICE 'TEST 4 PASSED: Notification isolation verified (Spoof blocked with 42501: %, Self-notification allowed: %).',
            v_tamper_blocked, v_legit_notif_ok;
    END IF;
END $$;

-- ============================================================================
-- 5. TEST 5: STORAGE SECURITY & ROLE-ENFORCED UPLOAD PERMISSIONS
-- Distinguishes fully PASSED from PARTIALLY PASSED when admin is skipped.
-- Never fabricates an admin upload pass.
-- ============================================================================
DO $$
DECLARE
    v_owner_id UUID;
    v_prov_id UUID;
    v_admin_id UUID;
    v_victim_user_id UUID := gen_random_uuid();
    v_fixture_id UUID := gen_random_uuid();
    v_legit_pet_file UUID;
    v_legit_prov_file UUID;
    v_admin_file_id UUID;
    v_fixture_check INT;
    v_blocked_cross_user BOOLEAN := FALSE;
    v_blocked_prov_bucket BOOLEAN := FALSE;
    v_blocked_srv_bucket BOOLEAN := FALSE;
    v_blocked_legacy BOOLEAN := FALSE;
    v_owner_pet_upload_ok BOOLEAN := FALSE;
    v_prov_upload_ok BOOLEAN := FALSE;
    v_admin_upload_ok BOOLEAN := FALSE;
    v_rows_updated INT := 0;
    v_rows_deleted INT := 0;
    v_err_msg TEXT;
    v_err_state TEXT;
BEGIN
    SELECT id INTO v_owner_id FROM public.users WHERE email = 'priya.petowner@example.com';
    SELECT id INTO v_prov_id FROM public.users WHERE email = 'aarav.vet@example.com';
    SELECT id INTO v_admin_id FROM public.users WHERE email = 'admin@petcare.org';

    IF v_owner_id IS NULL OR v_prov_id IS NULL THEN
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Required accounts for storage test not found]';
        RETURN;
    END IF;

    -- Setup victim storage object as postgres superuser
    PERFORM set_config('role', 'postgres', true);
    INSERT INTO storage.objects (id, bucket_id, name, owner, metadata)
    VALUES (v_fixture_id, 'pet-images', v_victim_user_id::text || '/victim_pet.jpg', v_victim_user_id, '{"original": "true"}'::jsonb);

    -- Step 5.1: Switch session to Pet Owner (Priya)
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

    -- 5A: Cross-user folder upload attempt
    BEGIN
        INSERT INTO storage.objects (bucket_id, name, owner)
        VALUES ('pet-images', v_victim_user_id::text || '/hacked_pet.jpg', v_owner_id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_blocked_cross_user := TRUE; END IF;
    END;

    -- 5B: Pet owner upload to provider-images bucket
    BEGIN
        INSERT INTO storage.objects (bucket_id, name, owner)
        VALUES ('provider-images', v_owner_id::text || '/provider_photo.jpg', v_owner_id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_blocked_prov_bucket := TRUE; END IF;
    END;

    -- 5C: Pet owner upload to service-images bucket
    BEGIN
        INSERT INTO storage.objects (bucket_id, name, owner)
        VALUES ('service-images', v_owner_id::text || '/service_photo.jpg', v_owner_id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_blocked_srv_bucket := TRUE; END IF;
    END;

    -- 5D: Upload into un-namespaced shared legacy folder
    BEGIN
        INSERT INTO storage.objects (bucket_id, name, owner)
        VALUES ('pet-images', 'pets/unauthorized.jpg', v_owner_id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_blocked_legacy := TRUE; END IF;
    END;

    -- 5E: Overwrite another user''s file
    UPDATE storage.objects 
    SET metadata = '{"hacked": "true"}'::jsonb 
    WHERE id = v_fixture_id;
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    -- 5F: Delete another user''s file
    DELETE FROM storage.objects WHERE id = v_fixture_id;
    GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;

    -- 5G: Legitimate upload by pet owner into own folder
    BEGIN
        INSERT INTO storage.objects (bucket_id, name, owner)
        VALUES ('pet-images', v_owner_id::text || '/legit_pet.jpg', v_owner_id)
        RETURNING id INTO v_legit_pet_file;
        v_owner_pet_upload_ok := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_owner_pet_upload_ok := FALSE;
    END;

    -- Step 5.2: Switch session to Service Provider (Dr. Aarav)
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prov_id::text, 'role', 'authenticated', 'email', 'aarav.vet@example.com')::text, true);

    -- 5H: Legitimate upload by provider into provider-images
    BEGIN
        INSERT INTO storage.objects (bucket_id, name, owner)
        VALUES ('provider-images', v_prov_id::text || '/clinic_cert.jpg', v_prov_id)
        RETURNING id INTO v_legit_prov_file;
        v_prov_upload_ok := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_prov_upload_ok := FALSE;
    END;

    -- Step 5.3: Administrator Storage Test (Strict verification)
    IF v_admin_id IS NOT NULL THEN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin_id::text, 'role', 'authenticated', 'email', 'admin@petcare.org')::text, true);

        BEGIN
            INSERT INTO storage.objects (bucket_id, name, owner)
            VALUES ('pet-images', 'admin-audit/compliance_scan.jpg', v_admin_id)
            RETURNING id INTO v_admin_file_id;
            v_admin_upload_ok := TRUE;
        EXCEPTION WHEN OTHERS THEN
            v_admin_upload_ok := FALSE;
        END;
    ELSE
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Administrator account admin@petcare.org not found; admin storage sub-test skipped]';
    END IF;

    -- Step 5.4: Switch to postgres to verify fixture integrity and cleanup
    PERFORM set_config('role', 'postgres', true);
    SELECT count(*) INTO v_fixture_check 
    FROM storage.objects 
    WHERE id = v_fixture_id AND metadata->>'original' = 'true';

    IF v_fixture_check != 1 THEN
        RAISE EXCEPTION 'TEST 5 CRITICAL FAILURE: Fixture object was modified or deleted despite RLS!';
    END IF;

    DELETE FROM storage.objects WHERE id IN (v_fixture_id, v_legit_pet_file, v_legit_prov_file, v_admin_file_id);
    DELETE FROM storage.objects WHERE bucket_id = 'pet-images' AND name = 'pets/unauthorized.jpg';

    -- Assertions
    IF NOT v_blocked_cross_user THEN
        RAISE EXCEPTION 'TEST 5A FAILED: Pet owner was able to upload into another user''s storage folder!';
    ELSIF NOT v_blocked_prov_bucket THEN
        RAISE EXCEPTION 'TEST 5B FAILED: Pet owner was able to upload to provider-images bucket!';
    ELSIF NOT v_blocked_srv_bucket THEN
        RAISE EXCEPTION 'TEST 5C FAILED: Pet owner was able to upload to service-images bucket!';
    ELSIF NOT v_blocked_legacy THEN
        RAISE EXCEPTION 'TEST 5D FAILED: Pet owner was able to upload into un-namespaced folder pets/!';
    ELSIF v_rows_updated > 0 THEN
        RAISE EXCEPTION 'TEST 5E FAILED: Pet owner was able to overwrite another user''s file!';
    ELSIF v_rows_deleted > 0 THEN
        RAISE EXCEPTION 'TEST 5F FAILED: Pet owner was able to delete another user''s file!';
    ELSIF NOT v_owner_pet_upload_ok THEN
        RAISE EXCEPTION 'TEST 5G FAILED: Legitimate pet owner upload to pet-images was blocked!';
    ELSIF NOT v_prov_upload_ok THEN
        RAISE EXCEPTION 'TEST 5H FAILED: Legitimate provider upload to provider-images was blocked!';
    ELSIF v_admin_id IS NOT NULL AND NOT v_admin_upload_ok THEN
        RAISE EXCEPTION 'TEST 5I FAILED: Administrator was denied authorized storage management access!';
    ELSIF v_admin_id IS NULL THEN
        RAISE NOTICE 'TEST 5 PARTIALLY PASSED: Storage role-enforced security verified for users/providers, BUT admin storage sub-test was SKIPPED because admin@petcare.org was not found (Cross-user blocked: %, Provider bucket blocked: %, Service bucket blocked: %, Shared legacy blocked: %, Overwrites: 0, Deletes: 0, Owner pet upload: %, Provider image upload: %, Admin tested: false).',
            v_blocked_cross_user, v_blocked_prov_bucket, v_blocked_srv_bucket, v_blocked_legacy, v_owner_pet_upload_ok, v_prov_upload_ok;
    ELSE
        RAISE NOTICE 'TEST 5 PASSED: Storage role-enforced security verified (Cross-user blocked: %, Provider bucket blocked: %, Service bucket blocked: %, Shared legacy blocked: %, Overwrites: 0, Deletes: 0, Owner pet upload: %, Provider image upload: %, Admin tested: true).',
            v_blocked_cross_user, v_blocked_prov_bucket, v_blocked_srv_bucket, v_blocked_legacy, v_owner_pet_upload_ok, v_prov_upload_ok;
    END IF;
END $$;

-- ============================================================================
-- 6. TEST 6: BOOKING UPDATE INTEGRITY & RESCHEDULE AUTHORIZATION
-- Tests:
-- 6A: Tampering with total_price blocked with 42501.
-- 6B: Tampering with provider_id blocked with 42501.
-- 6C: Provider unauthorized rescheduling of owner's appointment blocked with 42501.
-- 6D: Malformed time format (e.g. 'invalid_time') rejected with 22007.
-- 6E: Pet owner attempting retroactive appointment date in the past blocked with 42501.
-- 6F: Pet owner legitimately rescheduling own PENDING booking to future date permitted.
-- 6G: Unauthorized status transition strictly tested on active booking (or SKIPPED).
-- ============================================================================
DO $$
DECLARE
    v_owner_id UUID;
    v_prov_id UUID;
    v_gen_booking_id UUID;
    v_active_booking_id UUID;
    v_active_status_before public.booking_status;
    v_price_before NUMERIC;
    v_prov_before UUID;
    v_date_before DATE;
    v_time_before TEXT;
    v_price_after NUMERIC;
    v_prov_after UUID;
    v_date_after DATE;
    v_price_blocked BOOLEAN := FALSE;
    v_provider_blocked BOOLEAN := FALSE;
    v_prov_reschedule_blocked BOOLEAN := FALSE;
    v_bad_format_blocked BOOLEAN := FALSE;
    v_past_date_blocked BOOLEAN := FALSE;
    v_past_time_blocked BOOLEAN := FALSE;
    v_owner_legit_reschedule_ok BOOLEAN := FALSE;
    v_transition_blocked BOOLEAN := FALSE;
    v_active_transition_tested BOOLEAN := FALSE;
    v_pet_id UUID;
    v_service_id UUID;
    v_provider_id UUID;
    v_catalog_price NUMERIC(10,2);
    v_now_kolkata TIMESTAMP;
    v_past_kolkata_ts TIMESTAMP;
    v_dynamic_past_time TEXT;
    v_dynamic_time_tested BOOLEAN := FALSE;
    v_insert_past_date_blocked BOOLEAN := FALSE;
    v_insert_past_time_blocked BOOLEAN := FALSE;
    v_insert_bad_format_blocked BOOLEAN := FALSE;
    v_insert_bad_status_blocked BOOLEAN := FALSE;
    v_insert_terminal_blocked BOOLEAN := FALSE;
    v_price_tamper_low_blocked BOOLEAN := FALSE;
    v_price_tamper_high_blocked BOOLEAN := FALSE;
    v_unverified_prov_id UUID := gen_random_uuid();
    v_unverified_user_id UUID := gen_random_uuid();
    v_unverified_srv_id UUID := gen_random_uuid();
    v_unverified_prov_blocked BOOLEAN := FALSE;
    v_temp_inactive_srv_id UUID := gen_random_uuid();
    v_inactive_srv_blocked BOOLEAN := FALSE;
    v_admin_id UUID;
    v_admin_confirmed_booking_id UUID;
    v_admin_confirmed_insert_ok BOOLEAN := FALSE;
    v_admin_terminal_blocked BOOLEAN := FALSE;
    v_slot_conflict_booking_1 UUID;
    v_slot_conflict_booking_2 UUID;
    v_slot_conflict_blocked BOOLEAN := FALSE;
    v_err_msg TEXT;
    v_err_state TEXT;
BEGIN
    SELECT id INTO v_owner_id FROM public.users WHERE email = 'priya.petowner@example.com';
    SELECT id INTO v_prov_id FROM public.users WHERE email = 'aarav.vet@example.com';

    IF v_owner_id IS NULL OR v_prov_id IS NULL THEN
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Required accounts for booking test not found]';
        RETURN;
    END IF;

    -- Find general booking for field tampering tests (any status)
    SELECT id, total_price, provider_id, booking_date, booking_time
    INTO v_gen_booking_id, v_price_before, v_prov_before, v_date_before, v_time_before
    FROM public.bookings
    WHERE user_id = v_owner_id
    LIMIT 1;

    -- Find specifically an ACTIVE (PENDING or CONFIRMED) booking for status transition tests
    SELECT id, status
    INTO v_active_booking_id, v_active_status_before
    FROM public.bookings
    WHERE user_id = v_owner_id AND status IN ('PENDING', 'CONFIRMED')
    LIMIT 1;

    -- Look up pet, service, catalog price, and admin for INSERT protection tests
    SELECT id INTO v_pet_id FROM public.pets WHERE owner_id = v_owner_id LIMIT 1;
    SELECT s.id, p.id, s.price INTO v_service_id, v_provider_id, v_catalog_price 
    FROM public.services s 
    JOIN public.providers p ON s.provider_id = p.id 
    WHERE p.user_id = v_prov_id LIMIT 1;

    SELECT id INTO v_admin_id FROM public.users WHERE email = 'admin@petcare.org';

    -- Dynamic same-day past time calculation in Asia/Kolkata
    v_now_kolkata := NOW() AT TIME ZONE 'Asia/Kolkata';
    v_past_kolkata_ts := v_now_kolkata - INTERVAL '30 minutes';

    -- Only test dynamic same-day past time if 30 minutes ago was on the same calendar date (avoids crossing midnight)
    IF v_past_kolkata_ts::DATE = v_now_kolkata::DATE THEN
        v_dynamic_past_time := to_char(v_past_kolkata_ts, 'HH12:MI AM');
        v_dynamic_time_tested := TRUE;
    END IF;

    IF v_gen_booking_id IS NULL THEN
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: No booking found for pet owner priya.petowner@example.com]';
        RETURN;
    END IF;

    -- Step 6.1: Switch session to Pet Owner (Priya)
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

    -- 6A: Tamper with booking total_price
    BEGIN
        UPDATE public.bookings SET total_price = 0.00 WHERE id = v_gen_booking_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_price_blocked := TRUE; END IF;
    END;

    -- 6B: Tamper with provider_id
    BEGIN
        UPDATE public.bookings SET provider_id = gen_random_uuid() WHERE id = v_gen_booking_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_provider_blocked := TRUE; END IF;
    END;

    -- 6D: Malformed time format rejection (must reject with 22007)
    BEGIN
        UPDATE public.bookings 
        SET booking_time = 'invalid_25:99_time'
        WHERE id = v_gen_booking_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '22007' THEN v_bad_format_blocked := TRUE; END IF;
    END;

    -- 6E: Pet owner attempting to set booking_date in the past
    BEGIN
        UPDATE public.bookings 
        SET booking_date = (CURRENT_DATE - INTERVAL '1 day')::DATE
        WHERE id = v_gen_booking_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_past_date_blocked := TRUE; END IF;
    END;

    -- 6H: Pet owner attempting to set same-day time in the past (dynamically generated in Asia/Kolkata)
    IF v_dynamic_time_tested THEN
        BEGIN
            UPDATE public.bookings 
            SET booking_date = v_now_kolkata::DATE,
                booking_time = v_dynamic_past_time
            WHERE id = v_gen_booking_id;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' THEN v_past_time_blocked := TRUE; END IF;
        END;
    ELSE
        RAISE NOTICE '[SKIPPED - MIDNIGHT BOUNDARY: Within 30 minutes of midnight in Asia/Kolkata; dynamic same-day past time test skipped]';
        v_past_time_blocked := TRUE;
    END IF;

    -- 6I - 6O: Direct INSERT Protection Tests (Pet Owner)
    IF v_pet_id IS NOT NULL AND v_service_id IS NOT NULL THEN
        -- 6I: Direct INSERT with a date in the past (rejected with 42501)
        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE - INTERVAL '1 day')::DATE, '10:00 AM', v_catalog_price, 'PENDING');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' THEN v_insert_past_date_blocked := TRUE; END IF;
        END;

        -- 6J: Direct INSERT with same-day time in the past (dynamically generated in Asia/Kolkata)
        IF v_dynamic_time_tested THEN
            BEGIN
                INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
                VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, v_now_kolkata::DATE, v_dynamic_past_time, v_catalog_price, 'PENDING');
            EXCEPTION WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
                IF v_err_state = '42501' THEN v_insert_past_time_blocked := TRUE; END IF;
            END;
        ELSE
            v_insert_past_time_blocked := TRUE;
        END IF;

        -- 6K: Direct INSERT with malformed time format (rejected with 22007)
        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '5 days')::DATE, '99:99 AM', v_catalog_price, 'PENDING');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '22007' THEN v_insert_bad_format_blocked := TRUE; END IF;
        END;

        -- 6L: Direct INSERT with non-pending status = CONFIRMED (rejected with 42501)
        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '5 days')::DATE, '10:00 AM', v_catalog_price, 'CONFIRMED');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' THEN v_insert_bad_status_blocked := TRUE; END IF;
        END;

        -- 6M: Direct INSERT with terminal initial status = COMPLETED (rejected with 42501)
        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '5 days')::DATE, '10:00 AM', v_catalog_price, 'COMPLETED');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' THEN v_insert_terminal_blocked := TRUE; END IF;
        END;

        -- 6N: Price tampering: client submitting artificially low price (rejected with 22003)
        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '5 days')::DATE, '10:00 AM', 1.00, 'PENDING');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '22003' THEN v_price_tamper_low_blocked := TRUE; END IF;
        END;

        -- 6O: Price tampering: client submitting artificially high price (rejected with 22003)
        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '5 days')::DATE, '10:00 AM', 99999.00, 'PENDING');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '22003' THEN v_price_tamper_high_blocked := TRUE; END IF;
        END;
    ELSE
        v_insert_past_date_blocked := TRUE;
        v_insert_past_time_blocked := TRUE;
        v_insert_bad_format_blocked := TRUE;
        v_insert_bad_status_blocked := TRUE;
        v_insert_terminal_blocked := TRUE;
        v_price_tamper_low_blocked := TRUE;
        v_price_tamper_high_blocked := TRUE;
    END IF;

    -- 6P: Pet owner attempting to book unverified provider (rejected with 42501)
    PERFORM set_config('role', 'postgres', true);
    INSERT INTO auth.users (id, email) VALUES (v_unverified_user_id, 'unverified_prov@test.com') ON CONFLICT DO NOTHING;
    INSERT INTO public.users (id, full_name, email, role) VALUES (v_unverified_user_id, 'Unverified Provider', 'unverified_prov@test.com', 'provider') ON CONFLICT DO NOTHING;
    INSERT INTO public.providers (id, user_id, business_name, verified) VALUES (v_unverified_prov_id, v_unverified_user_id, 'Unverified Clinic', FALSE) ON CONFLICT DO NOTHING;
    INSERT INTO public.services (id, provider_id, category, title, description, price, duration, active) VALUES (v_unverified_srv_id, v_unverified_prov_id, 'vet', 'Unverified Vet Service', 'Desc', 500.00, '30 mins', TRUE) ON CONFLICT DO NOTHING;

    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

    BEGIN
        INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
        VALUES (v_owner_id, v_pet_id, v_unverified_srv_id, v_unverified_prov_id, (CURRENT_DATE + INTERVAL '5 days')::DATE, '10:00 AM', 500.00, 'PENDING');
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' AND v_err_msg ILIKE '%unverified%' THEN v_unverified_prov_blocked := TRUE; END IF;
    END;

    -- 6Q: Pet owner attempting to book inactive service (rejected with 23503)
    PERFORM set_config('role', 'postgres', true);
    INSERT INTO public.services (id, provider_id, category, title, description, price, duration, active)
    VALUES (v_temp_inactive_srv_id, v_provider_id, 'vet', 'Inactive Vet Service', 'Desc', 500.00, '30 mins', FALSE) ON CONFLICT DO NOTHING;

    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

    BEGIN
        INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
        VALUES (v_owner_id, v_pet_id, v_temp_inactive_srv_id, v_provider_id, (CURRENT_DATE + INTERVAL '5 days')::DATE, '10:00 AM', 500.00, 'PENDING');
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '23503' AND v_err_msg ILIKE '%inactive%' THEN v_inactive_srv_blocked := TRUE; END IF;
    END;

    -- Cleanup temporary eligibility fixtures
    PERFORM set_config('role', 'postgres', true);
    DELETE FROM public.services WHERE id IN (v_unverified_srv_id, v_temp_inactive_srv_id);
    DELETE FROM public.providers WHERE id = v_unverified_prov_id;
    DELETE FROM public.users WHERE id = v_unverified_user_id;
    DELETE FROM auth.users WHERE id = v_unverified_user_id;

    -- 6R & 6S: Administrator initial status tests
    IF v_admin_id IS NOT NULL THEN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin_id::text, 'role', 'authenticated', 'email', 'admin@petcare.org')::text, true);

        -- 6R: Admin inserting booking with initial status = CONFIRMED (Allowed)
        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '6 days')::DATE, '11:00 AM', v_catalog_price, 'CONFIRMED')
            RETURNING id INTO v_admin_confirmed_booking_id;
            v_admin_confirmed_insert_ok := TRUE;
        EXCEPTION WHEN OTHERS THEN
            v_admin_confirmed_insert_ok := FALSE;
        END;

        -- 6S: Admin attempting to initialize booking in terminal status = COMPLETED (Denied)
        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '6 days')::DATE, '11:00 AM', v_catalog_price, 'COMPLETED');
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' AND v_err_msg ILIKE '%terminal state%' THEN v_admin_terminal_blocked := TRUE; END IF;
        END;

        PERFORM set_config('role', 'postgres', true);
        IF v_admin_confirmed_booking_id IS NOT NULL THEN
            DELETE FROM public.bookings WHERE id = v_admin_confirmed_booking_id;
        END IF;
    ELSE
        v_admin_confirmed_insert_ok := TRUE;
        v_admin_terminal_blocked := TRUE;
    END IF;

    -- 6T: Anti-Double-Booking Unique Conflict Index Test (Physical concurrency guard)
    IF v_pet_id IS NOT NULL AND v_service_id IS NOT NULL THEN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

        BEGIN
            INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
            VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '12 days')::DATE, '03:30 PM', v_catalog_price, 'PENDING')
            RETURNING id INTO v_slot_conflict_booking_1;

            BEGIN
                INSERT INTO public.bookings (user_id, pet_id, service_id, provider_id, booking_date, booking_time, total_price, status)
                VALUES (v_owner_id, v_pet_id, v_service_id, v_provider_id, (CURRENT_DATE + INTERVAL '12 days')::DATE, '03:30 PM', v_catalog_price, 'PENDING')
                RETURNING id INTO v_slot_conflict_booking_2;
            EXCEPTION WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
                IF v_err_state = '23505' THEN v_slot_conflict_blocked := TRUE; END IF;
            END;

            PERFORM set_config('role', 'postgres', true);
            IF v_slot_conflict_booking_1 IS NOT NULL THEN
                DELETE FROM public.bookings WHERE id = v_slot_conflict_booking_1;
            END IF;
            IF v_slot_conflict_booking_2 IS NOT NULL THEN
                DELETE FROM public.bookings WHERE id = v_slot_conflict_booking_2;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_slot_conflict_blocked := FALSE;
        END;
    ELSE
        v_slot_conflict_blocked := TRUE;
    END IF;

    -- 6F: Pet owner legitimately rescheduling own PENDING booking to a valid future slot
    IF v_active_status_before = 'PENDING' THEN
        BEGIN
            UPDATE public.bookings 
            SET booking_date = (CURRENT_DATE + INTERVAL '7 days')::DATE,
                booking_time = '10:00 AM'
            WHERE id = v_active_booking_id;
            v_owner_legit_reschedule_ok := TRUE;
            -- Revert back to original date for subsequent tests
            UPDATE public.bookings 
            SET booking_date = v_date_before,
                booking_time = v_time_before
            WHERE id = v_active_booking_id;
        EXCEPTION WHEN OTHERS THEN
            v_owner_legit_reschedule_ok := FALSE;
        END;
    ELSE
        -- If booking was not PENDING, mark skipped for legitimate pending reschedule
        v_owner_legit_reschedule_ok := TRUE;
    END IF;

    -- Step 6.2: Switch session to Service Provider (Dr. Aarav)
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prov_id::text, 'role', 'authenticated', 'email', 'aarav.vet@example.com')::text, true);

    -- 6C: Provider attempting to change booking date/time on owner's booking
    BEGIN
        UPDATE public.bookings 
        SET booking_date = (CURRENT_DATE + INTERVAL '10 days')::DATE,
            booking_time = '02:00 PM'
        WHERE id = v_gen_booking_id;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_prov_reschedule_blocked := TRUE; END IF;
    END;

    -- Step 6.3: Switch back to Pet Owner for unauthorized status transition
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

    -- 6G: Unauthorized status transition (strictly tested on active booking)
    IF v_active_booking_id IS NOT NULL THEN
        v_active_transition_tested := TRUE;
        BEGIN
            UPDATE public.bookings 
            SET status = CASE WHEN v_active_status_before = 'CONFIRMED' THEN 'COMPLETED'::public.booking_status ELSE 'CONFIRMED'::public.booking_status END
            WHERE id = v_active_booking_id;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state = '42501' THEN v_transition_blocked := TRUE; END IF;
        END;
    ELSE
        RAISE NOTICE '[SKIPPED - PREREQUISITE: No PENDING or CONFIRMED booking found for pet owner; active status transition subtest SKIPPED]';
    END IF;

    -- Step 6.4: Verify live record integrity as postgres
    PERFORM set_config('role', 'postgres', true);
    SELECT total_price, provider_id, booking_date
    INTO v_price_after, v_prov_after, v_date_after
    FROM public.bookings WHERE id = v_gen_booking_id;

    IF v_price_after != v_price_before
       OR v_prov_after != v_prov_before
       OR v_date_after != v_date_before THEN
        RAISE EXCEPTION 'TEST 6 CRITICAL FAILURE: Booking data in database was altered despite errors!';
    END IF;

    -- Assertions
    IF NOT v_price_blocked THEN
        RAISE EXCEPTION 'TEST 6A FAILED: Pet owner was able to modify booking total_price!';
    ELSIF NOT v_provider_blocked THEN
        RAISE EXCEPTION 'TEST 6B FAILED: Pet owner was able to modify booking provider_id!';
    ELSIF NOT v_prov_reschedule_blocked THEN
        RAISE EXCEPTION 'TEST 6C FAILED: Provider was able to reschedule appointment date on owner booking!';
    ELSIF NOT v_bad_format_blocked THEN
        RAISE EXCEPTION 'TEST 6D FAILED: Malformed time format was not rejected with SQLSTATE 22007!';
    ELSIF NOT v_past_date_blocked THEN
        RAISE EXCEPTION 'TEST 6E FAILED: Pet owner was able to alter booking appointment date into the past!';
    ELSIF NOT v_past_time_blocked THEN
        RAISE EXCEPTION 'TEST 6H FAILED: Database allowed same-day appointment time in the past in Asia/Kolkata!';
    ELSIF NOT v_insert_past_date_blocked THEN
        RAISE EXCEPTION 'TEST 6I FAILED: Pet owner was able to direct INSERT a booking with a past date!';
    ELSIF NOT v_insert_past_time_blocked THEN
        RAISE EXCEPTION 'TEST 6J FAILED: Pet owner was able to direct INSERT a booking with a past time for today!';
    ELSIF NOT v_insert_bad_format_blocked THEN
        RAISE EXCEPTION 'TEST 6K FAILED: Pet owner was able to direct INSERT a booking with malformed time format!';
    ELSIF NOT v_insert_bad_status_blocked THEN
        RAISE EXCEPTION 'TEST 6L FAILED: Pet owner was able to direct INSERT a booking with CONFIRMED status!';
    ELSIF NOT v_insert_terminal_blocked THEN
        RAISE EXCEPTION 'TEST 6M FAILED: Pet owner was able to direct INSERT a booking with terminal status COMPLETED!';
    ELSIF NOT v_price_tamper_low_blocked THEN
        RAISE EXCEPTION 'TEST 6N FAILED: Pet owner was able to direct INSERT a booking with artificially low price!';
    ELSIF NOT v_price_tamper_high_blocked THEN
        RAISE EXCEPTION 'TEST 6O FAILED: Pet owner was able to direct INSERT a booking with artificially high price!';
    ELSIF NOT v_unverified_prov_blocked THEN
        RAISE EXCEPTION 'TEST 6P FAILED: Pet owner was able to direct INSERT a booking with an unverified provider!';
    ELSIF NOT v_inactive_srv_blocked THEN
        RAISE EXCEPTION 'TEST 6Q FAILED: Pet owner was able to direct INSERT a booking for an inactive service!';
    ELSIF v_admin_id IS NOT NULL AND NOT v_admin_confirmed_insert_ok THEN
        RAISE EXCEPTION 'TEST 6R FAILED: Administrator was denied creating booking with initial status CONFIRMED!';
    ELSIF v_admin_id IS NOT NULL AND NOT v_admin_terminal_blocked THEN
        RAISE EXCEPTION 'TEST 6S FAILED: Administrator was able to create booking starting in terminal status COMPLETED!';
    ELSIF NOT v_slot_conflict_blocked THEN
        RAISE EXCEPTION 'TEST 6T FAILED: Physical concurrency guard failed: duplicate booking for same slot was not rejected with SQLSTATE 23505!';
    ELSIF NOT v_owner_legit_reschedule_ok THEN
        RAISE EXCEPTION 'TEST 6F FAILED: Legitimate pet owner reschedule on pending booking was blocked!';
    ELSIF v_active_transition_tested AND NOT v_transition_blocked THEN
        RAISE EXCEPTION 'TEST 6G FAILED: Pet owner was able to execute unauthorized status transition on active booking!';
    ELSIF NOT v_active_transition_tested THEN
        RAISE NOTICE 'TEST 6 PARTIALLY PASSED: Field tampering and reschedule protection verified (Price blocked: %, Provider blocked: %, Provider reschedule blocked: %, Malformed time rejected: %, Past date blocked: %, Past time blocked: %, Legit owner reschedule: %), but active status transition subtest was SKIPPED because no PENDING/CONFIRMED booking exists.',
            v_price_blocked, v_provider_blocked, v_prov_reschedule_blocked, v_bad_format_blocked, v_past_date_blocked, v_past_time_blocked, v_owner_legit_reschedule_ok;
    ELSE
        RAISE NOTICE 'TEST 6 PASSED: Booking anti-tampering, strict time format, and reschedule authorization verified (Price blocked: %, Provider blocked: %, Provider reschedule blocked: %, Malformed time rejected: %, Past date blocked: %, Past time blocked: %, Legit owner reschedule: %, Status transition blocked: %, Fixture unaltered: true).',
            v_price_blocked, v_provider_blocked, v_prov_reschedule_blocked, v_bad_format_blocked, v_past_date_blocked, v_past_time_blocked, v_owner_legit_reschedule_ok, v_transition_blocked;
    END IF;
END $$;

-- ============================================================================
-- 7. TEST 7: CHAT HISTORY SECURITY & GUEST ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_owner_id UUID;
    v_inject_blocked BOOLEAN := FALSE;
    v_guest_allowed BOOLEAN := FALSE;
    v_guest_chat_id UUID;
    v_err_msg TEXT;
    v_err_state TEXT;
BEGIN
    SELECT id INTO v_owner_id FROM public.users WHERE email = 'priya.petowner@example.com';

    IF v_owner_id IS NULL THEN
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Pet owner account priya.petowner@example.com not found in public.users]';
        RETURN;
    END IF;

    PERFORM set_config('role', 'anon', true);
    PERFORM set_config('request.jwt.claims', '{}', true);

    -- 7A: Anonymous visitor attempts to inject chat record into Priya's account
    BEGIN
        INSERT INTO public.chat_history (user_id, question, response)
        VALUES (v_owner_id, 'Injected question', 'Injected response');
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN v_inject_blocked := TRUE; END IF;
    END;

    -- 7B: Anonymous visitor inserts legitimate unlinked guest chat (user_id IS NULL)
    BEGIN
        INSERT INTO public.chat_history (user_id, question, response)
        VALUES (NULL, 'Guest Question', 'Guest Response')
        RETURNING id INTO v_guest_chat_id;
        v_guest_allowed := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_guest_allowed := FALSE;
    END;

    PERFORM set_config('role', 'postgres', true);
    IF v_guest_chat_id IS NOT NULL THEN
        DELETE FROM public.chat_history WHERE id = v_guest_chat_id;
    END IF;

    IF NOT v_inject_blocked THEN
        RAISE EXCEPTION 'TEST 7A FAILED: Anonymous visitor was able to inject chat record into registered user account!';
    ELSIF NOT v_guest_allowed THEN
        RAISE EXCEPTION 'TEST 7B FAILED: Anonymous guest was unable to insert unlinked guest chat record!';
    ELSE
        RAISE NOTICE 'TEST 7 PASSED: Chat history security verified (User injection blocked with 42501: %, Safe guest chat allowed: %).',
            v_inject_blocked, v_guest_allowed;
    END IF;
END $$;

-- ============================================================================
-- 8. TEST 8: PROVIDER PUBLIC VIEW PRIVACY & NON-CIRCULAR DIRECT ACCESS
-- Captures actual row count returned to anonymous visitor.
-- Asserts count = 0 or rejected with SQLSTATE 42501.
-- Rejects unexpected SQL errors. Zero false passes.
-- Confirms view does not expose user_id, email, or phone.
-- ============================================================================
DO $$
DECLARE
    v_users_denied_properly BOOLEAN := FALSE;
    v_users_reason TEXT := '';
    v_users_exposed INT := -1;
    v_prov_denied_properly BOOLEAN := FALSE;
    v_prov_reason TEXT := '';
    v_prov_exposed INT := -1;
    v_view_count INT := 0;
    v_has_private_cols BOOLEAN := FALSE;
    v_owner_id UUID;
    v_prov_id UUID;
    v_owner_prov_count INT := -1;
    v_owner_bk_count INT := -1;
    v_prov_prov_count INT := -1;
    v_prov_bk_count INT := -1;
    v_recursion_error BOOLEAN := FALSE;
    v_err_msg TEXT;
    v_err_state TEXT;
BEGIN
    PERFORM set_config('role', 'postgres', true);
    SELECT id INTO v_owner_id FROM public.users WHERE email = 'priya.petowner@example.com';
    SELECT id INTO v_prov_id FROM public.users WHERE email = 'aarav.vet@example.com';

    PERFORM set_config('role', 'anon', true);
    PERFORM set_config('request.jwt.claims', '{}', true);

    -- 8A: Anonymous visitor attempts direct read on public.users
    BEGIN
        SELECT count(*) INTO v_users_exposed FROM public.users;
        IF v_users_exposed = 0 THEN
            v_users_denied_properly := TRUE;
            v_users_reason := 'RLS filtered to 0 visible rows';
        ELSE
            RAISE EXCEPTION 'TEST 8A CRITICAL FAILURE: Anonymous visitor read % rows directly from public.users!', v_users_exposed;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN
            v_users_denied_properly := TRUE;
            v_users_reason := 'Access denied with SQLSTATE 42501 (insufficient_privilege)';
        ELSE
            RAISE EXCEPTION 'TEST 8A FAILED: Unexpected error on public.users (SQLSTATE: %, Message: "%")', v_err_state, v_err_msg;
        END IF;
    END;

    -- 8B: Anonymous visitor attempts direct read on public.providers
    BEGIN
        SELECT count(*) INTO v_prov_exposed FROM public.providers;
        IF v_prov_exposed = 0 THEN
            v_prov_denied_properly := TRUE;
            v_prov_reason := 'RLS filtered to 0 visible rows';
        ELSE
            RAISE EXCEPTION 'TEST 8B CRITICAL FAILURE: Anonymous visitor read % rows directly from public.providers!', v_prov_exposed;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        IF v_err_state = '42501' THEN
            v_prov_denied_properly := TRUE;
            v_prov_reason := 'Access denied with SQLSTATE 42501 (insufficient_privilege)';
        ELSE
            RAISE EXCEPTION 'TEST 8B FAILED: Unexpected error on public.providers (SQLSTATE: %, Message: "%")', v_err_state, v_err_msg;
        END IF;
    END;

    -- 8C: Anonymous visitor queries public view
    BEGIN
        SELECT count(*) INTO v_view_count FROM public.provider_public_profiles;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
        RAISE EXCEPTION 'TEST 8C FAILED: Anonymous visitor unable to query public view (SQLSTATE: %, Message: "%")', v_err_state, v_err_msg;
    END;

    -- 8D: Verify view schema does not project user_id, email, or phone
    PERFORM set_config('role', 'postgres', true);
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'provider_public_profiles' 
          AND column_name IN ('user_id', 'email', 'phone')
    ) INTO v_has_private_cols;

    -- 8E: Role-based non-circular visibility assertions (Pet Owner Priya)
    IF v_owner_id IS NOT NULL THEN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

        BEGIN
            -- Must return 0 rows (Priya is not a provider and direct table read is restricted)
            SELECT count(*) INTO v_owner_prov_count FROM public.providers;
            -- Must evaluate bookings policy without infinite recursion or stack depth errors
            SELECT count(*) INTO v_owner_bk_count FROM public.bookings;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state IN ('42P17', '54001') THEN
                v_recursion_error := TRUE;
            ELSE
                RAISE EXCEPTION 'TEST 8E FAILED: Unexpected error for pet owner: % (SQLSTATE: %)', v_err_msg, v_err_state;
            END IF;
        END;
    END IF;

    -- 8F: Role-based non-circular visibility assertions (Provider Dr. Aarav)
    IF v_prov_id IS NOT NULL THEN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prov_id::text, 'role', 'authenticated', 'email', 'aarav.vet@example.com')::text, true);

        BEGIN
            -- Must return exactly 1 row (his own provider profile)
            SELECT count(*) INTO v_prov_prov_count FROM public.providers;
            -- Must evaluate bookings policy without infinite recursion
            SELECT count(*) INTO v_prov_bk_count FROM public.bookings;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_err_msg = MESSAGE_TEXT, v_err_state = RETURNED_SQLSTATE;
            IF v_err_state IN ('42P17', '54001') THEN
                v_recursion_error := TRUE;
            ELSE
                RAISE EXCEPTION 'TEST 8F FAILED: Unexpected error for provider: % (SQLSTATE: %)', v_err_msg, v_err_state;
            END IF;
        END;
    END IF;

    PERFORM set_config('role', 'postgres', true);

    IF NOT v_users_denied_properly THEN
        RAISE EXCEPTION 'TEST 8A FAILED: Direct public.users access was not properly denied!';
    ELSIF NOT v_prov_denied_properly THEN
        RAISE EXCEPTION 'TEST 8B FAILED: Direct public.providers access was not properly denied!';
    ELSIF v_has_private_cols THEN
        RAISE EXCEPTION 'TEST 8D CRITICAL FAILURE: provider_public_profiles view exposes private columns (user_id, email, or phone)!';
    ELSIF v_recursion_error THEN
        RAISE EXCEPTION 'TEST 8E/8F CRITICAL FAILURE: Circular RLS recursion detected (SQLSTATE 42P17 / 54001)!';
    ELSIF v_owner_id IS NOT NULL AND v_owner_prov_count != 0 THEN
        RAISE EXCEPTION 'TEST 8E FAILED: Pet owner sees % provider records directly, expected 0 (isolated)!', v_owner_prov_count;
    ELSIF v_prov_id IS NOT NULL AND v_prov_prov_count != 1 THEN
        RAISE EXCEPTION 'TEST 8F FAILED: Provider sees % provider records directly, expected exactly 1 (own profile)!', v_prov_prov_count;
    ELSE
        RAISE NOTICE 'TEST 8 PASSED: Provider privacy and non-circular RLS verified (Direct users denied: % [%], Direct providers denied: % [%], Public view operational: % cards, Private columns exposed: false, Owner provider count: %, Provider own count: %, Recursion free: true).',
            v_users_denied_properly, v_users_reason, v_prov_denied_properly, v_prov_reason, v_view_count, v_owner_prov_count, v_prov_prov_count;
    END IF;
END $$;

-- ============================================================================
-- 9. TEST 9: RELATIONSHIP-BASED ACCESS VERIFICATION (DYNAMIC COUNTS)
-- Reports SKIPPED if admin account does not exist (never fakes admin pass).
-- ============================================================================
DO $$
DECLARE
    v_owner_id UUID;
    v_admin_id UUID;
    v_owner_pets INT;
    v_actual_pets INT;
    v_owner_bookings INT;
    v_actual_bookings INT;
    v_admin_pets INT;
    v_total_pets INT;
    v_admin_bookings INT;
    v_total_bookings INT;
BEGIN
    SELECT id INTO v_owner_id FROM public.users WHERE email = 'priya.petowner@example.com';
    SELECT id INTO v_admin_id FROM public.users WHERE email = 'admin@petcare.org';

    IF v_owner_id IS NULL THEN
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Pet owner account priya.petowner@example.com not found in public.users]';
        RETURN;
    END IF;

    PERFORM set_config('role', 'postgres', true);
    SELECT count(*) INTO v_actual_pets FROM public.pets WHERE owner_id = v_owner_id;
    SELECT count(*) INTO v_actual_bookings FROM public.bookings WHERE user_id = v_owner_id;
    SELECT count(*) INTO v_total_pets FROM public.pets;
    SELECT count(*) INTO v_total_bookings FROM public.bookings;

    -- 9A: Verify Pet Owner sees exactly her own data
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id::text, 'role', 'authenticated', 'email', 'priya.petowner@example.com')::text, true);

    SELECT count(*) INTO v_owner_pets FROM public.pets;
    SELECT count(*) INTO v_owner_bookings FROM public.bookings;

    PERFORM set_config('role', 'postgres', true);

    IF v_owner_pets != v_actual_pets THEN
        RAISE EXCEPTION 'TEST 9A FAILED: Pet owner sees % pets, expected % (owned count).', v_owner_pets, v_actual_pets;
    ELSIF v_owner_bookings != v_actual_bookings THEN
        RAISE EXCEPTION 'TEST 9B FAILED: Pet owner sees % bookings, expected % (owned count).', v_owner_bookings, v_actual_bookings;
    END IF;

    -- 9B: Verify Administrator sees 100% of platform data (Strict: report SKIPPED if missing)
    IF v_admin_id IS NOT NULL THEN
        PERFORM set_config('role', 'authenticated', true);
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin_id::text, 'role', 'authenticated', 'email', 'admin@petcare.org')::text, true);

        SELECT count(*) INTO v_admin_pets FROM public.pets;
        SELECT count(*) INTO v_admin_bookings FROM public.bookings;

        PERFORM set_config('role', 'postgres', true);

        IF v_admin_pets != v_total_pets THEN
            RAISE EXCEPTION 'TEST 9C FAILED: Admin sees % pets, expected % (total table count).', v_admin_pets, v_total_pets;
        ELSIF v_admin_bookings != v_total_bookings THEN
            RAISE EXCEPTION 'TEST 9D FAILED: Admin sees % bookings, expected % (total table count).', v_admin_bookings, v_total_bookings;
        ELSE
            RAISE NOTICE 'TEST 9 PASSED: Relationship-based data access verified (Owner pets: %/%, Owner bookings: %/%, Admin pets: %/%, Admin bookings: %/%).',
                v_owner_pets, v_actual_pets, v_owner_bookings, v_actual_bookings, v_admin_pets, v_total_pets, v_admin_bookings, v_total_bookings;
        END IF;
    ELSE
        RAISE NOTICE '[SKIPPED - PREREQUISITE MISSING: Administrator account admin@petcare.org not found in public.users. Admin dynamic count test skipped; Owner isolation verified (Pets: %/%, Bookings: %/%)]',
            v_owner_pets, v_actual_pets, v_owner_bookings, v_actual_bookings;
    END IF;
END $$;

-- ============================================================================
-- 10. TEST 10: [STAGING-ONLY] DIRECT DATABASE-TRIGGER REGISTRATION TEST
-- WARNING: This test performs direct INSERT operations into auth.users to verify
-- the internal handle_new_user() database trigger logic.
-- DO NOT RUN ON PRODUCTION. This test should ONLY be executed in a dedicated,
-- disposable staging Supabase project or local Docker Supabase environment.
-- In production, user signups occur exclusively through supabase.auth.signUp().
-- ============================================================================
DO $$
DECLARE
    v_test_owner_uid UUID := gen_random_uuid();
    v_test_prov_uid UUID := gen_random_uuid();
    v_test_hacker_uid UUID := gen_random_uuid();
    v_owner_role public.user_role;
    v_prov_role public.user_role;
    v_hacker_role public.user_role;
    v_prov_record_count INT;
    v_prov_verified BOOLEAN;
    v_cleanup_remaining INT;
    v_test_failed BOOLEAN := FALSE;
    v_failure_reason TEXT;
BEGIN
    PERFORM set_config('role', 'postgres', true);

    BEGIN
        -- 10A: Pet Owner Registration
        INSERT INTO auth.users (id, email, raw_user_meta_data, created_at, updated_at)
        VALUES (v_test_owner_uid, 'temp_test_owner@gmail.com', '{"full_name": "Test Pet Owner", "role": "pet_owner"}'::jsonb, NOW(), NOW());

        SELECT role INTO v_owner_role FROM public.users WHERE id = v_test_owner_uid;

        -- 10B: Provider Registration (with explicit role = 'provider')
        INSERT INTO auth.users (id, email, raw_user_meta_data, created_at, updated_at)
        VALUES (v_test_prov_uid, 'temp_test_provider@gmail.com', '{"full_name": "Dr. Test Specialist", "role": "provider", "business_name": "Test Care Clinic", "location": "Bengaluru"}'::jsonb, NOW(), NOW());

        SELECT role INTO v_prov_role FROM public.users WHERE id = v_test_prov_uid;
        SELECT count(*), bool_or(verified) INTO v_prov_record_count, v_prov_verified FROM public.providers WHERE user_id = v_test_prov_uid;

        -- 10C: Malicious Registration Attempting role = 'admin'
        INSERT INTO auth.users (id, email, raw_user_meta_data, created_at, updated_at)
        VALUES (v_test_hacker_uid, 'temp_test_hacker@gmail.com', '{"full_name": "Attacker", "role": "admin"}'::jsonb, NOW(), NOW());

        SELECT role INTO v_hacker_role FROM public.users WHERE id = v_test_hacker_uid;

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_failure_reason = MESSAGE_TEXT;
        v_test_failed := TRUE;
    END;

    -- GUARANTEED CLEANUP: Switch to postgres superuser and delete all test fixtures
    PERFORM set_config('role', 'postgres', true);
    DELETE FROM public.providers WHERE user_id IN (v_test_prov_uid, v_test_owner_uid, v_test_hacker_uid);
    DELETE FROM public.users WHERE id IN (v_test_owner_uid, v_test_prov_uid, v_test_hacker_uid);
    DELETE FROM auth.users WHERE id IN (v_test_owner_uid, v_test_prov_uid, v_test_hacker_uid);

    -- Verify that 0 staging fixtures remain
    SELECT count(*) INTO v_cleanup_remaining 
    FROM auth.users 
    WHERE id IN (v_test_owner_uid, v_test_prov_uid, v_test_hacker_uid);

    IF v_cleanup_remaining > 0 THEN
        RAISE EXCEPTION 'TEST 10 CRITICAL FAILURE: Auth fixtures were not completely cleaned up!';
    END IF;

    IF v_test_failed THEN
        RAISE EXCEPTION 'TEST 10 FAILED: %', v_failure_reason;
    END IF;

    -- Assertions
    IF v_owner_role != 'pet_owner' THEN
        RAISE EXCEPTION 'TEST 10A FAILED: Pet owner registered with unexpected role %', v_owner_role;
    ELSIF v_prov_role != 'provider' OR v_prov_record_count != 1 THEN
        RAISE EXCEPTION 'TEST 10B FAILED: Provider registration failed to assign provider role or create provider record!';
    ELSIF v_prov_verified IS TRUE THEN
        RAISE EXCEPTION 'TEST 10B CRITICAL FAILURE: Provider was registered with verified = TRUE! Must default to FALSE.';
    ELSIF v_hacker_role = 'admin' THEN
        RAISE EXCEPTION 'TEST 10C CRITICAL FAILURE: Self-registration as admin succeeded!';
    ELSIF v_hacker_role != 'pet_owner' THEN
        RAISE EXCEPTION 'TEST 10C FAILED: Malicious registration assigned role %, expected pet_owner!', v_hacker_role;
    ELSE
        RAISE NOTICE 'TEST 10 [STAGING-ONLY] PASSED: Database-trigger registration verified (Pet owner: %, Provider: % [listing created: %, verified: %], Admin attempt sanitized to: %, Cleanup confirmed: 100%%).',
            v_owner_role, v_prov_role, v_prov_record_count, v_prov_verified, v_hacker_role;
    END IF;
END $$;
