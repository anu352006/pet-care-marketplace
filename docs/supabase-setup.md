# Supabase Backend Setup & Integration Guide
## Pet Care & Services Marketplace

This comprehensive guide details the architecture, database schema, authentication, Row Level Security (RLS) policies, storage configuration, Edge Functions, and frontend integration for the **Pet Care & Services Marketplace** using **Supabase** as the complete backend.

---

## 1. Architecture Overview

The backend has been transitioned from Java Spring Boot to **Supabase**, leveraging modern cloud-native serverless architecture:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   ReactJS + Vite Frontend (Port 5173)                   │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                    HTTPS / WebSocket / Supabase JS SDK
                                     │
 ┌───────────────────────────────────▼──────────────────────────────────┐
 │                          SUPABASE BACKEND                            │
 │                                                                      │
 │  ┌────────────────────────────────────────────────────────────────┐  │
 │  │ 1. Supabase Auth (GoTrue)                                      │  │
 │  │    - Email & Password Sign Up / Login                          │  │
 │  │    - JWT Tokens & Role Claims (pet_owner, provider, admin)     │  │
 │  │    - Auto-Profile Trigger into public.users                    │  │
 │  └────────────────────────────────────────────────────────────────┘  │
 │                                                                      │
 │  ┌────────────────────────────────────────────────────────────────┐  │
 │  │ 2. PostgreSQL 15 Relational Database                           │  │
 │  │    - 9 Normalized Relational Tables                            │  │
 │  │    - Foreign Keys with CASCADE / RESTRICT constraints         │  │
 │  │    - Slot Conflict Unique Constraints (Anti-Double Booking)    │  │
 │  └────────────────────────────────────────────────────────────────┘  │
 │                                                                      │
 │  ┌────────────────────────────────────────────────────────────────┐  │
 │  │ 3. Row Level Security (RLS)                                    │  │
 │  │    - Granular Owner & Provider Data Isolation                  │  │
 │  │    - Role Helper Functions (is_admin(), is_provider())        │  │
 │  └────────────────────────────────────────────────────────────────┘  │
 │                                                                      │
 │  ┌────────────────────────────────────────────────────────────────┐  │
 │  │ 4. Supabase Storage (S3-Compatible)                            │  │
 │  │    - Buckets: pet-images, provider-images, service-images      │  │
 │  │    - Public read CDN + Authenticated write security policies   │  │
 │  └────────────────────────────────────────────────────────────────┘  │
 │                                                                      │
 │  ┌────────────────────────────────────────────────────────────────┐  │
 │  │ 5. Supabase Edge Functions (Deno TypeScript)                   │  │
 │  │    - Function: ai-assistant                                    │  │
 │  │    - Secure external AI API communication (no keys on client)  │  │
 │  │    - Clinical Safety Guardrails & Emergency Triage             │  │
 │  │    - Service Recommendation Engine & chat_history persistence  │  │
 │  └────────────────────────────────────────────────────────────────┘  │
 └──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Database Schema (9 Relational Tables)

The PostgreSQL database schema is located in `supabase/schema.sql`.

### Relational Entity Model:

| Table | Primary Key | Foreign Keys | Purpose |
|---|---|---|---|
| `users` | `id` (UUID) | References `auth.users(id)` | Profile information, roles (`pet_owner`, `provider`, `admin`), phone, avatar |
| `providers` | `id` (UUID) | References `users(id)` | Business name, clinic/salon location, verification status, rating, bio |
| `pets` | `id` (UUID) | References `users(id)` (`owner_id`) | Pet name, species, breed, age, gender, weight, vaccines, medical history |
| `services` | `id` (UUID) | References `providers(id)` | Category (vet, grooming, boarding, etc.), title, description, price, slots |
| `availability`| `id` (UUID) | References `providers(id)` | Provider operating dates and working time slots |
| `bookings` | `id` (UUID) | References `users`, `providers`, `pets`, `services` | Appointment records, slot date/time, price, status (`PENDING`, `CONFIRMED`, `CANCELLED`, `COMPLETED`) |
| `reviews` | `id` (UUID) | References `bookings`, `users`, `providers`, `services` | Customer ratings (1-5) and feedback comments |
| `notifications`| `id` (UUID)| References `users(id)` | Real-time and persistent alerts (e.g., booking confirmations) |
| `chat_history` | `id` (UUID)| References `users(id)`, `pets(id)` | AI assistant conversation audit logs and personalized recommendations |

---

## 3. Step-by-Step Supabase Setup

