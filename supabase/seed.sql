-- ============================================================================
-- SUPABASE SEED DATA: Pet Care & Services Marketplace
-- Pure PostgreSQL 15+ DML for Supabase
-- Run in: Supabase Dashboard -> SQL Editor -> New query -> Paste & Run
-- (Execute AFTER supabase/schema.sql and supabase/storage.sql)
-- ============================================================================
--
-- IMPORTANT PREREQUISITE:
-- In compliance with Supabase security rules, this script DOES NOT directly insert
-- into 'auth.users' or create fake authentication credentials.
--
-- Before running this seed script, you MUST register at least the core demo users
-- in Supabase Authentication:
--   Option A: Supabase Dashboard -> Authentication -> Users -> "Add User" -> "Create User"
--   Option B: React Web App -> Register page (/register)
--
-- REQUIRED MULTI-PROVIDER STAGING ACCOUNTS IN SUPABASE AUTHENTICATION:
-- (Create in Supabase Dashboard -> Authentication -> Users -> Add User -> Create User
--  with "Auto Confirm User" toggled ON)
-- -----------------------------------------------------------------------------------
-- | Role             | Email Address               | Status / Specialty / City          |
-- |------------------|-----------------------------|------------------------------------|
-- | Pet Owner        | priya.petowner@example.com  | Pet Owner (Priya Sundaram)         |
-- | Provider (Vet)   | aarav.vet@example.com       | Vet: Dr. Aarav Sharma (Bengaluru)  |
-- | Provider (Groom) | pooja.grooming@example.com  | Grooming: Pooja Deshmukh (Mumbai)  |
-- | Provider (Board) | rohan.happytails@example.com| Boarding: Rohan Mehra (Delhi NCR)  |
-- | Provider (Train) | vikram.k9@example.com       | Training: Vikram Joshi (Pune)      |
-- | Provider (Walk)  | ananya.walkers@example.com  | Walking: Ananya Reddy (Hyderabad)  |
-- | Provider (Taxi)  | karthik.petride@example.com | Transit: Karthik Subramanian (MAA) |
-- | Administrator    | admin@petcare.org           | Platform Governance Administrator  |
-- -----------------------------------------------------------------------------------
--
-- MULTI-PROVIDER ARCHITECTURE:
-- Silent provider fallback/consolidation is strictly removed. All 6 distinct
-- provider accounts and the pet owner account must exist in Authentication before
-- seeding to guarantee authentic multi-city, multi-specialty marketplace data.
-- ============================================================================

SET search_path = public, extensions;

DO $$
DECLARE
    -- User UUIDs resolved from public.users
    owner_uid UUID;
    admin_uid UUID;
    prov1_uid UUID;
    prov2_uid UUID;
    prov3_uid UUID;
    prov4_uid UUID;
    prov5_uid UUID;
    prov6_uid UUID;

    -- Provider Profile UUIDs
    p1_id UUID;
    p2_id UUID;
    p3_id UUID;
    p4_id UUID;
    p5_id UUID;
    p6_id UUID;

    -- Pet UUIDs
    pet1_id UUID;
    pet2_id UUID;
    pet3_id UUID;

    -- Service UUIDs
    s1_id UUID;
    s2_id UUID;
    s3_id UUID;
    s4_id UUID;

    user_count INT;
    provider_count INT;
    service_count INT;
    availability_count INT;
    pet_count INT;
    booking_count INT;
    review_count INT;
    notification_count INT;

    -- Lookup validation counters
    v_cnt INT;
    v_b1_cnt INT;
    v_b2_cnt INT;

    -- Safeguard & duplicate validation counters
    v_r1_cnt INT;
    v_r2_cnt INT;
    v_r3_cnt INT;
    v_dup_review_cnt INT;
    v_dup_svc_cnt INT;
    v_dup_avail_cnt INT;
    v_dup_pet_cnt INT;
    v_dup_booking_cnt INT;
