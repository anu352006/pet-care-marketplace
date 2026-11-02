# 🐾 Pet Care & Services Marketplace
### Full-Stack AI-Powered Web Application
*Academic Project for Master Program in AI Full Stack Development*

---

## 🌟 1. Project Overview

**Pet Care & Services Marketplace** is a modern, responsive web application connecting loving pet parents with certified veterinary doctors, luxury grooming salons, resort boarders, dog-walkers, and certified trainers across major Indian cities (Bengaluru, Mumbai, Delhi NCR, Pune, Hyderabad, and Chennai).

The application features:
- **Interactive Marketplace**: Search and multi-filter across 8 categories with pricing in Indian Rupees (₹).
- **Conflict-Free Booking System**: Live slot reservation with duplicate conflict prevention.
- **Pet Profile Management**: Full digital health passports including photos, age, breed, vaccination history, and medical records.
- **Role-Based Portals**: Tailored dashboards for **Pet Owners**, **Service Providers**, and **System Administrators**.
- **AI Pet Care Assistant**: 24/7 intelligent pet wellness companion with strict veterinary clinical triage guardrails and personalized advice based on pet profile.
- **AI Recommendation Engine**: Contextual recommendations matching pet breed, age, and wellness history.

---

## 🛠️ 2. Technology Stack

| Layer | Technologies Used |
| :--- | :--- |
| **Frontend** | React 18, Vite, React Router v6, Axios, Lucide Icons, Modern Responsive CSS3 |
| **Backend** | Java 21, Spring Boot 3.3, Spring Web, Spring Data JPA, Hibernate, Spring Security, JWT (JJWT) |
| **Database** | MySQL 8.0 (InnoDB, Relational Schema, Multi-column Unique Constraints) |
| **AI Integration** | External AI API integration with intelligent safe clinical fallback demo engine |
| **Design System** | Forest Green (`#1E3F20`), Sage Green (`#4E7A58`), Warm Terracotta (`#E07A5F`), Off-White Canvas (`#F8F9F5`) |

---

## 📂 3. Project Directory Structure

```
pet-care-marketplace/
│
├── frontend/                     # React + Vite Single Page Application
│   ├── public/                   # Static assets & SVG icons
│   ├── src/
│   │   ├── assets/               # Branding assets
│   │   ├── components/           # Reusable components (ServiceCard, BookingModal, ScrollToTop)
│   │   ├── context/              # AuthContext & MarketplaceContext
│   │   ├── layouts/              # Navbar (with 1-click Role Switcher) & Footer
│   │   ├── pages/                # Home, Services, Detail, Dashboards, AI Assistant, Auth
│   │   ├── services/             # Mock datasets & REST API client connectors
│   │   ├── styles/               # Design tokens (variables.css) & global stylesheets
│   │   ├── App.jsx               # Client-side router configuration
│   │   └── main.jsx              # React DOM entrypoint
│   ├── package.json              # Frontend scripts & dependencies
│   └── vite.config.js            # Vite configuration with proxy to Spring Boot
│
├── backend/                      # Java 21 + Spring Boot 3 Layered Backend
│   ├── src/main/java/com/petcare/marketplace/
│   │   ├── config/               # SecurityConfig, CORS settings, Beans
│   │   ├── controller/           # REST Controllers (Auth, Pets, Services, Bookings, AI, Admin)
│   │   ├── dto/                  # Data Transfer Objects (AuthRequest, BookingRequest, AiChat)
│   │   ├── entity/               # JPA Entities (User, Provider, Pet, ServiceListing, Booking, Review)
│   │   ├── exception/            # GlobalExceptionHandler with standardized JSON responses
│   │   ├── repository/           # Spring Data JPA Repositories
│   │   ├── security/             # JwtUtils, JwtAuthFilter, UserDetailsServiceImpl
│   │   ├── service/              # Core business services & AI clinical triage logic
│   │   └── PetCareMarketplaceApplication.java
│   ├── src/main/resources/
│   │   └── application.properties # Database connection & JWT configuration
│   └── pom.xml                   # Maven dependencies & build configuration
│
├── database/                     # MySQL Database Assets
│   ├── schema.sql                # Complete relational schema (9 tables, constraints, foreign keys)
│   └── sample-data.sql           # Pre-seeded users, 6 providers, 12 services, pets, bookings
│
├── docs/                         # Academic Documentation
│   ├── project-documentation.md  # Comprehensive project report & architecture details
│   └── api-documentation.md      # REST API endpoints & Postman payload references
│
├── run-frontend.bat              # 1-Click Windows script to launch React frontend
├── run-backend.bat               # 1-Click Windows script to launch Spring Boot backend
└── README.md                     # Setup guide & instructions
```

