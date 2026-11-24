-- ============================================================================
-- PRODUCTION SECURITY MIGRATION SCRIPT (FINAL REVISED - PRODUCTION-READY)
-- ============================================================================
-- Target Environment: Supabase Production (uuhxfrobjbysasznothx)
-- Validation Environment: Supabase Staging (pcizqsdnddlfxecmgojn)
-- Release: Pet Care & Services Marketplace - Production Security Hardening
--
-- STRICT PRESERVATION GUARANTEES:
--   1. Zero data loss: Preserves all existing users, providers, services, bookings,
--      reviews, availability, notifications, and storage objects.
--   2. Auth integrity: Does NOT touch auth.users, credentials, passwords, or emails.
--   3. Transactional safety: Executed within an atomic transaction (BEGIN ... COMMIT).
--   4. Idempotency: All DDL uses CREATE OR REPLACE, DROP ... IF EXISTS, and IF NOT EXISTS.
--
-- ============================================================================
-- EXPLICIT RLS POLICY INVENTORY: BEFORE AND AFTER MIGRATION
-- ============================================================================
--
-- 1. public.users
--    --------------------------------------------------------------------------
--    BEFORE (Production Baseline - 3 policies):
--      - "Public users profile read" (SELECT, qual: true) -> CRITICAL LEAK: DROP
--      - "Admin full control on users" (ALL, qual: is_admin()) -> REPLACE with granular
--      - "Users can update own profile" (UPDATE, qual: auth.uid() = id, NO WITH CHECK) -> REPLACE
--    AFTER (Hardened State - 5 policies):
--      - "Users can view own profile" (SELECT, qual: auth.uid() = id)
--      - "Admins can view all user profiles" (SELECT, qual: is_admin())
--      - "Users can update own profile" (UPDATE, qual/check: (auth.uid() = id) OR is_admin())
--      - "Admins can insert user profiles" (INSERT, check: is_admin())
--      - "Admins can delete user profiles" (DELETE, qual: is_admin())
--    VERDICT: Anonymous users cannot read or modify any user data.
--
-- 2. public.providers
--    --------------------------------------------------------------------------
--    BEFORE (Production Baseline - 4 policies):
--      - "Public can view providers" (SELECT, qual: true) -> CRITICAL LEAK: DROP
--      - "Admin full control on providers" (ALL, qual: is_admin()) -> REPLACE with granular
--      - "Provider can insert own profile" (INSERT, check: auth.uid() = user_id) -> REPLACE
--      - "Provider can update own profile" (UPDATE, qual: auth.uid() = user_id) -> REPLACE
--    AFTER (Hardened State - 4 policies + 1 sanitized view):
--      - "Providers view own profile and admins" (SELECT, qual: (auth.uid() = user_id) OR is_admin())
--      - "Providers can register business profile" (INSERT, check: ((auth.uid() = user_id) AND is_provider()) OR is_admin())
--      - "Providers can update own business profile" (UPDATE, qual/check: (auth.uid() = user_id) OR is_admin())
--      - "Admins can delete provider records" (DELETE, qual: is_admin())
--      - VIEW "public.provider_public_profiles" (SELECT, security_invoker = false, 9 public columns only)
--    VERDICT: Base table is private; public reads sanitized view only (zero PII/phone/email).
--
-- 3. public.reviews
--    --------------------------------------------------------------------------
--    BEFORE (Production Baseline - 3 policies):
--      - "Public can view reviews" (SELECT, qual: true) -> STANDARDIZE naming
--      - "Users can insert reviews" (INSERT, check: auth.uid() = user_id) -> REPLACE with completed booking check
--      - "Admin full control on reviews" (ALL, qual: is_admin()) -> REPLACE with granular
--    AFTER (Hardened State - 4 policies):
--      - "Reviews are viewable by everyone" (SELECT, qual: true) [Preserves public review display]
--      - "Authenticated users can submit reviews for completed bookings" (INSERT, check: completed booking & owner)
--      - "Authors can update own reviews" (UPDATE, qual/check: (auth.uid() = user_id) OR is_admin())
--      - "Authors and admins can delete reviews" (DELETE, qual: (auth.uid() = user_id) OR is_admin())
--    VERDICT: Public read preserved; review creation requires completed booking; updates guarded by trigger.
--
-- 4. storage.objects
--    --------------------------------------------------------------------------
--    BEFORE (Production Baseline - 12 policies):
--      - 3 Public SELECT policies ("Public can view pet/provider/service images")
--      - "Authenticated users upload pet images" (INSERT, NO folder check!) -> VULNERABLE: REPLACE
--      - "Providers can upload provider images" (INSERT, allows ANY authenticated user!) -> VULNERABLE: REPLACE
--      - "Providers can upload service images" (INSERT, allows ANY authenticated user!) -> VULNERABLE: REPLACE
--      - 6 update/delete policies with inconsistent folder checks
--    AFTER (Hardened State - 12 standardized policies):
--      - "Public Read pet-images" (SELECT, bucket_id = 'pet-images')
--      - "Public Read provider-images" (SELECT, bucket_id = 'provider-images')
--      - "Public Read service-images" (SELECT, bucket_id = 'service-images')
--      - "Users upload own pet images" (INSERT, authenticated + folder = auth.uid())
--      - "Users update own pet images" (UPDATE, authenticated + folder = auth.uid() OR admin)
--      - "Users delete own pet images" (DELETE, authenticated + folder = auth.uid() OR admin)
--      - "Providers upload own provider images" (INSERT, verified provider + folder = auth.uid())
--      - "Providers update own provider images" (UPDATE, verified provider + folder = auth.uid() OR admin)
--      - "Providers delete own provider images" (DELETE, verified provider + folder = auth.uid() OR admin)
--      - "Providers upload service images" (INSERT, verified provider + folder = auth.uid())
--      - "Providers update service images" (UPDATE, verified provider + folder = auth.uid() OR admin)
--      - "Providers delete service images" (DELETE, verified provider + folder = auth.uid() OR admin)
--    VERDICT: Zero anonymous mutations; folder ownership strictly enforced; verified provider enforced.
--
-- 5. Availability Overlap Prevention Design
--    --------------------------------------------------------------------------
--    - Requires `btree_gist` extension to index uuid, date, and ranges together.
--    - Adds `chk_availability_times_valid`: CHECK (start_time < end_time).
--    - Adds `chk_availability_no_overlap`: EXCLUDE USING gist (
--          provider_id WITH =,
--          date WITH =,
--          tsrange((date + start_time), (date + end_time), '[)') WITH &&
--      ).
--    - Enforces true atomic interval overlap prevention at the PostgreSQL engine level.
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 0: EXTENSION REQUIREMENTS
-- ============================================================================
-- btree_gist provides GiST indexing for scalar datatypes (uuid, date) needed
-- for atomic exclusion constraints on temporal ranges.
CREATE EXTENSION IF NOT EXISTS btree_gist;


