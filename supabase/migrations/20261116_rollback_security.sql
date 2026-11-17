-- ============================================================================
-- ROLLBACK SCRIPT: Revert Security Migration
-- File: supabase/migrations/20261116_rollback_security.sql
--
-- Safely reverts triggers, unique indexes, views, and custom functions
-- created by 20261116_admin_auth_and_security.sql without dropping tables or deleting data.
-- ============================================================================

-- 1. Drop Triggers
DROP TRIGGER IF EXISTS trg_validate_booking_transition_and_fields ON public.bookings;
DROP TRIGGER IF EXISTS trg_prevent_provider_verification_tampering ON public.providers;
DROP TRIGGER IF EXISTS trg_prevent_user_role_escalation ON public.users;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Drop Functions
DROP FUNCTION IF EXISTS public.validate_booking_transition_and_fields() CASCADE;
DROP FUNCTION IF EXISTS public.prevent_provider_verification_tampering() CASCADE;
DROP FUNCTION IF EXISTS public.prevent_user_role_escalation() CASCADE;
DROP FUNCTION IF EXISTS public.promote_user_to_admin(TEXT) CASCADE;

-- 3. Drop Partial Unique Indexes
DROP INDEX IF EXISTS public.uq_active_booking_slot;
DROP INDEX IF EXISTS public.uq_reviews_booking_id;

-- 4. Drop Public Discovery View
DROP VIEW IF EXISTS public.provider_public_profiles;

-- 5. Restore Baseline Permissive Grants on Tables
GRANT ALL ON public.users TO authenticated;
GRANT SELECT ON public.users TO anon;
GRANT ALL ON public.providers TO authenticated;
GRANT SELECT ON public.providers TO anon;
GRANT ALL ON public.services TO anon, authenticated;
GRANT ALL ON public.pets TO authenticated;
GRANT ALL ON public.bookings TO authenticated;
GRANT ALL ON public.reviews TO anon, authenticated;
GRANT ALL ON public.notifications TO authenticated;
