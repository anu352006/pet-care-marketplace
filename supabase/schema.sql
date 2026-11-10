-- ==========================================================
-- SUPABASE POSTGRESQL SCHEMA: Pet Care & Services Marketplace
-- Run this in your Supabase Project: SQL Editor -> New Query -> Run
-- ==========================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Custom Types & Enums
DO $$ BEGIN
    CREATE TYPE public.user_role AS ENUM ('pet_owner', 'provider', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.booking_status AS ENUM ('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED', 'REJECTED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. USERS TABLE (Linked to Supabase Auth)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    role public.user_role NOT NULL DEFAULT 'pet_owner',
    phone TEXT,
    avatar_url TEXT DEFAULT 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 4. SERVICE PROVIDERS TABLE
CREATE TABLE IF NOT EXISTS public.providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL,
    location TEXT NOT NULL,
    description TEXT,
    verified BOOLEAN DEFAULT FALSE,
    rating NUMERIC(3,1) DEFAULT 5.0,
    reviews_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT uq_provider_user UNIQUE (user_id)
);
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;

-- 5. PETS TABLE
CREATE TABLE IF NOT EXISTS public.pets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    animal_type TEXT NOT NULL DEFAULT 'Dog', -- Dog, Cat, Bird, etc.
    breed TEXT NOT NULL,
    age INT DEFAULT 1,
    gender TEXT DEFAULT 'Male',
    weight TEXT DEFAULT '10 kg',
    vaccination_details TEXT,
    medical_history TEXT,
    image_url TEXT DEFAULT 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=600&q=80',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;

-- 6. SERVICES TABLE
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    category TEXT NOT NULL, -- vet, grooming, boarding, walking, training, sitting, daycare, taxi
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    image_url TEXT,
    rating NUMERIC(3,1) DEFAULT 5.0,
    duration TEXT DEFAULT '45 mins',
    available_slots JSONB DEFAULT '["09:30 AM", "11:00 AM", "02:30 PM", "04:30 PM", "06:00 PM"]'::jsonb,
    featured BOOLEAN DEFAULT FALSE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

-- 7. AVAILABILITY TABLE
CREATE TABLE IF NOT EXISTS public.availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;

-- 8. BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE RESTRICT,
    service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES public.providers(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    booking_date DATE NOT NULL,
    booking_time TEXT NOT NULL,
    status public.booking_status DEFAULT 'PENDING' NOT NULL,
    total_price NUMERIC(10,2) NOT NULL,
    booking_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Partial unique index: ensures no two active bookings share the same provider, date and time slot.
-- Blocks genuinely active bookings: PENDING and CONFIRMED.
-- Releases slots for non-active bookings: CANCELLED, REJECTED, and COMPLETED.
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_booking_slot
ON public.bookings (provider_id, booking_date, booking_time)
WHERE status IN ('PENDING', 'CONFIRMED');

-- 9. REVIEWS TABLE
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    service_id UUID REFERENCES public.services(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- 10. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 11. CHAT HISTORY TABLE (AI Assistant Sessions)
CREATE TABLE IF NOT EXISTS public.chat_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    pet_id UUID REFERENCES public.pets(id) ON DELETE SET NULL,
    question TEXT NOT NULL,
    response TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
ALTER TABLE public.chat_history ENABLE ROW LEVEL SECURITY;

-- ==========================================================
-- HELPER FUNCTIONS & TRIGGERS
-- ==========================================================

-- Function to check if authenticated user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if authenticated user is provider
CREATE OR REPLACE FUNCTION public.is_provider()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'provider'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Automatically create public.users record when new user signs up in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    assigned_role public.user_role;
    user_full_name TEXT;
    user_phone TEXT;
    business_title TEXT;
    user_location TEXT;
BEGIN
    -- Determine role from metadata (case-insensitive, default pet_owner)
    IF LOWER(COALESCE(NEW.raw_user_meta_data->>'role', '')) IN ('provider', 'service_provider') THEN
        assigned_role := 'provider';
    ELSIF LOWER(COALESCE(NEW.raw_user_meta_data->>'role', '')) = 'admin' THEN
        assigned_role := 'admin';
    ELSE
        assigned_role := 'pet_owner';
    END IF;

    user_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Pet Parent');
    user_phone := NEW.raw_user_meta_data->>'phone';
    business_title := COALESCE(NEW.raw_user_meta_data->>'business_name', user_full_name || '''s Pet Care');
    user_location := COALESCE(NEW.raw_user_meta_data->>'location', NEW.raw_user_meta_data->>'city', 'Bengaluru');

    -- Insert into public.users
    INSERT INTO public.users (id, full_name, email, role, phone)
    VALUES (NEW.id, user_full_name, NEW.email, assigned_role, user_phone)
    ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        phone = EXCLUDED.phone;

    -- If provider, create provider profile
    IF assigned_role = 'provider' THEN
        INSERT INTO public.providers (user_id, business_name, location, description, verified)
        VALUES (NEW.id, business_title, user_location, 'Dedicated pet wellness specialist offering high quality care.', false)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_history ENABLE ROW LEVEL SECURITY;

-- 1. USERS POLICIES
DROP POLICY IF EXISTS "Public users profile read" ON public.users;
CREATE POLICY "Public users profile read" ON public.users
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admin full control on users" ON public.users;
CREATE POLICY "Admin full control on users" ON public.users
    FOR ALL USING (public.is_admin());

-- 2. PROVIDERS POLICIES
DROP POLICY IF EXISTS "Public can view providers" ON public.providers;
CREATE POLICY "Public can view providers" ON public.providers
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Provider can update own profile" ON public.providers;
CREATE POLICY "Provider can update own profile" ON public.providers
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Provider can insert own profile" ON public.providers;
CREATE POLICY "Provider can insert own profile" ON public.providers
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin full control on providers" ON public.providers;
CREATE POLICY "Admin full control on providers" ON public.providers
    FOR ALL USING (public.is_admin());

-- 3. PETS POLICIES
DROP POLICY IF EXISTS "Owners can view own pets" ON public.pets;
DROP POLICY IF EXISTS "Owners and booked providers can view pets" ON public.pets;
CREATE POLICY "Owners and booked providers can view pets" ON public.pets
    FOR SELECT USING (
        auth.uid() = owner_id OR 
        public.is_admin() OR
        auth.uid() IN (
            SELECT pr.user_id 
            FROM public.bookings b 
            JOIN public.providers pr ON b.provider_id = pr.id 
            WHERE b.pet_id = pets.id
        )
    );

DROP POLICY IF EXISTS "Owners can insert pets" ON public.pets;
CREATE POLICY "Owners can insert pets" ON public.pets
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can update own pets" ON public.pets;
CREATE POLICY "Owners can update own pets" ON public.pets
    FOR UPDATE USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can delete own pets" ON public.pets;
CREATE POLICY "Owners can delete own pets" ON public.pets
    FOR DELETE USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Admin full control on pets" ON public.pets;
CREATE POLICY "Admin full control on pets" ON public.pets
    FOR ALL USING (public.is_admin());

-- 4. SERVICES POLICIES
DROP POLICY IF EXISTS "Public can view active services" ON public.services;
CREATE POLICY "Public can view active services" ON public.services
    FOR SELECT USING (active = true OR public.is_admin() OR auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id));

DROP POLICY IF EXISTS "Providers can insert their services" ON public.services;
CREATE POLICY "Providers can insert their services" ON public.services
    FOR INSERT WITH CHECK (auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR public.is_admin());

DROP POLICY IF EXISTS "Providers can update their services" ON public.services;
CREATE POLICY "Providers can update their services" ON public.services
    FOR UPDATE USING (auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR public.is_admin());

DROP POLICY IF EXISTS "Providers can delete their services" ON public.services;
CREATE POLICY "Providers can delete their services" ON public.services
    FOR DELETE USING (auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR public.is_admin());

-- 5. AVAILABILITY POLICIES
DROP POLICY IF EXISTS "Public can view availability" ON public.availability;
CREATE POLICY "Public can view availability" ON public.availability
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Providers manage own availability" ON public.availability;
CREATE POLICY "Providers manage own availability" ON public.availability
    FOR ALL USING (auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR public.is_admin());

-- 6. BOOKINGS POLICIES
DROP POLICY IF EXISTS "Owners can view own bookings" ON public.bookings;
CREATE POLICY "Owners can view own bookings" ON public.bookings
    FOR SELECT USING (
        auth.uid() = user_id OR
        auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR
        public.is_admin()
    );

DROP POLICY IF EXISTS "Owners can create bookings" ON public.bookings;
CREATE POLICY "Owners can create bookings" ON public.bookings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Owners or Providers can update bookings status" ON public.bookings;
CREATE POLICY "Owners or Providers can update bookings status" ON public.bookings
    FOR UPDATE USING (
        auth.uid() = user_id OR
        auth.uid() IN (SELECT user_id FROM public.providers WHERE id = provider_id) OR
        public.is_admin()
    );

-- 7. REVIEWS POLICIES
DROP POLICY IF EXISTS "Public can view reviews" ON public.reviews;
CREATE POLICY "Public can view reviews" ON public.reviews
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert reviews" ON public.reviews;
CREATE POLICY "Users can insert reviews" ON public.reviews
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin full control on reviews" ON public.reviews;
CREATE POLICY "Admin full control on reviews" ON public.reviews
    FOR ALL USING (public.is_admin());

-- 8. NOTIFICATIONS POLICIES
DROP POLICY IF EXISTS "Users view own notifications" ON public.notifications;
CREATE POLICY "Users view own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "Users insert own notifications" ON public.notifications;
CREATE POLICY "Users insert own notifications" ON public.notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;
CREATE POLICY "Users update own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- 9. CHAT HISTORY POLICIES
DROP POLICY IF EXISTS "Users view own chat history" ON public.chat_history;
CREATE POLICY "Users view own chat history" ON public.chat_history
    FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "Users insert chat history" ON public.chat_history;
CREATE POLICY "Users insert chat history" ON public.chat_history
    FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);

-- ==========================================================
-- ENABLE REAL-TIME BROADCASTS (IDEMPOTENT)
-- ==========================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'bookings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'services'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.services;
    END IF;
END $$;
