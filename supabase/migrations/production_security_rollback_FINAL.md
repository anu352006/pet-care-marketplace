# PRODUCTION SECURITY MIGRATION ROLLBACK PLAN (FINAL REVISED)

**Target Environment**: Supabase Production (`uuhxfrobjbysasznothx`)  
**Validation Environment**: Supabase Staging (`pcizqsdnddlfxecmgojn`)  
**Release**: Pet Care & Services Marketplace - Production Security Hardening  
**Document Classification**: Operational Recovery Procedure  

---

## 1. Rollback Overview & Safety Principles

If any critical issue arises during or following the execution of `production_security_migration_FINAL.sql`, this document establishes two distinct, mutually exclusive recovery procedures.

> [!CAUTION]
> **ZERO PERMISSIVE REGRESSION GUARANTEE**:
> Under no circumstances should a rollback recreate the insecure legacy policies that exposed private customer data to anonymous users (e.g., `SELECT true` on `public.users` or `public.providers`). A rollback must restore operational availability without opening security vulnerabilities.

---

## 2. Recovery Procedure A: Full Database Snapshot / Point-in-Time Recovery (PITR)

### 2.1 When to Use
Use Procedure A if an unrecoverable schema corruption occurs, or if state synchronization between Auth, Storage, and PostgreSQL is severely compromised.

### 2.2 Execution Steps
1. **Initiate Maintenance Window**:
   - Temporarily pause incoming client traffic in Vercel or route traffic to a maintenance page.
2. **Access Supabase Dashboard**:
   - Navigate to **Project Settings** > **Database** > **Backups** for project `uuhxfrobjbysasznothx`.
3. **Select Restore Target**:
   - If Point-in-Time Recovery (PITR) is enabled, select the exact timestamp `T_PRE_MIGRATION` recorded in the migration pre-check log.
   - If manual backup was captured via `pg_dump`, restore the pre-migration snapshot:
     ```bash
     psql -h db.uuhxfrobjbysasznothx.supabase.co -U postgres -d postgres -f pre_migration_backup.sql
     ```
4. **Post-Restore Verification**:
   - Run `production_security_precheck_FINAL.sql` to confirm baseline row counts match:
     - 4 users, 1 provider, 9 services, 2 availability, 3 pets, 4 bookings, 1 review, 4 notifications, 2 storage objects.

---

## 3. Recovery Procedure B: Surgical In-Place Reversion

### 3.1 When to Use
Use Procedure B to revert specific triggers, constraints, or policies without database downtime, table locking, or data loss.

### 3.2 Surgical Reversion Script

Execute the following SQL block within an atomic transaction (`BEGIN ... COMMIT`):