BEGIN
    -- 1. Check if ANY user exists in public.users
    SELECT COUNT(*) INTO user_count FROM public.users;
    IF user_count = 0 THEN
        RAISE EXCEPTION 'SEED HALTED: public.users has 0 records! You must create at least one user in Supabase Authentication first (Supabase Dashboard -> Authentication -> Users -> Add user, e.g. priya.petowner@example.com and aarav.vet@example.com). After creating the user(s), re-run this seed script.';
    END IF;

    -- ========================================================================
    -- 2. SYNCHRONIZE & PROMOTE ROLES IN PUBLIC.USERS
    -- (Essential if users were created via Supabase Dashboard without metadata)
    -- ========================================================================
    UPDATE public.users 
    SET role = 'provider',
        full_name = 'Dr. Aarav Sharma',
        phone = COALESCE(phone, '+91 98450 12345')
    WHERE email = 'aarav.vet@example.com';

    UPDATE public.users 
    SET role = 'provider',
        full_name = 'Pooja Deshmukh',
        phone = COALESCE(phone, '+91 98200 45678')
    WHERE email = 'pooja.grooming@example.com';

    UPDATE public.users 
    SET role = 'provider',
        full_name = 'Rohan Mehra',
        phone = COALESCE(phone, '+91 98110 78901')
    WHERE email = 'rohan.happytails@example.com';

    UPDATE public.users 
    SET role = 'provider',
        full_name = 'Vikram Joshi',
        phone = COALESCE(phone, '+91 97660 33445')
    WHERE email = 'vikram.k9@example.com';

    UPDATE public.users 
    SET role = 'provider',
        full_name = 'Ananya Reddy',
        phone = COALESCE(phone, '+91 94400 99887')
    WHERE email = 'ananya.walkers@example.com';

    UPDATE public.users 
    SET role = 'provider',
        full_name = 'Karthik Subramanian',
        phone = COALESCE(phone, '+91 98840 55667')
    WHERE email = 'karthik.petride@example.com';

    UPDATE public.users 
    SET role = 'pet_owner',
        full_name = 'Priya Sundaram',
        phone = COALESCE(phone, '+91 98765 43210')
    WHERE email = 'priya.petowner@example.com';

    UPDATE public.users 
    SET role = 'admin',
        full_name = 'System Administrator',
        phone = COALESCE(phone, '+91 80234 56789')
    WHERE email = 'admin@petcare.org';

    -- ========================================================================
    -- 3. RESOLVE AUTHENTICATED USER IDS (STRICT: NO SILENT FALLBACK)
    -- ========================================================================
    -- Deterministic user lookups: verify exact single-row resolution for each account
    SELECT count(*), max(id) INTO v_cnt, owner_uid FROM public.users WHERE email = 'priya.petowner@example.com';
    IF v_cnt != 1 OR owner_uid IS NULL THEN
        RAISE EXCEPTION 'SEED HALTED: Expected exactly 1 pet owner account with email "priya.petowner@example.com", found % rows.', v_cnt
            USING ERRCODE = 'P0002';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, admin_uid FROM public.users WHERE email = 'admin@petcare.org';
    IF v_cnt != 1 OR admin_uid IS NULL THEN
        RAISE EXCEPTION 'SEED HALTED: Expected exactly 1 administrator account with email "admin@petcare.org", found % rows.', v_cnt
            USING ERRCODE = 'P0002';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, prov1_uid FROM public.users WHERE email = 'aarav.vet@example.com';
    IF v_cnt != 1 OR prov1_uid IS NULL THEN
        RAISE EXCEPTION 'SEED HALTED: Expected exactly 1 provider account with email "aarav.vet@example.com", found % rows.', v_cnt
            USING ERRCODE = 'P0002';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, prov2_uid FROM public.users WHERE email = 'pooja.grooming@example.com';
    IF v_cnt != 1 OR prov2_uid IS NULL THEN
        RAISE EXCEPTION 'SEED HALTED: Expected exactly 1 provider account with email "pooja.grooming@example.com", found % rows.', v_cnt
            USING ERRCODE = 'P0002';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, prov3_uid FROM public.users WHERE email = 'rohan.happytails@example.com';
    IF v_cnt != 1 OR prov3_uid IS NULL THEN
        RAISE EXCEPTION 'SEED HALTED: Expected exactly 1 provider account with email "rohan.happytails@example.com", found % rows.', v_cnt
            USING ERRCODE = 'P0002';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, prov4_uid FROM public.users WHERE email = 'vikram.k9@example.com';
    IF v_cnt != 1 OR prov4_uid IS NULL THEN
        RAISE EXCEPTION 'SEED HALTED: Expected exactly 1 provider account with email "vikram.k9@example.com", found % rows.', v_cnt
            USING ERRCODE = 'P0002';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, prov5_uid FROM public.users WHERE email = 'ananya.walkers@example.com';
    IF v_cnt != 1 OR prov5_uid IS NULL THEN
        RAISE EXCEPTION 'SEED HALTED: Expected exactly 1 provider account with email "ananya.walkers@example.com", found % rows.', v_cnt
            USING ERRCODE = 'P0002';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, prov6_uid FROM public.users WHERE email = 'karthik.petride@example.com';
    IF v_cnt != 1 OR prov6_uid IS NULL THEN
        RAISE EXCEPTION 'SEED HALTED: Expected exactly 1 provider account with email "karthik.petride@example.com", found % rows.', v_cnt
            USING ERRCODE = 'P0002';
    END IF;

    -- ========================================================================
    -- 4. PROVISION & ENRICH PROVIDER PROFILES (ALL 6 SPECIALIST PROVIDERS)
    -- ========================================================================
    -- Provider 1: Dr. Aarav Sharma (Vet - Bengaluru)
    SELECT count(*), max(id) INTO v_cnt, p1_id FROM public.providers WHERE user_id = prov1_uid;
    IF v_cnt > 1 THEN
        RAISE EXCEPTION 'DATABASE ERROR: Multiple provider profiles found for Dr. Aarav Sharma (%). Aborting.', prov1_uid USING ERRCODE = 'P0003';
    END IF;
    IF p1_id IS NULL THEN
        INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
        VALUES (prov1_uid, 'Paws & Claws Veterinary Wellness', 'Indiranagar, Bengaluru', 'Experienced veterinarian with 12+ years of clinical expertise in canine internal medicine, feline preventative diagnostics, and surgical wellness.', true, 4.9, 142)
        RETURNING id INTO p1_id;
    ELSE
        UPDATE public.providers
        SET business_name = 'Paws & Claws Veterinary Wellness',
            location = 'Indiranagar, Bengaluru',
            description = 'Experienced veterinarian with 12+ years of clinical expertise in canine internal medicine, feline preventative diagnostics, and surgical wellness.',
            verified = true,
            rating = 4.9,
            reviews_count = 142
        WHERE id = p1_id;
    END IF;

    -- Provider 2: Pooja Deshmukh (Grooming - Mumbai)
    SELECT count(*), max(id) INTO v_cnt, p2_id FROM public.providers WHERE user_id = prov2_uid;
    IF v_cnt > 1 THEN
        RAISE EXCEPTION 'DATABASE ERROR: Multiple provider profiles found for Pooja Deshmukh (Grooming - Mumbai) (%). Aborting.', prov2_uid USING ERRCODE = 'P0003';
    END IF;
    IF p2_id IS NULL THEN
        INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
        VALUES (prov2_uid, 'Velvet Fur Luxury Grooming Salon', 'Bandra West, Mumbai', 'Certified master pet stylist specializing in breed-specific haircuts, aromatic botanical baths, de-shedding, and anxiety-free feline grooming.', true, 4.8, 98)
        RETURNING id INTO p2_id;
    ELSE
        UPDATE public.providers
        SET business_name = 'Velvet Fur Luxury Grooming Salon',
            location = 'Bandra West, Mumbai',
            description = 'Certified master pet stylist specializing in breed-specific haircuts, aromatic botanical baths, de-shedding, and anxiety-free feline grooming.',
            verified = true,
            rating = 4.8,
            reviews_count = 98
        WHERE id = p2_id;
    END IF;

    -- Provider 3: Rohan Mehra (Boarding - Delhi NCR)
    SELECT count(*), max(id) INTO v_cnt, p3_id FROM public.providers WHERE user_id = prov3_uid;
    IF v_cnt > 1 THEN
        RAISE EXCEPTION 'DATABASE ERROR: Multiple provider profiles found for Rohan Mehra (Boarding - Delhi NCR) (%). Aborting.', prov3_uid USING ERRCODE = 'P0003';
    END IF;
    IF p3_id IS NULL THEN
        INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
        VALUES (prov3_uid, 'Happy Tails Green Boarding Resort', 'Gurugram, Delhi NCR', 'Eco-friendly pet retreat featuring 2 acres of grassy play paddocks, splash pools, climate-regulated private suites, and 24/7 on-site medical supervision.', true, 4.7, 84)
        RETURNING id INTO p3_id;
    ELSE
        UPDATE public.providers
        SET business_name = 'Happy Tails Green Boarding Resort',
            location = 'Gurugram, Delhi NCR',
            description = 'Eco-friendly pet retreat featuring 2 acres of grassy play paddocks, splash pools, climate-regulated private suites, and 24/7 on-site medical supervision.',
            verified = true,
            rating = 4.7,
            reviews_count = 84
        WHERE id = p3_id;
    END IF;

    -- Provider 4: Vikram Joshi (Training - Pune)
    SELECT count(*), max(id) INTO v_cnt, p4_id FROM public.providers WHERE user_id = prov4_uid;
    IF v_cnt > 1 THEN
        RAISE EXCEPTION 'DATABASE ERROR: Multiple provider profiles found for Vikram Joshi (Training - Pune) (%). Aborting.', prov4_uid USING ERRCODE = 'P0003';
    END IF;
    IF p4_id IS NULL THEN
        INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
        VALUES (prov4_uid, 'Pawsome Canines Training Academy', 'Koregaon Park, Pune', 'Certified positive-reinforcement behaviorist covering foundational puppy training, leash reactivity, impulse control, and agility sports.', true, 4.9, 116)
        RETURNING id INTO p4_id;
    ELSE
        UPDATE public.providers
        SET business_name = 'Pawsome Canines Training Academy',
            location = 'Koregaon Park, Pune',
            description = 'Certified positive-reinforcement behaviorist covering foundational puppy training, leash reactivity, impulse control, and agility sports.',
            verified = true,
            rating = 4.9,
            reviews_count = 116
        WHERE id = p4_id;
    END IF;

    -- Provider 5: Ananya Reddy (Walking - Hyderabad)
    SELECT count(*), max(id) INTO v_cnt, p5_id FROM public.providers WHERE user_id = prov5_uid;
    IF v_cnt > 1 THEN
        RAISE EXCEPTION 'DATABASE ERROR: Multiple provider profiles found for Ananya Reddy (Walking - Hyderabad) (%). Aborting.', prov5_uid USING ERRCODE = 'P0003';
    END IF;
    IF p5_id IS NULL THEN
        INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
        VALUES (prov5_uid, 'CityWalkers & Feline Friends', 'Jubilee Hills, Hyderabad', 'Dedicated animal fitness specialists providing daily neighborhood walks, live GPS tracking, in-home companionship, and puppy play sessions.', true, 4.9, 73)
        RETURNING id INTO p5_id;
    ELSE
        UPDATE public.providers
        SET business_name = 'CityWalkers & Feline Friends',
            location = 'Jubilee Hills, Hyderabad',
            description = 'Dedicated animal fitness specialists providing daily neighborhood walks, live GPS tracking, in-home companionship, and puppy play sessions.',
            verified = true,
            rating = 4.9,
            reviews_count = 73
        WHERE id = p5_id;
    END IF;

    -- Provider 6: Karthik Subramanian (Taxi - Chennai)
    SELECT count(*), max(id) INTO v_cnt, p6_id FROM public.providers WHERE user_id = prov6_uid;
    IF v_cnt > 1 THEN
        RAISE EXCEPTION 'DATABASE ERROR: Multiple provider profiles found for Karthik Subramanian (Taxi - Chennai) (%). Aborting.', prov6_uid USING ERRCODE = 'P0003';
    END IF;
    IF p6_id IS NULL THEN
        INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
        VALUES (prov6_uid, 'PetRide Express Cab & Ambulance', 'Adyar, Chennai', 'Sanitized, air-conditioned animal transportation equipped with stretchers, safety harnesses, and oxygen equipment for clinic trips and airport transfers.', true, 4.8, 62)
        RETURNING id INTO p6_id;
    ELSE
        UPDATE public.providers
        SET business_name = 'PetRide Express Cab & Ambulance',
            location = 'Adyar, Chennai',
            description = 'Sanitized, air-conditioned animal transportation equipped with stretchers, safety harnesses, and oxygen equipment for clinic trips and airport transfers.',
            verified = true,
            rating = 4.8,
            reviews_count = 62
        WHERE id = p6_id;
    END IF;

    -- Positively assert that all 6 provider profile IDs resolved to distinct records
    IF p1_id IS NULL OR p2_id IS NULL OR p3_id IS NULL OR 
       p4_id IS NULL OR p5_id IS NULL OR p6_id IS NULL THEN
        RAISE EXCEPTION 'PROVIDER RESOLUTION ERROR: One or more provider profiles failed to resolve.'
            USING ERRCODE = 'P0003';
    END IF;

    IF (SELECT count(DISTINCT id) FROM (VALUES (p1_id), (p2_id), (p3_id), (p4_id), (p5_id), (p6_id)) AS t(id)) != 6 THEN
        RAISE EXCEPTION 'PROVIDER RESOLUTION ERROR: Duplicate provider IDs detected among personas.'
            USING ERRCODE = 'P0003';
    END IF;

    -- ========================================================================
    -- 5. RECONCILE & INSERT REALISTIC MARKETPLACE SERVICES (INR PRICING & CITIES)
    -- ========================================================================
    -- Safeguard 2: Deterministic Service Ownership Reconciliation
    --
    -- Business & Safety Rules:
    -- 1. Check title uniqueness: each of the 9 seed service titles must resolve to at most 1 row in public.services.
    --    If any title is duplicated, abort immediately without modifying any row.
    -- 2. Explicit pre-update ownership checks:
    --    - For the two veterinary services ('Comprehensive Health & Wellness Exam' and 'Essential Annual Vaccination Package'):
    --      If the service already exists, its owner MUST be Dr. Aarav Sharma (p1_id). If it belongs to any other provider,
    --      abort immediately to protect third-party/unrelated services.
    --    - For services 3 to 9: If the service already exists, its owner MUST be either the target specialist provider
    --      or the known previous seed provider (p1_id, from earlier staging consolidated seed execution).
    --      If it belongs to any unrelated provider, abort immediately without modifying it.
    -- 3. Reassignment: Only reassign records from p1_id to target provider when previous ownership is positively verified.
    DECLARE
        r_svc RECORD;
        v_svc_cnt INT;
        v_existing_prov UUID;
    BEGIN
        FOR r_svc IN (
            SELECT 'Comprehensive Health & Wellness Exam' AS title, p1_id AS target_prov, p1_id AS allowed_orig UNION ALL
            SELECT 'Essential Annual Vaccination Package', p1_id, p1_id UNION ALL
            SELECT 'Royal Spa Bath & Full Body Grooming', p2_id, p1_id UNION ALL
            SELECT 'Tick & Flea Deep Medicated Wash', p2_id, p1_id UNION ALL
            SELECT 'Luxury Suite Overnight Boarding', p3_id, p1_id UNION ALL
            SELECT 'Pet Daycare Social Agility Park', p3_id, p1_id UNION ALL
            SELECT 'Puppy Foundation & Basic Manners (6 Sessions)', p4_id, p1_id UNION ALL
            SELECT 'Daily 45-Min Fitness Dog Walk', p5_id, p1_id UNION ALL
            SELECT 'Sanitized Pet Taxi & Vet Transit Ride', p6_id, p1_id
        ) LOOP
            SELECT count(*), max(provider_id)
            INTO v_svc_cnt, v_existing_prov
            FROM public.services
            WHERE title = r_svc.title;

            -- Abort if duplicate titles exist
            IF v_svc_cnt > 1 THEN
                RAISE EXCEPTION 'SERVICE RECONCILIATION ERROR: Duplicate service title "%" detected (% rows). Aborting to prevent inconsistent reassignment.', r_svc.title, v_svc_cnt
                    USING ERRCODE = 'P0003';
            END IF;

            -- Pre-update ownership check if record exists
            IF v_svc_cnt = 1 THEN
                -- Vet services (1 & 2): Must belong to p1_id
                IF r_svc.target_prov = p1_id AND r_svc.allowed_orig = p1_id THEN
                    IF v_existing_prov != p1_id THEN
                        RAISE EXCEPTION 'SERVICE OWNERSHIP ERROR: Vet service "%" is owned by unexpected provider (%) instead of Dr. Aarav Sharma (%). Aborting without modifying.',
                            r_svc.title, v_existing_prov, p1_id
                            USING ERRCODE = 'P0003';
                    END IF;
                -- Non-vet services (3 to 9): Must belong to either target_prov or p1_id
                ELSE
                    IF v_existing_prov != r_svc.target_prov AND v_existing_prov != r_svc.allowed_orig THEN
                        RAISE EXCEPTION 'SERVICE OWNERSHIP ERROR: Service "%" is owned by unrelated provider (%) instead of expected target (%) or known seed provider (%). Aborting without modifying.',
                            r_svc.title, v_existing_prov, r_svc.target_prov, r_svc.allowed_orig
                            USING ERRCODE = 'P0003';
                    END IF;
                END IF;

                -- Reassign only from known seed provider p1_id to target_prov
                IF v_existing_prov = r_svc.allowed_orig AND r_svc.allowed_orig != r_svc.target_prov THEN
                    UPDATE public.services
                    SET provider_id = r_svc.target_prov
                    WHERE title = r_svc.title AND provider_id = r_svc.allowed_orig;

                    RAISE NOTICE 'Service Reconciliation: Successfully reassigned service "%" from Provider 1 to target provider (%).', r_svc.title, r_svc.target_prov;
                END IF;
            END IF;
        END LOOP;
    END;

    -- Veterinary Services (Dr. Aarav Sharma - Bengaluru)
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p1_id, 'vet', 'Comprehensive Health & Wellness Exam', 'Thorough nose-to-tail physical exam, vital signs check, nutritional advice, dental assessment, and tailored wellness counseling for dogs and cats.', 850.00, 'https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?auto=format&fit=crop&w=800&q=80', 4.9, '45 mins', '["09:30 AM", "11:00 AM", "02:30 PM", "04:30 PM", "06:00 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Comprehensive Health & Wellness Exam'
    );

    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p1_id, 'vet', 'Essential Annual Vaccination Package', 'Full core immunizations (DHPPi/Rabies for dogs or Tricat/Rabies for cats) combined with deworming and health passport sign-off.', 1450.00, 'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&w=800&q=80', 4.9, '30 mins', '["10:00 AM", "12:00 PM", "03:30 PM", "05:30 PM"]'::jsonb, false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Essential Annual Vaccination Package'
    );

    -- Grooming Services (Pooja Deshmukh - Mumbai)
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p2_id, 'grooming', 'Royal Spa Bath & Full Body Grooming', 'Hydro-massage bath with natural botanical conditioning shampoo, full-body breed haircut, blow-dry, ear cleansing, and nail grinding.', 1800.00, 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80', 4.8, '90 mins', '["10:00 AM", "01:00 PM", "03:30 PM", "06:00 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Royal Spa Bath & Full Body Grooming'
    );

    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p2_id, 'grooming', 'Tick & Flea Deep Medicated Wash', 'Therapeutic rinse to eliminate external parasites, soothe irritated skin, and restore healthy skin moisture barrier.', 1200.00, 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80', 4.7, '60 mins', '["09:00 AM", "11:30 AM", "02:00 PM", "04:30 PM"]'::jsonb, false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Tick & Flea Deep Medicated Wash'
    );

    -- Boarding & Daycare (Rohan Mehra - Delhi NCR)
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p3_id, 'boarding', 'Luxury Suite Overnight Boarding', 'Private AC suites, orthopaedic bedding, 3 gourmet meals per day, supervised paddock playtime, and daily photo/video updates.', 1500.00, 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=800&q=80', 4.8, '24 hours', '["Check-in: 09:00 AM", "Check-in: 02:00 PM", "Check-in: 06:00 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Luxury Suite Overnight Boarding'
    );

    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p3_id, 'daycare', 'Pet Daycare Social Agility Park', 'Supervised daytime playground with obstacle tunnels, splash pads, ball pits, and cozy nap stations.', 800.00, 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80', 4.7, '8 hours', '["08:00 AM - 04:00 PM", "10:00 AM - 06:00 PM"]'::jsonb, false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Pet Daycare Social Agility Park'
    );

    -- Training Services (Vikram Joshi - Pune)
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p4_id, 'training', 'Puppy Foundation & Basic Manners (6 Sessions)', 'Positive-reinforcement training covering sit, stay, recall, potty training, impulse control, and biting deterrence.', 7500.00, 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?auto=format&fit=crop&w=800&q=80', 4.9, '6 x 60 mins', '["Weekend Batches", "Weekday Mornings", "Weekday Evenings"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Puppy Foundation & Basic Manners (6 Sessions)'
    );

    -- Walking Services (Ananya Reddy - Hyderabad)
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p5_id, 'walking', 'Daily 45-Min Fitness Dog Walk', 'Brisk neighborhood walk focused on exercise, sniffing enrichment, leash manners, and waste cleanup with live GPS route map.', 350.00, 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?auto=format&fit=crop&w=800&q=80', 4.9, '45 mins', '["06:30 AM", "07:30 AM", "05:00 PM", "06:30 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Daily 45-Min Fitness Dog Walk'
    );

    -- Pet Taxi & Transport (Karthik Subramanian - Chennai)
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p6_id, 'taxi', 'Sanitized Pet Taxi & Vet Transit Ride', 'Stress-free, sanitized, AC vehicle equipped with pet safety harnesses, ramp access, and protective seat covers for vet visits and airport drops.', 900.00, 'https://images.unsplash.com/photo-1544568100-847a948585b9?auto=format&fit=crop&w=800&q=80', 4.8, 'Base (up to 10 km)', '["08:00 AM", "11:00 AM", "02:00 PM", "05:00 PM", "08:00 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE title = 'Sanitized Pet Taxi & Vet Transit Ride'
    );

    -- Post-insert verification: Check that each service title resolves to exactly one row and correct provider
    DECLARE
        r_chk RECORD;
        v_chk_cnt INT;
        v_chk_prov UUID;
    BEGIN
        FOR r_chk IN (
            SELECT 'Comprehensive Health & Wellness Exam' AS title, p1_id AS expected_prov UNION ALL
            SELECT 'Essential Annual Vaccination Package', p1_id UNION ALL
            SELECT 'Royal Spa Bath & Full Body Grooming', p2_id UNION ALL
            SELECT 'Tick & Flea Deep Medicated Wash', p2_id UNION ALL
            SELECT 'Luxury Suite Overnight Boarding', p3_id UNION ALL
            SELECT 'Pet Daycare Social Agility Park', p3_id UNION ALL
            SELECT 'Puppy Foundation & Basic Manners (6 Sessions)', p4_id UNION ALL
            SELECT 'Daily 45-Min Fitness Dog Walk', p5_id UNION ALL
            SELECT 'Sanitized Pet Taxi & Vet Transit Ride', p6_id
        ) LOOP
            SELECT count(*), max(provider_id) INTO v_chk_cnt, v_chk_prov
            FROM public.services WHERE title = r_chk.title;

            IF v_chk_cnt != 1 THEN
                RAISE EXCEPTION 'SERVICE RESOLUTION ERROR: Expected exactly 1 service titled "%", found % rows.', r_chk.title, v_chk_cnt
                    USING ERRCODE = 'P0003';
            END IF;

            IF v_chk_prov != r_chk.expected_prov THEN
                RAISE EXCEPTION 'SERVICE RESOLUTION ERROR: Service "%" is owned by provider % instead of expected %.', r_chk.title, v_chk_prov, r_chk.expected_prov
                    USING ERRCODE = 'P0003';
            END IF;
        END LOOP;
    END;

    -- ========================================================================
    -- 6. INSERT PROVIDER AVAILABILITY SLOTS (ALL 6 SPECIALIST PROVIDERS)
    -- ========================================================================
    -- Schema Note: public.availability does not define a database-level UNIQUE
    -- constraint or index on (provider_id, date, start_time, end_time).
    -- Therefore, NOT EXISTS clauses below provide DML-level idempotency only and
    -- do not provide database-level concurrency safety against race conditions.
    -- Strict uniqueness and absence of duplicates are verified post-seed in Section 11.

    -- Reconcile previous seed availability slots from earlier calendar runs:
    -- Safely remove existing seed-generated slots for the 6 providers where dates are
    -- outside the intended rolling window, preventing stale slot accumulation across days.
    DELETE FROM public.availability
    WHERE (
        (provider_id = p1_id AND start_time = '09:00:00'::TIME AND end_time = '18:00:00'::TIME AND date NOT IN ((CURRENT_DATE + INTERVAL '1 day')::DATE, (CURRENT_DATE + INTERVAL '2 days')::DATE))
        OR (provider_id = p2_id AND start_time = '10:00:00'::TIME AND end_time = '19:00:00'::TIME AND date NOT IN ((CURRENT_DATE + INTERVAL '1 day')::DATE, (CURRENT_DATE + INTERVAL '2 days')::DATE, (CURRENT_DATE + INTERVAL '3 days')::DATE))
        OR (provider_id = p3_id AND start_time = '08:00:00'::TIME AND end_time = '20:00:00'::TIME AND date NOT IN ((CURRENT_DATE + INTERVAL '1 day')::DATE, (CURRENT_DATE + INTERVAL '2 days')::DATE))
        OR (provider_id = p4_id AND start_time = '07:00:00'::TIME AND end_time = '17:00:00'::TIME AND date NOT IN ((CURRENT_DATE + INTERVAL '1 day')::DATE, (CURRENT_DATE + INTERVAL '2 days')::DATE))
        OR (provider_id = p5_id AND start_time = '06:00:00'::TIME AND end_time = '19:00:00'::TIME AND date NOT IN ((CURRENT_DATE + INTERVAL '1 day')::DATE, (CURRENT_DATE + INTERVAL '2 days')::DATE))
        OR (provider_id = p6_id AND start_time = '08:00:00'::TIME AND end_time = '20:00:00'::TIME AND date NOT IN ((CURRENT_DATE + INTERVAL '1 day')::DATE, (CURRENT_DATE + INTERVAL '2 days')::DATE))
    );

    -- Provider 1: Dr. Aarav Sharma (Bengaluru)
    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p1_id, (CURRENT_DATE + INTERVAL '1 day')::DATE, '09:00:00'::TIME, '18:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p1_id 
          AND date = (CURRENT_DATE + INTERVAL '1 day')::DATE
          AND start_time = '09:00:00'::TIME
          AND end_time = '18:00:00'::TIME
    );

    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p1_id, (CURRENT_DATE + INTERVAL '2 days')::DATE, '09:00:00'::TIME, '18:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p1_id 
          AND date = (CURRENT_DATE + INTERVAL '2 days')::DATE
          AND start_time = '09:00:00'::TIME
          AND end_time = '18:00:00'::TIME
    );

    -- Provider 2: Pooja Deshmukh (Mumbai)
    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p2_id, (CURRENT_DATE + INTERVAL '1 day')::DATE, '10:00:00'::TIME, '19:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p2_id 
          AND date = (CURRENT_DATE + INTERVAL '1 day')::DATE
          AND start_time = '10:00:00'::TIME
          AND end_time = '19:00:00'::TIME
    );

    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p2_id, (CURRENT_DATE + INTERVAL '2 days')::DATE, '10:00:00'::TIME, '19:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p2_id 
          AND date = (CURRENT_DATE + INTERVAL '2 days')::DATE
          AND start_time = '10:00:00'::TIME
          AND end_time = '19:00:00'::TIME
    );

    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p2_id, (CURRENT_DATE + INTERVAL '3 days')::DATE, '10:00:00'::TIME, '19:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p2_id 
          AND date = (CURRENT_DATE + INTERVAL '3 days')::DATE
          AND start_time = '10:00:00'::TIME
          AND end_time = '19:00:00'::TIME
    );

    -- Provider 3: Rohan Mehra (Delhi NCR)
    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p3_id, (CURRENT_DATE + INTERVAL '1 day')::DATE, '08:00:00'::TIME, '20:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p3_id 
          AND date = (CURRENT_DATE + INTERVAL '1 day')::DATE
          AND start_time = '08:00:00'::TIME
          AND end_time = '20:00:00'::TIME
    );

    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p3_id, (CURRENT_DATE + INTERVAL '2 days')::DATE, '08:00:00'::TIME, '20:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p3_id 
          AND date = (CURRENT_DATE + INTERVAL '2 days')::DATE
          AND start_time = '08:00:00'::TIME
          AND end_time = '20:00:00'::TIME
    );

    -- Provider 4: Vikram Joshi (Pune)
    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p4_id, (CURRENT_DATE + INTERVAL '1 day')::DATE, '07:00:00'::TIME, '17:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p4_id 
          AND date = (CURRENT_DATE + INTERVAL '1 day')::DATE
          AND start_time = '07:00:00'::TIME
          AND end_time = '17:00:00'::TIME
    );

    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p4_id, (CURRENT_DATE + INTERVAL '2 days')::DATE, '07:00:00'::TIME, '17:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p4_id 
          AND date = (CURRENT_DATE + INTERVAL '2 days')::DATE
          AND start_time = '07:00:00'::TIME
          AND end_time = '17:00:00'::TIME
    );

    -- Provider 5: Ananya Reddy (Hyderabad)
    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p5_id, (CURRENT_DATE + INTERVAL '1 day')::DATE, '06:00:00'::TIME, '19:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p5_id 
          AND date = (CURRENT_DATE + INTERVAL '1 day')::DATE
          AND start_time = '06:00:00'::TIME
          AND end_time = '19:00:00'::TIME
    );

    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p5_id, (CURRENT_DATE + INTERVAL '2 days')::DATE, '06:00:00'::TIME, '19:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p5_id 
          AND date = (CURRENT_DATE + INTERVAL '2 days')::DATE
          AND start_time = '06:00:00'::TIME
          AND end_time = '19:00:00'::TIME
    );

    -- Provider 6: Karthik Subramanian (Chennai)
    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p6_id, (CURRENT_DATE + INTERVAL '1 day')::DATE, '08:00:00'::TIME, '20:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p6_id 
          AND date = (CURRENT_DATE + INTERVAL '1 day')::DATE
          AND start_time = '08:00:00'::TIME
          AND end_time = '20:00:00'::TIME
    );

    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p6_id, (CURRENT_DATE + INTERVAL '2 days')::DATE, '08:00:00'::TIME, '20:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability 
        WHERE provider_id = p6_id 
          AND date = (CURRENT_DATE + INTERVAL '2 days')::DATE
          AND start_time = '08:00:00'::TIME
          AND end_time = '20:00:00'::TIME
    );

    -- ========================================================================
    -- 7. INSERT SAMPLE PETS FOR OWNER
    -- ========================================================================
    INSERT INTO public.pets (owner_id, name, animal_type, breed, age, gender, weight, vaccination_details, medical_history, image_url)
    SELECT owner_uid, 'Bruno', 'Dog', 'Golden Retriever', 3, 'Male', '31 kg', 'Rabies (Valid Dec 2026), DHPPi complete', 'Mild chicken allergy. Regular ear cleaning required.', 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=600&q=80'
    WHERE NOT EXISTS (
        SELECT 1 FROM public.pets WHERE owner_id = owner_uid AND name = 'Bruno'
    );

    INSERT INTO public.pets (owner_id, name, animal_type, breed, age, gender, weight, vaccination_details, medical_history, image_url)
    SELECT owner_uid, 'Mochi', 'Cat', 'Persian Longhair', 2, 'Female', '4.2 kg', 'Tricat (Valid Aug 2026), Rabies up to date', 'Sensitive digestive tract. Requires daily combing to prevent coat mats.', 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80'
    WHERE NOT EXISTS (
        SELECT 1 FROM public.pets WHERE owner_id = owner_uid AND name = 'Mochi'
    );

    INSERT INTO public.pets (owner_id, name, animal_type, breed, age, gender, weight, vaccination_details, medical_history, image_url)
    SELECT owner_uid, 'Coco', 'Dog', 'Beagle', 1, 'Male', '12 kg', 'Complete puppy vaccination series done, Anti-rabies current', 'Active and playful, no chronic issues.', 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=600&q=80'
    WHERE NOT EXISTS (
        SELECT 1 FROM public.pets WHERE owner_id = owner_uid AND name = 'Coco'
    );

    -- Resolve Pet IDs with explicit single-row assertions
    SELECT count(*), max(id) INTO v_cnt, pet1_id FROM public.pets WHERE owner_id = owner_uid AND name = 'Bruno';
    IF v_cnt != 1 OR pet1_id IS NULL THEN
        RAISE EXCEPTION 'PET RESOLUTION ERROR: Expected exactly 1 pet named "Bruno" for owner %, found % rows.', owner_uid, v_cnt
            USING ERRCODE = 'P0003';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, pet2_id FROM public.pets WHERE owner_id = owner_uid AND name = 'Mochi';
    IF v_cnt != 1 OR pet2_id IS NULL THEN
        RAISE EXCEPTION 'PET RESOLUTION ERROR: Expected exactly 1 pet named "Mochi" for owner %, found % rows.', owner_uid, v_cnt
            USING ERRCODE = 'P0003';
    END IF;

    SELECT count(*), max(id) INTO v_cnt, pet3_id FROM public.pets WHERE owner_id = owner_uid AND name = 'Coco';
    IF v_cnt != 1 OR pet3_id IS NULL THEN
        RAISE EXCEPTION 'PET RESOLUTION ERROR: Expected exactly 1 pet named "Coco" for owner %, found % rows.', owner_uid, v_cnt
            USING ERRCODE = 'P0003';
    END IF;

    -- ========================================================================
    -- 8. INSERT SAMPLE BOOKINGS (RESPECTS PARTIAL UNIQUE INDEX & RLS)
    -- ========================================================================
    -- Booking 1: Bruno with Dr. Aarav Sharma (Vet - Bengaluru)
    -- Deterministic service resolution: exact title match, uniqueness, ownership & price validation
    DECLARE
        v_s1_cnt INT;
        v_s1_price NUMERIC(10,2);
        v_s1_prov UUID;
    BEGIN
        SELECT count(*), max(id), max(price), max(provider_id)
        INTO v_s1_cnt, s1_id, v_s1_price, v_s1_prov
        FROM public.services
        WHERE title = 'Comprehensive Health & Wellness Exam';

        IF v_s1_cnt != 1 OR s1_id IS NULL THEN
            RAISE EXCEPTION 'BOOKING SERVICE RESOLUTION ERROR: Expected exactly 1 service titled "Comprehensive Health & Wellness Exam", found % rows.', v_s1_cnt
                USING ERRCODE = 'P0003';
        END IF;

        IF v_s1_prov != p1_id THEN
            RAISE EXCEPTION 'BOOKING SERVICE RESOLUTION ERROR: Service "Comprehensive Health & Wellness Exam" belongs to provider % instead of Dr. Aarav (%).', v_s1_prov, p1_id
                USING ERRCODE = 'P0003';
        END IF;

        IF v_s1_price != 850.00 THEN
            RAISE EXCEPTION 'BOOKING SERVICE RESOLUTION ERROR: Service "Comprehensive Health & Wellness Exam" price (%) does not match booking total (850.00).', v_s1_price
                USING ERRCODE = 'P0003';
        END IF;
    END;

    -- Reconcile previous seed Booking 1 if it exists with past date from an earlier calendar run
    DELETE FROM public.bookings
    WHERE user_id = owner_uid
      AND pet_id = pet1_id
      AND provider_id = p1_id
      AND service_id = s1_id
      AND booking_time = '11:00 AM'
      AND total_price = 850.00
      AND booking_date != (CURRENT_DATE + INTERVAL '1 day')::DATE;

    IF pet1_id IS NOT NULL THEN
        INSERT INTO public.bookings (pet_id, service_id, provider_id, user_id, booking_date, booking_time, status, total_price, booking_notes)
        SELECT pet1_id, s1_id, p1_id, owner_uid, (CURRENT_DATE + INTERVAL '1 day')::DATE, '11:00 AM', 'CONFIRMED'::public.booking_status, 850.00, 'Routine annual general checkup & wellness review.'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.bookings WHERE provider_id = p1_id AND booking_date = (CURRENT_DATE + INTERVAL '1 day')::DATE AND booking_time = '11:00 AM'
        );
    ELSE
        RAISE EXCEPTION 'BOOKING ERROR: Pet Bruno (pet1_id) not found for owner.' USING ERRCODE = 'P0003';
    END IF;

    -- ------------------------------------------------------------------------
    -- 8.1 Reconcile Fallback Booking 2 with Exact Multi-Field Validation (Safeguard 1)
    -- ------------------------------------------------------------------------
    -- In a prior consolidated seed run, Booking 2 (grooming for Mochi) was assigned
    -- to p1_id because p2_id fell back to p1_id. Because booking provider_id and
    -- service_id are strictly immutable under trigger trg_validate_booking_transition,
    -- we must positively identify the exact seed-fallback booking and delete it by primary key
    -- before re-creating it under Pooja Deshmukh (p2_id).
    --
    -- Multi-field validation requirement:
    -- Positively verifies expected original service (Royal Spa Bath & Full Body Grooming)
    -- and expected booking date, along with user_id, pet_id, provider_id, status, total_price,
    -- booking_time, and booking_notes. Aborts execution if any field differs or if multiple match.
    DECLARE
        r RECORD;
        v_fallback_b2_id UUID;
        v_orig_s2_id UUID;
        v_orig_s2_cnt INT;
        v_candidate_b2_count INT := 0;
        v_actual_service_id UUID;
        v_actual_booking_date DATE;
        v_actual_status public.booking_status;
        v_actual_total_price NUMERIC(10,2);
        v_actual_booking_time TEXT;
        v_actual_booking_notes TEXT;
        v_b2_created_at TIMESTAMPTZ;
    BEGIN
        -- Resolve expected original grooming service ID with uniqueness check
        SELECT count(*), max(id)
        INTO v_orig_s2_cnt, v_orig_s2_id 
        FROM public.services 
        WHERE title = 'Royal Spa Bath & Full Body Grooming';

        IF v_orig_s2_cnt != 1 OR v_orig_s2_id IS NULL THEN
            RAISE EXCEPTION 'RECONCILIATION ERROR: Expected exactly 1 service "Royal Spa Bath & Full Body Grooming", found % rows.', v_orig_s2_cnt
                USING ERRCODE = 'P0003';
        END IF;

        -- Acquire exclusive row locks on matching candidate fallback bookings using FOR UPDATE
        -- and iterate to count and capture record attributes safely against race conditions.
        FOR r IN (
            SELECT id, service_id, booking_date, status, total_price, booking_time, booking_notes, created_at
            FROM public.bookings
            WHERE user_id = owner_uid
              AND pet_id = pet2_id
              AND provider_id = p1_id
            FOR UPDATE
        ) LOOP
            v_candidate_b2_count := v_candidate_b2_count + 1;
            v_fallback_b2_id := r.id;
            v_actual_service_id := r.service_id;
            v_actual_booking_date := r.booking_date;
            v_actual_status := r.status;
            v_actual_total_price := r.total_price;
            v_actual_booking_time := r.booking_time;
            v_actual_booking_notes := r.booking_notes;
            v_b2_created_at := r.created_at;
        END LOOP;

        -- Abort immediately if multiple records match
        IF v_candidate_b2_count > 1 THEN
            RAISE EXCEPTION 'RECONCILIATION ERROR: Multiple fallback bookings matched criteria (% rows). Aborting to prevent accidental data deletion.', v_candidate_b2_count
                USING ERRCODE = 'P0003';
        END IF;

        -- If exactly one candidate exists, verify ALL fields before deleting by primary key
        IF v_candidate_b2_count = 1 THEN
            IF v_fallback_b2_id IS NULL THEN
                RAISE EXCEPTION 'RECONCILIATION ERROR: Fallback booking primary key is NULL. Aborting.'
                    USING ERRCODE = 'P0003';
            END IF;

            -- Field 1: Verify service_id matches expected original grooming service
            IF v_actual_service_id != v_orig_s2_id THEN
                RAISE EXCEPTION 'RECONCILIATION ERROR: Fallback booking service_id (%) does not match expected original grooming service ID (%). Aborting.', v_actual_service_id, v_orig_s2_id
                    USING ERRCODE = 'P0003';
            END IF;

            -- Field 2: Verify booking_date matches expected seed schedule
            -- (Accepts relative 3-day offset from insertion timestamp, known staging baseline 2026-11-20, or current 3-day projection)
            IF v_actual_booking_date != (v_b2_created_at::DATE + INTERVAL '3 days')::DATE
               AND v_actual_booking_date != DATE '2026-11-20'
               AND v_actual_booking_date != (CURRENT_DATE + INTERVAL '3 days')::DATE THEN
                RAISE EXCEPTION 'RECONCILIATION ERROR: Fallback booking booking_date (%) differs from expected seed schedule. Aborting.', v_actual_booking_date
                    USING ERRCODE = 'P0003';
            END IF;

            -- Field 3: Verify status
            IF v_actual_status != 'PENDING'::public.booking_status THEN
                RAISE EXCEPTION 'RECONCILIATION ERROR: Fallback booking status (%) differs from expected PENDING. Aborting.', v_actual_status
                    USING ERRCODE = 'P0003';
            END IF;

            -- Field 4: Verify total_price
            IF v_actual_total_price != 1800.00 THEN
                RAISE EXCEPTION 'RECONCILIATION ERROR: Fallback booking total_price (%) differs from expected 1800.00. Aborting.', v_actual_total_price
                    USING ERRCODE = 'P0003';
            END IF;

            -- Field 5: Verify booking_time
            IF v_actual_booking_time != '01:00 PM' THEN
                RAISE EXCEPTION 'RECONCILIATION ERROR: Fallback booking booking_time (%) differs from expected "01:00 PM". Aborting.', v_actual_booking_time
                    USING ERRCODE = 'P0003';
            END IF;

            -- Field 6: Verify booking_notes
            IF v_actual_booking_notes != 'De-shedding and careful sanitary trimming.' THEN
                RAISE EXCEPTION 'RECONCILIATION ERROR: Fallback booking booking_notes differ from expected text. Aborting.'
                    USING ERRCODE = 'P0003';
            END IF;

            -- All fields verified: Delete strictly by primary key UUID
            DELETE FROM public.bookings WHERE id = v_fallback_b2_id;
            RAISE NOTICE 'Reconciliation: Verified all fields and deleted exact fallback Booking 2 (PK: %, Service: %, Date: %) from Provider 1.', v_fallback_b2_id, v_actual_service_id, v_actual_booking_date;
        END IF;
    END;

    -- Booking 2: Mochi with Pooja Deshmukh (Grooming - Mumbai)
    -- Deterministic service resolution: exact title match, uniqueness, ownership & price validation
    DECLARE
        v_s2_cnt INT;
        v_s2_price NUMERIC(10,2);
        v_s2_prov UUID;
    BEGIN
        SELECT count(*), max(id), max(price), max(provider_id)
        INTO v_s2_cnt, s2_id, v_s2_price, v_s2_prov
        FROM public.services
        WHERE title = 'Royal Spa Bath & Full Body Grooming';

        IF v_s2_cnt != 1 OR s2_id IS NULL THEN
            RAISE EXCEPTION 'BOOKING SERVICE RESOLUTION ERROR: Expected exactly 1 service titled "Royal Spa Bath & Full Body Grooming", found % rows.', v_s2_cnt
                USING ERRCODE = 'P0003';
        END IF;

        IF v_s2_prov != p2_id THEN
            RAISE EXCEPTION 'BOOKING SERVICE RESOLUTION ERROR: Service "Royal Spa Bath & Full Body Grooming" provider (%) does not match Pooja Deshmukh (%).', v_s2_prov, p2_id
                USING ERRCODE = 'P0003';
        END IF;

        IF v_s2_price != 1800.00 THEN
            RAISE EXCEPTION 'BOOKING SERVICE RESOLUTION ERROR: Service "Royal Spa Bath & Full Body Grooming" price (%) does not match booking total (1800.00).', v_s2_price
                USING ERRCODE = 'P0003';
        END IF;
    END;

    -- Reconcile previous seed Booking 2 under p2_id if it exists with date from an earlier calendar run
    DELETE FROM public.bookings
    WHERE user_id = owner_uid
      AND pet_id = pet2_id
      AND provider_id = p2_id
      AND service_id = s2_id
      AND booking_time = '01:00 PM'
      AND total_price = 1800.00
      AND booking_date != (CURRENT_DATE + INTERVAL '3 days')::DATE;

    IF pet2_id IS NOT NULL THEN
        INSERT INTO public.bookings (pet_id, service_id, provider_id, user_id, booking_date, booking_time, status, total_price, booking_notes)
        SELECT pet2_id, s2_id, p2_id, owner_uid, (CURRENT_DATE + INTERVAL '3 days')::DATE, '01:00 PM', 'PENDING'::public.booking_status, 1800.00, 'De-shedding and careful sanitary trimming.'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.bookings WHERE provider_id = p2_id AND booking_date = (CURRENT_DATE + INTERVAL '3 days')::DATE AND booking_time = '01:00 PM'
        );
    ELSE
        RAISE EXCEPTION 'BOOKING ERROR: Pet Mochi (pet2_id) not found for owner.' USING ERRCODE = 'P0003';
    END IF;

    -- Note: Booking 3 (historical completed booking) is intentionally omitted in compliance
    -- with trigger trg_validate_booking_transition, which prohibits initializing bookings
    -- in terminal states (COMPLETED) or inserting past dates/times. Completed bookings
    -- are naturally created through authorized scheduling (PENDING/CONFIRMED) followed by service completion.

    -- ========================================================================
    -- 9. INSERT SAMPLE REVIEWS (VALIDATED RELATIONSHIPS & DEDUPLICATION)
    -- ========================================================================
    -- Safeguard 3: Explicitly validate service existence & provider relationship before inserting reviews.
    -- Review 1: Pet Owner -> Dr. Aarav Sharma (Vet - Bengaluru)
    SELECT count(*), max(id) INTO v_cnt, s1_id 
    FROM public.services 
    WHERE provider_id = p1_id AND title = 'Comprehensive Health & Wellness Exam';

    IF v_cnt != 1 OR s1_id IS NULL THEN
        RAISE EXCEPTION 'REVIEW RELATIONSHIP ERROR: Expected exactly 1 service "Comprehensive Health & Wellness Exam" for Dr. Aarav Sharma (p1), found % rows.', v_cnt
            USING ERRCODE = 'P0003';
    END IF;

    INSERT INTO public.reviews (user_id, provider_id, service_id, rating, review)
    SELECT owner_uid, p1_id, s1_id, 5, 'Dr. Aarav was remarkably patient with my hyperactive Golden Retriever. He thoroughly examined his joints, checked his teeth, and suggested great nutritional swaps. Highly recommended clinic in Indiranagar!'
    WHERE NOT EXISTS (
        SELECT 1 FROM public.reviews WHERE user_id = owner_uid AND provider_id = p1_id AND service_id = s1_id
    );

    -- Review 2: Pet Owner -> Pooja Deshmukh (Grooming - Mumbai)
    SELECT count(*), max(id) INTO v_cnt, s2_id 
    FROM public.services 
    WHERE provider_id = p2_id AND title = 'Royal Spa Bath & Full Body Grooming';

    IF v_cnt != 1 OR s2_id IS NULL THEN
        RAISE EXCEPTION 'REVIEW RELATIONSHIP ERROR: Expected exactly 1 service "Royal Spa Bath & Full Body Grooming" for Pooja Deshmukh (p2), found % rows.', v_cnt
            USING ERRCODE = 'P0003';
    END IF;

    INSERT INTO public.reviews (user_id, provider_id, service_id, rating, review)
    SELECT owner_uid, p2_id, s2_id, 5, 'Pooja is a master artist with long-haired cats! Mochi came back silky smooth, smelling fresh, and completely relaxed without any grooming stress. Worth every rupee in Bandra.'
    WHERE NOT EXISTS (
        SELECT 1 FROM public.reviews WHERE user_id = owner_uid AND provider_id = p2_id AND service_id = s2_id
    );

    -- Review 3: Pet Owner -> Rohan Mehra (Boarding - Delhi NCR)
    SELECT count(*), max(id) INTO v_cnt, s4_id 
    FROM public.services 
    WHERE provider_id = p3_id AND title = 'Luxury Suite Overnight Boarding';

    IF v_cnt != 1 OR s4_id IS NULL THEN
        RAISE EXCEPTION 'REVIEW RELATIONSHIP ERROR: Expected exactly 1 service "Luxury Suite Overnight Boarding" for Rohan Mehra (p3), found % rows.', v_cnt
            USING ERRCODE = 'P0003';
    END IF;

    INSERT INTO public.reviews (user_id, provider_id, service_id, rating, review)
    SELECT owner_uid, p3_id, s4_id, 5, 'The live video updates gave my family complete peace of mind while we were away for 4 days. Happy Tails is genuinely the most hygienic and caring pet resort in NCR.'
    WHERE NOT EXISTS (
        SELECT 1 FROM public.reviews WHERE user_id = owner_uid AND provider_id = p3_id AND service_id = s4_id
    );

    -- ========================================================================
    -- 10. INSERT SAMPLE NOTIFICATIONS
    -- ========================================================================
    INSERT INTO public.notifications (user_id, title, message, is_read)
    SELECT owner_uid, 'Appointment Confirmed', 'Dr. Aarav Sharma confirmed your wellness exam for Bruno.', false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.notifications WHERE user_id = owner_uid AND title = 'Appointment Confirmed'
    );

    INSERT INTO public.notifications (user_id, title, message, is_read)
    SELECT owner_uid, 'Vaccination Reminder', 'Bruno is due for his annual booster shot in 4 weeks.', true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.notifications WHERE user_id = owner_uid AND title = 'Vaccination Reminder'
    );

    INSERT INTO public.notifications (user_id, title, message, is_read)
    SELECT owner_uid, 'Grooming Request Sent', 'Your appointment request for Mochi at Velvet Fur is pending confirmation.', false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.notifications WHERE user_id = owner_uid AND title = 'Grooming Request Sent'
    );

    -- ========================================================================
    -- 11. ATOMIC VALIDATION & ROW-COUNT ASSERTIONS (Safeguard 4)
    -- (Any failed assertion raises an exception, triggering an automatic
    --  atomic rollback of the entire seed transaction)
    -- ========================================================================
    SELECT COUNT(*) INTO user_count FROM public.users;
    SELECT COUNT(*) INTO provider_count FROM public.providers;
    SELECT COUNT(*) INTO service_count FROM public.services;
    SELECT COUNT(*) INTO availability_count FROM public.availability;
    SELECT COUNT(*) INTO pet_count FROM public.pets;
    SELECT COUNT(*) INTO booking_count FROM public.bookings;
    SELECT COUNT(*) INTO review_count FROM public.reviews;
    SELECT COUNT(*) INTO notification_count FROM public.notifications;

    -- Assert Users: Exactly 8 in staging (1 pet owner + 1 admin + 6 providers)
    IF user_count != 8 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 8 users in public.users, found %.', user_count
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Providers: Exactly 6 provider profiles
    IF provider_count != 6 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 6 provider profiles in public.providers, found %.', provider_count
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Services: Exactly 9 services (catalog complete, zero unexpected duplicates)
    IF service_count != 9 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 9 services in public.services, found %.', service_count
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Zero Duplicate Service Titles
    SELECT count(*) INTO v_dup_svc_cnt FROM (
        SELECT title FROM public.services GROUP BY title HAVING count(*) > 1
    ) d;
    IF v_dup_svc_cnt > 0 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Detected duplicate service titles (% duplicate groups).', v_dup_svc_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Distinct Service Ownership (No provider consolidation)
    IF NOT EXISTS (SELECT 1 FROM public.services WHERE provider_id = p1_id AND title = 'Comprehensive Health & Wellness Exam') THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Service "Comprehensive Health & Wellness Exam" is not assigned to Dr. Aarav Sharma (p1).' USING ERRCODE = 'P0004';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.services WHERE provider_id = p2_id AND title = 'Royal Spa Bath & Full Body Grooming') THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Service "Royal Spa Bath & Full Body Grooming" is not assigned to Pooja Deshmukh (p2).' USING ERRCODE = 'P0004';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.services WHERE provider_id = p3_id AND title = 'Luxury Suite Overnight Boarding') THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Service "Luxury Suite Overnight Boarding" is not assigned to Rohan Mehra (p3).' USING ERRCODE = 'P0004';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.services WHERE provider_id = p4_id AND title = 'Puppy Foundation & Basic Manners (6 Sessions)') THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Service "Puppy Foundation & Basic Manners (6 Sessions)" is not assigned to Vikram Joshi (p4).' USING ERRCODE = 'P0004';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.services WHERE provider_id = p5_id AND title = 'Daily 45-Min Fitness Dog Walk') THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Service "Daily 45-Min Fitness Dog Walk" is not assigned to Ananya Reddy (p5).' USING ERRCODE = 'P0004';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.services WHERE provider_id = p6_id AND title = 'Sanitized Pet Taxi & Vet Transit Ride') THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Service "Sanitized Pet Taxi & Vet Transit Ride" is not assigned to Karthik Subramanian (p6).' USING ERRCODE = 'P0004';
    END IF;

    -- Assert Availability: Exactly 13 slots across all 6 providers
    IF availability_count != 13 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 13 availability slots, found %.', availability_count
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Zero Duplicate Availability Slots
    -- (Essential validation: public.availability has no database UNIQUE constraint)
    SELECT count(*) INTO v_dup_avail_cnt FROM (
        SELECT provider_id, date, start_time, end_time FROM public.availability GROUP BY provider_id, date, start_time, end_time HAVING count(*) > 1
    ) d;
    IF v_dup_avail_cnt > 0 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Detected duplicate availability slots (% duplicate groups).', v_dup_avail_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Pets: Exactly 3 pets for Priya
    IF pet_count != 3 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 3 pets in public.pets, found %.', pet_count
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Zero Duplicate Pets per Owner
    SELECT count(*) INTO v_dup_pet_cnt FROM (
        SELECT owner_id, name FROM public.pets GROUP BY owner_id, name HAVING count(*) > 1
    ) d;
    IF v_dup_pet_cnt > 0 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Detected duplicate pet names for owner (% duplicate groups).', v_dup_pet_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Bookings: Exactly 2 valid active bookings in staging
    IF booking_count != 2 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 2 bookings in public.bookings, found %.', booking_count
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Zero Duplicate Active Bookings
    SELECT count(*) INTO v_dup_booking_cnt FROM (
        SELECT pet_id, service_id, booking_date FROM public.bookings GROUP BY pet_id, service_id, booking_date HAVING count(*) > 1
    ) d;
    IF v_dup_booking_cnt > 0 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Detected duplicate bookings (% duplicate groups).', v_dup_booking_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Booking 1: Bruno with Dr. Aarav (all 8 fields verified: owner, provider, pet, service, date, time, status, price)
    SELECT count(*) INTO v_b1_cnt
    FROM public.bookings 
    WHERE user_id = owner_uid 
      AND provider_id = p1_id 
      AND pet_id = pet1_id 
      AND service_id = s1_id 
      AND booking_date = (CURRENT_DATE + INTERVAL '1 day')::DATE
      AND booking_time = '11:00 AM'
      AND status = 'CONFIRMED'::public.booking_status
      AND total_price = 850.00;

    IF v_b1_cnt != 1 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Booking 1 (CONFIRMED vet appointment for Bruno with Dr. Aarav at 11:00 AM tomorrow, total 850.00) not found or mismatched (% rows).', v_b1_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Booking 2: Mochi with Pooja Deshmukh (all 8 fields verified: owner, provider, pet, service, date, time, status, price)
    SELECT count(*) INTO v_b2_cnt
    FROM public.bookings 
    WHERE user_id = owner_uid 
      AND provider_id = p2_id 
      AND pet_id = pet2_id 
      AND service_id = s2_id 
      AND booking_date = (CURRENT_DATE + INTERVAL '3 days')::DATE
      AND booking_time = '01:00 PM'
      AND status = 'PENDING'::public.booking_status
      AND total_price = 1800.00;

    IF v_b2_cnt != 1 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Booking 2 (PENDING grooming appointment for Mochi with Pooja Deshmukh at 01:00 PM in 3 days, total 1800.00) not found or mismatched (% rows).', v_b2_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert ZERO residual fallback bookings for Mochi under Dr. Aarav
    IF EXISTS (
        SELECT 1 FROM public.bookings 
        WHERE user_id = owner_uid AND provider_id = p1_id AND pet_id = pet2_id
    ) THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Residual fallback booking for Mochi under Dr. Aarav (p1) was not properly reconciled.' USING ERRCODE = 'P0004';
    END IF;

    -- Assert Reviews: Exactly 3 reviews across 3 distinct providers
    IF review_count != 3 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 3 reviews in public.reviews, found %.', review_count
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Review 1: Exactly 1 review with exact expected relationship (Dr. Aarav, s1, rating 5)
    SELECT count(*) INTO v_r1_cnt 
    FROM public.reviews 
    WHERE user_id = owner_uid 
      AND provider_id = p1_id 
      AND service_id = s1_id 
      AND rating = 5;

    IF v_r1_cnt != 1 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 1 review for Dr. Aarav Sharma (p1, service %, rating 5), found %.', s1_id, v_r1_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Review 2: Exactly 1 review with exact expected relationship (Pooja Deshmukh, s2, rating 5)
    SELECT count(*) INTO v_r2_cnt 
    FROM public.reviews 
    WHERE user_id = owner_uid 
      AND provider_id = p2_id 
      AND service_id = s2_id 
      AND rating = 5;

    IF v_r2_cnt != 1 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 1 review for Pooja Deshmukh (p2, service %, rating 5), found %.', s2_id, v_r2_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Review 3: Exactly 1 review with exact expected relationship (Rohan Mehra, s4, rating 5)
    SELECT count(*) INTO v_r3_cnt 
    FROM public.reviews 
    WHERE user_id = owner_uid 
      AND provider_id = p3_id 
      AND service_id = s4_id 
      AND rating = 5;

    IF v_r3_cnt != 1 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 1 review for Rohan Mehra (p3, service %, rating 5), found %.', s4_id, v_r3_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Zero Duplicate Reviews per User and Provider
    SELECT count(*) INTO v_dup_review_cnt FROM (
        SELECT user_id, provider_id FROM public.reviews GROUP BY user_id, provider_id HAVING count(*) > 1
    ) d;
    IF v_dup_review_cnt > 0 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Detected duplicate reviews for the same user and provider (% duplicate pairs).', v_dup_review_cnt
            USING ERRCODE = 'P0004';
    END IF;

    -- Assert Notifications: Exactly 3 notifications for pet owner
    IF notification_count != 3 THEN
        RAISE EXCEPTION 'ATOMIC ROLLBACK: Expected exactly 3 notifications in public.notifications, found %.', notification_count
            USING ERRCODE = 'P0004';
    END IF;

    RAISE NOTICE '========================================================================';
    RAISE NOTICE 'SUCCESS: Multi-Provider Seed data populated and verified!';
    RAISE NOTICE '  - Users:         % (Expected: 8)', user_count;
    RAISE NOTICE '  - Providers:     % (Expected: 6)', provider_count;
    RAISE NOTICE '  - Services:      % (Expected: 9)', service_count;
    RAISE NOTICE '  - Availability:  % (Expected: 13)', availability_count;
    RAISE NOTICE '  - Pets:          % (Expected: 3)', pet_count;
    RAISE NOTICE '  - Bookings:      % (Expected: 2)', booking_count;
    RAISE NOTICE '  - Reviews:       % (Expected: 3)', review_count;
    RAISE NOTICE '  - Notifications: % (Expected: 3)', notification_count;
    RAISE NOTICE '========================================================================';
END $$;
