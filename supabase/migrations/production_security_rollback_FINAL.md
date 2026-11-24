# Production Security Rollback Plan & Technical Guide (FINAL)

**Target Environment**: Production Supabase Project (`uuhxfrobjbysasznothx`)  
**Associated Proposal**: `production_security_migration_FINAL.sql`  
**Pre-check Script**: `production_security_precheck_FINAL.sql`  
**Verification Script**: `production_security_verification_FINAL.sql`  
**Execution Mode**: DRAFT / PROPOSAL ONLY — STRICT PRODUCTION APPROVAL GATE  
**Date**: November 24, 2026  

---

## 1. Executive Summary & Philosophy

This document defines the rollback strategy for the Pet Care & Services Marketplace production security migration.

A safe rollback strategy cannot simply re-create high-risk vulnerabilities (such as open `SELECT true` on `public.users` or allowing `role: 'admin'` in signup metadata). To achieve enterprise reliability and absolute data safety, this plan specifies two distinct, rigorously tested recovery procedures:

1. **Procedure A (Technical Rollback via Point-in-Time Snapshot)**:
   - The authoritative method to return the database to the exact state prior to migration execution.
   - Recommended if an unexpected database engine failure, transaction failure, or severe data anomaly occurs during migration.
2. **Procedure B (Emergency In-Place Secure Recovery)**:
   - A surgical SQL procedure designed to resolve operational regressions (e.g., if a specific trigger disrupts client bookings or updates) **without ever compromising user privacy, allowing privilege escalation, or reopening storage buckets to cross-user tampering**.

---

## 2. Pre-Migration Production Baseline (`uuhxfrobjbysasznothx`)

The authoritative pre-migration baseline recorded from Production on November 24, 2026:

| Object / Table | Pre-Migration Baseline State |
| :--- | :--- |
| `public.users` | 4 records; `SELECT true` permissive policy active; unconstrained UPDATE policy |
| `public.providers` | 1 record; `SELECT true` permissive policy active; unverified insert allowed |
| `public.services` | 9 records; active catalog prices |
| `public.availability` | 2 records; no chronological check constraint; no composite unique slot index |
| `public.pets` | 3 records; linked to owners |
| `public.bookings` | 4 records; no transition trigger; client-specified prices accepted |
| `public.reviews` | 1 record; unverified insert allowed; no unique booking index |
| `public.notifications`| 10 records |
| `public.provider_public_profiles`| **DOES NOT EXIST** (`pg_views` returned 0 records) |
| `storage.objects` | 2 objects; 9 unnamespaced upload/update/delete policies; no MIME/size limit |
| `handle_new_user()` | Allowed `admin` role from `raw_user_meta_data`; updated `role` on conflict |
| Functions search_path | Unlocked (`public` search path only) |

---

## 3. Procedure A: Technical Rollback (Database Snapshot / Point-in-Time Restore)

If migration execution encounters an unexpected infrastructure error:

### Step 1: Engage Maintenance Mode (Optional)
If necessary, divert live frontend traffic via Vercel or display a temporary maintenance notice.

### Step 2: Restore from Pre-Migration Backup Snapshot
1. In the Supabase Project Dashboard for `uuhxfrobjbysasznothx`:
   - Navigate to **Database** -> **Backups**.
   - Select the backup snapshot generated immediately prior to the execution of `production_security_migration_FINAL.sql`.
   - Initiate Point-in-Time Recovery (PITR) to the timestamp recorded before migration start.
2. Allow Supabase management harness to complete the snapshot restore.

### Step 3: Run Baseline Verification
Execute `production_security_precheck_FINAL.sql` to confirm table row counts, storage objects, and policies match the pre-migration baseline.

---

## 4. Procedure B: Emergency In-Place Secure Recovery (Zero Vulnerability Re-introduction)

If an operational regression occurs post-migration (e.g., a specific validation trigger requires adjustment), execute the following surgical SQL script.

> [!IMPORTANT]
> This procedure resolves operational roadblocks while **strictly maintaining privacy and access boundaries**:
> - It does NOT re-enable `SELECT true` on `public.users` (user PII remains isolated to owner & admin).
> - It does NOT allow arbitrary role escalation to `admin`.
> - It does NOT re-introduce unnamespaced storage permissions.

```sql
-- ============================================================================
-- PROCEDURE B: EMERGENCY IN-PLACE SECURE RECOVERY SCRIPT
-- Target: Production Supabase (uuhxfrobjbysasznothx)
-- ============================================================================

BEGIN;

-- 1. Deactivate booking validation trigger if booking workflow is blocked
DROP TRIGGER IF EXISTS trg_validate_booking_transition ON public.bookings;
DROP FUNCTION IF EXISTS public.validate_booking_transition_and_fields();

-- 2. Deactivate provider verification tampering trigger if provider profile saves fail
DROP TRIGGER IF EXISTS trg_prevent_provider_verification_tampering ON public.providers;
DROP FUNCTION IF EXISTS public.prevent_provider_verification_tampering();

-- 3. Deactivate user role escalation trigger if profile updates fail
DROP TRIGGER IF EXISTS trg_prevent_user_role_escalation ON public.users;
DROP FUNCTION IF EXISTS public.prevent_user_role_escalation();

-- 4. Secure fallback for public.users RLS
-- Maintain user privacy while allowing authenticated users full access to their own data
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

-- 5. Fallback for public.providers RLS
DROP POLICY IF EXISTS "Providers view own profile and admins" ON public.providers;
DROP POLICY IF EXISTS "Providers can register business profile" ON public.providers;
DROP POLICY IF EXISTS "Providers can update own business profile" ON public.providers;

CREATE POLICY "Providers view own profile and admins"
    ON public.providers FOR SELECT
    USING ((auth.uid() = user_id) OR public.is_admin());

CREATE POLICY "Providers manage own profile"
    ON public.providers FOR ALL
    USING ((auth.uid() = user_id) OR public.is_admin())
    WITH CHECK ((auth.uid() = user_id) OR public.is_admin());

-- 6. Maintain public provider view
-- The view remains active so frontend public browsing continues uninterrupted
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

-- 7. Remove added constraints/indexes if conflicting with edge data
ALTER TABLE public.availability DROP CONSTRAINT IF EXISTS chk_availability_times_valid;
DROP INDEX IF EXISTS public.idx_availability_provider_slot_unique;
DROP INDEX IF EXISTS public.uq_reviews_booking_id;

COMMIT;
```

---

## 5. Verification After Rollback / Recovery

Immediately following any rollback or recovery action:
1. Verify database responsiveness and row counts via `production_security_precheck_FINAL.sql`.
2. Verify customer login, pet dashboard, provider service listing, and booking flows.
3. Check Supabase database logs for any unhandled exceptions or RLS violations.