```sql
BEGIN;

-- ============================================================================
-- 1. DROP SECURITY TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS trg_validate_review_integrity ON public.reviews;
DROP TRIGGER IF EXISTS trg_validate_booking_transition_and_fields ON public.bookings;
DROP TRIGGER IF EXISTS trg_prevent_provider_verification_tampering ON public.providers;
DROP TRIGGER IF EXISTS trg_prevent_user_role_escalation ON public.users;

-- ============================================================================
-- 2. DROP INTEGRITY CONSTRAINTS
-- ============================================================================
ALTER TABLE public.availability DROP CONSTRAINT IF EXISTS chk_availability_no_overlap;
ALTER TABLE public.availability DROP CONSTRAINT IF EXISTS chk_availability_times_valid;
DROP INDEX IF EXISTS public.idx_availability_provider_slot_unique;
DROP INDEX IF EXISTS public.uq_reviews_booking_id;

-- ============================================================================
-- 3. DROP SANITIZED PUBLIC VIEW
-- ============================================================================
DROP VIEW IF EXISTS public.provider_public_profiles;

-- ============================================================================
-- 4. REVERT STORAGE POLICIES TO BASELINE
-- ============================================================================
-- Drop hardened policies
DROP POLICY IF EXISTS "Users upload own pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users update own pet images" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own pet images" ON storage.objects;
DROP POLICY IF EXISTS "Providers upload own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers update own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers delete own provider images" ON storage.objects;
DROP POLICY IF EXISTS "Providers upload service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers update service images" ON storage.objects;
DROP POLICY IF EXISTS "Providers delete service images" ON storage.objects;
DROP POLICY IF EXISTS "Public Read pet-images" ON storage.objects;
DROP POLICY IF EXISTS "Public Read provider-images" ON storage.objects;
DROP POLICY IF EXISTS "Public Read service-images" ON storage.objects;

-- Restore baseline storage policies
CREATE POLICY "Public can view pet images" ON storage.objects FOR SELECT USING (bucket_id = 'pet-images');
CREATE POLICY "Public can view provider images" ON storage.objects FOR SELECT USING (bucket_id = 'provider-images');
CREATE POLICY "Public can view service images" ON storage.objects FOR SELECT USING (bucket_id = 'service-images');

CREATE POLICY "Authenticated users upload pet images" ON storage.objects FOR INSERT
WITH CHECK ((bucket_id = 'pet-images') AND (auth.role() = 'authenticated'));

CREATE POLICY "Users can update their pet images" ON storage.objects FOR UPDATE
USING ((bucket_id = 'pet-images') AND (((auth.uid())::text = (owner)::text) OR ((auth.uid())::text = (storage.foldername(name))[1]) OR public.is_admin()));

CREATE POLICY "Users can delete their pet images" ON storage.objects FOR DELETE
USING ((bucket_id = 'pet-images') AND (((auth.uid())::text = (owner)::text) OR ((auth.uid())::text = (storage.foldername(name))[1]) OR public.is_admin()));

CREATE POLICY "Providers can upload provider images" ON storage.objects FOR INSERT
WITH CHECK ((bucket_id = 'provider-images') AND (public.is_provider() OR public.is_admin() OR (auth.role() = 'authenticated')));

CREATE POLICY "Providers can update own provider images" ON storage.objects FOR UPDATE
USING ((bucket_id = 'provider-images') AND (((auth.uid())::text = (owner)::text) OR ((auth.uid())::text = (storage.foldername(name))[1]) OR public.is_admin()));

CREATE POLICY "Providers can delete own provider images" ON storage.objects FOR DELETE
USING ((bucket_id = 'provider-images') AND (((auth.uid())::text = (owner)::text) OR ((auth.uid())::text = (storage.foldername(name))[1]) OR public.is_admin()));

CREATE POLICY "Providers can upload service images" ON storage.objects FOR INSERT
WITH CHECK ((bucket_id = 'service-images') AND (public.is_provider() OR public.is_admin() OR (auth.role() = 'authenticated')));

CREATE POLICY "Providers can update own service images" ON storage.objects FOR UPDATE
USING ((bucket_id = 'service-images') AND (((auth.uid())::text = (owner)::text) OR ((auth.uid())::text = (storage.foldername(name))[1]) OR public.is_admin()));

CREATE POLICY "Providers can delete own service images" ON storage.objects FOR DELETE
USING ((bucket_id = 'service-images') AND (((auth.uid())::text = (owner)::text) OR ((auth.uid())::text = (storage.foldername(name))[1]) OR public.is_admin()));

-- ============================================================================
-- 5. REVERT TABLE RLS POLICIES (SAFE RESTORATION)
-- ============================================================================
-- public.reviews
DROP POLICY IF EXISTS "Authenticated users can submit reviews for completed bookings" ON public.reviews;
DROP POLICY IF EXISTS "Authors can update own reviews" ON public.reviews;
DROP POLICY IF EXISTS "Authors and admins can delete reviews" ON public.reviews;
DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.reviews;

CREATE POLICY "Public can view reviews" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Users can insert reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admin full control on reviews" ON public.reviews FOR ALL USING (public.is_admin());

-- public.providers (Restoring operational baseline)
DROP POLICY IF EXISTS "Providers view own profile and admins" ON public.providers;
DROP POLICY IF EXISTS "Providers can register business profile" ON public.providers;
DROP POLICY IF EXISTS "Providers can update own business profile" ON public.providers;
DROP POLICY IF EXISTS "Admins can delete provider records" ON public.providers;

CREATE POLICY "Provider can insert own profile" ON public.providers FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Provider can update own profile" ON public.providers FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admin full control on providers" ON public.providers FOR ALL USING (public.is_admin());
-- Note: "Public can view providers" (SELECT true) is deliberately OMITTED to prevent re-opening PII leaks.

-- public.users (Restoring operational baseline)
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Admins can view all user profiles" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Admins can insert user profiles" ON public.users;
DROP POLICY IF EXISTS "Admins can delete user profiles" ON public.users;

CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admin full control on users" ON public.users FOR ALL USING (public.is_admin());
-- Note: "Public users profile read" (SELECT true) is deliberately OMITTED.

COMMIT;
```

---

## 4. Verification After Rollback

Following execution of Procedure A or Procedure B:
1. Verify that `public.users` has 0 rows returned for anonymous callers (`auth.uid() IS NULL`).
2. Verify that all 4 existing production bookings remain intact and queryable.
3. Verify that the production application at `https://pet-care-marketplace.vercel.app/` loads without console errors.
4. Verify database health:
   ```sql
   SELECT count(*) FROM public.users;        -- Expected: 4
   SELECT count(*) FROM public.providers;    -- Expected: 1
   SELECT count(*) FROM public.services;     -- Expected: 9
   SELECT count(*) FROM public.bookings;     -- Expected: 4
   SELECT count(*) FROM public.reviews;      -- Expected: 1
   ```
