-- ============================================================================
-- SAFE TARGETED CLEANUP SCRIPT: Production Test Records
-- File: supabase/migrations/cleanup_test_data.sql
--
-- Targeted removal of 4 test records created during backend verification.
-- Strict single-UUID targeting with ownership checks to ensure zero impact
-- on pre-existing customer or provider data.
-- ============================================================================

BEGIN;

-- 1. Remove Test Review (Dependent on Test Booking)
DELETE FROM public.reviews 
WHERE id = 'd392467f-1099-499d-a9d0-1887ad5cbe31' 
  AND user_id = '4fc539a0-2c03-4656-bddb-ad960b90ce19';

-- 2. Remove Test Booking (Dependent on Test Pet & Test Service)
DELETE FROM public.bookings 
WHERE id = 'aa362ac1-f671-42a7-9c29-7185ecf7733f' 
  AND user_id = '4fc539a0-2c03-4656-bddb-ad960b90ce19';

-- 3. Remove Test Pet (Foreign key clear after Test Booking removal)
DELETE FROM public.pets 
WHERE id = '73649437-f2be-4e8a-9c2f-fb2fed10abd5' 
  AND owner_id = '4fc539a0-2c03-4656-bddb-ad960b90ce19';

-- 4. Remove Test Service (Confirmed 0 dependent bookings)
DELETE FROM public.services 
WHERE id = '52e1c3ae-dc52-4d43-956e-2d608d599720' 
  AND provider_id = 'ab5b99cd-ed3c-4fe6-b26f-45240d49a213';

-- 5. Restore Dr. Aarav Sharma's Authentic Original Provider Description
UPDATE public.providers 
SET description = 'Experienced veterinarian with 12+ years of clinical expertise in canine internal medicine, feline preventative diagnostics, and surgical wellness.'
WHERE id = 'ab5b99cd-ed3c-4fe6-b26f-45240d49a213';

COMMIT;
