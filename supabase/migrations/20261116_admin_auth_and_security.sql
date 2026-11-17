-- ============================================================================
-- PET CARE MARKETPLACE: COMPREHENSIVE SECURITY, RLS, AND ADMIN MIGRATION
-- Migration File: supabase/migrations/20261116_admin_auth_and_security.sql
-- ============================================================================

-- 1. EXTENSIONS & ENUMS (IDEMPOTENT)
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$ BEGIN
    CREATE TYPE public.user_role AS ENUM ('pet_owner', 'provider', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.booking_status AS ENUM ('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. EXPLICIT & CONTROLLED ADMINISTRATOR PROVISIONING
-- ============================================================================
-- Notice: Automatic promotion is disabled. Administrator privileges must be
-- granted explicitly via public.promote_user_to_admin('target_email').
-- Security Architecture:
-- 1. The function is REVOKED from PUBLIC, anon, and authenticated.
-- 2. PostgREST rejects any client-side RPC invocation with HTTP 403.
-- 3. In PostgreSQL, session_user authenticates the physical database connection:
--    - PostgREST API client calls: session_user = 'authenticator'.
--    - Supabase Dashboard SQL Editor: session_user = 'postgres' (or 'supabase_admin').
-- 4. The function checks session_user, public.is_admin(), and auth.role() = 'service_role'.
--    It NEVER trusts current_user inside a SECURITY DEFINER function.
DO $$
BEGIN
    RAISE NOTICE 'ADMIN PROVISIONING POLICY: Automatic admin promotion by email is disabled. Initial admin bootstrap must be executed in the Supabase SQL Editor (session_user = postgres) or via service_role using public.promote_user_to_admin(''target_email'').';
END $$;

-- Explicit administrator promotion procedure:
-- Callable strictly by:
-- 1. Database superuser in Supabase SQL Editor (session_user IN ('postgres', 'supabase_admin'))
-- 2. Authenticated platform administrator (public.is_admin())
-- 3. Trusted backend service role (auth.role() = 'service_role')
-- Validates that the target account exists and has confirmed their email address.
-- Modifies ZERO passwords and touches ZERO email confirmation states.
CREATE OR REPLACE FUNCTION public.promote_user_to_admin(target_email TEXT)
RETURNS VOID AS $$
DECLARE
    target_uid UUID;
    v_confirmed BOOLEAN;
BEGIN
    -- Strict authorization check:
    -- In a SECURITY DEFINER function, current_user is always the function owner (postgres).
    -- Therefore, we inspect session_user (physical connection role), public.is_admin(),
    -- or the verified service_role JWT claim.
    IF NOT (
        public.is_admin() 
        OR auth.role() = 'service_role' 
        OR session_user IN ('postgres', 'supabase_admin')
    ) THEN
        RAISE EXCEPTION 'Security Violation: Only platform administrators, service_role, or direct database superusers can promote users to admin.'
            USING ERRCODE = '42501';
    END IF;

    SELECT id, (email_confirmed_at IS NOT NULL) 
    INTO target_uid, v_confirmed
    FROM auth.users 
    WHERE LOWER(email) = LOWER(target_email);

    IF target_uid IS NULL THEN
        RAISE EXCEPTION 'Target user "%" not found in auth.users. User must register first.', target_email;
    END IF;

    IF NOT v_confirmed THEN
        RAISE EXCEPTION 'Security Violation: Target user "%" has not confirmed their email address. Unverified accounts cannot be promoted.', target_email
            USING ERRCODE = '42501';
    END IF;

    UPDATE public.users 
    SET role = 'admin' 
    WHERE id = target_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile for "%" not found in public.users.', target_email;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, auth;

ALTER FUNCTION public.promote_user_to_admin(TEXT) OWNER TO postgres;

-- Revoke execute from all untrusted roles; grant only to service_role and postgres owner
REVOKE ALL ON FUNCTION public.promote_user_to_admin(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.promote_user_to_admin(TEXT) TO postgres, service_role;

-- 3. HARDENED SECURITY DEFINER HELPER FUNCTIONS
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = pg_catalog, public, auth;

CREATE OR REPLACE FUNCTION public.is_provider()
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role = 'provider'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = pg_catalog, public, auth;

CREATE OR REPLACE FUNCTION public.is_owner()
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role = 'pet_owner'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = pg_catalog, public, auth;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_provider() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_provider() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_owner() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_owner() TO authenticated, service_role;

-- 4. HARDENED REGISTRATION TRIGGER FUNCTION (HANDLE_NEW_USER)
-- Trigger runs on auth.users insert (executed internally by GoTrue auth worker).
-- Direct client execution is completely revoked.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    requested_role TEXT;
    assigned_role public.user_role;
    user_name TEXT;
    prov_business_name TEXT;
    prov_location TEXT;
    prov_desc TEXT;
BEGIN
    requested_role := LOWER(COALESCE(NEW.raw_user_meta_data->>'role', ''));

    -- Role sanitization: Users can only sign up as 'provider' or 'pet_owner'.
    -- Malicious attempts to pass role = 'admin' are strictly sanitized to 'pet_owner'.
    IF requested_role = 'provider' THEN
        assigned_role := 'provider'::public.user_role;
    ELSE
        assigned_role := 'pet_owner'::public.user_role;
    END IF;

    user_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        split_part(NEW.email, '@', 1)
    );

    INSERT INTO public.users (id, full_name, email, role, phone, avatar_url)
    VALUES (
        NEW.id,
        user_name,
        NEW.email,
        assigned_role,
        NEW.raw_user_meta_data->>'phone',
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = COALESCE(public.users.full_name, EXCLUDED.full_name);

    IF assigned_role = 'provider' THEN
        prov_business_name := COALESCE(NEW.raw_user_meta_data->>'business_name', user_name || ' Pet Care');
        prov_location := COALESCE(NEW.raw_user_meta_data->>'location', 'Location pending');
        prov_desc := COALESCE(NEW.raw_user_meta_data->>'description', 'Professional pet care services');

        INSERT INTO public.providers (
            user_id,
            business_name,
            location,
            description,
            verified,
            rating,
            reviews_count
        ) VALUES (
            NEW.id,
            prov_business_name,
            prov_location,
            prov_desc,
            FALSE,
            5.0,
            0
        )
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, auth;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. ROLE ESCALATION & PROFILE INSERTION PREVENTION (SECURITY TRIGGER)
-- Protects both INSERT and UPDATE operations on public.users.
-- Ensures that:
-- 1. Direct client INSERT on public.users is blocked by RLS ("Admins can insert user profiles").
-- 2. As defense-in-depth, trigger ensures ordinary callers cannot insert elevated roles.
-- 3. On UPDATE, ordinary users cannot alter their role or ID.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.prevent_user_role_escalation()
RETURNS TRIGGER AS $$
BEGIN
    -- INSERT PROTECTION
    IF TG_OP = 'INSERT' THEN
        -- Allow internal Auth trigger execution (GoTrue runs as supabase_auth_admin or postgres)
        IF session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin') OR auth.role() = 'service_role' THEN
            RETURN NEW;
        END IF;

        -- Direct client INSERT: strictly restricted to pet_owner role (or platform admin)
        IF NEW.role IS DISTINCT FROM 'pet_owner'::public.user_role THEN
            IF NOT public.is_admin() THEN
                RAISE EXCEPTION 'Security Violation: Direct creation of profiles with elevated role (%) is unauthorized.', NEW.role
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        RETURN NEW;
    END IF;

    -- UPDATE PROTECTION: Only administrators, service_role, or direct SQL Editor sessions can modify user roles
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, auth;

DROP TRIGGER IF EXISTS trg_prevent_user_role_escalation ON public.users;
CREATE TRIGGER trg_prevent_user_role_escalation
    BEFORE INSERT OR UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.prevent_user_role_escalation();

-- 6. PROVIDER CREATION & VERIFICATION INTEGRITY (SECURITY TRIGGER)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.prevent_provider_verification_tampering()
RETURNS TRIGGER AS $$
BEGIN
    IF public.is_admin() OR auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin') THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NOT public.is_provider() THEN
            RAISE EXCEPTION 'Security Violation: Only users with the provider role can register a provider business profile.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.verified IS TRUE THEN
            RAISE EXCEPTION 'Security Violation: Only platform administrators can verify provider profiles.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.verified IS NULL THEN
            NEW.verified := FALSE;
        END IF;
        IF NEW.rating IS DISTINCT FROM 5.0 THEN
            NEW.rating := 5.0;
        END IF;
        IF NEW.reviews_count IS DISTINCT FROM 0 THEN
            NEW.reviews_count := 0;
        END IF;

        IF NEW.user_id IS DISTINCT FROM auth.uid() THEN
            RAISE EXCEPTION 'Security Violation: Cannot register provider profile for another user account.'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Security Violation: Provider profile ID is immutable.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Security Violation: Provider user_id is immutable.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.verified IS DISTINCT FROM OLD.verified THEN
            RAISE EXCEPTION 'Security Violation: Only platform administrators can change provider verification status.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.rating IS DISTINCT FROM OLD.rating OR NEW.reviews_count IS DISTINCT FROM OLD.reviews_count THEN
            RAISE EXCEPTION 'Security Violation: Provider rating and review counts cannot be modified directly.'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, auth;

DROP TRIGGER IF EXISTS trg_prevent_provider_verification_tampering ON public.providers;
CREATE TRIGGER trg_prevent_provider_verification_tampering
    BEFORE INSERT OR UPDATE ON public.providers
    FOR EACH ROW EXECUTE FUNCTION public.prevent_provider_verification_tampering();

-- 7. BOOKING ATTRIBUTE PROTECTION & RESCHEDULE AUTHORIZATION (SECURITY TRIGGER)
-- Operates on BOTH INSERT and UPDATE.
-- INSERT:
-- - Initial status: pet owners restricted strictly to PENDING; admins/service-role to PENDING or CONFIRMED.
--   Zero bookings can start in terminal states (COMPLETED, CANCELLED, REJECTED).
-- - Provider & Service eligibility: rejects unverified providers and inactive services.
-- - Authoritative Price Integrity: enforces NEW.total_price matches public.services.price.
-- - Chronological & format validation: validates HH:MI AM/PM format (22007), future date (42501),
--   and future same-day time in Asia/Kolkata (42501).
-- UPDATE:
-- - UNIVERSALLY blocks mutations to immutable fields (id, user_id, provider_id, service_id, total_price)
--   for ALL actors (including admins and service_role).
-- - Restricts reschedule strictly to pet owner or admin while status is PENDING.
-- - Strictly enforces role-based state transitions and blocks transitions out of terminal states for all actors.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.validate_booking_transition_and_fields()
RETURNS TRIGGER AS $$
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
        -- 1. Initial Status Authorization
        IF NOT is_admin_actor THEN
            -- Pet owners may ONLY create bookings in PENDING status
            IF NEW.status IS DISTINCT FROM 'PENDING'::public.booking_status THEN
                RAISE EXCEPTION 'Security Violation: New pet owner bookings must be created with PENDING status.'
                    USING ERRCODE = '42501';
            END IF;

            IF auth.uid() IS NULL OR NEW.user_id IS DISTINCT FROM auth.uid() THEN
                RAISE EXCEPTION 'Security Violation: Cannot create a booking on behalf of another user account.'
                    USING ERRCODE = '42501';
            END IF;
        ELSE
            -- Admins & service-role may initialize bookings ONLY in PENDING or CONFIRMED status
            IF NEW.status NOT IN ('PENDING'::public.booking_status, 'CONFIRMED'::public.booking_status) THEN
                RAISE EXCEPTION 'Security Violation: New bookings cannot be initialized in a terminal state (%). Allowed initial states: PENDING, CONFIRMED.', NEW.status
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- 2. Universal Pet Ownership Verification (Enforced for ALL actors including admins)
        -- The designated pet MUST belong to the user specified in NEW.user_id
        IF NOT EXISTS (SELECT 1 FROM public.pets WHERE id = NEW.pet_id AND owner_id = NEW.user_id) THEN
            RAISE EXCEPTION 'Security Violation: The designated pet (%) does not belong to the booking user (%).', NEW.pet_id, NEW.user_id
                USING ERRCODE = '42501';
        END IF;

        -- 3. Universal Provider Verification Check (Enforced for ALL actors including admins)
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

        -- 4. Universal Service Eligibility & Active Status Check (Enforced for ALL actors)
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

        -- 5. Universal Authoritative Price Integrity (Enforced for ALL actors including admins & service_role)
        -- In the Pet Care Marketplace fixed-catalog pricing model, every booking price must match the authoritative service catalog price.
        IF NEW.total_price IS NULL OR NEW.total_price != v_authoritative_price THEN
            RAISE EXCEPTION 'Validation Error: Booking total_price (%) does not match the authoritative service catalog price (%).', NEW.total_price, v_authoritative_price
                USING ERRCODE = '22003';
        END IF;

        -- 6. Strict time format validation
        v_clean_time := UPPER(TRIM(NEW.booking_time));
        IF v_clean_time !~ '^(0[1-9]|1[0-2]):[0-5][0-9]\s?(AM|PM)$' THEN
            RAISE EXCEPTION 'Validation Error: Invalid booking_time format "%". Expected format is "HH:MI AM/PM" (e.g. "09:30 AM").', NEW.booking_time
                USING ERRCODE = '22007';
        END IF;

        -- 7. Marketplace timezone awareness (Asia/Kolkata / UTC+05:30)
        v_current_marketplace_date := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;

        -- Prohibit dates in the past in Asia/Kolkata
        IF NEW.booking_date < v_current_marketplace_date THEN
            RAISE EXCEPTION 'Security Violation: Booking appointment date cannot be set in the past.'
                USING ERRCODE = '42501';
        END IF;

        -- Prohibit same-day time slots in the past
        v_appointment_instant := (NEW.booking_date + v_clean_time::time) AT TIME ZONE 'Asia/Kolkata';

        IF NEW.booking_date = v_current_marketplace_date AND v_appointment_instant < NOW() THEN
            RAISE EXCEPTION 'Security Violation: Booking appointment time (%) for today has already passed.', NEW.booking_time
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    -- ========================================================================
    -- 2. UPDATE VALIDATION & PROTECTION (TG_OP = 'UPDATE')
    -- ========================================================================
    IF TG_OP = 'UPDATE' THEN
        -- UNIVERSAL IMMUTABLE FIELD INTEGRITY (Enforced even for platform admins and service_role)
        -- Prevents accidental database corruption or untracked relational/price mutations
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Security Violation: Booking ID is immutable.' USING ERRCODE = '42501';
        END IF;
        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Security Violation: Booking pet owner user_id is immutable.' USING ERRCODE = '42501';
        END IF;
        IF NEW.provider_id IS DISTINCT FROM OLD.provider_id THEN
            RAISE EXCEPTION 'Security Violation: Booking provider_id is immutable.' USING ERRCODE = '42501';
        END IF;
        IF NEW.service_id IS DISTINCT FROM OLD.service_id THEN
            RAISE EXCEPTION 'Security Violation: Booking service_id is immutable.' USING ERRCODE = '42501';
        END IF;
        IF NEW.total_price IS DISTINCT FROM OLD.total_price THEN
            RAISE EXCEPTION 'Security Violation: Booking total_price is immutable.' USING ERRCODE = '42501';
        END IF;

        -- Party authorization for non-admin actors
        SELECT user_id INTO booking_prov_user_id 
        FROM public.providers 
        WHERE id = OLD.provider_id;

        is_owner_party := (auth.uid() = OLD.user_id);
        is_provider_party := (auth.uid() = booking_prov_user_id);

        IF NOT is_admin_actor AND NOT (is_owner_party OR is_provider_party) THEN
            RAISE EXCEPTION 'Security Violation: You are not a party to this booking.'
                USING ERRCODE = '42501';
        END IF;

        -- Date & Time Reschedule Authorization & Strict Validation:
        IF (NEW.booking_date IS DISTINCT FROM OLD.booking_date) OR (NEW.booking_time IS DISTINCT FROM OLD.booking_time) THEN
            -- Strictly restricted to pet owner or platform admin (providers cannot reschedule)
            IF NOT (is_owner_party OR is_admin_actor) THEN
                RAISE EXCEPTION 'Security Violation: Only the pet owner can reschedule a booking appointment.'
                    USING ERRCODE = '42501';
            END IF;

            -- Permitted ONLY while booking status is PENDING
            IF OLD.status != 'PENDING' THEN
                RAISE EXCEPTION 'Security Violation: Booking appointment date and time can only be modified while status is PENDING.'
                    USING ERRCODE = '42501';
            END IF;

            -- Strict format validation for booking_time
            v_clean_time := UPPER(TRIM(NEW.booking_time));
            IF v_clean_time !~ '^(0[1-9]|1[0-2]):[0-5][0-9]\s?(AM|PM)$' THEN
                RAISE EXCEPTION 'Validation Error: Invalid booking_time format "%". Expected format is "HH:MI AM/PM" (e.g. "09:30 AM").', NEW.booking_time
                    USING ERRCODE = '22007';
            END IF;

            -- Marketplace timezone awareness (Asia/Kolkata / UTC+05:30)
            v_current_marketplace_date := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;

            -- Prohibit dates in the past in Asia/Kolkata
            IF NEW.booking_date < v_current_marketplace_date THEN
                RAISE EXCEPTION 'Security Violation: Booking appointment date cannot be set in the past.'
                    USING ERRCODE = '42501';
            END IF;

            -- Prohibit same-day time slots in the past
            v_appointment_instant := (NEW.booking_date + v_clean_time::time) AT TIME ZONE 'Asia/Kolkata';

            IF NEW.booking_date = v_current_marketplace_date AND v_appointment_instant < NOW() THEN
                RAISE EXCEPTION 'Security Violation: Booking appointment time (%) for today has already passed.', NEW.booking_time
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Booking Notes Authorization
        IF NEW.booking_notes IS DISTINCT FROM OLD.booking_notes THEN
            IF NOT (is_owner_party OR is_admin_actor) THEN
                RAISE EXCEPTION 'Security Violation: Only the pet owner can modify booking notes.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Status Transition Matrix Authorization
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            -- Universal terminal state check (enforced even for admins)
            IF OLD.status IN ('COMPLETED', 'CANCELLED', 'REJECTED') THEN
                RAISE EXCEPTION 'Security Violation: Cannot transition booking out of terminal state %.', OLD.status
                    USING ERRCODE = '42501';
            END IF;

            -- Admin status transitions
            IF is_admin_actor THEN
                IF OLD.status = 'PENDING' AND NEW.status IN ('CONFIRMED', 'CANCELLED', 'REJECTED') THEN
                    RETURN NEW;
                ELSIF OLD.status = 'CONFIRMED' AND NEW.status IN ('COMPLETED', 'CANCELLED') THEN
                    RETURN NEW;
                ELSE
                    RAISE EXCEPTION 'Security Violation: Invalid administrative status transition from % to %.', OLD.status, NEW.status
                        USING ERRCODE = '42501';
                END IF;
            END IF;

            -- Dual-party actor (account is both owner and provider)
            IF is_owner_party AND is_provider_party THEN
                IF OLD.status = 'PENDING' AND NEW.status IN ('CONFIRMED', 'CANCELLED', 'REJECTED') THEN
                    RETURN NEW;
                ELSIF OLD.status = 'CONFIRMED' AND NEW.status IN ('COMPLETED', 'CANCELLED') THEN
                    RETURN NEW;
                ELSE
                    RAISE EXCEPTION 'Security Violation: Invalid dual-party transition from % to %.', OLD.status, NEW.status
                        USING ERRCODE = '42501';
                END IF;
            END IF;

            -- Pet owner actor
            IF is_owner_party THEN
                IF OLD.status IN ('PENDING', 'CONFIRMED') AND NEW.status = 'CANCELLED' THEN
                    RETURN NEW;
                ELSE
                    RAISE EXCEPTION 'Security Violation: Pet owners can only cancel active bookings (attempted transition from % to %).', OLD.status, NEW.status
                        USING ERRCODE = '42501';
                END IF;
            END IF;

            -- Provider actor
            IF is_provider_party THEN
                IF OLD.status = 'PENDING' AND NEW.status IN ('CONFIRMED', 'REJECTED') THEN
                    RETURN NEW;
                ELSIF OLD.status = 'CONFIRMED' AND NEW.status = 'COMPLETED' THEN
                    RETURN NEW;
                ELSIF OLD.status = 'CONFIRMED' AND NEW.status = 'CANCELLED' THEN
                    RETURN NEW;
                ELSE
                    RAISE EXCEPTION 'Security Violation: Providers cannot transition booking from % to %.', OLD.status, NEW.status
                        USING ERRCODE = '42501';
                END IF;
            END IF;
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, auth;

DROP TRIGGER IF EXISTS trg_validate_booking_transition ON public.bookings;
CREATE TRIGGER trg_validate_booking_transition
    BEFORE INSERT OR UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.validate_booking_transition_and_fields();

-- 7.1 ANTI-DOUBLE-BOOKING UNIQUE CONFLICT INDEX (CONCURRENCY PROTECTION)
-- ============================================================================
-- Partial unique index physically preventing concurrent duplicate bookings
-- for the same provider, date and time slot while active (PENDING or CONFIRMED).
-- Automatically releases the slot if booking is CANCELLED or REJECTED.
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_booking_slot
ON public.bookings (provider_id, booking_date, booking_time)
WHERE status IN ('PENDING', 'CONFIRMED');

-- 8. SAFE PUBLIC PROVIDER PROFILE VIEW (PRIVACY PRESERVING)
-- ============================================================================
-- The official public discovery route for providers.
-- Excludes personal phone, email, internal user_id, and duplicate columns.
-- Uses security_invoker = false to execute with owner permissions, allowing safe
-- joins with public.users (which has RLS blocking anon) without leaking private columns.
CREATE OR REPLACE VIEW public.provider_public_profiles
WITH (security_invoker = false) AS
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
JOIN public.users u ON pr.user_id = u.id;

GRANT SELECT ON public.provider_public_profiles TO anon, authenticated;

-- 9. RLS POLICY PURGE & RE-CREATION
-- ============================================================================

-- 9.1 Purge policies on the 9 marketplace tables
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename IN ('users', 'providers', 'pets', 'services', 'bookings', 'reviews', 'notifications', 'availability', 'chat_history')
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- 9.2 Scoped purge on storage.objects: Drops ONLY policies belonging to this project's 3 buckets
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'storage' 
          AND tablename = 'objects'
          AND (
              policyname ILIKE '%pet image%' 
              OR policyname ILIKE '%provider image%' 
              OR policyname ILIKE '%service image%'
              OR qual ILIKE '%pet-images%'
              OR qual ILIKE '%provider-images%'
              OR qual ILIKE '%service-images%'
              OR with_check ILIKE '%pet-images%'
              OR with_check ILIKE '%provider-images%'
              OR with_check ILIKE '%service-images%'
          )
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.policyname);
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 9.3 USERS TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.users FROM anon;
GRANT SELECT, UPDATE ON public.users TO authenticated;
REVOKE INSERT ON public.users FROM anon, authenticated;
GRANT INSERT ON public.users TO service_role;
GRANT ALL ON public.users TO service_role;

CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Admins can view all user profiles" ON public.users
    FOR SELECT USING (public.is_admin());

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (
        auth.uid() = id OR public.is_admin()
    ) WITH CHECK (
        auth.uid() = id OR public.is_admin()
    );

-- Direct client-side INSERT on public.users is restricted strictly to administrators.
-- All normal user profiles are created through the trusted handle_new_user() trigger.
CREATE POLICY "Admins can insert user profiles" ON public.users
    FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "Admins can delete user profiles" ON public.users
    FOR DELETE USING (public.is_admin());

-- ----------------------------------------------------------------------------
-- 9.4 PROVIDERS TABLE
-- Direct SELECT is restricted strictly to:
-- 1. The provider themselves (auth.uid() = user_id)
-- 2. Platform administrators (is_admin())
-- NON-CIRCULAR DESIGN: Zero subqueries to public.bookings.
-- Public discovery is routed through public.provider_public_profiles view.
-- ----------------------------------------------------------------------------
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.providers FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.providers TO authenticated;
GRANT ALL ON public.providers TO service_role;

CREATE POLICY "Providers view own profile and admins" ON public.providers
    FOR SELECT USING (
        auth.uid() = user_id 
        OR public.is_admin()
    );

CREATE POLICY "Providers can update own business profile" ON public.providers
    FOR UPDATE USING (auth.uid() = user_id OR public.is_admin())
    WITH CHECK (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Providers can register business profile" ON public.providers
    FOR INSERT WITH CHECK (
        (auth.uid() = user_id AND public.is_provider())
        OR public.is_admin()
    );

CREATE POLICY "Admins can delete provider records" ON public.providers
    FOR DELETE USING (public.is_admin());

-- ----------------------------------------------------------------------------
-- 9.5 PETS TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pet owners view own pets, providers with bookings, and admins" ON public.pets
    FOR SELECT USING (
        auth.uid() = owner_id 
        OR EXISTS (
            SELECT 1 FROM public.bookings b
            JOIN public.providers p ON b.provider_id = p.id
            WHERE b.pet_id = public.pets.id AND p.user_id = auth.uid()
        )
        OR public.is_admin()
    );

CREATE POLICY "Pet owners can insert own pets" ON public.pets
    FOR INSERT WITH CHECK (auth.uid() = owner_id OR public.is_admin());

CREATE POLICY "Pet owners can update own pets" ON public.pets
    FOR UPDATE USING (auth.uid() = owner_id OR public.is_admin());

CREATE POLICY "Pet owners and admins can delete pets" ON public.pets
    FOR DELETE USING (auth.uid() = owner_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 9.6 SERVICES TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Services are viewable by everyone" ON public.services
    FOR SELECT USING (true);

CREATE POLICY "Providers can insert own services" ON public.services
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.providers
            WHERE id = provider_id AND user_id = auth.uid()
        ) OR public.is_admin()
    );

CREATE POLICY "Providers can update own services" ON public.services
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.providers
            WHERE id = provider_id AND user_id = auth.uid()
        ) OR public.is_admin()
    );

