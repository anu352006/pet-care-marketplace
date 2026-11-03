-- ==========================================================
-- SUPABASE SEED DATA: Realistic Indian Cities, Services & Pets
-- Run in Supabase SQL Editor AFTER schema.sql
-- ==========================================================

DO $$
DECLARE
    admin_uid UUID := '00000000-0000-0000-0000-000000000001';
    owner_uid UUID := '00000000-0000-0000-0000-000000000002';
    prov1_uid UUID := '00000000-0000-0000-0000-000000000003';
    prov2_uid UUID := '00000000-0000-0000-0000-000000000004';
    prov3_uid UUID := '00000000-0000-0000-0000-000000000005';
    prov4_uid UUID := '00000000-0000-0000-0000-000000000006';
    prov5_uid UUID := '00000000-0000-0000-0000-000000000007';

    p1_id UUID := '11111111-1111-1111-1111-111111111111';
    p2_id UUID := '22222222-2222-2222-2222-222222222222';
    p3_id UUID := '33333333-3333-3333-3333-333333333333';
    p4_id UUID := '44444444-4444-4444-4444-444444444444';
    p5_id UUID := '55555555-5555-5555-5555-555555555555';

    pet1_id UUID := 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    pet2_id UUID := 'b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    pet3_id UUID := 'c3333333-cccc-cccc-cccc-cccccccccccc';
