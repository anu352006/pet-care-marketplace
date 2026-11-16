-- ============================================================================
-- SUPABASE MIGRATION: Administrator Authentication & RLS Security Audit
-- File: supabase/migrations/20261116_admin_auth_and_security.sql
-- Run in: Supabase Dashboard -> SQL Editor -> New query -> Paste & Run
-- ============================================================================

-- 1. Ensure extensions exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Ensure user_role enum exists
DO $$ BEGIN
    CREATE TYPE public.user_role AS ENUM ('pet_owner', 'provider', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. Confirm Administrator Email in auth.users (if registered)
-- This allows instant login with password 'AdminPass123!'
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
    updated_at = NOW()
WHERE email = 'admin@petcare.org';

-- If admin@petcare.org was not yet registered in auth.users, create it with confirmed email
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
)
VALUES (
    '00000000-0000-0000-0000-000000000000',
    '676755ee-0c42-4a53-a1b5-33393aafcdfa',
    'authenticated',
    'authenticated',
    'admin@petcare.org',
    crypt('AdminPass123!', gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"System Administrator","role":"admin"}'::jsonb,
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()),
    encrypted_password = crypt('AdminPass123!', gen_salt('bf'));

-- 4. Ensure public.users has role = 'admin' for admin@petcare.org
INSERT INTO public.users (
    id,
    full_name,
    email,
    role,
    phone,
    avatar_url
)
VALUES (
    '676755ee-0c42-4a53-a1b5-33393aafcdfa',
    'System Administrator',
    'admin@petcare.org',
    'admin',
    '+91 80234 56789',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80'
)
ON CONFLICT (id) DO UPDATE SET
    role = 'admin',
    full_name = 'System Administrator',
    phone = '+91 80234 56789';

-- 5. Helper Function: is_admin() (SECURITY DEFINER to prevent bypass)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6. Helper Function: is_provider()
CREATE OR REPLACE FUNCTION public.is_provider()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'provider'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 7. Explicit RLS Policies Audit across all 9 tables

-- 7.1 USERS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public users profile read" ON public.users;
CREATE POLICY "Public users profile read" ON public.users FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "Admin full control on users" ON public.users;
CREATE POLICY "Admin full control on users" ON public.users FOR ALL USING (public.is_admin());

-- 7.2 PROVIDERS
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view providers" ON public.providers;
CREATE POLICY "Public can view providers" ON public.providers FOR SELECT USING (true);
DROP POLICY IF EXISTS "Provider can update own profile" ON public.providers;
CREATE POLICY "Provider can update own profile" ON public.providers FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Provider can insert own profile" ON public.providers;
CREATE POLICY "Provider can insert own profile" ON public.providers FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Admin full control on providers" ON public.providers;
CREATE POLICY "Admin full control on providers" ON public.providers FOR ALL USING (public.is_admin());

-- 7.3 PETS
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners and booked providers can view pets" ON public.pets;
CREATE POLICY "Owners and booked providers can view pets" ON public.pets FOR SELECT USING (
    auth.uid() = owner_id OR 
    public.is_admin() OR
    auth.uid() IN (SELECT pr.user_id FROM public.bookings b JOIN public.providers pr ON b.provider_id = pr.id WHERE b.pet_id = pets.id)
);
DROP POLICY IF EXISTS "Owners can insert pets" ON public.pets;
CREATE POLICY "Owners can insert pets" ON public.pets FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owners can update own pets" ON public.pets;
CREATE POLICY "Owners can update own pets" ON public.pets FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owners can delete own pets" ON public.pets;
CREATE POLICY "Owners can delete own pets" ON public.pets FOR DELETE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Admin full control on pets" ON public.pets;
CREATE POLICY "Admin full control on pets" ON public.pets FOR ALL USING (public.is_admin());

-- 7.4 SERVICES
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view active services" ON public.services;
CREATE POLICY "Public can view active services" ON public.services FOR SELECT USING (
    active = true OR public.is_admin() OR auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id)
);
DROP POLICY IF EXISTS "Providers can insert their services" ON public.services;
CREATE POLICY "Providers can insert their services" ON public.services FOR INSERT WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR public.is_admin()
);
DROP POLICY IF EXISTS "Providers can update their services" ON public.services;
CREATE POLICY "Providers can update their services" ON public.services FOR UPDATE USING (
    auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR public.is_admin()
);
DROP POLICY IF EXISTS "Providers can delete their services" ON public.services;
CREATE POLICY "Providers can delete their services" ON public.services FOR DELETE USING (
    auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR public.is_admin()
);

-- 7.5 BOOKINGS
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owners can view own bookings" ON public.bookings;
CREATE POLICY "Owners can view own bookings" ON public.bookings FOR SELECT USING (
    auth.uid() = user_id OR
    auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR
    public.is_admin()
);
DROP POLICY IF EXISTS "Owners can create bookings" ON public.bookings;
CREATE POLICY "Owners can create bookings" ON public.bookings FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Owners or Providers can update bookings status" ON public.bookings;
CREATE POLICY "Owners or Providers can update bookings status" ON public.bookings FOR UPDATE USING (
    auth.uid() = user_id OR
    auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR
    public.is_admin()
);

-- 7.6 REVIEWS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view reviews" ON public.reviews;
CREATE POLICY "Public can view reviews" ON public.reviews FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can insert reviews" ON public.reviews;
CREATE POLICY "Users can insert reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Admin full control on reviews" ON public.reviews;
CREATE POLICY "Admin full control on reviews" ON public.reviews FOR ALL USING (public.is_admin());

-- 7.7 NOTIFICATIONS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own notifications" ON public.notifications;
CREATE POLICY "Users view own notifications" ON public.notifications FOR SELECT USING (
    auth.uid() = user_id OR public.is_admin()
);
DROP POLICY IF EXISTS "Users insert own notifications" ON public.notifications;
CREATE POLICY "Users insert own notifications" ON public.notifications FOR INSERT WITH CHECK (
    auth.uid() = user_id OR public.is_admin()
);
DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING (
    auth.uid() = user_id
);

-- 7.8 AVAILABILITY
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can view availability" ON public.availability;
CREATE POLICY "Public can view availability" ON public.availability FOR SELECT USING (true);
DROP POLICY IF EXISTS "Providers manage own availability" ON public.availability;
CREATE POLICY "Providers manage own availability" ON public.availability FOR ALL USING (
    auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR public.is_admin()
);

-- 7.9 CHAT HISTORY
ALTER TABLE public.chat_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own chat history" ON public.chat_history;
CREATE POLICY "Users view own chat history" ON public.chat_history FOR SELECT USING (
    auth.uid() = user_id OR public.is_admin()
);
DROP POLICY IF EXISTS "Users insert chat history" ON public.chat_history;
CREATE POLICY "Users insert chat history" ON public.chat_history FOR INSERT WITH CHECK (
    auth.uid() = user_id OR auth.uid() IS NULL
);

-- 8. STORAGE RLS AUDIT
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