CREATE POLICY "Providers can delete own services" ON public.services
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.providers
            WHERE id = provider_id AND user_id = auth.uid()
        ) OR public.is_admin()
    );

-- ----------------------------------------------------------------------------
-- 9.7 BOOKINGS TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Parties and admins can view bookings" ON public.bookings
    FOR SELECT USING (
        auth.uid() = user_id 
        OR EXISTS (
            SELECT 1 FROM public.providers p
            WHERE p.id = provider_id AND p.user_id = auth.uid()
        )
        OR public.is_admin()
    );

CREATE POLICY "Pet owners can create bookings" ON public.bookings
    FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Involved parties can update bookings" ON public.bookings
    FOR UPDATE USING (
        auth.uid() = user_id 
        OR EXISTS (
            SELECT 1 FROM public.providers p
            WHERE p.id = provider_id AND p.user_id = auth.uid()
        )
        OR public.is_admin()
    );

CREATE POLICY "Only admins can delete bookings" ON public.bookings
    FOR DELETE USING (public.is_admin());

-- ----------------------------------------------------------------------------
-- 9.8 REVIEWS TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reviews are viewable by everyone" ON public.reviews
    FOR SELECT USING (true);

CREATE UNIQUE INDEX IF NOT EXISTS uq_reviews_booking_id
ON public.reviews (booking_id)
WHERE booking_id IS NOT NULL;

