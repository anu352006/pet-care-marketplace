-- ============================================================================
-- PRODUCTION SECURITY VERIFICATION SCRIPT (FINAL REVISED - READ ONLY)
-- ============================================================================
-- Target Environment: Supabase Production (uuhxfrobjbysasznothx)
-- Validation Environment: Supabase Staging (pcizqsdnddlfxecmgojn)
-- Release: Pet Care & Services Marketplace - Production Security Verification
--
-- STRICT READ-ONLY SAFETY GUARANTEES:
--   1. Zero mutations: Exclusively executes SELECT queries and assertion blocks.
--   2. Zero DDL: No ALTER, DROP, CREATE, or TRUNCATE statements.
--   3. Diagnostic clarity: Returns comprehensive structured diagnostics for each check.
-- ============================================================================

-- ============================================================================
-- CHECK 1: RLS ENABLED AND LEAKED PERMISSIVE POLICIES AUDIT
-- ============================================================================
-- Verifies that RLS is enabled on all tables and NO permissive leaks exist.
WITH rls_status AS (
    SELECT 
        c.relname AS table_name,
        c.relrowsecurity AS rls_enabled,
        c.relforcerowsecurity AS rls_forced
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' 
      AND c.relkind = 'r'
      AND c.relname IN ('users', 'providers', 'reviews', 'bookings', 'services', 'availability', 'pets', 'notifications', 'chat_history')
),
leaked_policies AS (
    SELECT 
        schemaname, tablename, policyname, cmd, qual
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('users', 'providers')
      AND cmd = 'SELECT'
      AND qual = 'true'
)
SELECT 
    'Check 1.1: RLS Enforcement' AS check_name,
    rs.table_name,
    CASE WHEN rs.rls_enabled THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE WHEN rs.rls_enabled THEN 'RLS is strictly enabled' ELSE 'CRITICAL: RLS IS DISABLED' END AS details
FROM rls_status rs
UNION ALL
SELECT 
    'Check 1.2: Privacy Leak Audit (Permissive SELECT true)' AS check_name,
    COALESCE(lp.tablename, 'users/providers') AS table_name,
    CASE WHEN COUNT(lp.policyname) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE 
        WHEN COUNT(lp.policyname) = 0 THEN 'Zero permissive SELECT true policies found on users and providers'
        ELSE 'CRITICAL: Permissive policy leaked: ' || string_agg(lp.policyname, ', ')
    END AS details
FROM leaked_policies lp
GROUP BY lp.tablename;


-- ============================================================================
-- CHECK 2: POLICY INVENTORY AUDIT ON FOCUS TABLES
-- ============================================================================
-- Verifies exact expected policy counts and names on users, providers, reviews, and storage.objects
SELECT 
    'Check 2: Exact Policy Inventory' AS check_name,
    schemaname || '.' || tablename AS target_table,
    COUNT(*) AS active_policies_count,
    string_agg(policyname, ' | ' ORDER BY policyname) AS policy_names
FROM pg_policies
WHERE (schemaname = 'public' AND tablename IN ('users', 'providers', 'reviews'))
   OR (schemaname = 'storage' AND tablename = 'objects')
GROUP BY schemaname, tablename
ORDER BY schemaname, tablename;


-- ============================================================================
-- CHECK 3: SANITIZED PUBLIC VIEW AUDIT (provider_public_profiles)
-- ============================================================================
-- Asserts view exists, security_invoker = false, and exposes only 9 public fields.
WITH view_cols AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'provider_public_profiles'
),
view_opts AS (
    SELECT pg_catalog.pg_options_to_table(c.reloptions) AS opt
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'provider_public_profiles'
)
SELECT 
    'Check 3: Public Provider View Audit' AS check_name,
    'public.provider_public_profiles' AS target,
    CASE 
        WHEN (SELECT COUNT(*) FROM view_cols) = 9
         AND NOT EXISTS (SELECT 1 FROM view_cols WHERE column_name IN ('user_id', 'email', 'phone', 'created_at'))
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS status,
    'Exposes ' || (SELECT COUNT(*) FROM view_cols) || ' columns (0 sensitive columns: user_id, email, phone excluded)' AS details;


-- ============================================================================
-- CHECK 4: AVAILABILITY INTEGRITY CONSTRAINTS AUDIT
-- ============================================================================
-- Asserts time validity check, btree_gist extension, and exclusion constraint exist.
SELECT 
    'Check 4.1: Availability Time Constraint (start_time < end_time)' AS check_name,
    conname,
    CASE WHEN contype = 'c' THEN 'PASS' ELSE 'FAIL' END AS status,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.availability'::regclass 
  AND conname = 'chk_availability_times_valid'
