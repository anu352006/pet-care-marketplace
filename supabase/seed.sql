-- ============================================================================
-- SUPABASE SEED DATA: Marketplace Services, Providers, Pets & Demo Accounts
-- Run in Supabase SQL Editor AFTER schema.sql and storage.sql
-- ============================================================================
--
-- AUTHENTICATION & DEMO USERS NOTICE:
-- In Supabase, the recommended production pattern for user creation is through
-- Supabase Authentication (GoTrue):
--   Option A (Recommended): Register via the web app (/register)
--   Option B: Supabase Dashboard -> Authentication -> Users -> "Add User"
--
-- This seed script safely checks whether demo users exist in auth.users.
-- If not found, it provisions them with COMPLETE GoTrue credentials, including
-- verified email status and valid bcrypt password hashes (via pgcrypto).
--
-- Demo Accounts Provisioned / Supported:
--   1. Pet Owner:       priya.petowner@example.com      (Password: OwnerPass123!)
--   2. Vet Provider:    aarav.vet@example.com          (Password: ProviderPass123!)
--   3. Master Groomer:  pooja.grooming@example.com     (Password: ProviderPass123!)
--   4. Boarding Resort: rohan.happytails@example.com   (Password: ProviderPass123!)
--   5. Canine Trainer:  vikram.k9@example.com          (Password: ProviderPass123!)
--   6. Pet Walker:      ananya.walkers@example.com     (Password: ProviderPass123!)
--   7. Administrator:   admin@petcare.org              (Password: AdminPass123!)
--
-- TRIGGER COMPATIBILITY:
-- This script DOES NOT disable the 'on_auth_user_created' trigger.
-- It resolves the provider profile created by the trigger and safely enriches it,
-- avoiding duplicate key violations on 'public.providers.user_id'.
-- It is completely idempotent and safe to rerun multiple times without duplicates.
-- ============================================================================

DO $$
DECLARE
    admin_uid UUID;
    owner_uid UUID;
    prov1_uid UUID;
    prov2_uid UUID;
    prov3_uid UUID;
    prov4_uid UUID;
    prov5_uid UUID;

    p1_id UUID;
    p2_id UUID;
    p3_id UUID;
    p4_id UUID;
    p5_id UUID;