CREATE POLICY "Authenticated users can submit reviews for completed bookings" ON public.reviews
    FOR INSERT WITH CHECK (
        (
            auth.uid() = user_id
            AND (
                public.is_admin()
                OR (
                    booking_id IS NOT NULL 
                    AND EXISTS (
                        SELECT 1 FROM public.bookings b
                        WHERE b.id = booking_id
                          AND b.user_id = auth.uid()
                          AND b.provider_id = public.reviews.provider_id
                          AND b.status = 'COMPLETED'
                    )
                )
            )
        )
        OR public.is_admin()
    );

CREATE POLICY "Authors can update own reviews" ON public.reviews
    FOR UPDATE USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Authors and admins can delete reviews" ON public.reviews
    FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 9.9 NOTIFICATIONS TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Users can insert own notifications or admins" ON public.notifications
    FOR INSERT WITH CHECK (
        (auth.uid() IS NOT NULL AND auth.uid() = user_id)
        OR public.is_admin()
    );

CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Users can delete own notifications" ON public.notifications
    FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 9.10 AVAILABILITY TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Availability is viewable by everyone" ON public.availability
    FOR SELECT USING (true);

CREATE POLICY "Providers manage own availability" ON public.availability
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.providers p
            WHERE p.id = provider_id AND p.user_id = auth.uid()
        ) OR public.is_admin()
    );

