# Pet Care & Services Marketplace - Academic Project Documentation
**Master Program in AI Full Stack Development**

---

## 1. Executive Summary & Vision

The **Pet Care & Services Marketplace** is a full-stack, enterprise-grade web application engineered to solve fragmentation in the companion animal wellness industry. The platform provides a trustworthy, transparent bridge connecting responsible pet owners with background-verified service providers—including veterinary clinicians, certified master groomers, luxury boarding resorts, energetic canine dog-walkers, and certified behavioral trainers.

In addition to transactional appointment scheduling, the system features an **AI-Powered Pet Care Assistant** designed with strict veterinary clinical guardrails, offering non-prescriptive nutritional guidance, breed-specific grooming timelines, positive-reinforcement behavioral techniques, and acute emergency symptom triage.

---

## 2. System Architecture

The project adheres to a modern, decoupled layered architecture:

```
[ Client Layer: React 18 + Vite ]
               │
               ▼  (HTTP REST / JSON / JWT Authentication)
[ API Gateway & Security: Spring Security 6 + JJWT ]
               │
               ▼
[ Application Business Layer: Spring Boot 3 Controllers & Services ]
               │
        ┌──────┴─────────────────────────┐
        ▼                                ▼
[ Persistence Layer: Hibernate / JPA ]  [ AI Engine: Triage & Recommendation ]
        │
        ▼
[ Database: MySQL 8.0 Relational Store ]
```

### Layer Responsibilities
1. **Frontend Presentation Layer (`frontend/`)**:
   - Single Page Application (SPA) powered by React 18 and Vite.
   - Client-side routing managed by `react-router-dom` v6.
   - Responsive design system adopting soft off-white (`#F8F9F5`), deep forest green (`#1E3F20`), sage green (`#4E7A58`), and warm terracotta (`#E07A5F`).
   - Global state orchestration through `AuthContext` and `MarketplaceContext`.
2. **Backend Services Layer (`backend/`)**:
   - Built on Java 21+ and Spring Boot 3.3.
   - Organized into Controller, Service, Repository, Entity, DTO, Config, and Exception layers.
   - Stateless authentication enforced via JSON Web Tokens (JWT) and Spring Security filters.
   - Transactional business logic with automated double-booking conflict detection.
3. **Database Layer (`database/`)**:
   - MySQL 8.0 relational schema with InnoDB storage engine.
   - Strict referential integrity via Foreign Key constraints (`ON DELETE CASCADE` / `RESTRICT`).
   - Unique multi-column constraint on `(provider_id, booking_date, time_slot, status)` ensuring zero scheduling overlaps.
4. **AI Integration Engine**:
   - Clinical symptom triage identifying acute distress (choking, bloat, toxic ingestion, seizures) with immediate emergency hospital referral.
   - Strict pharmacological guardrails preventing human drug prescription (paracetamol, ibuprofen).
   - Personalized recommendations matching pet age, breed, and past wellness records.

---

## 3. Database Entity Relationship (ER) Model

The MySQL database `pet_care_marketplace` comprises 9 normalized tables:

1. **`users`**: Base identity storing emails, hashed passwords (`BCrypt`), role (`PET_OWNER`, `SERVICE_PROVIDER`, `ADMIN`), phone, and city.
2. **`providers`**: Professional profile extending a user with business name, clinical bio, physical address, verified badge, and aggregate rating.
3. **`pets`**: Pet owner's companions detailing name, animal type, breed, age, gender, weight, photo URL, vaccination passport, and medical history.
4. **`services`**: Service catalog entries with category, title, duration, starting price (in ₹ INR), description, and available time slots.
5. **`bookings`**: Confirmed and pending appointments linking a service, provider, pet, and user with date and time slot.
6. **`availability`**: Provider weekly scheduling parameters.
7. **`reviews`**: Verified customer ratings (1 to 5 stars) and feedback comments.
8. **`notifications`**: User alert stream for appointment status updates.
9. **`chat_history`**: Audit trail of pet parent queries and AI wellness responses.

---

## 4. Role-Based Access Control (RBAC)

The application enforces 3 distinct operational roles:

| Feature / Module | Pet Owner | Service Provider | Administrator |
| :--- | :---: | :---: | :---: |
| Browse Marketplace & Filter Services | ✅ | ✅ | ✅ |
| Book Appointment Slots | ✅ | ❌ | ❌ |
| Manage Companion Pet Profiles (CRUD) | ✅ | ❌ | ❌ |
| AI Pet Care Assistant Access | ✅ | ✅ | ✅ |
| Add / Manage Service Listings | ❌ | ✅ | ✅ |
| Accept / Reject / Complete Appointments | ❌ | ✅ | ❌ |
| View Earnings & Provider Revenue (₹) | ❌ | ✅ | ✅ |
| Verify / Revoke Specialist Badges | ❌ | ❌ | ✅ |
| Platform KPI Analytics & Bookings Audit | ❌ | ❌ | ✅ |
| Self-Registration on Public Portal | ✅ | ✅ | ❌ (Pre-Seeded) |

---

## 5. AI Assistant & Recommendation Safety Guardrails

### 5.1 Veterinary Clinical Disclaimer
The AI Assistant explicitly identifies itself as an educational wellness assistant. Every output includes a disclaimer reminding the user that it does not replace a clinical examination.

### 5.2 Emergency Symptom Detection
If keywords associated with critical distress (e.g. `poison`, `chocolate`, `choking`, `seizure`, `pale gums`, `unconscious`) are detected:
- The assistant immediately activates **Emergency Triage Protocol**.
- It directs the owner to transport the pet immediately to a 24/7 clinic.
- It recommends the platform's **Pet Ambulance & Emergency Taxi** for dispatch.

### 5.3 Pharmacological Safety Boundary
If users query human medications (e.g. `paracetamol`, `crocin`, `ibuprofen`, `antibiotic doses`):
- The assistant refuses chemical dosage calculation.
- Explains the fatal toxicity risks of human antipyretics to canine/feline livers.
- Recommends an in-person veterinary exam.

### 5.4 Personalization Mechanics
When a user selects one of their registered pets (e.g. "Bruno - 3yr Golden Retriever"):
- Diet advice takes into account breed size, stomach sensitivities, and recorded allergies.
- Grooming advice matches the pet's double-coat or long-hair requirements.
