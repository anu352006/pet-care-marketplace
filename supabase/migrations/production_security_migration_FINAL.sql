-- ============================================================================
-- PRODUCTION SECURITY MIGRATION (FINAL - REVISED)
-- Target Project: Production Supabase (Project ID: uuhxfrobjbysasznothx)
-- Mode: PROPOSAL ONLY — DO NOT EXECUTE WITHOUT EXPLICIT USER APPROVAL
-- Author: Antigravity Deepmind Agent
-- Date: November 24, 2026
--
-- Description:
-- Final, comprehensive security migration script for the Pet Care & Services Marketplace:
-- 1. Hardens search_path on all SECURITY DEFINER functions (mitigates search-path hijacking).
-- 2. Eliminates role self-assignment to admin via auth signup metadata in handle_new_user().
-- 3. Installs prevent_user_role_escalation trigger on public.users.
-- 4. Installs prevent_provider_verification_tampering trigger on public.providers.
-- 5. Installs validate_booking_transition_and_fields trigger on public.bookings:
--    - Enforces catalog price match on creation while preserving historical prices on update.
--    - Strict authorization: non-owner/non-provider/non-admin completely blocked (no fall-through).
--    - Validates state machine transitions (pending -> confirmed/rejected -> completed/cancelled).
--    - Validates pet ownership, provider verification, service active state, and date/time.
-- 6. Installs validate_review_integrity trigger on public.reviews:
--    - Enforces that reviews can only be submitted for COMPLETED bookings belonging to author.
--    - Guarantees immutability of user_id, booking_id, provider_id, and service_id on UPDATE.
--    - Restricts updates to author and admin only.
-- 7. Creates sanitized public.provider_public_profiles view (zero private PII exposed).
-- 8. Restricts public.users read access strictly to profile owner and platform administrators.
-- 9. Enforces verified provider status (is_verified_provider) and user folder namespacing
--    along with 5MB file-size limit and image MIME-whitelist on storage buckets.
-- 10. Adds chronological availability check, unique slot index, and unique review index.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1: SEARCH PATH HARDENING ON CORE FUNCTIONS
-- ============================================================================

-- Function 1.1: is_admin() with explicit pg_catalog search path
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$function$;

-- Function 1.2: is_provider() with explicit pg_catalog search path
CREATE OR REPLACE FUNCTION public.is_provider()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role = 'provider'
    );
END;
$function$;

-- Function 1.3: is_verified_provider() helper function
-- Strictly validates that the caller owns an active, verified provider profile
CREATE OR REPLACE FUNCTION public.is_verified_provider()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.providers
        WHERE user_id = auth.uid() AND verified = true
    );
END;
$function$;

-- Function 1.4: is_owner() helper function with explicit pg_catalog search path
CREATE OR REPLACE FUNCTION public.is_owner()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role = 'pet_owner'
    );
END;
$function$;

-- Grant execution privileges on helper functions
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_provider() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_verified_provider() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_owner() TO anon, authenticated, service_role;


-- ============================================================================
-- SECTION 2: SIGNUP ROLE ESCALATION PROTECTION (handle_new_user)
-- ============================================================================

-- Function 2.1: Hardened handle_new_user()
-- Prohibits self-assigning 'admin' through raw signup metadata.
-- Existing users cannot update their role via on-conflict auth metadata.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
    assigned_role public.user_role;
    user_full_name TEXT;
    user_phone TEXT;
    business_title TEXT;
    user_location TEXT;