-- ----------------------------------------------------------------------------
-- 9.11 CHAT HISTORY TABLE
-- ----------------------------------------------------------------------------
ALTER TABLE public.chat_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own chat history" ON public.chat_history
    FOR SELECT USING (
        (auth.uid() IS NOT NULL AND auth.uid() = user_id) 
        OR public.is_admin()
    );

CREATE POLICY "Users and guests can insert chat messages" ON public.chat_history
    FOR INSERT WITH CHECK (
        (auth.uid() IS NOT NULL AND auth.uid() = user_id)
        OR (auth.uid() IS NULL AND user_id IS NULL)
        OR public.is_admin()
    );

CREATE POLICY "Admins can delete chat history" ON public.chat_history
    FOR DELETE USING (public.is_admin());

-- ============================================================================
-- 10. STORAGE BUCKET CONFIGURATION & ROLE-ENFORCED POLICIES
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('pet-images', 'pet-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
    ('provider-images', 'provider-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
    ('service-images', 'service-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE 
SET file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY "Public Read pet-images" ON storage.objects
    FOR SELECT USING (bucket_id = 'pet-images');

CREATE POLICY "Users upload own pet images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'pet-images'
        AND (
            (auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Users update own pet images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'pet-images'
        AND (
            (auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Users delete own pet images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'pet-images'
        AND (
            (auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Public Read provider-images" ON storage.objects
    FOR SELECT USING (bucket_id = 'provider-images');

CREATE POLICY "Providers upload own provider images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'provider-images'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Providers update own provider images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'provider-images'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Providers delete own provider images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'provider-images'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Public Read service-images" ON storage.objects
    FOR SELECT USING (bucket_id = 'service-images');

CREATE POLICY "Providers upload service images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'service-images'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Providers update service images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'service-images'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

CREATE POLICY "Providers delete service images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'service-images'
        AND (
            (public.is_provider() AND (storage.foldername(name))[1] = auth.uid()::text)
            OR public.is_admin()
        )
    );

-- 11. REALTIME REPLICATION PUBLICATION CONFIGURATION
-- ============================================================================
DO $$
DECLARE
    tbl TEXT;
    tbls TEXT[] := ARRAY['users', 'providers', 'pets', 'services', 'bookings', 'reviews', 'notifications', 'availability', 'chat_history'];
BEGIN
    FOREACH tbl IN ARRAY tbls LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
              AND schemaname = 'public' 
              AND tablename = tbl
        ) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
        END IF;
    END LOOP;
END $$;