-- ============================================================================
-- SECTION 1: SEARCH PATH HARDENING ON CORE FUNCTIONS
-- ============================================================================

-- Function 1.1: is_admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.users
        WHERE id = auth.uid()
          AND role = 'admin'::public.user_role
    );
END;
$function$;

-- Function 1.2: is_provider
CREATE OR REPLACE FUNCTION public.is_provider()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.users
        WHERE id = auth.uid()
          AND role = 'provider'::public.user_role
    );
END;
$function$;

-- Function 1.3: is_verified_provider
CREATE OR REPLACE FUNCTION public.is_verified_provider()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.providers pr
        JOIN public.users u ON pr.user_id = u.id
        WHERE pr.user_id = auth.uid()
          AND pr.verified = true
          AND u.role = 'provider'::public.user_role
    );
END;
$function$;

-- Function 1.4: is_owner
CREATE OR REPLACE FUNCTION public.is_owner(record_owner_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    IF auth.uid() IS NULL OR record_owner_id IS NULL THEN
        RETURN false;
    END IF;
    RETURN auth.uid() = record_owner_id;
END;
$function$;

-- Explicit execution privileges
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_provider() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_verified_provider() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_owner(uuid) TO authenticated, anon;


-- ============================================================================
-- SECTION 2: SIGNUP ROLE ESCALATION PROTECTION (handle_new_user)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
    requested_role text;
    assigned_role public.user_role;
    admin_count int;
BEGIN
    -- Extract requested role from raw_user_meta_data
    requested_role := lower(COALESCE(NEW.raw_user_meta_data->>'role', ''));

    IF requested_role = 'admin' THEN
        -- Allow admin assignment only during initial system bootstrapping (0 admins exist)
        SELECT count(*) INTO admin_count FROM public.users WHERE role = 'admin'::public.user_role;
        IF admin_count = 0 THEN
            assigned_role := 'admin'::public.user_role;
        ELSE
            -- Reject unauthorized self-registration as admin; default safely to pet_owner
            assigned_role := 'pet_owner'::public.user_role;
        END IF;
    ELSIF requested_role = 'provider' THEN
        assigned_role := 'provider'::public.user_role;
    ELSE
        assigned_role := 'pet_owner'::public.user_role;
    END IF;

    -- Insert into public.users with resolved safe role
    INSERT INTO public.users (
        id,
        email,
        full_name,
        role,
        avatar_url,
        phone,
        created_at
    ) VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        assigned_role,
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL),
        COALESCE(NEW.raw_user_meta_data->>'phone', NULL),
        COALESCE(NEW.created_at, now())
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = CASE 
            WHEN public.users.full_name IS NULL OR public.users.full_name = '' 
            THEN EXCLUDED.full_name 
            ELSE public.users.full_name 
        END,
        avatar_url = COALESCE(public.users.avatar_url, EXCLUDED.avatar_url),
        phone = COALESCE(public.users.phone, EXCLUDED.phone);

    RETURN NEW;