BEGIN
    -- 1. Insert seed users in auth.users if not present
    INSERT INTO auth.users (id, email, raw_user_meta_data, created_at)
    VALUES
        (admin_uid, 'admin@petcare.org', '{"full_name": "System Administrator", "role": "admin"}'::jsonb, now()),
        (owner_uid, 'priya.petowner@example.com', '{"full_name": "Priya Sundaram", "role": "pet_owner", "phone": "+91 98765 43210"}'::jsonb, now()),
        (prov1_uid, 'aarav.vet@example.com', '{"full_name": "Dr. Aarav Sharma", "role": "provider", "business_name": "Paws & Claws Veterinary Wellness"}'::jsonb, now()),
        (prov2_uid, 'pooja.grooming@example.com', '{"full_name": "Pooja Deshmukh", "role": "provider", "business_name": "Velvet Fur Luxury Grooming Salon"}'::jsonb, now()),
        (prov3_uid, 'rohan.happytails@example.com', '{"full_name": "Rohan Mehra", "role": "provider", "business_name": "Happy Tails Green Boarding Resort"}'::jsonb, now()),
        (prov4_uid, 'vikram.k9@example.com', '{"full_name": "Vikram Joshi", "role": "provider", "business_name": "Pawsome Canines Training Academy"}'::jsonb, now()),
        (prov5_uid, 'ananya.walkers@example.com', '{"full_name": "Ananya Reddy", "role": "provider", "business_name": "CityWalkers & Feline Friends"}'::jsonb, now())
    ON CONFLICT (id) DO NOTHING;

    -- 2. Insert into public.users
    INSERT INTO public.users (id, full_name, email, role, phone, avatar_url)
    VALUES
        (admin_uid, 'System Administrator', 'admin@petcare.org', 'admin', '+91 80234 56789', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=400&q=80'),
        (owner_uid, 'Priya Sundaram', 'priya.petowner@example.com', 'pet_owner', '+91 98765 43210', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80'),
        (prov1_uid, 'Dr. Aarav Sharma', 'aarav.vet@example.com', 'provider', '+91 98450 12345', 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80'),
        (prov2_uid, 'Pooja Deshmukh', 'pooja.grooming@example.com', 'provider', '+91 98200 45678', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80'),
        (prov3_uid, 'Rohan Mehra', 'rohan.happytails@example.com', 'provider', '+91 98110 78901', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80'),
        (prov4_uid, 'Vikram Joshi', 'vikram.k9@example.com', 'provider', '+91 97660 33445', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80'),
        (prov5_uid, 'Ananya Reddy', 'ananya.walkers@example.com', 'provider', '+91 94400 99887', 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=400&q=80')
    ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

    -- 3. Insert into public.providers
    INSERT INTO public.providers (id, user_id, business_name, location, description, verified, rating, reviews_count)
    VALUES
        (p1_id, prov1_uid, 'Paws & Claws Veterinary Wellness', 'Indiranagar, Bengaluru', 'Experienced veterinary surgeon with 12+ years expertise in feline medicine and canine wellness.', true, 4.9, 142),
        (p2_id, prov2_uid, 'Velvet Fur Luxury Grooming Salon', 'Bandra West, Mumbai', 'Master stylist providing breed-specific styling, medicated baths, and cat spas.', true, 4.8, 98),
        (p3_id, prov3_uid, 'Happy Tails Green Boarding Resort', 'Gurugram, Delhi NCR', '2 acres of grass paddocks, air-conditioned suites, splash pools, and 24/7 care.', true, 4.7, 84),
        (p4_id, prov4_uid, 'Pawsome Canines Training Academy', 'Koregaon Park, Pune', 'Positive-reinforcement behaviorist covering puppy foundation and leash reactivity.', true, 4.9, 116),
        (p5_id, prov5_uid, 'CityWalkers & Feline Friends', 'Jubilee Hills, Hyderabad', 'Daily fitness strolls, live GPS tracking, and personalized in-home visits.', true, 4.9, 73)
    ON CONFLICT (id) DO NOTHING;

    -- 4. Insert into public.pets
    INSERT INTO public.pets (id, owner_id, name, animal_type, breed, age, gender, weight, vaccination_details, medical_history, image_url)
    VALUES
        (pet1_id, owner_uid, 'Bruno', 'Dog', 'Golden Retriever', 3, 'Male', '31 kg', 'Rabies (Valid Dec 2026), DHPPi complete', 'Mild chicken allergy. Regular ear cleaning required.', 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=600&q=80'),
        (pet2_id, owner_uid, 'Mochi', 'Cat', 'Persian Longhair', 2, 'Female', '4.2 kg', 'Tricat (Valid Aug 2026), Rabies up to date', 'Sensitive digestive tract. Requires daily combing.', 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80'),
        (pet3_id, owner_uid, 'Coco', 'Dog', 'Beagle', 1, 'Male', '12 kg', 'Complete puppy vaccination series done', 'Active and playful, no chronic issues.', 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=600&q=80')
    ON CONFLICT (id) DO NOTHING;

    -- 5. Insert Services
    INSERT INTO public.services (provider_id, category, title, description, price, image_url, rating, duration, featured)
    VALUES
        (p1_id, 'vet', 'Comprehensive Health & Wellness Exam', 'Thorough nose-to-tail physical exam, vital signs check, nutritional advice, dental assessment, and wellness counseling.', 850.00, 'https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?auto=format&fit=crop&w=800&q=80', 4.9, '45 mins', true),
        (p1_id, 'vet', 'Essential Annual Vaccination Package', 'Core immunizations (DHPPi/Rabies for dogs or Tricat/Rabies for cats) combined with deworming and passport sign-off.', 1450.00, 'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&w=800&q=80', 4.9, '30 mins', false),
        (p2_id, 'grooming', 'Royal Spa Bath & Full Body Grooming', 'Hydro-massage bath with natural botanical conditioning shampoo, full-body breed haircut, blow-dry, ear cleansing, and nail grinding.', 1800.00, 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80', 4.8, '90 mins', true),
        (p2_id, 'grooming', 'Tick & Flea Deep Medicated Wash', 'Therapeutic rinse to eliminate external parasites and soothe irritated skin barrier.', 1200.00, 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80', 4.7, '60 mins', false),
        (p3_id, 'boarding', 'Luxury Suite Overnight Boarding', 'Private AC suites, orthopaedic bedding, 3 gourmet meals per day, supervised paddock playtime, and daily WhatsApp updates.', 1500.00, 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=800&q=80', 4.8, '24 hours', true),
        (p3_id, 'daycare', 'Pet Daycare Social Agility Park', 'Supervised daytime playground with obstacle tunnels, splash pads, ball pits, and cozy nap stations.', 800.00, 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80', 4.7, '8 hours', false),
        (p5_id, 'walking', 'Daily 45-Min Fitness Dog Walk', 'Brisk neighborhood walk focused on exercise, sniffing enrichment, leash manners, and waste cleanup.', 350.00, 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?auto=format&fit=crop&w=800&q=80', 4.9, '45 mins', true),
        (p4_id, 'training', 'Puppy Foundation & Basic Manners (6 Sessions)', 'Positive-reinforcement training covering sit, stay, recall, potty training, impulse control, and biting deterrence.', 7500.00, 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?auto=format&fit=crop&w=800&q=80', 4.9, '6 x 60 mins', true);

    -- 6. Insert Notifications
    INSERT INTO public.notifications (user_id, title, message, is_read)
    VALUES
        (owner_uid, 'Appointment Confirmed', 'Dr. Aarav Sharma confirmed your wellness exam for Bruno.', false),
        (owner_uid, 'Vaccination Reminder', 'Bruno is due for annual booster in 4 weeks.', true);
END $$;