BEGIN
    -- ========================================================================
    -- 1. RESOLVE OR SAFELY PROVISION AUTH USERS WITH COMPLETE CREDENTIALS
    -- ========================================================================

    -- Admin User
    SELECT id INTO admin_uid FROM auth.users WHERE email = 'admin@petcare.org';
    IF admin_uid IS NULL THEN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'admin@petcare.org',
            crypt('AdminPass123!', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name": "System Administrator", "role": "admin", "phone": "+91 80234 56789"}'::jsonb,
            now(),
            now()
        ) RETURNING id INTO admin_uid;
    END IF;

    -- Pet Owner: Priya Sundaram
    SELECT id INTO owner_uid FROM auth.users WHERE email = 'priya.petowner@example.com';
    IF owner_uid IS NULL THEN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'priya.petowner@example.com',
            crypt('OwnerPass123!', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name": "Priya Sundaram", "role": "pet_owner", "phone": "+91 98765 43210"}'::jsonb,
            now(),
            now()
        ) RETURNING id INTO owner_uid;
    END IF;

    -- Provider 1: Dr. Aarav Sharma
    SELECT id INTO prov1_uid FROM auth.users WHERE email = 'aarav.vet@example.com';
    IF prov1_uid IS NULL THEN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'aarav.vet@example.com',
            crypt('ProviderPass123!', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name": "Dr. Aarav Sharma", "role": "provider", "business_name": "Paws & Claws Veterinary Wellness", "phone": "+91 98450 12345", "city": "Bengaluru"}'::jsonb,
            now(),
            now()
        ) RETURNING id INTO prov1_uid;
    END IF;

    -- Provider 2: Pooja Deshmukh
    SELECT id INTO prov2_uid FROM auth.users WHERE email = 'pooja.grooming@example.com';
    IF prov2_uid IS NULL THEN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'pooja.grooming@example.com',
            crypt('ProviderPass123!', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name": "Pooja Deshmukh", "role": "provider", "business_name": "Velvet Fur Luxury Grooming Salon", "phone": "+91 98200 45678", "city": "Mumbai"}'::jsonb,
            now(),
            now()
        ) RETURNING id INTO prov2_uid;
    END IF;

    -- Provider 3: Rohan Mehra
    SELECT id INTO prov3_uid FROM auth.users WHERE email = 'rohan.happytails@example.com';
    IF prov3_uid IS NULL THEN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'rohan.happytails@example.com',
            crypt('ProviderPass123!', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name": "Rohan Mehra", "role": "provider", "business_name": "Happy Tails Green Boarding Resort", "phone": "+91 98110 78901", "city": "Delhi NCR"}'::jsonb,
            now(),
            now()
        ) RETURNING id INTO prov3_uid;
    END IF;

    -- Provider 4: Vikram Joshi
    SELECT id INTO prov4_uid FROM auth.users WHERE email = 'vikram.k9@example.com';
    IF prov4_uid IS NULL THEN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'vikram.k9@example.com',
            crypt('ProviderPass123!', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name": "Vikram Joshi", "role": "provider", "business_name": "Pawsome Canines Training Academy", "phone": "+91 97660 33445", "city": "Pune"}'::jsonb,
            now(),
            now()
        ) RETURNING id INTO prov4_uid;
    END IF;

    -- Provider 5: Ananya Reddy
    SELECT id INTO prov5_uid FROM auth.users WHERE email = 'ananya.walkers@example.com';
    IF prov5_uid IS NULL THEN
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'ananya.walkers@example.com',
            crypt('ProviderPass123!', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name": "Ananya Reddy", "role": "provider", "business_name": "CityWalkers & Feline Friends", "phone": "+91 94400 99887", "city": "Hyderabad"}'::jsonb,
            now(),
            now()
        ) RETURNING id INTO prov5_uid;
    END IF;

    -- ========================================================================
    -- 2. ENSURE PUBLIC.USERS PROFILES ARE SYNCHRONIZED
    -- ========================================================================
    IF admin_uid IS NOT NULL THEN
        UPDATE public.users 
        SET avatar_url = 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=400&q=80',
            phone = '+91 80234 56789'
        WHERE id = admin_uid;
    END IF;

    IF owner_uid IS NOT NULL THEN
        UPDATE public.users 
        SET avatar_url = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
            phone = '+91 98765 43210'
        WHERE id = owner_uid;
    END IF;

    -- ========================================================================
    -- 3. RESOLVE & ENRICH PROVIDER PROFILES (COMPATIBLE WITH TRIGGER)
    -- ========================================================================
    -- Provider 1: Dr. Aarav Sharma
    IF prov1_uid IS NOT NULL THEN
        SELECT id INTO p1_id FROM public.providers WHERE user_id = prov1_uid;
        IF p1_id IS NOT NULL THEN
            UPDATE public.providers
            SET business_name = 'Paws & Claws Veterinary Wellness',
                location = 'Indiranagar, Bengaluru',
                description = 'Experienced veterinary surgeon with 12+ years expertise in feline medicine and canine wellness.',
                verified = true,
                rating = 4.9,
                reviews_count = 142
            WHERE id = p1_id;
        ELSE
            INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
            VALUES (prov1_uid, 'Paws & Claws Veterinary Wellness', 'Indiranagar, Bengaluru', 'Experienced veterinary surgeon with 12+ years expertise in feline medicine and canine wellness.', true, 4.9, 142)
            RETURNING id INTO p1_id;
        END IF;
    END IF;

    -- Provider 2: Pooja Deshmukh
    IF prov2_uid IS NOT NULL THEN
        SELECT id INTO p2_id FROM public.providers WHERE user_id = prov2_uid;
        IF p2_id IS NOT NULL THEN
            UPDATE public.providers
            SET business_name = 'Velvet Fur Luxury Grooming Salon',
                location = 'Bandra West, Mumbai',
                description = 'Master stylist providing breed-specific styling, medicated baths, and cat spas.',
                verified = true,
                rating = 4.8,
                reviews_count = 98
            WHERE id = p2_id;
        ELSE
            INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
            VALUES (prov2_uid, 'Velvet Fur Luxury Grooming Salon', 'Bandra West, Mumbai', 'Master stylist providing breed-specific styling, medicated baths, and cat spas.', true, 4.8, 98)
            RETURNING id INTO p2_id;
        END IF;
    END IF;

    -- Provider 3: Rohan Mehra
    IF prov3_uid IS NOT NULL THEN
        SELECT id INTO p3_id FROM public.providers WHERE user_id = prov3_uid;
        IF p3_id IS NOT NULL THEN
            UPDATE public.providers
            SET business_name = 'Happy Tails Green Boarding Resort',
                location = 'Gurugram, Delhi NCR',
                description = '2 acres of grass paddocks, air-conditioned suites, splash pools, and 24/7 care.',
                verified = true,
                rating = 4.7,
                reviews_count = 84
            WHERE id = p3_id;
        ELSE
            INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
            VALUES (prov3_uid, 'Happy Tails Green Boarding Resort', 'Gurugram, Delhi NCR', '2 acres of grass paddocks, air-conditioned suites, splash pools, and 24/7 care.', true, 4.7, 84)
            RETURNING id INTO p3_id;
        END IF;
    END IF;

    -- Provider 4: Vikram Joshi
    IF prov4_uid IS NOT NULL THEN
        SELECT id INTO p4_id FROM public.providers WHERE user_id = prov4_uid;
        IF p4_id IS NOT NULL THEN
            UPDATE public.providers
            SET business_name = 'Pawsome Canines Training Academy',
                location = 'Koregaon Park, Pune',
                description = 'Positive-reinforcement behaviorist covering puppy foundation and leash reactivity.',
                verified = true,
                rating = 4.9,
                reviews_count = 116
            WHERE id = p4_id;
        ELSE
            INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
            VALUES (prov4_uid, 'Pawsome Canines Training Academy', 'Koregaon Park, Pune', 'Positive-reinforcement behaviorist covering puppy foundation and leash reactivity.', true, 4.9, 116)
            RETURNING id INTO p4_id;
        END IF;
    END IF;

    -- Provider 5: Ananya Reddy
    IF prov5_uid IS NOT NULL THEN
        SELECT id INTO p5_id FROM public.providers WHERE user_id = prov5_uid;
        IF p5_id IS NOT NULL THEN
            UPDATE public.providers
            SET business_name = 'CityWalkers & Feline Friends',
                location = 'Jubilee Hills, Hyderabad',
                description = 'Daily fitness strolls, live GPS tracking, and personalized in-home visits.',
                verified = true,
                rating = 4.9,
                reviews_count = 73
            WHERE id = p5_id;
        ELSE
            INSERT INTO public.providers (user_id, business_name, location, description, verified, rating, reviews_count)
            VALUES (prov5_uid, 'CityWalkers & Feline Friends', 'Jubilee Hills, Hyderabad', 'Daily fitness strolls, live GPS tracking, and personalized in-home visits.', true, 4.9, 73)
            RETURNING id INTO p5_id;
        END IF;
    END IF;

    -- ========================================================================
    -- 4. INSERT PETS (SAFE TO RERUN - NO DUPLICATES)
    -- ========================================================================
    IF owner_uid IS NOT NULL THEN
        INSERT INTO public.pets (owner_id, name, animal_type, breed, age, gender, weight, vaccination_details, medical_history, image_url)
        SELECT owner_uid, 'Bruno', 'Dog', 'Golden Retriever', 3, 'Male', '31 kg', 'Rabies (Valid Dec 2026), DHPPi complete', 'Mild chicken allergy. Regular ear cleaning required.', 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=600&q=80'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.pets WHERE owner_id = owner_uid AND name = 'Bruno'
        );

        INSERT INTO public.pets (owner_id, name, animal_type, breed, age, gender, weight, vaccination_details, medical_history, image_url)
        SELECT owner_uid, 'Mochi', 'Cat', 'Persian Longhair', 2, 'Female', '4.2 kg', 'Tricat (Valid Aug 2026), Rabies up to date', 'Sensitive digestive tract. Requires daily combing.', 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.pets WHERE owner_id = owner_uid AND name = 'Mochi'
        );

        INSERT INTO public.pets (owner_id, name, animal_type, breed, age, gender, weight, vaccination_details, medical_history, image_url)
        SELECT owner_uid, 'Coco', 'Dog', 'Beagle', 1, 'Male', '12 kg', 'Complete puppy vaccination series done', 'Active and playful, no chronic issues.', 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=600&q=80'
        WHERE NOT EXISTS (
            SELECT 1 FROM public.pets WHERE owner_id = owner_uid AND name = 'Coco'
        );
    END IF;

    -- ========================================================================
    -- 5. INSERT SERVICES (SAFE TO RERUN - NO DUPLICATES)
    -- ========================================================================
    IF p1_id IS NOT NULL THEN
        INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
        SELECT p1_id, 'vet', 'Comprehensive Health & Wellness Exam', 'Thorough nose-to-tail physical exam, vital signs check, nutritional advice, dental assessment, and wellness counseling.', 850.00, 'https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?auto=format&fit=crop&w=800&q=80', 4.9, '45 mins', true
        WHERE NOT EXISTS (
            SELECT 1 FROM public.services WHERE provider_id = p1_id AND title = 'Comprehensive Health & Wellness Exam'
        );

        INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
        SELECT p1_id, 'vet', 'Essential Annual Vaccination Package', 'Core immunizations (DHPPi/Rabies for dogs or Tricat/Rabies for cats) combined with deworming and passport sign-off.', 1450.00, 'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&w=800&q=80', 4.9, '30 mins', false
        WHERE NOT EXISTS (
            SELECT 1 FROM public.services WHERE provider_id = p1_id AND title = 'Essential Annual Vaccination Package'
        );
    END IF;

    IF p2_id IS NOT NULL THEN
        INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
        SELECT p2_id, 'grooming', 'Royal Spa Bath & Full Body Grooming', 'Hydro-massage bath with natural botanical conditioning shampoo, full-body breed haircut, blow-dry, ear cleansing, and nail grinding.', 1800.00, 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80', 4.8, '90 mins', true
        WHERE NOT EXISTS (
            SELECT 1 FROM public.services WHERE provider_id = p2_id AND title = 'Royal Spa Bath & Full Body Grooming'
        );

        INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
        SELECT p2_id, 'grooming', 'Tick & Flea Deep Medicated Wash', 'Therapeutic rinse to eliminate external parasites and soothe irritated skin barrier.', 1200.00, 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80', 4.7, '60 mins', false
        WHERE NOT EXISTS (
            SELECT 1 FROM public.services WHERE provider_id = p2_id AND title = 'Tick & Flea Deep Medicated Wash'
        );
    END IF;

    IF p3_id IS NOT NULL THEN
        INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
        SELECT p3_id, 'boarding', 'Luxury Suite Overnight Boarding', 'Private AC suites, orthopaedic bedding, 3 gourmet meals per day, supervised paddock playtime, and daily WhatsApp updates.', 1500.00, 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=800&q=80', 4.8, '24 hours', true
        WHERE NOT EXISTS (
            SELECT 1 FROM public.services WHERE provider_id = p3_id AND title = 'Luxury Suite Overnight Boarding'
        );

        INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
        SELECT p3_id, 'daycare', 'Pet Daycare Social Agility Park', 'Supervised daytime playground with obstacle tunnels, splash pads, ball pits, and cozy nap stations.', 800.00, 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80', 4.7, '8 hours', false
        WHERE NOT EXISTS (
            SELECT 1 FROM public.services WHERE provider_id = p3_id AND title = 'Pet Daycare Social Agility Park'
        );
    END IF;

    IF p4_id IS NOT NULL THEN
        INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
        SELECT p4_id, 'training', 'Puppy Foundation & Basic Manners (6 Sessions)', 'Positive-reinforcement training covering sit, stay, recall, potty training, impulse control, and biting deterrence.', 7500.00, 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?auto=format&fit=crop&w=800&q=80', 4.9, '6 x 60 mins', true
        WHERE NOT EXISTS (
            SELECT 1 FROM public.services WHERE provider_id = p4_id AND title = 'Puppy Foundation & Basic Manners (6 Sessions)'
        );
    END IF;

    IF p5_id IS NOT NULL THEN
        INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
        SELECT p5_id, 'walking', 'Daily 45-Min Fitness Dog Walk', 'Brisk neighborhood walk focused on exercise, sniffing enrichment, leash manners, and waste cleanup.', 350.00, 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?auto=format&fit=crop&w=800&q=80', 4.9, '45 mins', true
        WHERE NOT EXISTS (
            SELECT 1 FROM public.services WHERE provider_id = p5_id AND title = 'Daily 45-Min Fitness Dog Walk'
        );
    END IF;

    -- ========================================================================
    -- 6. INSERT NOTIFICATIONS (SAFE TO RERUN - NO DUPLICATES)
    -- ========================================================================
    IF owner_uid IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, message, is_read)
        SELECT owner_uid, 'Appointment Confirmed', 'Dr. Aarav Sharma confirmed your wellness exam for Bruno.', false
        WHERE NOT EXISTS (
            SELECT 1 FROM public.notifications WHERE user_id = owner_uid AND title = 'Appointment Confirmed'
        );

        INSERT INTO public.notifications (user_id, title, message, is_read)
        SELECT owner_uid, 'Vaccination Reminder', 'Bruno is due for annual booster in 4 weeks.', true
        WHERE NOT EXISTS (
            SELECT 1 FROM public.notifications WHERE user_id = owner_uid AND title = 'Vaccination Reminder'
        );
    END IF;

END $$;