END;
$function$;


-- ============================================================================
-- SECTION 3: ROLE ESCALATION & PROVIDER VERIFICATION TRIGGERS
-- ============================================================================

-- Function 3.1: prevent_user_role_escalation
CREATE OR REPLACE FUNCTION public.prevent_user_role_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
        IF NOT public.is_admin() THEN
            RAISE EXCEPTION 'Security Violation: You are not authorized to modify user roles.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'Security Violation: User ID is immutable.'
            USING ERRCODE = '42501';
    END IF;

    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        NEW.created_at := OLD.created_at;
    END IF;

    RETURN NEW;
END;
$function$;

-- Trigger 3.1: Attach to public.users
DROP TRIGGER IF EXISTS trg_prevent_user_role_escalation ON public.users;
CREATE TRIGGER trg_prevent_user_role_escalation
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_user_role_escalation();

-- Function 3.2: prevent_provider_verification_tampering
CREATE OR REPLACE FUNCTION public.prevent_provider_verification_tampering()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.verified IS TRUE THEN
            IF NOT public.is_admin() THEN
                NEW.verified := false;
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.verified IS DISTINCT FROM OLD.verified THEN
            IF NOT public.is_admin() THEN
                RAISE EXCEPTION 'Security Violation: Only platform administrators can change provider verification status.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Security Violation: Provider ID is immutable.'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Security Violation: Provider user_id cannot be reassigned.'
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
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
    svc_record RECORD;
    pet_record RECORD;
    prov_record RECORD;
    is_admin_actor boolean;
    is_owner_party boolean;
    is_provider_party boolean;