---

## 🚀 4. Step-by-Step Setup & Execution

### Prerequisites Installed on Machine
- **Node.js**: v20+ or v22+ (`node -v`)
- **Java Development Kit (JDK)**: Java 21+ (`C:\Program Files\Java\jdk-25` is installed)
- **MySQL Server 8.0 & MySQL Workbench** (`C:\Program Files\MySQL\MySQL Server 8.0`)

---

### Step A: Set Up MySQL Database

1. Open **MySQL Workbench** or your terminal.
2. Connect to your local MySQL instance (default: `localhost:3306`, user: `root`).
3. Open and execute the script:
   ```
   database/schema.sql
   ```
   *(This creates the database `pet_care_marketplace` and all 9 tables).*
4. Open and execute the seed script:
   ```
   database/sample-data.sql
   ```
   *(This populates realistic Indian service providers, clinics, pet profiles, and appointments).*

---

### Step B: Run the React Frontend (Instant UI Access)

1. Open a terminal in the project root:
   ```powershell
   cd frontend
   npm run dev
   ```
   *Or simply double-click `run-frontend.bat` on Windows!*
2. Open your browser and navigate to:
   ```
   http://localhost:5173
   ```
3. The frontend runs immediately with full interactive capabilities, pre-loaded mock datasets, search filters, booking modals, and the AI Assistant!

---

### Step C: Run the Spring Boot Backend

1. In `backend/src/main/resources/application.properties`, verify your MySQL password:
   ```properties
   spring.datasource.username=root
   spring.datasource.password=YOUR_MYSQL_PASSWORD
   ```
2. Open a second terminal window in the project root:
   ```powershell
   cd backend
   mvn spring-boot:run
   ```
   *Or simply double-click `run-backend.bat` on Windows!*
3. The backend will initialize on:
   ```
   http://localhost:8080
   ```

---

## 🔑 5. Pre-Seeded Evaluation Accounts

The navigation bar features an **Instant Role Switcher Banner** at the top, allowing academic evaluators to switch between all three roles in one click. Alternatively, you can log in manually:

| Role | Email Address | Password | Focus Modules |
| :--- | :--- | :--- | :--- |
| **Pet Owner** | `priya.petowner@example.com` | `Password123!` | Pet profiles, book services, view bookings, AI triage |
| **Service Provider** | `aarav.vet@example.com` | `Password123!` | Accept/reject appointments, add services, view revenue |
| **Administrator** | `admin@petcare.org` | `Password123!` | Verify providers, monitor all bookings, catalog hygiene |

---

## 🧪 6. Testing Key Application Features

1. **Marketplace Discovery & Filters**:
   - Go to **Services**.
   - Filter by city (e.g. `Bengaluru` or `Mumbai`), select category `Veterinary Consultation` or `Pet Grooming`, and adjust the price slider.
2. **Conflict-Free Appointment Booking**:
   - Click **Book Now** on any service.
   - Select one of Priya's registered pets (`Bruno` or `Mochi`).
   - Pick a date and time slot.
   - Confirm booking to generate an instant `BK-XXXX` confirmation receipt.
3. **Pet Health Passport Management**:
   - Go to **My Pets** (`/pets`).
   - Click **Add New Pet** to register a new companion with vaccinations and dietary notes, or edit Bruno's profile.
4. **AI Pet Care Assistant**:
   - Navigate to **AI Assistant** (`/ai-assistant`).
   - Select **Bruno (Golden Retriever, 3y)** in the context dropdown.
   - Click one of the starter chips or ask:
     - *"What vegetables are safe to feed Bruno?"*
     - *"My dog swallowed dark chocolate and is trembling!"* (Notice the **Emergency Triage Warning**).
     - *"Can I give 500mg Paracetamol for fever?"* (Notice the **Pharmacological Protection Warning**).
5. **Provider Appointment Console**:
   - Switch role to **Service Provider** using the top banner.
   - Navigate to `/provider-dashboard`.
   - Accept or Reject pending appointments and view your calculated revenue in ₹ INR.
6. **Administrator Compliance Console**:
   - Switch role to **Administrator** using the top banner.
   - Navigate to `/admin`.
   - Toggle **Approve & Verify** on unverified clinic providers.

---

## 📜 7. Academic Declaration
This project was conceptualized, designed, and developed for the **Master Program in AI Full Stack Development**. All code follows strict layered design principles, clean separation of concerns, and security best practices.