BEGIN
    -- Determine role from metadata (DISALLOW 'admin' from self-service signup)
    IF LOWER(COALESCE(NEW.raw_user_meta_data->>'role', '')) IN ('provider', 'service_provider') THEN
        assigned_role := 'provider';
    ELSE
        -- Default to pet_owner. 'admin' role CANNOT be self-assigned via metadata.
        assigned_role := 'pet_owner';
    END IF;

    user_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Pet Parent');
    user_phone := NEW.raw_user_meta_data->>'phone';
    business_title := COALESCE(NEW.raw_user_meta_data->>'business_name', user_full_name || '''s Pet Care');
    user_location := COALESCE(NEW.raw_user_meta_data->>'location', NEW.raw_user_meta_data->>'city', 'Bengaluru');

    -- Insert into public.users
    -- ON CONFLICT DO UPDATE updates name and phone only; role is IMMUTABLE here.
    INSERT INTO public.users (id, full_name, email, role, phone)
    VALUES (NEW.id, user_full_name, NEW.email, assigned_role, user_phone)
    ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone;

    -- If provider, create unverified provider profile
    IF assigned_role = 'provider' THEN
        INSERT INTO public.providers (user_id, business_name, location, description, verified)
        VALUES (NEW.id, business_title, user_location, 'Dedicated pet wellness specialist offering high quality care.', false)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$function$;


-- ============================================================================
-- SECTION 3: ROLE ESCALATION & PROVIDER VERIFICATION TRIGGERS
-- ============================================================================

-- Function 3.1: prevent_user_role_escalation()
CREATE OR REPLACE FUNCTION public.prevent_user_role_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    -- INSERT PROTECTION
    IF TG_OP = 'INSERT' THEN
        -- Allow internal Auth trigger execution (GoTrue runs as supabase_auth_admin or postgres)
        IF session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin') OR auth.role() = 'service_role' THEN
            RETURN NEW;
        END IF;

        -- Direct client INSERT: restricted to pet_owner or provider (never admin)
        IF NEW.role NOT IN ('pet_owner'::public.user_role, 'provider'::public.user_role) THEN
            IF NOT public.is_admin() THEN
                RAISE EXCEPTION 'Security Violation: Direct creation of profiles with elevated role (%) is unauthorized.', NEW.role
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        RETURN NEW;
    END IF;

    -- UPDATE PROTECTION: Only administrators or service_role can modify user roles
    IF TG_OP = 'UPDATE' THEN
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            IF NOT (public.is_admin() OR auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin')) THEN
                RAISE EXCEPTION 'Security Violation: You are not authorized to modify user roles.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Security Violation: User account ID is immutable.'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

-- Trigger 3.1: Attach to public.users
DROP TRIGGER IF EXISTS trg_prevent_user_role_escalation ON public.users;
CREATE TRIGGER trg_prevent_user_role_escalation
    BEFORE INSERT OR UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_user_role_escalation();

-- Function 3.2: prevent_provider_verification_tampering()
CREATE OR REPLACE FUNCTION public.prevent_provider_verification_tampering()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    -- Only platform admins or service_role can create pre-verified providers
    IF TG_OP = 'INSERT' THEN
        IF NEW.verified IS TRUE THEN
            IF NOT (public.is_admin() OR auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin')) THEN
                NEW.verified := FALSE;
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    -- Only platform admins or service_role can alter the verification status
    IF TG_OP = 'UPDATE' THEN
        IF NEW.verified IS DISTINCT FROM OLD.verified THEN
            IF NOT (public.is_admin() OR auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin')) THEN
                RAISE EXCEPTION 'Security Violation: Only platform administrators can change provider verification status.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Provider user_id cannot be reassigned
        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Security Violation: Provider user account link is immutable.'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

-- Trigger 3.2: Attach to public.providers
DROP TRIGGER IF EXISTS trg_prevent_provider_verification_tampering ON public.providers;
CREATE TRIGGER trg_prevent_provider_verification_tampering
    BEFORE INSERT OR UPDATE ON public.providers
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_provider_verification_tampering();


-- ============================================================================
-- SECTION 4: SERVER-SIDE BOOKING VALIDATION & TRANSITION TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_booking_transition_and_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
    is_owner_party BOOLEAN;
    is_provider_party BOOLEAN;
    is_admin_actor BOOLEAN;
    booking_prov_user_id UUID;
    v_clean_time TEXT;
    v_appointment_instant TIMESTAMPTZ;
    v_current_marketplace_date DATE;
    v_authoritative_price NUMERIC(10,2);
    v_service_active BOOLEAN;
    v_provider_verified BOOLEAN;
BEGIN
    is_admin_actor := public.is_admin() OR auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin');

    -- ========================================================================
    -- 1. INSERT VALIDATION & PROTECTION (TG_OP = 'INSERT')
    -- ========================================================================
    IF TG_OP = 'INSERT' THEN
        -- Initial Status Authorization
        IF NOT is_admin_actor THEN
            IF NEW.status IS DISTINCT FROM 'PENDING'::public.booking_status THEN
                RAISE EXCEPTION 'Security Violation: New pet owner bookings must be created with PENDING status.'
                    USING ERRCODE = '42501';
            END IF;

            IF auth.uid() IS NULL OR NEW.user_id IS DISTINCT FROM auth.uid() THEN
                RAISE EXCEPTION 'Security Violation: Cannot create a booking on behalf of another user account.'
                    USING ERRCODE = '42501';
            END IF;
        ELSE
            IF NEW.status NOT IN ('PENDING'::public.booking_status, 'CONFIRMED'::public.booking_status) THEN
                RAISE EXCEPTION 'Security Violation: New bookings cannot be initialized in a terminal state (%). Allowed initial states: PENDING, CONFIRMED.', NEW.status
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Universal Pet Ownership Verification
        IF NOT EXISTS (SELECT 1 FROM public.pets WHERE id = NEW.pet_id AND owner_id = NEW.user_id) THEN
            RAISE EXCEPTION 'Security Violation: The designated pet (%) does not belong to the booking user (%).', NEW.pet_id, NEW.user_id
                USING ERRCODE = '42501';
        END IF;

        -- Universal Provider Verification Check
        SELECT verified INTO v_provider_verified
        FROM public.providers 
        WHERE id = NEW.provider_id;

        IF v_provider_verified IS NULL THEN
            RAISE EXCEPTION 'Validation Error: Designated provider profile does not exist.'
                USING ERRCODE = '23503';
        END IF;

        IF NOT v_provider_verified THEN
            RAISE EXCEPTION 'Security Violation: Cannot book appointments with unverified service providers.'
                USING ERRCODE = '42501';
        END IF;

        -- Universal Service Eligibility & Active Status Check
        SELECT price, active INTO v_authoritative_price, v_service_active
        FROM public.services 
        WHERE id = NEW.service_id AND provider_id = NEW.provider_id;

        IF v_authoritative_price IS NULL THEN
            RAISE EXCEPTION 'Validation Error: The selected service does not belong to the designated provider.'
                USING ERRCODE = '23503';
        END IF;

        IF NOT v_service_active THEN
            RAISE EXCEPTION 'Validation Error: The selected service is currently inactive and cannot receive new bookings.'
                USING ERRCODE = '23503';
        END IF;

        -- Universal Authoritative Price Integrity (on creation)
        IF NEW.total_price IS NULL OR NEW.total_price != v_authoritative_price THEN
            RAISE EXCEPTION 'Validation Error: Booking total_price (%) does not match the authoritative service catalog price (%).', NEW.total_price, v_authoritative_price
                USING ERRCODE = '22003';
        END IF;

        -- Strict time format validation (supports 'HH:MI AM/PM' format)
        v_clean_time := UPPER(TRIM(NEW.booking_time));
        IF v_clean_time !~ '^(0[1-9]|1[0-2]):[0-5][0-9]\s?(AM|PM)$' THEN
            RAISE EXCEPTION 'Validation Error: Invalid booking_time format "%". Expected format is "HH:MI AM/PM".', NEW.booking_time
                USING ERRCODE = '22007';
        END IF;

        -- Timezone-aware date validation (Asia/Kolkata / UTC+05:30)
        v_current_marketplace_date := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;

        IF NEW.booking_date < v_current_marketplace_date THEN
            RAISE EXCEPTION 'Validation Error: Appointment date cannot be in the past.'
                USING ERRCODE = '22008';
        END IF;

        v_appointment_instant := (NEW.booking_date + v_clean_time::time) AT TIME ZONE 'Asia/Kolkata';

        IF NEW.booking_date = v_current_marketplace_date AND v_appointment_instant < NOW() THEN
            RAISE EXCEPTION 'Validation Error: Appointment time slot has already passed for today.'
                USING ERRCODE = '22008';
        END IF;

        RETURN NEW;
    END IF;

    -- ========================================================================
    -- 2. UPDATE VALIDATION & PROTECTION (TG_OP = 'UPDATE')
    -- ========================================================================
    IF TG_OP = 'UPDATE' THEN
        -- Resolve actor relationships
        is_owner_party := (auth.uid() IS NOT NULL AND auth.uid() = OLD.user_id);

        SELECT user_id INTO booking_prov_user_id 
        FROM public.providers 
        WHERE id = OLD.provider_id;

        is_provider_party := (auth.uid() IS NOT NULL AND auth.uid() = booking_prov_user_id);

        -- Strict actor authorization guard: Unrelated actors cannot modify bookings
        IF NOT (is_admin_actor OR is_owner_party OR is_provider_party) THEN
            RAISE EXCEPTION 'Security Violation: You are not authorized to modify this booking.'
                USING ERRCODE = '42501';
        END IF;

        -- Immutable core identity fields
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Security Violation: Booking ID is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Security Violation: Booking customer ID is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.provider_id IS DISTINCT FROM OLD.provider_id THEN
            RAISE EXCEPTION 'Security Violation: Booking provider ID is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.service_id IS DISTINCT FROM OLD.service_id THEN
            RAISE EXCEPTION 'Security Violation: Booking service ID is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.pet_id IS DISTINCT FROM OLD.pet_id THEN
            RAISE EXCEPTION 'Security Violation: Booking pet ID is immutable.' USING ERRCODE = '42501';
        END IF;

        -- Historical booking price preservation: price is immutable once booked
        IF NEW.total_price IS DISTINCT FROM OLD.total_price THEN
            RAISE EXCEPTION 'Security Violation: Booking total price is immutable once booked.' USING ERRCODE = '42501';
        END IF;

        -- Appointment Rescheduling Authorization (Date / Time)
        IF NEW.booking_date IS DISTINCT FROM OLD.booking_date OR NEW.booking_time IS DISTINCT FROM OLD.booking_time THEN
            IF NOT (is_owner_party OR is_provider_party OR is_admin_actor) THEN
                RAISE EXCEPTION 'Security Violation: You are not authorized to reschedule this booking.' USING ERRCODE = '42501';
            END IF;

            IF OLD.status IS DISTINCT FROM 'PENDING'::public.booking_status AND NOT is_admin_actor THEN
                RAISE EXCEPTION 'Security Violation: Booking appointment date and time can only be modified while status is PENDING.' USING ERRCODE = '42501';
            END IF;

            v_clean_time := UPPER(TRIM(NEW.booking_time));
            IF v_clean_time !~ '^(0[1-9]|1[0-2]):[0-5][0-9]\s?(AM|PM)$' THEN
                RAISE EXCEPTION 'Validation Error: Invalid booking_time format "%". Expected format is "HH:MI AM/PM".', NEW.booking_time USING ERRCODE = '22007';
            END IF;

            v_current_marketplace_date := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;

            IF NEW.booking_date < v_current_marketplace_date THEN
                RAISE EXCEPTION 'Security Violation: Booking appointment date cannot be set in the past.' USING ERRCODE = '42501';
            END IF;

            v_appointment_instant := (NEW.booking_date + v_clean_time::time) AT TIME ZONE 'Asia/Kolkata';

            IF NEW.booking_date = v_current_marketplace_date AND v_appointment_instant < NOW() THEN
                RAISE EXCEPTION 'Security Violation: Booking appointment time (%) for today has already passed.', NEW.booking_time USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Booking Notes Authorization
        IF NEW.booking_notes IS DISTINCT FROM OLD.booking_notes THEN
            IF NOT (is_owner_party OR is_admin_actor) THEN
                RAISE EXCEPTION 'Security Violation: Only the pet owner can modify booking notes.' USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Status Transition Matrix Authorization (ZERO fall-through)
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            -- Universal terminal state check
            IF OLD.status IN ('COMPLETED', 'CANCELLED', 'REJECTED') THEN
                RAISE EXCEPTION 'Security Violation: Cannot transition booking out of terminal state %.', OLD.status USING ERRCODE = '42501';
            END IF;

            IF is_admin_actor THEN
                IF OLD.status = 'PENDING' AND NEW.status IN ('CONFIRMED', 'CANCELLED', 'REJECTED', 'COMPLETED') THEN
                    RETURN NEW;
                ELSIF OLD.status = 'CONFIRMED' AND NEW.status IN ('COMPLETED', 'CANCELLED', 'REJECTED') THEN
                    RETURN NEW;
                ELSE
                    RAISE EXCEPTION 'Security Violation: Invalid administrative status transition from % to %.', OLD.status, NEW.status USING ERRCODE = '42501';
                END IF;
            ELSIF is_owner_party AND is_provider_party THEN
                IF OLD.status = 'PENDING' AND NEW.status IN ('CONFIRMED', 'CANCELLED', 'REJECTED') THEN
                    RETURN NEW;
                ELSIF OLD.status = 'CONFIRMED' AND NEW.status IN ('COMPLETED', 'CANCELLED') THEN
                    RETURN NEW;
                ELSE
                    RAISE EXCEPTION 'Security Violation: Invalid dual-party transition from % to %.', OLD.status, NEW.status USING ERRCODE = '42501';
                END IF;
            ELSIF is_owner_party THEN
                IF OLD.status IN ('PENDING', 'CONFIRMED') AND NEW.status = 'CANCELLED' THEN
                    RETURN NEW;
                ELSE
                    RAISE EXCEPTION 'Security Violation: Pet owners can only cancel active bookings (attempted transition from % to %).', OLD.status, NEW.status USING ERRCODE = '42501';
                END IF;
            ELSIF is_provider_party THEN
                IF OLD.status = 'PENDING' AND NEW.status IN ('CONFIRMED', 'REJECTED') THEN
                    RETURN NEW;
                ELSIF OLD.status = 'CONFIRMED' AND NEW.status IN ('COMPLETED', 'CANCELLED') THEN
                    RETURN NEW;
                ELSE
                    RAISE EXCEPTION 'Security Violation: Providers cannot transition booking from % to %.', OLD.status, NEW.status USING ERRCODE = '42501';
                END IF;
            ELSE
                RAISE EXCEPTION 'Security Violation: You are not authorized to change the status of this booking.' USING ERRCODE = '42501';
            END IF;
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

-- Trigger 4.1: Attach to public.bookings
DROP TRIGGER IF EXISTS trg_validate_booking_transition ON public.bookings;
CREATE TRIGGER trg_validate_booking_transition
    BEFORE INSERT OR UPDATE ON public.bookings
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_booking_transition_and_fields();


-- ============================================================================
-- SECTION 5: REVIEW INTEGRITY FUNCTION & TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_review_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
    is_admin_actor BOOLEAN;
    v_booking_user_id UUID;
    v_booking_provider_id UUID;
    v_booking_service_id UUID;
    v_booking_status public.booking_status;
BEGIN
    is_admin_actor := public.is_admin() OR auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin');

    -- ====================================================================
    -- 1. INSERT VALIDATION
    -- ====================================================================
    IF TG_OP = 'INSERT' THEN
        IF NOT is_admin_actor THEN
            IF auth.uid() IS NULL OR NEW.user_id IS DISTINCT FROM auth.uid() THEN
                RAISE EXCEPTION 'Security Violation: Review user_id must match the authenticated user.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Require valid booking reference
        IF NEW.booking_id IS NULL THEN
            RAISE EXCEPTION 'Validation Error: Review must be linked to a valid appointment booking.'
                USING ERRCODE = '23502';
        END IF;

        -- Verify booking exists, is COMPLETED, and matches user_id and provider_id
        SELECT user_id, provider_id, service_id, status 
        INTO v_booking_user_id, v_booking_provider_id, v_booking_service_id, v_booking_status
        FROM public.bookings
        WHERE id = NEW.booking_id;

        IF v_booking_status IS NULL THEN
            RAISE EXCEPTION 'Validation Error: Referenced booking does not exist.'
                USING ERRCODE = '23503';
        END IF;

        IF v_booking_status IS DISTINCT FROM 'COMPLETED'::public.booking_status THEN
            RAISE EXCEPTION 'Security Violation: Reviews can only be submitted for COMPLETED bookings (current status: %).', v_booking_status
                USING ERRCODE = '42501';
        END IF;

        IF v_booking_user_id IS DISTINCT FROM NEW.user_id THEN
            RAISE EXCEPTION 'Security Violation: The booking does not belong to the review author.'
                USING ERRCODE = '42501';
        END IF;

        IF v_booking_provider_id IS DISTINCT FROM NEW.provider_id THEN
            RAISE EXCEPTION 'Security Violation: The designated provider does not match the booking provider.'
                USING ERRCODE = '42501';
        END IF;

        -- Sync or validate service_id
        IF NEW.service_id IS NULL THEN
            NEW.service_id := v_booking_service_id;
        ELSIF NEW.service_id IS DISTINCT FROM v_booking_service_id THEN
            RAISE EXCEPTION 'Security Violation: The designated service does not match the booking service.'
                USING ERRCODE = '42501';
        END IF;

        -- Validate rating range
        IF NEW.rating IS NULL OR NEW.rating < 1 OR NEW.rating > 5 THEN
            RAISE EXCEPTION 'Validation Error: Review rating must be an integer between 1 and 5.'
                USING ERRCODE = '22003';
        END IF;

        RETURN NEW;
    END IF;

    -- ====================================================================
    -- 2. UPDATE VALIDATION
    -- ====================================================================
    IF TG_OP = 'UPDATE' THEN
        -- Immutable review linkage fields
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Security Violation: Review ID is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Security Violation: Review author user_id is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.booking_id IS DISTINCT FROM OLD.booking_id THEN
            RAISE EXCEPTION 'Security Violation: Review booking_id is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.provider_id IS DISTINCT FROM OLD.provider_id THEN
            RAISE EXCEPTION 'Security Violation: Review provider_id is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.service_id IS DISTINCT FROM OLD.service_id THEN
            RAISE EXCEPTION 'Security Violation: Review service_id is immutable.' USING ERRCODE = '42501';
        END IF;

        -- Validate actor authorization: only the author or an admin can update the review
        IF NOT is_admin_actor THEN
            IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM OLD.user_id THEN
                RAISE EXCEPTION 'Security Violation: You are not authorized to update this review.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Validate rating range
        IF NEW.rating IS NULL OR NEW.rating < 1 OR NEW.rating > 5 THEN
            RAISE EXCEPTION 'Validation Error: Review rating must be an integer between 1 and 5.'
                USING ERRCODE = '22003';
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

-- Trigger 5.1: Attach to public.reviews
DROP TRIGGER IF EXISTS trg_validate_review_integrity ON public.reviews;
CREATE TRIGGER trg_validate_review_integrity
    BEFORE INSERT OR UPDATE ON public.reviews
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_review_integrity();


-- ============================================================================
-- SECTION 6: SANITIZED PUBLIC PROVIDER VIEW & BASE TABLE ACCESS
-- ============================================================================

-- View 6.1: Create public.provider_public_profiles view
-- Exposes ONLY non-sensitive fields; excludes user_id, email, phone, internal timestamps.
CREATE OR REPLACE VIEW public.provider_public_profiles
WITH (security_invoker = false)
AS
SELECT 
    pr.id AS provider_id,
    pr.business_name,
    pr.description,
    pr.location,
    pr.verified,
    pr.rating,
    pr.reviews_count,
    u.full_name AS provider_name,
    u.avatar_url
FROM public.providers pr
JOIN public.users u ON pr.user_id = u.id
WHERE pr.verified = true;

-- Grants for public view
GRANT SELECT ON public.provider_public_profiles TO anon, authenticated;

-- Hardened RLS on public.providers
DROP POLICY IF EXISTS "Public can view providers" ON public.providers;
DROP POLICY IF EXISTS "Provider can insert own profile" ON public.providers;
DROP POLICY IF EXISTS "Provider can update own profile" ON public.providers;
DROP POLICY IF EXISTS "Providers view own profile and admins" ON public.providers;
DROP POLICY IF EXISTS "Providers can register business profile" ON public.providers;
DROP POLICY IF EXISTS "Providers can update own business profile" ON public.providers;

CREATE POLICY "Providers view own profile and admins"
    ON public.providers FOR SELECT
    USING ((auth.uid() = user_id) OR public.is_admin());

CREATE POLICY "Providers can register business profile"
    ON public.providers FOR INSERT
    WITH CHECK (((auth.uid() = user_id) AND public.is_provider()) OR public.is_admin());

CREATE POLICY "Providers can update own business profile"
    ON public.providers FOR UPDATE
    USING ((auth.uid() = user_id) OR public.is_admin())
    WITH CHECK ((auth.uid() = user_id) OR public.is_admin());


-- ============================================================================
-- SECTION 7: PUBLIC.USERS RLS HARDENING (PRIVACY ENFORCEMENT)
-- ============================================================================

DROP POLICY IF EXISTS "Public users profile read" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Admins can view all user profiles" ON public.users;

CREATE POLICY "Users can view own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Admins can view all user profiles"
    ON public.users FOR SELECT
    USING (public.is_admin());

CREATE POLICY "Users can update own profile"
    ON public.users FOR UPDATE
    USING ((auth.uid() = id) OR public.is_admin())
    WITH CHECK ((auth.uid() = id) OR public.is_admin());


-- ============================================================================
-- SECTION 8: PUBLIC.REVIEWS RLS HARDENING
-- ============================================================================

DROP POLICY IF EXISTS "Users can insert reviews" ON public.reviews;
DROP POLICY IF EXISTS "Authenticated users can submit reviews for completed bookings" ON public.reviews;
DROP POLICY IF EXISTS "Authors can update own reviews" ON public.reviews;
DROP POLICY IF EXISTS "Authors and admins can delete reviews" ON public.reviews;

CREATE POLICY "Authenticated users can submit reviews for completed bookings"
    ON public.reviews FOR INSERT
    WITH CHECK (
        ((auth.uid() = user_id) AND (
            public.is_admin() OR (
                booking_id IS NOT NULL AND EXISTS (
                    SELECT 1 FROM public.bookings b
                    WHERE b.id = reviews.booking_id
                      AND b.user_id = auth.uid()
                      AND b.provider_id = reviews.provider_id
                      AND b.status = 'COMPLETED'::public.booking_status
                )
            )
        )) OR public.is_admin()
    );

CREATE POLICY "Authors can update own reviews"
    ON public.reviews FOR UPDATE
    USING ((auth.uid() = user_id) OR public.is_admin())
    WITH CHECK ((auth.uid() = user_id) OR public.is_admin());

CREATE POLICY "Authors and admins can delete reviews"
    ON public.reviews FOR DELETE
    USING ((auth.uid() = user_id) OR public.is_admin());


-- ============================================================================
-- SECTION 9: STORAGE BUCKET CONFIGURATION & VERIFIED PROVIDER POLICIES
-- ============================================================================

-- 1. Configure 5MB size limit and image MIME-types on all three buckets
UPDATE storage.buckets
SET file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
WHERE id IN ('pet-images', 'provider-images', 'service-images');

-- 2. Drop only the 9 targeted mutating storage policies (preserves Public Read CDN policies)
DROP POLICY IF EXISTS "Authenticated users upload pet images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can upload provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can upload service images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can update own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can delete own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can update own service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can delete own service images" ON storage.objects;
DROP POLICY IF EXISTS "Users upload own pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users update own pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own pet images" ON storage.objects;
DROP POLICY IF EXISTS "Providers upload own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers update own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers delete own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers upload service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers update service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers delete service images" ON storage.objects;

-- 3. Create hardened storage policies
-- pet-images: Authenticated user must own the top-level folder
CREATE POLICY "Users upload own pet images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'pet-images' AND (
            (auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Users update own pet images"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'pet-images' AND (
            (auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Users delete own pet images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'pet-images' AND (
            (auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

-- provider-images: Must be VERIFIED provider AND own top-level folder
CREATE POLICY "Providers upload own provider images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'provider-images' AND (
            (public.is_verified_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Providers update own provider images"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'provider-images' AND (
            (public.is_verified_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Providers delete own provider images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'provider-images' AND (
            (public.is_verified_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

-- service-images: Must be VERIFIED provider AND own top-level folder
CREATE POLICY "Providers upload service images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'service-images' AND (
            (public.is_verified_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Providers update service images"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'service-images' AND (
            (public.is_verified_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Providers delete service images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'service-images' AND (
            (public.is_verified_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );


-- ============================================================================
-- SECTION 10: INTEGRITY CONSTRAINTS & INDEXES
-- ============================================================================

-- 1. Availability start_time < end_time check constraint
ALTER TABLE public.availability 
    DROP CONSTRAINT IF EXISTS chk_availability_times_valid;
ALTER TABLE public.availability 
    ADD CONSTRAINT chk_availability_times_valid 
    CHECK (start_time < end_time);

-- 2. Availability unique provider slot composite index
CREATE UNIQUE INDEX IF NOT EXISTS idx_availability_provider_slot_unique 
    ON public.availability USING btree (provider_id, date, start_time, end_time);

-- 3. Review unique booking partial index
CREATE UNIQUE INDEX IF NOT EXISTS uq_reviews_booking_id 
    ON public.reviews USING btree (booking_id) 
    WHERE (booking_id IS NOT NULL);

COMMIT;
