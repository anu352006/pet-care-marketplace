# 🐾 Pet Care & Services Marketplace
### Modern Full-Stack AI-Powered Marketplace for Pet Parents, Care Providers & Veterinary Specialists

[![Live Demo](https://img.shields.io/badge/Live%20Demo-Vercel-success?style=for-the-badge&logo=vercel)](https://pet-care-marketplace.vercel.app/)
[![GitHub](https://img.shields.io/badge/GitHub-Repository-181717?style=for-the-badge&logo=github)](https://github.com/anu352006/pet-care-marketplace)
[![React](https://img.shields.io/badge/Frontend-React%2018%20%7C%20Vite-61DAFB?style=for-the-badge&logo=react)](https://react.dev/)
[![Supabase](https://img.shields.io/badge/Backend-Supabase%20%7C%20PostgreSQL%2015-3ECF8E?style=for-the-badge&logo=supabase)](https://supabase.com/)

---

## 🌟 1. Project Overview & Mission

**Pet Care & Services Marketplace** is a full-stack, cloud-native web application designed to connect pet parents with certified veterinary doctors, professional pet groomers, boarding resorts, dog walkers, and certified trainers across major metropolitan hubs in India (Bengaluru, Mumbai, Delhi NCR, Hyderabad, Pune, and Chennai).

### 🎯 Problems Addressed:
1. **Fragmented Pet Care Discovery**: Pet owners often struggle to locate verified, high-quality care options within their city.
2. **Double-Booking & Scheduling Conflicts**: Traditional appointment systems lack strict database-level conflict prevention.
3. **Decentralized Pet Health Records**: Pet vaccinations, medical notes, allergies, and health history are scattered across paper booklets.
4. **Emergency Health Confusion**: Pet parents often panic during sudden health emergencies or administer dangerous human medication.

### 💡 The Solution:
A unified, multi-tenant digital marketplace providing **instant service discovery**, **guaranteed conflict-free appointment booking**, **digital Pet Health Passports**, and a **24/7 AI Pet Health Assistant** equipped with veterinary clinical triage guardrails.

---

## 🌐 Live Application Links

- **Production Web Application**: [https://pet-care-marketplace.vercel.app/](https://pet-care-marketplace.vercel.app/)
- **GitHub Repository**: [https://github.com/anu352006/pet-care-marketplace](https://github.com/anu352006/pet-care-marketplace)

---

## ✨ 2. Key Features by User Role

### 🐾 For Pet Owners
- **Marketplace Discovery & Smart Filters**: Search across 8 service categories (Veterinary Care, Grooming, Boarding, Training, Walking, Pet Sitting, Nutrition, Pet Taxi) with real-time filters by city, price range (in ₹ INR), and rating.
- **Conflict-Free Appointment Booking**: Book appointments with specific registered pets, selecting available provider time slots with instant confirmation receipts (`BK-XXXX`).
- **Digital Pet Health Passports (`/pets`)**: Centralized digital profiles for each pet, storing photo, breed, age, weight, allergies, dietary guidelines, and vaccination history.
- **24/7 AI Pet Health Assistant (`/ai-assistant`)**: Intelligent conversational triage assistant providing immediate care advice, breed-specific wellness tips, emergency toxicity warnings (e.g. chocolate, xylitol), and pharmacological safeguards preventing dangerous human drug administration.
- **My Bookings Dashboard (`/owner-dashboard`)**: Track active, completed, and pending appointment requests with live status updates.

### 🩺 For Service Providers
- **Provider Business Profile (`/provider-dashboard`)**: Manage clinic name, service bio, physical address, business hours, and professional verification badges.
- **Appointment Request Console**: Review incoming booking requests in real time with 1-click **Accept** or **Reject** actions.
- **Revenue & Analytics Tracking**: Monitor completed appointments, total platform earnings in ₹ INR, and upcoming appointments.
- **Service Catalog Management**: Add, update, or remove specialized service offerings with custom pricing, duration, and descriptions.

### 🛡️ For System Administrators
- **Governance & Compliance Master Console (`/admin`)**:
  - **Provider Verification Queue**: Review submitted clinic documents, license numbers, and toggle **Approve & Verify** badges.
  - **Platform-Wide Booking Oversight**: Monitor all bookings, filter by status (`pending`, `confirmed`, `completed`, `cancelled`), and inspect dispute details.
  - **Catalog Hygiene**: Audit published services across all categories and cities to maintain high marketplace standards.

---

## 🛠️ 3. Technology Stack & Architecture

| Layer | Technologies & Tools | Purpose |
| :--- | :--- | :--- |
| **Frontend** | React 18, Vite 5, React Router v6, Lucide Icons | High-performance Single Page Application (SPA) with responsive UI/UX |
| **Styling** | Modern CSS3 Design Tokens, Flexbox/Grid | Custom pet-care aesthetic with natural tones (Forest Green, Sage, Terracotta) |
| **Backend / DB** | **Supabase** (PostgreSQL 15) | Relational database with 9 core tables, custom ENUMs, and automated triggers |
| **Authentication** | Supabase Auth (JWT) | Secure token-based session management with role-based routing |
| **Data Protection** | PostgreSQL Row-Level Security (RLS) | Strict database-level isolation protecting user data, bookings, and private profiles |
| **Scheduling Engine** | PostgreSQL `btree_gist` Exclusion Constraints | Prevents overlapping provider slots and simultaneous double-bookings |
| **File Storage** | Supabase Storage (`pet-images`, `provider-images`, `service-images`) | Secure cloud media storage with user-isolated folder access |
| **AI Companion** | Supabase Edge Functions (Deno / TypeScript) | LLM integration with strict clinical triage guardrails and emergency protocols |
| **Hosting & CI/CD** | **Vercel** + **GitHub Actions** | Automated production deployments on every push to `main` |

---

## 🔒 4. Security & Database Design

The application implements defense-in-depth security:
1. **Row-Level Security (RLS)**: Enforced on all tables (`users`, `providers`, `services`, `bookings`, `pets`, `reviews`, `notifications`, `availability`). Pet owners can only access their own pets and bookings; providers can only view bookings assigned to them.
2. **Signup Privilege Escalation Protection**: Database triggers (`handle_new_user`) ensure all public signups default strictly to `pet_owner`, preventing unauthorized self-elevation to `admin`.
3. **No-Overlap Availability Protection**: Uses PostgreSQL GiST exclusion constraints (`chk_availability_no_overlap`) with the `btree_gist` extension, guaranteeing no conflicting time intervals can be scheduled.
4. **Sanitized Public Views**: Public visitor discovery queries use sanitized views (`public.public_providers_view`) that redact internal user IDs, phone numbers, and private data.
5. **Storage Bucket Hardening**: Image uploads are isolated to user-owned folder namespaces with strict MIME type (`image/jpeg`, `image/png`, `image/webp`) and file-size constraints.

---

## 🔑 5. Pre-Seeded Evaluation Accounts

The web application features an **Instant Role Switcher Banner** at the top of the screen for seamless academic and grading evaluation. You can also sign in manually with these credentials:

| Role | Email Address | Password | Focus Modules |
| :--- | :--- | :--- | :--- |
| **Pet Owner** | `priya.petowner@example.com` | `Password123!` | Pet profiles, appointment booking, bookings list, AI triage |
| **Service Provider** | `aarav.vet@example.com` | `Password123!` | Accept/reject appointments, view earnings, manage services |
| **Administrator** | `ananya03052006@gmail.com` | *(Your Admin Password)* | Verify providers, audit all bookings, catalog hygiene |

---

## 📂 6. Project Directory Structure

```text
pet-care-marketplace/
│
├── frontend/                          # React 18 + Vite Single Page Application
│   ├── public/                        # Static assets, logos, and images
│   ├── src/
│   │   ├── components/                # Reusable UI components (Navbar, Footer, ProtectedRoute, ServiceCard)
│   │   ├── context/                   # Global State (AuthContext, MarketplaceContext)
│   │   ├── layouts/                   # Layout wrappers and Navigation bars
│   │   ├── pages/                     # Application views (Home, Services, Dashboards, AI Assistant)
│   │   ├── services/                  # Supabase Client, API services, and AI triage logic
│   │   ├── styles/                    # Global design tokens and responsive CSS
│   │   ├── App.jsx                    # Client-side routing configuration
│   │   └── main.jsx                   # React entry point
│   ├── index.html                     # HTML5 shell
│   ├── package.json                   # Dependencies and scripts
│   └── vite.config.js                 # Vite bundler configuration
│
├── supabase/                          # Supabase Cloud Database Infrastructure
│   ├── migrations/                    # Versioned database migrations & security scripts
│   │   ├── production_security_migration_FINAL.sql  # Complete hardened RLS & security schema
│   │   ├── production_security_precheck_FINAL.sql   # Pre-migration verification checks
│   │   ├── production_security_verification_FINAL.sql # 43 automated security assertion tests
│   │   └── production_security_rollback_FINAL.md    # Multi-tier recovery & disaster rollback plan
│   ├── schema.sql                     # Full PostgreSQL relational schema & triggers
│   ├── seed.sql                       # Demonstration seed data for Indian cities
│   ├── storage.sql                    # Cloud storage bucket creation and policies
│   └── functions/                     # Supabase Edge Functions
│       └── ai-assistant/              # Deno/TypeScript AI triage function
│
├── docs/                              # Technical & Architecture Documentation
│   ├── project-documentation.md       # Comprehensive architecture report
│   ├── api-documentation.md           # API reference & data models
│   └── supabase-setup.md              # Supabase cloud setup instructions
│
├── backend/                           # Reference Spring Boot backend (for reference/archival)
├── database/                          # Reference MySQL scripts (for reference/archival)
└── README.md                          # Project documentation
```

---

## 🚀 7. Local Development Setup

To run the application locally on your machine:

### Prerequisites:
- **Node.js**: v18.0.0 or higher (`node -v`)
- **npm**: v9.0.0 or higher (`npm -v`)
- **Git**: Installed and configured

### Step 1: Clone the Repository
```bash
git clone https://github.com/anu352006/pet-care-marketplace.git
cd pet-care-marketplace
```

### Step 2: Install Dependencies
```bash
cd frontend
npm install
```

### Step 3: Configure Environment Variables
Create a `.env` file inside the `frontend/` directory:
```env
VITE_SUPABASE_URL=https://uuhxfrobjbysasznothx.supabase.co
VITE_SUPABASE_ANON_KEY=your_supabase_publishable_anon_key
```

### Step 4: Start the Development Server
```bash
npm run dev
```
Open your browser and navigate to: `http://localhost:5173`

### Step 5: Build for Production
```bash
npm run build
```

---

## 🧪 8. Key User Journeys to Test

1. **Browse & Filter Services**:
   - Go to **Services** in the top navigation.
   - Filter by City (e.g. *Bengaluru*), Category (e.g. *Veterinary Consultation*), and adjust the price slider.
2. **Book an Appointment**:
   - Click **Book Now** on any service.
   - Select a pet (e.g., *Bruno* or *Mochi*), select a date and an available time slot.
   - Click **Confirm Booking** to receive an instant booking code.
3. **Manage Pet Health Passports**:
   - Go to **My Pets** (`/pets`).
   - Add a new pet with vaccination records and dietary restrictions.
4. **Interact with AI Pet Assistant**:
   - Navigate to **AI Assistant** (`/ai-assistant`).
   - Ask nutritional questions (e.g., *"Can dogs eat carrots?"*).
   - Test safety triage (e.g., *"My puppy ate paracetamol"* or *"My dog ate dark chocolate"*). Observe the high-priority **Emergency Veterinary Warning**.
5. **Provider Console**:
   - Switch role to **Service Provider** (or login as `aarav.vet@example.com`).
   - Accept or reject appointments and inspect calculated revenue.
6. **Administrator Governance**:
   - Switch role to **Admin** (or login as `ananya03052006@gmail.com`).
   - View provider verification queue, approve pending clinics, and inspect all platform bookings.

---

## 📜 9. Academic & Technical Declaration

This project was conceptualized, architected, and engineered for the **Master Program in AI Full Stack Development**. It demonstrates mastery in:
- Modern frontend engineering with React, Vite, and component-driven architecture.
- Cloud-native relational database modeling with PostgreSQL 15 and Supabase.
- Rigorous security implementation using Row-Level Security (RLS) and cryptographic tokens.
- Enterprise-grade database constraint design for scheduling conflict prevention.
- AI prompt engineering with clinical triage and safety guardrails.
- Seamless CI/CD automated deployment with GitHub and Vercel.

---

## 📄 License
This project is open-source under the [MIT License](LICENSE).