BEGIN
    is_admin_actor := public.is_admin();

    -- ====================================================================
    -- 1. INSERT VALIDATION
    -- ====================================================================
    IF TG_OP = 'INSERT' THEN
        SELECT id, provider_id, price, active INTO svc_record
        FROM public.services
        WHERE id = NEW.service_id;

        IF svc_record.id IS NULL THEN
            RAISE EXCEPTION 'Validation Error: Referenced service does not exist.' USING ERRCODE = '23503';
        END IF;

        IF NOT svc_record.active THEN
            RAISE EXCEPTION 'Validation Error: Referenced service is inactive.' USING ERRCODE = '22023';
        END IF;

        IF NEW.provider_id <> svc_record.provider_id THEN
            RAISE EXCEPTION 'Validation Error: Provider ID (%) does not match service provider ID (%).',
                NEW.provider_id, svc_record.provider_id USING ERRCODE = '22023';
        END IF;

        IF NEW.total_price IS DISTINCT FROM svc_record.price THEN
            RAISE EXCEPTION 'Validation Error: Booking total_price (%) does not match catalog price (%).',
                NEW.total_price, svc_record.price USING ERRCODE = '22023';
        END IF;

        SELECT id, owner_id INTO pet_record
        FROM public.pets
        WHERE id = NEW.pet_id;

        IF pet_record.id IS NULL THEN
            RAISE EXCEPTION 'Validation Error: Referenced pet does not exist.' USING ERRCODE = '23503';
        END IF;

        IF pet_record.owner_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Validation Error: Pet does not belong to booking user.' USING ERRCODE = '22023';
        END IF;

        SELECT id, verified INTO prov_record
        FROM public.providers
        WHERE id = NEW.provider_id;

        IF prov_record.id IS NULL THEN
            RAISE EXCEPTION 'Validation Error: Referenced provider does not exist.' USING ERRCODE = '23503';
        END IF;

        IF NOT prov_record.verified THEN
            RAISE EXCEPTION 'Validation Error: Cannot create booking for unverified provider.' USING ERRCODE = '22023';
        END IF;

        IF NEW.status IS NULL THEN
            NEW.status := 'PENDING'::public.booking_status;
        ELSIF NEW.status <> 'PENDING'::public.booking_status AND NOT is_admin_actor THEN
            RAISE EXCEPTION 'Validation Error: New bookings must be created in PENDING status.' USING ERRCODE = '22023';
        END IF;

        RETURN NEW;
    END IF;

    -- ====================================================================
    -- 2. UPDATE VALIDATION
    -- ====================================================================
    IF TG_OP = 'UPDATE' THEN
        is_owner_party := (auth.uid() IS NOT NULL AND auth.uid() = OLD.user_id);
        is_provider_party := (auth.uid() IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.providers pr WHERE pr.id = OLD.provider_id AND pr.user_id = auth.uid()
        ));

        -- Strict actor check: Only owner, assigned provider, or admin may update
        IF NOT (is_admin_actor OR is_owner_party OR is_provider_party) THEN
            RAISE EXCEPTION 'Security Violation: You are not authorized to modify this booking.'
                USING ERRCODE = '42501';
        END IF;

        -- Immutable core keys
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Security Violation: Booking ID is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Security Violation: Booking user_id is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.provider_id IS DISTINCT FROM OLD.provider_id THEN
            RAISE EXCEPTION 'Security Violation: Booking provider_id is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.service_id IS DISTINCT FROM OLD.service_id THEN
            RAISE EXCEPTION 'Security Violation: Booking service_id is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.pet_id IS DISTINCT FROM OLD.pet_id THEN
            RAISE EXCEPTION 'Security Violation: Booking pet_id is immutable.' USING ERRCODE = '42501';
        END IF;

        IF NEW.total_price IS DISTINCT FROM OLD.total_price THEN
            IF NOT is_admin_actor THEN
                RAISE EXCEPTION 'Security Violation: Booking total_price is immutable once created.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Rescheduling appointment
        IF (NEW.booking_date IS DISTINCT FROM OLD.booking_date) OR 
           (NEW.booking_time IS DISTINCT FROM OLD.booking_time) THEN
            IF OLD.status <> 'PENDING'::public.booking_status AND NOT is_admin_actor THEN
                RAISE EXCEPTION 'Validation Error: Rescheduling is only permitted while booking is in PENDING status.'
                    USING ERRCODE = '22023';
            END IF;
        END IF;

        -- Status transition state machine
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            -- Terminal state protection
            IF OLD.status IN ('COMPLETED'::public.booking_status, 'CANCELLED'::public.booking_status) THEN
                IF NOT is_admin_actor THEN
                    RAISE EXCEPTION 'Security Violation: Cannot transition booking out of terminal state %.', OLD.status
                        USING ERRCODE = '42501';
                END IF;
            END IF;

            -- PENDING transitions
            IF OLD.status = 'PENDING'::public.booking_status THEN
                IF NEW.status = 'CONFIRMED'::public.booking_status THEN
                    IF NOT (is_provider_party OR is_admin_actor) THEN
                        RAISE EXCEPTION 'Security Violation: Only the assigned provider or admin can confirm a booking.'
                            USING ERRCODE = '42501';
                    END IF;
                ELSIF NEW.status = 'CANCELLED'::public.booking_status THEN
                    IF NOT (is_owner_party OR is_provider_party OR is_admin_actor) THEN
                        RAISE EXCEPTION 'Security Violation: Only involved parties or admin can cancel a booking.'
                            USING ERRCODE = '42501';
                    END IF;
                ELSE
                    IF NOT is_admin_actor THEN
                        RAISE EXCEPTION 'Security Violation: Invalid status transition from PENDING to %.', NEW.status
                            USING ERRCODE = '42501';
                    END IF;
                END IF;

            -- CONFIRMED transitions
            ELSIF OLD.status = 'CONFIRMED'::public.booking_status THEN
                IF NEW.status = 'COMPLETED'::public.booking_status THEN
                    IF NOT (is_provider_party OR is_admin_actor) THEN
                        RAISE EXCEPTION 'Security Violation: Only the assigned provider or admin can complete a booking.'
                            USING ERRCODE = '42501';
                    END IF;
                ELSIF NEW.status = 'CANCELLED'::public.booking_status THEN
                    IF NOT (is_owner_party OR is_provider_party OR is_admin_actor) THEN
                        RAISE EXCEPTION 'Security Violation: Only involved parties or admin can cancel a confirmed booking.'
                            USING ERRCODE = '42501';
                    END IF;
                ELSE
                    IF NOT is_admin_actor THEN
                        RAISE EXCEPTION 'Security Violation: Invalid status transition from CONFIRMED to %.', NEW.status
                            USING ERRCODE = '42501';
                    END IF;
                END IF;

            -- Fall-through
            ELSE
                IF NOT is_admin_actor THEN
                    RAISE EXCEPTION 'Security Violation: Invalid status transition from % to %.', OLD.status, NEW.status
                        USING ERRCODE = '42501';
                END IF;
            END IF;
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

