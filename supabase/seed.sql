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
-- RECOMMENDED DEMO ACCOUNTS TO ADD IN SUPABASE AUTHENTICATION:
-- -----------------------------------------------------------------------------------
-- | Role             | Email Address               | Suggested Password |
-- |------------------|-----------------------------|--------------------|
-- | Pet Owner        | priya.petowner@example.com  | OwnerPass123!      |
-- | Provider (Vet)   | aarav.vet@example.com       | ProviderPass123!   |
-- | Provider (Groom) | pooja.grooming@example.com  | ProviderPass123!   |
-- | Provider (Board) | rohan.happytails@example.com| ProviderPass123!   |
-- | Provider (Train) | vikram.k9@example.com       | ProviderPass123!   |
-- | Provider (Walk)  | ananya.walkers@example.com  | ProviderPass123!   |
-- | Provider (Taxi)  | karthik.petride@example.com | ProviderPass123!   |
-- | Administrator    | admin@petcare.org           | AdminPass123!      |
-- -----------------------------------------------------------------------------------
--
-- Note: Even if you only create 2 accounts (priya.petowner@example.com and aarav.vet@example.com),
-- this script automatically falls back and seeds ALL marketplace services, pets,
-- availability, bookings, and reviews without skipping!
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
    pet_count INT;
    booking_count INT;
    review_count INT;
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
    -- 3. RESOLVE AUTHENTICATED USER IDS WITH SAFE FALLBACKS
    -- ========================================================================
    SELECT id INTO owner_uid FROM public.users WHERE email = 'priya.petowner@example.com';
    IF owner_uid IS NULL THEN
        SELECT id INTO owner_uid FROM public.users WHERE role = 'pet_owner' ORDER BY created_at ASC LIMIT 1;
    END IF;
    IF owner_uid IS NULL THEN
        SELECT id INTO owner_uid FROM public.users ORDER BY created_at ASC LIMIT 1;
    END IF;

    SELECT id INTO admin_uid FROM public.users WHERE email = 'admin@petcare.org';
    IF admin_uid IS NULL THEN
        SELECT id INTO admin_uid FROM public.users WHERE role = 'admin' ORDER BY created_at ASC LIMIT 1;
    END IF;

    -- Resolve providers by email
    SELECT id INTO prov1_uid FROM public.users WHERE email = 'aarav.vet@example.com';
    SELECT id INTO prov2_uid FROM public.users WHERE email = 'pooja.grooming@example.com';
    SELECT id INTO prov3_uid FROM public.users WHERE email = 'rohan.happytails@example.com';
    SELECT id INTO prov4_uid FROM public.users WHERE email = 'vikram.k9@example.com';
    SELECT id INTO prov5_uid FROM public.users WHERE email = 'ananya.walkers@example.com';
    SELECT id INTO prov6_uid FROM public.users WHERE email = 'karthik.petride@example.com';

    -- Primary provider fallback: any registered provider or any non-owner user
    IF prov1_uid IS NULL THEN
        SELECT id INTO prov1_uid FROM public.users WHERE role = 'provider' ORDER BY created_at ASC LIMIT 1;
    END IF;
    IF prov1_uid IS NULL THEN
        SELECT id INTO prov1_uid FROM public.users WHERE id != owner_uid ORDER BY created_at ASC LIMIT 1;
    END IF;
    IF prov1_uid IS NULL THEN
        -- If literally only 1 user exists in the entire database, promote and use them
        prov1_uid := owner_uid;
        UPDATE public.users SET role = 'provider' WHERE id = prov1_uid;
    END IF;

    -- Secondary provider fallbacks: map to primary provider if not individually registered
    IF prov2_uid IS NULL THEN prov2_uid := prov1_uid; END IF;
    IF prov3_uid IS NULL THEN prov3_uid := prov1_uid; END IF;
    IF prov4_uid IS NULL THEN prov4_uid := prov1_uid; END IF;
    IF prov5_uid IS NULL THEN prov5_uid := prov1_uid; END IF;
    IF prov6_uid IS NULL THEN prov6_uid := prov1_uid; END IF;

    -- ========================================================================
    -- 4. PROVISION & ENRICH PROVIDER PROFILES
    -- ========================================================================
    -- Provider 1: Dr. Aarav Sharma (Vet)
    SELECT id INTO p1_id FROM public.providers WHERE user_id = prov1_uid;
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

    -- Provider 2: Pooja Deshmukh (Grooming)
    IF prov2_uid != prov1_uid THEN
        SELECT id INTO p2_id FROM public.providers WHERE user_id = prov2_uid;
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
    ELSE
        p2_id := p1_id;
    END IF;

    -- Provider 3: Rohan Mehra (Boarding)
    IF prov3_uid != prov1_uid AND prov3_uid != prov2_uid THEN
        SELECT id INTO p3_id FROM public.providers WHERE user_id = prov3_uid;
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
    ELSE
        p3_id := p1_id;
    END IF;

    -- Provider 4: Vikram Joshi (Training)
    IF prov4_uid != prov1_uid AND prov4_uid != prov2_uid AND prov4_uid != prov3_uid THEN
        SELECT id INTO p4_id FROM public.providers WHERE user_id = prov4_uid;
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
    ELSE
        p4_id := p1_id;
    END IF;

    -- Provider 5: Ananya Reddy (Walking)
    IF prov5_uid != prov1_uid AND prov5_uid != prov2_uid AND prov5_uid != prov3_uid AND prov5_uid != prov4_uid THEN
        SELECT id INTO p5_id FROM public.providers WHERE user_id = prov5_uid;
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
    ELSE
        p5_id := p1_id;
    END IF;

    -- Provider 6: Karthik Subramanian (Taxi)
    IF prov6_uid != prov1_uid AND prov6_uid != prov2_uid AND prov6_uid != prov3_uid AND prov6_uid != prov4_uid AND prov6_uid != prov5_uid THEN
        SELECT id INTO p6_id FROM public.providers WHERE user_id = prov6_uid;
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
    ELSE
        p6_id := p1_id;
    END IF;

    -- ========================================================================
    -- 5. INSERT REALISTIC MARKETPLACE SERVICES (INR PRICING & CITIES)
    -- ========================================================================
    -- Veterinary Services
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p1_id, 'vet', 'Comprehensive Health & Wellness Exam', 'Thorough nose-to-tail physical exam, vital signs check, nutritional advice, dental assessment, and tailored wellness counseling for dogs and cats.', 850.00, 'https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?auto=format&fit=crop&w=800&q=80', 4.9, '45 mins', '["09:30 AM", "11:00 AM", "02:30 PM", "04:30 PM", "06:00 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p1_id AND title = 'Comprehensive Health & Wellness Exam'
    );

    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p1_id, 'vet', 'Essential Annual Vaccination Package', 'Full core immunizations (DHPPi/Rabies for dogs or Tricat/Rabies for cats) combined with deworming and health passport sign-off.', 1450.00, 'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&w=800&q=80', 4.9, '30 mins', '["10:00 AM", "12:00 PM", "03:30 PM", "05:30 PM"]'::jsonb, false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p1_id AND title = 'Essential Annual Vaccination Package'
    );

    -- Grooming Services
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p2_id, 'grooming', 'Royal Spa Bath & Full Body Grooming', 'Hydro-massage bath with natural botanical conditioning shampoo, full-body breed haircut, blow-dry, ear cleansing, and nail grinding.', 1800.00, 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80', 4.8, '90 mins', '["10:00 AM", "01:00 PM", "03:30 PM", "06:00 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p2_id AND title = 'Royal Spa Bath & Full Body Grooming'
    );

    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p2_id, 'grooming', 'Tick & Flea Deep Medicated Wash', 'Therapeutic rinse to eliminate external parasites, soothe irritated skin, and restore healthy skin moisture barrier.', 1200.00, 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80', 4.7, '60 mins', '["09:00 AM", "11:30 AM", "02:00 PM", "04:30 PM"]'::jsonb, false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p2_id AND title = 'Tick & Flea Deep Medicated Wash'
    );

    -- Boarding & Daycare
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p3_id, 'boarding', 'Luxury Suite Overnight Boarding', 'Private AC suites, orthopaedic bedding, 3 gourmet meals per day, supervised paddock playtime, and daily photo/video updates.', 1500.00, 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=800&q=80', 4.8, '24 hours', '["Check-in: 09:00 AM", "Check-in: 02:00 PM", "Check-in: 06:00 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p3_id AND title = 'Luxury Suite Overnight Boarding'
    );

    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p3_id, 'daycare', 'Pet Daycare Social Agility Park', 'Supervised daytime playground with obstacle tunnels, splash pads, ball pits, and cozy nap stations.', 800.00, 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80', 4.7, '8 hours', '["08:00 AM - 04:00 PM", "10:00 AM - 06:00 PM"]'::jsonb, false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p3_id AND title = 'Pet Daycare Social Agility Park'
    );

    -- Training Services
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p4_id, 'training', 'Puppy Foundation & Basic Manners (6 Sessions)', 'Positive-reinforcement training covering sit, stay, recall, potty training, impulse control, and biting deterrence.', 7500.00, 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?auto=format&fit=crop&w=800&q=80', 4.9, '6 x 60 mins', '["Weekend Batches", "Weekday Mornings", "Weekday Evenings"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p4_id AND title = 'Puppy Foundation & Basic Manners (6 Sessions)'
    );

    -- Walking Services
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p5_id, 'walking', 'Daily 45-Min Fitness Dog Walk', 'Brisk neighborhood walk focused on exercise, sniffing enrichment, leash manners, and waste cleanup with live GPS route map.', 350.00, 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?auto=format&fit=crop&w=800&q=80', 4.9, '45 mins', '["06:30 AM", "07:30 AM", "05:00 PM", "06:30 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p5_id AND title = 'Daily 45-Min Fitness Dog Walk'
    );

    -- Pet Taxi & Transport
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, available_slots, featured)
    SELECT p6_id, 'taxi', 'Sanitized Pet Taxi & Vet Transit Ride', 'Stress-free, sanitized, AC vehicle equipped with pet safety harnesses, ramp access, and protective seat covers for vet visits and airport drops.', 900.00, 'https://images.unsplash.com/photo-1544568100-847a948585b9?auto=format&fit=crop&w=800&q=80', 4.8, 'Base (up to 10 km)', '["08:00 AM", "11:00 AM", "02:00 PM", "05:00 PM", "08:00 PM"]'::jsonb, true
    WHERE NOT EXISTS (
        SELECT 1 FROM public.services WHERE provider_id = p6_id AND title = 'Sanitized Pet Taxi & Vet Transit Ride'
    );

    -- ========================================================================
    -- 6. INSERT PROVIDER AVAILABILITY SLOTS
    -- ========================================================================
    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p1_id, (CURRENT_DATE + INTERVAL '1 day')::DATE, '09:00:00'::TIME, '18:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability WHERE provider_id = p1_id AND date = (CURRENT_DATE + INTERVAL '1 day')::DATE
    );

    INSERT INTO public.availability (provider_id, date, start_time, end_time)
    SELECT p1_id, (CURRENT_DATE + INTERVAL '2 days')::DATE, '09:00:00'::TIME, '18:00:00'::TIME
    WHERE NOT EXISTS (
        SELECT 1 FROM public.availability WHERE provider_id = p1_id AND date = (CURRENT_DATE + INTERVAL '2 days')::DATE
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

    -- Resolve Pet IDs
    SELECT id INTO pet1_id FROM public.pets WHERE owner_id = owner_uid AND name = 'Bruno';
    SELECT id INTO pet2_id FROM public.pets WHERE owner_id = owner_uid AND name = 'Mochi';
    SELECT id INTO pet3_id FROM public.pets WHERE owner_id = owner_uid AND name = 'Coco';

    -- ========================================================================
    -- 8. INSERT SAMPLE BOOKINGS (RESPECTS PARTIAL UNIQUE INDEX & RLS)
    -- ========================================================================
    SELECT id INTO s1_id FROM public.services WHERE provider_id = p1_id AND category = 'vet' LIMIT 1;
    IF s1_id IS NOT NULL AND pet1_id IS NOT NULL THEN
        INSERT INTO public.bookings (pet_id, service_id, provider_id, user_id, booking_date, booking_time, status, total_price, booking_notes)
        SELECT pet1_id, s1_id, p1_id, owner_uid, (CURRENT_DATE + INTERVAL '1 day')::DATE, '11:00 AM', 'CONFIRMED'::public.booking_status, 850.00, 'Routine annual general checkup & wellness review.'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.bookings WHERE provider_id = p1_id AND booking_date = (CURRENT_DATE + INTERVAL '1 day')::DATE AND booking_time = '11:00 AM'
        );
    END IF;

    SELECT id INTO s2_id FROM public.services WHERE provider_id = p2_id AND category = 'grooming' LIMIT 1;
    IF s2_id IS NOT NULL AND pet2_id IS NOT NULL THEN
        INSERT INTO public.bookings (pet_id, service_id, provider_id, user_id, booking_date, booking_time, status, total_price, booking_notes)
        SELECT pet2_id, s2_id, p2_id, owner_uid, (CURRENT_DATE + INTERVAL '3 days')::DATE, '01:00 PM', 'PENDING'::public.booking_status, 1800.00, 'De-shedding and careful sanitary trimming.'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.bookings WHERE provider_id = p2_id AND booking_date = (CURRENT_DATE + INTERVAL '3 days')::DATE AND booking_time = '01:00 PM'
        );
    END IF;

    SELECT id INTO s3_id FROM public.services WHERE provider_id = p5_id AND category = 'walking' LIMIT 1;
    IF s3_id IS NOT NULL AND pet3_id IS NOT NULL THEN
        INSERT INTO public.bookings (pet_id, service_id, provider_id, user_id, booking_date, booking_time, status, total_price, booking_notes)
        SELECT pet3_id, s3_id, p5_id, owner_uid, (CURRENT_DATE - INTERVAL '5 days')::DATE, '05:30 PM', 'COMPLETED'::public.booking_status, 350.00, 'Evening park walk with leash obedience practice.'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.bookings WHERE provider_id = p5_id AND booking_date = (CURRENT_DATE - INTERVAL '5 days')::DATE AND booking_time = '05:30 PM'
        );
    END IF;

    -- ========================================================================
    -- 9. INSERT SAMPLE REVIEWS
    -- ========================================================================
    IF s1_id IS NOT NULL THEN
        INSERT INTO public.reviews (user_id, provider_id, service_id, rating, review)
        SELECT owner_uid, p1_id, s1_id, 5, 'Dr. Aarav was remarkably patient with my hyperactive Golden Retriever. He thoroughly examined his joints, checked his teeth, and suggested great nutritional swaps. Highly recommended clinic in Indiranagar!'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.reviews WHERE user_id = owner_uid AND provider_id = p1_id AND rating = 5
        );
    END IF;

    IF s2_id IS NOT NULL THEN
        INSERT INTO public.reviews (user_id, provider_id, service_id, rating, review)
        SELECT owner_uid, p2_id, s2_id, 5, 'Pooja is a master artist with long-haired cats! Mochi came back silky smooth, smelling fresh, and completely relaxed without any grooming stress. Worth every rupee in Bandra.'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.reviews WHERE user_id = owner_uid AND provider_id = p2_id AND rating = 5
        );
    END IF;

    SELECT id INTO s4_id FROM public.services WHERE provider_id = p3_id AND category = 'boarding' LIMIT 1;
    IF s4_id IS NOT NULL THEN
        INSERT INTO public.reviews (user_id, provider_id, service_id, rating, review)
        SELECT owner_uid, p3_id, s4_id, 5, 'The live video updates gave my family complete peace of mind while we were away for 4 days. Happy Tails is genuinely the most hygienic and caring pet resort in NCR.'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.reviews WHERE user_id = owner_uid AND provider_id = p3_id AND rating = 5
        );
    END IF;

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
    -- 11. VERIFICATION REPORT IN MESSAGES
    -- ========================================================================
    SELECT COUNT(*) INTO user_count FROM public.users;
    SELECT COUNT(*) INTO provider_count FROM public.providers;
    SELECT COUNT(*) INTO service_count FROM public.services;
    SELECT COUNT(*) INTO pet_count FROM public.pets;
    SELECT COUNT(*) INTO booking_count FROM public.bookings;
    SELECT COUNT(*) INTO review_count FROM public.reviews;

    RAISE NOTICE '========================================================================';
    RAISE NOTICE 'SUCCESS: Seed data populated!';
    RAISE NOTICE '  - Users:        %', user_count;
    RAISE NOTICE '  - Providers:    %', provider_count;
    RAISE NOTICE '  - Services:     %', service_count;
    RAISE NOTICE '  - Pets:         %', pet_count;
    RAISE NOTICE '  - Bookings:     %', booking_count;
    RAISE NOTICE '  - Reviews:      %', review_count;
    RAISE NOTICE '========================================================================';
END $$;
