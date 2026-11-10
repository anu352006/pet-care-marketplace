-- ============================================================================
-- WARNING: DO NOT RUN THIS SCRIPT IN SUPABASE!
-- ============================================================================
-- This file contains legacy MySQL 8.0 seed commands (USE pet_care_marketplace,
-- numeric BIGINT user IDs) designed for standalone MySQL / Spring Boot.
--
-- FOR SUPABASE (PostgreSQL 15+), PLEASE EXECUTE:
--   >>> supabase/seed.sql <<<
-- ============================================================================

-- Compatible with MySQL 8.0 & MySQL Workbench
-- Pre-seeded accounts, realistic Indian cities, INR pricing

USE pet_care_marketplace;

-- Password for all seed users is 'Password123!' (BCrypt Hash below)
-- $2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG

-- 1. SEED USERS
INSERT INTO users (id, email, password_hash, full_name, phone, role, city, avatar_url) VALUES
(1, 'admin@petcare.org', '$2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG', 'System Administrator', '+91 80234 56789', 'ADMIN', 'Bengaluru', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=400&q=80'),
(2, 'aarav.vet@example.com', '$2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG', 'Dr. Aarav Sharma', '+91 98450 12345', 'SERVICE_PROVIDER', 'Bengaluru', 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80'),
(3, 'pooja.grooming@example.com', '$2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG', 'Pooja Deshmukh', '+91 98200 45678', 'SERVICE_PROVIDER', 'Mumbai', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80'),
(4, 'rohan.happytails@example.com', '$2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG', 'Rohan Mehra', '+91 98110 78901', 'SERVICE_PROVIDER', 'Delhi NCR', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80'),
(5, 'vikram.k9@example.com', '$2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG', 'Vikram Joshi', '+91 97660 33445', 'SERVICE_PROVIDER', 'Pune', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80'),
(6, 'ananya.walkers@example.com', '$2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG', 'Ananya Reddy', '+91 94400 99887', 'SERVICE_PROVIDER', 'Hyderabad', 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=400&q=80'),
(7, 'karthik.petride@example.com', '$2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG', 'Karthik Subramanian', '+91 98840 55667', 'SERVICE_PROVIDER', 'Chennai', 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80'),
(10, 'priya.petowner@example.com', '$2a$10$VjQ3aK9V4U93n.G54M3zqu.1yZ02g9B/s8qgU43r17Qp.kO/sQ6aG', 'Priya Sundaram', '+91 98765 43210', 'PET_OWNER', 'Bengaluru', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80');

-- 2. SEED PROVIDERS
INSERT INTO providers (id, user_id, business_name, bio, area, city, address, rating, reviews_count, experience_years, verified) VALUES
(1, 2, 'Paws & Claws Veterinary Wellness', 'Experienced veterinarian with 12+ years clinical expertise in canine internal medicine and feline preventative surgery.', 'Indiranagar', 'Bengaluru', '14, 100ft Road, Indiranagar, Bengaluru, KA 560038', 4.9, 142, 12, TRUE),
(2, 3, 'Velvet Fur Luxury Grooming Salon', 'Certified master pet stylist specializing in breed-specific haircuts, medicated organic baths and anxiety-free feline handling.', 'Bandra West', 'Mumbai', 'B-202, Pali Hill, Bandra West, Mumbai, MH 400050', 4.8, 98, 8, TRUE),
(3, 4, 'Happy Tails Green Boarding Resort', 'Pioneered eco-friendly pet stays featuring 2 acres of grassy play paddocks, splash pools, and climate-regulated private suites.', 'Gurugram', 'Delhi NCR', 'Plot 45, Sector 48, Sohna Road, Gurugram, HR 122001', 4.7, 84, 7, TRUE),
(4, 5, 'Pawsome Canines Training Academy', 'Certified positive-reinforcement behaviorist specializing in leash reactivity, puppy basics and agility coaching.', 'Koregaon Park', 'Pune', 'Lane 7, Koregaon Park, Pune, MH 411001', 4.9, 116, 10, TRUE),
(5, 6, 'CityWalkers & Feline Friends', 'Dedicated animal lover providing daily energetic walks, in-home companionship, and puppy play sessions.', 'Jubilee Hills', 'Hyderabad', 'Road No. 36, Jubilee Hills, Hyderabad, TS 500033', 4.9, 73, 5, TRUE),
(6, 7, 'PetRide Express Cab & Ambulance', 'Sanitized, air-conditioned animal transportation equipped with stretchers and safety cages for clinic trips.', 'Adyar', 'Chennai', '1st Cross Road, Gandhi Nagar, Adyar, Chennai, TN 600020', 4.8, 62, 6, TRUE);

-- 3. SEED PETS
INSERT INTO pets (id, user_id, name, type, breed, age, gender, weight, photo_url, vaccinations, medical_history) VALUES
(1, 10, 'Bruno', 'Dog', 'Golden Retriever', 3, 'Male', '31 kg', 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=600&q=80', 'Rabies (Valid till Dec 2026), DHPPi (Valid till Oct 2026)', 'Mild chicken allergy. Regular ear cleansing advised.'),
(2, 10, 'Mochi', 'Cat', 'Persian Longhair', 2, 'Female', '4.2 kg', 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80', 'Tricat Core (Valid till Aug 2026), Rabies (Valid till Nov 2026)', 'Sensitive digestive tract. Requires daily combing.'),
(3, 10, 'Coco', 'Dog', 'Beagle', 1, 'Male', '12 kg', 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=600&q=80', 'Puppy core schedule completed', 'Active, healthy and energetic.');

-- 4. SEED SERVICES
INSERT INTO services (id, provider_id, name, category, category_name, price, price_unit, duration, image_url, description, included_items, available_slots, featured, active) VALUES
(101, 1, 'Comprehensive Health & Wellness Exam', 'vet', 'Veterinary Consultation', 850.00, 'per consultation', '45 mins', 'https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?auto=format&fit=crop&w=800&q=80', 'Thorough nose-to-tail physical exam, vital signs check, dental assessment, and tailored wellness counseling.', 'Cardiopulmonary checkup, Dental evaluation, Body condition score, Digital prescription', '09:30 AM, 11:00 AM, 02:30 PM, 04:30 PM, 06:00 PM', TRUE, TRUE),
(102, 1, 'Essential Annual Vaccination Package', 'vet', 'Veterinary Consultation', 1450.00, 'per package', '30 mins', 'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&w=800&q=80', 'Full core immunizations (DHPPi/Rabies for dogs or Tricat/Rabies for cats) combined with deworming.', 'Core vaccine shot by licensed vet, Deworming tablet, Passport sign-off', '10:00 AM, 12:00 PM, 03:30 PM, 05:30 PM', FALSE, TRUE),
(103, 2, 'Royal Spa Bath & Full Body Grooming', 'grooming', 'Pet Grooming & Spa', 1800.00, 'per session', '90 mins', 'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?auto=format&fit=crop&w=800&q=80', 'Premium hydro-massage bath with natural botanical shampoo, breed haircut, ear cleaning, and nail grinding.', 'Double organic wash, Breed scissor styling, Nail clipping, Paw balm treatment', '10:00 AM, 01:00 PM, 03:30 PM, 05:30 PM', TRUE, TRUE),
(104, 2, 'Tick & Flea Deep Medicated Wash', 'grooming', 'Pet Grooming & Spa', 1200.00, 'per session', '60 mins', 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=800&q=80', 'Specialized medicated therapeutic rinse to eliminate parasites and soothe irritated skin.', 'Herbal anti-parasitic soak, Fine-tooth combing, Blow dry, Coat defense spray', '11:30 AM, 02:00 PM, 04:00 PM', FALSE, TRUE),
(105, 3, 'Luxury Suite Overnight Boarding', 'boarding', 'Pet Boarding & Resort', 1500.00, 'per night', '24 hours', 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=800&q=80', 'Private temperature-controlled suites, scheduled meal times, supervised playtime, and live updates.', 'AC private suite, 3 gourmet balanced meals, 4 play paddock runs, Daily WhatsApp updates', '09:00 AM Check-in, 12:00 PM Check-in, 03:00 PM Check-in', TRUE, TRUE),
(106, 3, 'Daycare Social Play & Agility Park', 'daycare', 'Pet Daycare Playgroups', 800.00, 'per day', '8 hours', 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=800&q=80', 'Supervised daytime playground with obstacle tunnels, splash pads, ball pits, and cozy nap stations.', 'Screened group play, Handler supervision, Rest interval, Healthy snacks', '08:00 AM - 04:00 PM, 10:00 AM - 06:00 PM', FALSE, TRUE),
(107, 5, 'Daily 45-Min Fitness Dog Walk', 'walking', 'Dog Walking & Fitness', 350.00, 'per walk', '45 mins', 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?auto=format&fit=crop&w=800&q=80', 'Brisk, invigorating neighborhood walk focused on exercise, sniffing stimulation, and waste cleanup.', '1-on-1 walk with dedicated handler, Live GPS route summary, Paw cleaning', '06:30 AM, 07:30 AM, 05:30 PM, 06:30 PM', TRUE, TRUE),
(108, 4, 'Puppy Foundation & Basic Manners (6 Sessions)', 'training', 'Pet Behavior & Training', 7500.00, 'course', '6 x 60 mins', 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?auto=format&fit=crop&w=800&q=80', 'Science-backed positive-reinforcement covering sit, stay, recall, and biting deterrence.', 'In-person 1-on-1 sessions, Potty training blueprint, Leash manners, Certificate', '09:00 AM, 11:00 AM, 04:00 PM, 05:30 PM', TRUE, TRUE),
(109, 4, 'Advanced Leash Reactivity Modification', 'training', 'Pet Behavior & Training', 1500.00, 'per session', '75 mins', 'https://images.unsplash.com/photo-1534361960057-19889db9621e?auto=format&fit=crop&w=800&q=80', 'Targeted behavioral modification for dogs showing fear, barking, or lunging on outdoor walks.', 'Trigger threshold analysis, Desensitization drills, Owner handling tips', '08:00 AM, 10:30 AM, 05:00 PM', FALSE, TRUE),
(110, 5, 'In-Home Day Care & Sitter Visit', 'sitting', 'In-Home Pet Sitting', 600.00, 'per 2 hours', '2 hours', 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=800&q=80', 'Comforting in-home pet sitting for anxious pets who prefer familiar surroundings.', 'Meal & water replenishment, Litter scooping, Companion play & updates', '10:00 AM, 01:00 PM, 04:00 PM, 07:00 PM', FALSE, TRUE),
(111, 6, 'Door-to-Door Sanitized Pet Taxi Cab', 'taxi', 'Pet Taxi & Transport', 900.00, 'base ride', 'Flexible', 'https://images.unsplash.com/photo-1544568100-847a948585b9?auto=format&fit=crop&w=800&q=80', 'Safe, AC transport equipped with pet safety harnesses and protective barriers for clinic visits.', 'Sanitized vehicle, Certified driver handler, Space for owner, First aid kit', '08:00 AM, 11:00 AM, 02:00 PM, 05:00 PM, 08:00 PM', TRUE, TRUE),
(112, 6, 'Veterinary Emergency Ambulance & Oxygen', 'taxi', 'Pet Taxi & Transport', 1800.00, 'per trip', 'Urgent', 'https://images.unsplash.com/photo-1584824486509-112e4181ff6b?auto=format&fit=crop&w=800&q=80', 'Urgent vehicle dispatch equipped with animal stretcher cot, oxygen concentrator, and triage assistance.', 'Urgent priority dispatch, Stretcher cot, Medical oxygen flow, Liaison with ER', '24/7 On-Call Support', FALSE, TRUE);

-- 5. SEED BOOKINGS
INSERT INTO bookings (id, booking_code, service_id, provider_id, pet_id, user_id, booking_date, time_slot, total_price, status, booking_notes) VALUES
(1, 'BK-9021', 101, 1, 1, 10, '2026-11-08', '11:00 AM', 850.00, 'CONFIRMED', 'Routine annual general checkup & wellness review.'),
(2, 'BK-8742', 103, 2, 2, 10, '2026-11-12', '01:00 PM', 1800.00, 'PENDING', 'De-shedding and careful sanitary trimming.'),
(3, 'BK-7619', 107, 5, 3, 10, '2026-10-25', '05:30 PM', 350.00, 'COMPLETED', 'Evening park walk with leash obedience practice.');

-- 6. SEED REVIEWS
INSERT INTO reviews (id, service_id, provider_id, user_id, booking_id, rating, comment) VALUES
(1, 101, 1, 10, 1, 5, 'Dr. Aarav was remarkably patient with Bruno. He thoroughly examined his joints, checked his teeth, and suggested great nutritional swaps. Highly recommended clinic!'),
(2, 103, 2, 10, 2, 5, 'Pooja is a master artist with long-haired cats! Mochi came back silky smooth, smelling fresh, and completely relaxed without any grooming stress.'),
(3, 105, 3, 10, 3, 5, 'The live video updates gave my family complete peace of mind while we were away for 4 days. Happy Tails is genuinely the most hygienic pet resort in NCR.');

-- 7. SEED NOTIFICATIONS
INSERT INTO notifications (id, user_id, title, message, is_read) VALUES
(1, 10, 'Appointment Confirmed', 'Dr. Aarav Sharma confirmed your wellness exam for Bruno on Nov 08 at 11:00 AM.', FALSE),
(2, 10, 'Vaccination Due Reminder', 'Bruno is due for annual booster vaccination in 4 weeks.', TRUE);