-- Trigger 4.1: Attach to public.bookings
DROP TRIGGER IF EXISTS trg_validate_booking_transition_and_fields ON public.bookings;
CREATE TRIGGER trg_validate_booking_transition_and_fields
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
SET search_path = 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
    booking_record RECORD;
    is_admin_actor boolean;
BEGIN
    is_admin_actor := public.is_admin();

    -- ====================================================================
    -- 1. INSERT VALIDATION
    -- ====================================================================
    IF TG_OP = 'INSERT' THEN
        IF NOT is_admin_actor THEN
            IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM NEW.user_id THEN
                RAISE EXCEPTION 'Security Violation: Review author user_id must match authenticated caller.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        -- Validate booking linkage
        IF NEW.booking_id IS NOT NULL THEN
            SELECT id, user_id, provider_id, service_id, status INTO booking_record
            FROM public.bookings
            WHERE id = NEW.booking_id;

            IF booking_record.id IS NULL THEN
                RAISE EXCEPTION 'Validation Error: Referenced booking does not exist.' USING ERRCODE = '23503';
            END IF;

            IF booking_record.status <> 'COMPLETED'::public.booking_status THEN
                RAISE EXCEPTION 'Validation Error: Reviews can only be submitted for COMPLETED bookings (current status: %).',
                    booking_record.status USING ERRCODE = '22023';
            END IF;

            IF booking_record.user_id <> NEW.user_id THEN
                RAISE EXCEPTION 'Validation Error: Review author does not match booking owner.' USING ERRCODE = '42501';
            END IF;

            IF booking_record.provider_id <> NEW.provider_id THEN
                RAISE EXCEPTION 'Validation Error: Review provider_id does not match booking provider_id.' USING ERRCODE = '22023';
            END IF;

            IF NEW.service_id IS NOT NULL AND booking_record.service_id <> NEW.service_id THEN
                RAISE EXCEPTION 'Validation Error: Review service_id does not match booking service_id.' USING ERRCODE = '22023';
            END IF;

            IF NEW.service_id IS NULL THEN
                NEW.service_id := booking_record.service_id;
            END IF;
        ELSE
            IF NOT is_admin_actor THEN
                RAISE EXCEPTION 'Validation Error: A verified booking_id is required to submit a customer review.'
                    USING ERRCODE = '22023';
            END IF;
        END IF;

        -- Validate rating
        IF NEW.rating IS NULL OR NEW.rating < 1 OR NEW.rating > 5 THEN
            RAISE EXCEPTION 'Validation Error: Review rating must be an integer between 1 and 5.' USING ERRCODE = '22003';
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

        IF NOT is_admin_actor THEN
            IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM OLD.user_id THEN
                RAISE EXCEPTION 'Security Violation: You are not authorized to update this review.'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        IF NEW.rating IS NULL OR NEW.rating < 1 OR NEW.rating > 5 THEN
            RAISE EXCEPTION 'Validation Error: Review rating must be an integer between 1 and 5.' USING ERRCODE = '22003';
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
-- Exposes ONLY 9 non-sensitive columns; excludes user_id, email, phone, timestamps.
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
-- Explicitly drop ALL prior policy variants across Production and Staging
DROP POLICY IF EXISTS "Public can view providers" ON public.providers;
DROP POLICY IF EXISTS "Provider can insert own profile" ON public.providers;
DROP POLICY IF EXISTS "Provider can update own profile" ON public.providers;
DROP POLICY IF EXISTS "Admin full control on providers" ON public.providers;
DROP POLICY IF EXISTS "Providers view own profile and admins" ON public.providers;
DROP POLICY IF EXISTS "Providers can register business profile" ON public.providers;
DROP POLICY IF EXISTS "Providers can update own business profile" ON public.providers;
DROP POLICY IF EXISTS "Admins can delete provider records" ON public.providers;

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