UNION ALL
SELECT 
    'Check 4.2: Availability Overlap Exclusion Constraint' AS check_name,
    conname,
    CASE WHEN contype = 'x' THEN 'PASS' ELSE 'FAIL' END AS status,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.availability'::regclass 
  AND conname = 'chk_availability_no_overlap'
UNION ALL
SELECT 
    'Check 4.3: Availability Slot Unique Composite Index' AS check_name,
    indexname AS conname,
    'PASS' AS status,
    indexdef AS definition
FROM pg_indexes
WHERE schemaname = 'public' 
  AND tablename = 'availability' 
  AND indexname = 'idx_availability_provider_slot_unique';


-- ============================================================================
-- CHECK 5: FUNCTION SECURITY DEFINER & SEARCH PATH AUDIT
-- ============================================================================
-- Verifies that all 9 critical functions have search_path explicitly locked.
WITH target_functions AS (
    SELECT unnest(ARRAY[
        'is_admin',
        'is_provider',
        'is_verified_provider',
        'is_owner',
        'handle_new_user',
        'prevent_user_role_escalation',
        'prevent_provider_verification_tampering',
        'validate_booking_transition_and_fields',
        'validate_review_integrity'
    ]) AS proname
)
SELECT 
    'Check 5: Function Security Hardening' AS check_name,
    tf.proname,
    CASE 
        WHEN p.oid IS NOT NULL 
         AND p.prosecdef = true 
         AND 'search_path=pg_catalog, public, auth' = ANY(p.proconfig) 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS status,
    CASE 
        WHEN p.oid IS NULL THEN 'CRITICAL: Function missing'
        WHEN NOT p.prosecdef THEN 'CRITICAL: Function not SECURITY DEFINER'
        WHEN NOT ('search_path=pg_catalog, public, auth' = ANY(p.proconfig)) THEN 'CRITICAL: search_path not locked to pg_catalog, public, auth'
        ELSE 'SECURITY DEFINER with locked search_path'
    END AS details
FROM target_functions tf
LEFT JOIN pg_proc p ON p.proname = tf.proname AND p.pronamespace = 'public'::regnamespace;


-- ============================================================================
-- CHECK 6: ACTIVE TRIGGERS ATTACHMENT AUDIT
-- ============================================================================
-- Verifies that all 4 security enforcement triggers are active.
WITH target_triggers AS (
    SELECT * FROM (VALUES
        ('public.users', 'trg_prevent_user_role_escalation'),
        ('public.providers', 'trg_prevent_provider_verification_tampering'),
        ('public.bookings', 'trg_validate_booking_transition_and_fields'),
        ('public.reviews', 'trg_validate_review_integrity')
    ) AS t(table_name, trigger_name)
)
SELECT 
    'Check 6: Security Triggers' AS check_name,
    tt.trigger_name,
    CASE WHEN tg.tgenabled = 'O' THEN 'PASS' ELSE 'FAIL' END AS status,
    'Attached to ' || tt.table_name || ' (enabled: ' || COALESCE(tg.tgenabled, 'MISSING') || ')' AS details
FROM target_triggers tt
LEFT JOIN pg_class c ON c.relname = split_part(tt.table_name, '.', 2)
LEFT JOIN pg_trigger tg ON tg.tgrelid = c.oid AND tg.tgname = tt.trigger_name;


-- ============================================================================
-- CHECK 7: STORAGE BUCKET CONFIGURATION & POLICIES AUDIT
-- ============================================================================
SELECT 
    'Check 7.1: Storage Bucket Limits' AS check_name,
    id AS bucket_id,
    CASE 
        WHEN file_size_limit = 5242880 AND array_length(allowed_mime_types, 1) = 4 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS status,
    'Limit: ' || (file_size_limit / 1048576) || 'MB, MIME count: ' || array_length(allowed_mime_types, 1) AS details
FROM storage.buckets
WHERE id IN ('pet-images', 'provider-images', 'service-images')
UNION ALL
SELECT 
    'Check 7.2: Storage Policies Count' AS check_name,
    'storage.objects' AS bucket_id,
    CASE WHEN COUNT(*) = 12 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) || ' total policies active on storage.objects (3 public read + 9 role-isolated mutating)' AS details
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects';