### Step 3.1: Create a Free Project
1. Go to [supabase.com](https://supabase.com) and sign in.
2. Click **New Project** and select your preferred region (e.g., *Singapore* or *Mumbai* for optimal latency).
3. Set a secure database password and choose the **Free Plan**.

### Step 3.2: Execute Schema & Tables
1. In the Supabase Dashboard, navigate to **SQL Editor** in the left sidebar.
2. Click **New Query**.
3. Open `supabase/schema.sql` from this repository, copy all contents, paste into the SQL Editor, and click **Run**.
4. All 9 tables, custom ENUMs, triggers, and Row Level Security (RLS) policies are automatically instantiated.

### Step 3.3: Configure Storage Buckets
1. In **SQL Editor**, click **New Query**.
2. Open `supabase/storage.sql`, copy and run it.
3. This creates the three public buckets with secure upload/read policies:
   - `pet-images`: Pet profile pictures
   - `provider-images`: Provider avatars and clinic photos
   - `service-images`: Service catalog illustrations

### Step 3.4: Seed Initial Marketplace Data
1. In **SQL Editor**, click **New Query**.
2. Open `supabase/seed.sql`, copy and run it.
3. This populates realistic clinics, certified groomers, trainers, pet taxis, and starter services across major Indian metros (Bengaluru, Mumbai, Delhi NCR, Pune, Hyderabad, Chennai) with ₹ INR pricing.

---

## 4. Row Level Security (RLS) Policy Matrix

RLS is strictly enforced on all tables. Helper functions `public.is_admin()` and `public.is_provider()` provide role-based elevation.

| Table | Policy Name | Permitted Operations | Permitted Actors |
|---|---|---|---|
| `users` | Public profiles are readable | `SELECT` | All authenticated & anonymous users |
| `users` | Users can update their own profile | `UPDATE` | Matching `auth.uid() = id` or `is_admin()` |
| `pets` | Anyone can view pets for booking | `SELECT` | Authenticated users & providers |
| `pets` | Owners can insert & manage pets | `INSERT, UPDATE, DELETE` | Matching `owner_id = auth.uid()` or `is_admin()` |
| `providers`| Anyone can browse providers | `SELECT` | Public / All users |
| `providers`| Providers manage their profile | `UPDATE` | Matching `user_id = auth.uid()` or `is_admin()` |
| `services` | Anyone can browse active services | `SELECT` | Public / All users |
| `services` | Providers can manage services | `INSERT, UPDATE, DELETE` | Provider owning the service or `is_admin()` |
| `bookings` | Owners & Providers view bookings | `SELECT` | Customer (`user_id`), Provider, or `is_admin()` |
| `bookings` | Authenticated users create bookings | `INSERT` | Matching `user_id = auth.uid()` |
| `bookings` | Update booking status | `UPDATE` | Customer (can cancel), Provider, or `is_admin()` |
| `reviews`  | Anyone can view reviews | `SELECT` | Public / All users |
| `reviews`  | Customers post reviews | `INSERT` | Matching `user_id = auth.uid()` |
| `notifications` | Users view and manage own notifications | `SELECT, INSERT, UPDATE` | Matching `user_id = auth.uid()` or `is_admin()` |
| `chat_history` | Users view own chat history | `SELECT, INSERT` | Matching `user_id = auth.uid()` or `is_admin()` |

---

## 5. Supabase Edge Function: `ai-assistant`

The Edge Function resides in `supabase/functions/ai-assistant/index.ts`.

### Key Capabilities:
1. **Server-Side Security**: External AI API keys (`AI_API_KEY` or `OPENAI_API_KEY`) remain securely in Supabase environment secrets. No API keys are ever transmitted to or exposed in the frontend.
2. **Clinical Safety Guardrails**:
   - Detects acute emergency keywords (e.g., choking, poisoning, chocolate, blood, collapse, seizures, severe lethargy) and triggers an immediate **Urgent Veterinary Advisory** directing the user to 24/7 trauma clinics or the Pet Taxi ambulance service.
   - Blocks requests for human pharmaceutical dosages (Paracetamol, Crocin, Ibuprofen, Aspirin), warning against fatal feline and canine toxicity.
3. **Contextual Service Recommendations**: Automatically surfaces matching services (Veterinary Consultation, Spa Bath, Obedience Training, Boarding, or Pet Taxi).
4. **Audit Persistence**: Inserts every question, answer, and pet context into the `public.chat_history` table.

### Deploying the Edge Function:
Using the Supabase CLI:
```bash
# Install Supabase CLI if not already installed:
npm install -g supabase

# Log in to your Supabase account:
supabase login

# Link your local repo to your Supabase project:
supabase link --project-ref your-project-id

# Set your external AI API key (OpenAI, Gemini, or Groq):
supabase secrets set AI_API_KEY=your-external-ai-key-here

# Deploy the Edge Function:
supabase functions deploy ai-assistant
```

---

## 6. Frontend Environment Configuration

In `frontend/`, configure `.env` (a template is provided in `frontend/.env.example`):

```env
# Supabase Project Connection Credentials
# Found under: Project Settings -> API
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-public-key-here
```

### Dual Operating Modes (Academic Evaluation Safe):
- **Live Supabase Mode**: When `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are populated with valid project credentials, the app runs against your live PostgreSQL tables, Supabase Auth, Storage buckets, and Edge Functions.
- **Academic Demo Mode**: If credentials have not yet been pasted, the app runs in an instant interactive demo mode using cached local storage and pre-configured role switcher buttons in the navigation bar. This ensures that examiners and evaluators can review the platform instantly without setup barriers.

---

## 7. How to Run & Verify

1. **Start the Frontend Development Server**:
   ```bash
   cd frontend
   npm run dev -- --host
   ```
   Open your browser at `http://localhost:5173`.

2. **Verify Authentication**:
   - Navigate to `/register` and create a new **Pet Owner** or **Service Provider** account.
   - Navigate to `/login` and sign in.
   - Use the Forgot Password interface at `/forgot-password`.

3. **Verify Pet Profile Management & Storage Upload**:
   - Go to `/pets`.
   - Click **Add Pet Profile**.
   - Click **Upload Image File** to test direct upload to the `pet-images` Supabase Storage bucket.
   - Save and verify the profile appears in the pet grid.

4. **Verify Booking Conflict Prevention**:
   - Navigate to `/services` and click **Book Now** on any service.
   - Choose a pet, date, and time slot, then submit the appointment.
   - Attempt to book the exact same provider, date, and slot again to verify that the conflict guardrail rejects the duplicate booking.

5. **Verify AI Pet Care Assistant**:
   - Navigate to `/ai-assistant`.
   - Ask: *"What are safe vegetables I can feed my dog?"* (Verifies nutrition guidance).
   - Ask: *"My dog ate chocolate and is vomiting"* (Verifies emergency veterinary triage).
   - Ask: *"Can I give paracetamol to my cat for fever?"* (Verifies medication safety barrier).