CREATE POLICY "Admins can delete provider records"
    ON public.providers FOR DELETE
    USING (public.is_admin());


-- ============================================================================
-- SECTION 7: PUBLIC.USERS RLS HARDENING (PRIVACY ENFORCEMENT)
-- ============================================================================

-- Explicitly drop ALL prior policy variants across Production and Staging
DROP POLICY IF EXISTS "Public users profile read" ON public.users;
DROP POLICY IF EXISTS "Admin full control on users" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Admins can view all user profiles" ON public.users;
DROP POLICY IF EXISTS "Admins can insert user profiles" ON public.users;
DROP POLICY IF EXISTS "Admins can delete user profiles" ON public.users;

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

CREATE POLICY "Admins can insert user profiles"
    ON public.users FOR INSERT
    WITH CHECK (public.is_admin());

CREATE POLICY "Admins can delete user profiles"
    ON public.users FOR DELETE
    USING (public.is_admin());


-- ============================================================================
-- SECTION 8: PUBLIC.REVIEWS RLS HARDENING
-- ============================================================================

-- Explicitly drop ALL prior policy variants across Production and Staging
DROP POLICY IF EXISTS "Public can view reviews" ON public.reviews;
DROP POLICY IF EXISTS "Users can insert reviews" ON public.reviews;
DROP POLICY IF EXISTS "Admin full control on reviews" ON public.reviews;
DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.reviews;
DROP POLICY IF EXISTS "Authenticated users can submit reviews for completed bookings" ON public.reviews;
DROP POLICY IF EXISTS "Authors can update own reviews" ON public.reviews;
DROP POLICY IF EXISTS "Authors and admins can delete reviews" ON public.reviews;

-- Preserves intended public read of customer reviews
CREATE POLICY "Reviews are viewable by everyone"
    ON public.reviews FOR SELECT
    USING (true);

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
-- SECTION 9: STORAGE BUCKET CONFIGURATION & POLICIES
-- ============================================================================

-- 1. Configure 5MB size limit and image MIME-types on all three buckets
UPDATE storage.buckets
SET file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
WHERE id IN ('pet-images', 'provider-images', 'service-images');

-- 2. Explicitly drop ALL 12 Production policies AND ALL 12 Staging policies on storage.objects
DROP POLICY IF EXISTS "Public can view pet images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view provider images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view service images" ON storage.objects;
DROP POLICY IF EXISTS "Public Read pet-images" ON storage.objects;
DROP POLICY IF EXISTS "Public Read provider-images" ON storage.objects;
DROP POLICY IF EXISTS "Public Read service-images" ON storage.objects;

DROP POLICY IF EXISTS "Authenticated users upload pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users upload own pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users update own pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own pet images" ON storage.objects;

DROP POLICY IF EXISTS "Providers can upload provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can update own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can delete own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers upload own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers update own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers delete own provider images" ON storage.objects;

DROP POLICY IF EXISTS "Providers can upload service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can update own service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers can delete own service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers upload service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers update service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers delete service images" ON storage.objects;

-- 3. Create standardized, hardened policies
-- A. Public CDN Read Policies (3 buckets)
CREATE POLICY "Public Read pet-images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'pet-images');

CREATE POLICY "Public Read provider-images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'provider-images');

CREATE POLICY "Public Read service-images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'service-images');

-- B. pet-images: Authenticated user must own the top-level folder
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

-- C. provider-images: Must be VERIFIED provider AND own top-level folder
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

-- D. service-images: Must be VERIFIED provider AND own top-level folder
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
-- SECTION 10: INTEGRITY CONSTRAINTS & AVAILABILITY OVERLAP PREVENTION
-- ============================================================================

-- 1. Availability start_time < end_time check constraint
ALTER TABLE public.availability 
    DROP CONSTRAINT IF EXISTS chk_availability_times_valid;
ALTER TABLE public.availability 
    ADD CONSTRAINT chk_availability_times_valid 
    CHECK (start_time < end_time);

-- 2. Availability overlapping range exclusion constraint
-- Uses GiST indexing with btree_gist to enforce non-overlapping time ranges
-- for the same provider on the same date.
ALTER TABLE public.availability 
    DROP CONSTRAINT IF EXISTS chk_availability_no_overlap;
ALTER TABLE public.availability 
    ADD CONSTRAINT chk_availability_no_overlap
    EXCLUDE USING gist (
        provider_id WITH =,
        date WITH =,
        tsrange((date + start_time), (date + end_time), '[)'::text) WITH &&
    );

-- 3. Availability unique provider slot composite index (exact duplicate lookups)
CREATE UNIQUE INDEX IF NOT EXISTS idx_availability_provider_slot_unique 
    ON public.availability USING btree (provider_id, date, start_time, end_time);

-- 4. Review unique booking partial index
CREATE UNIQUE INDEX IF NOT EXISTS uq_reviews_booking_id 
    ON public.reviews USING btree (booking_id) 
    WHERE (booking_id IS NOT NULL);


-- ============================================================================
-- SECTION 11: POST-MIGRATION INTEGRITY SANITY CHECKS
-- ============================================================================
DO $$
DECLARE
    leaked_user_policies int;
    leaked_provider_policies int;
    unverified_storage_policies int;
    overlap_constraint_exists boolean;
BEGIN
    -- Assert zero public/anon readable policies on users
    SELECT count(*) INTO leaked_user_policies
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users'
      AND cmd = 'SELECT' AND qual = 'true';

    IF leaked_user_policies > 0 THEN
        RAISE EXCEPTION 'POST-CHECK FAILED: Leaked permissive SELECT policy found on public.users!';
    END IF;

    -- Assert zero public/anon readable policies on providers
    SELECT count(*) INTO leaked_provider_policies
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'providers'
      AND cmd = 'SELECT' AND qual = 'true';

    IF leaked_provider_policies > 0 THEN
        RAISE EXCEPTION 'POST-CHECK FAILED: Leaked permissive SELECT policy found on public.providers!';
    END IF;

    -- Assert overlap exclusion constraint exists
    SELECT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_availability_no_overlap'
          AND conrelid = 'public.availability'::regclass
    ) INTO overlap_constraint_exists;

    IF NOT overlap_constraint_exists THEN
        RAISE EXCEPTION 'POST-CHECK FAILED: Availability overlap exclusion constraint chk_availability_no_overlap is missing!';
    END IF;

    RAISE NOTICE 'POST-MIGRATION SANITY CHECKS PASSED: Zero permissive leaks, overlap exclusion constraint verified.';
END $$;

COMMIT;
