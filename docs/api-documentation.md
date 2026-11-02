# REST API Specification & Postman Testing Reference
**Pet Care & Services Marketplace**

Base URL: `http://localhost:8080/api`

---

## 1. Authentication Endpoints

### 1.1 User Login
- **Endpoint**: `POST /api/auth/login`
- **Access**: Public
- **Request Body**:
```json
{
  "email": "priya.petowner@example.com",
  "password": "Password123!"
}
```
- **Response (200 OK)**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "id": 10,
  "name": "Priya Sundaram",
  "email": "priya.petowner@example.com",
  "role": "PET_OWNER",
  "city": "Bengaluru",
  "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2..."
}
```

### 1.2 User Registration
- **Endpoint**: `POST /api/auth/register`
- **Access**: Public
- **Request Body**:
```json
{
  "name": "Karan Malhotra",
  "email": "karan.owner@example.com",
  "password": "Password123!",
  "phone": "+91 98100 23456",
  "role": "PET_OWNER",
  "city": "Delhi NCR"
}
```
- **Response (200 OK)**: Returns JWT AuthResponse.

---

## 2. Services Marketplace Endpoints

### 2.1 Get All Services / Search & Filter
- **Endpoint**: `GET /api/services`
- **Query Parameters**:
  - `category` (optional, e.g. `vet`, `grooming`, `boarding`, `walking`, `training`, `taxi`)
  - `city` (optional, e.g. `Bengaluru`, `Mumbai`, `Delhi NCR`, `Pune`, `Hyderabad`, `Chennai`)
  - `maxPrice` (optional, e.g. `2000`)
  - `q` (optional, search term)
- **Response (200 OK)**: Array of `ServiceListing` objects.

### 2.2 Get Service by ID
- **Endpoint**: `GET /api/services/{id}`
- **Response (200 OK)**: Single `ServiceListing` with provider details, duration, included items, and available slots.

---

## 3. Pet Profile Management Endpoints

### 3.1 Get My Registered Pets
- **Endpoint**: `GET /api/pets`
- **Headers**: `Authorization: Bearer <JWT>`
- **Response (200 OK)**:
```json
[
  {
    "id": 1,
    "name": "Bruno",
    "type": "Dog",
    "breed": "Golden Retriever",
    "age": 3,
    "gender": "Male",
    "weight": "31 kg",
    "photoUrl": "https://images.unsplash.com/...",
    "vaccinations": "Rabies (Valid till Dec 2026), DHPPi (Valid till Oct 2026)",
    "medicalHistory": "Mild chicken allergy."
  }
]
```

### 3.2 Add Pet Profile
- **Endpoint**: `POST /api/pets`
- **Headers**: `Authorization: Bearer <JWT>`
- **Request Body**:
```json
{
  "name": "Leo",
  "type": "Cat",
  "breed": "Siamese",
  "age": 1,
  "gender": "Male",
  "weight": "3.8 kg",
  "vaccinations": "Tricat booster given",
  "medicalHistory": "None"
}
```

### 3.3 Delete Pet Profile
- **Endpoint**: `DELETE /api/pets/{id}`
- **Headers**: `Authorization: Bearer <JWT>`
- **Response (200 OK)**: `{"message": "Pet profile deleted successfully"}`

---

## 4. Bookings & Appointments Endpoints

### 4.1 Create Booking
- **Endpoint**: `POST /api/bookings`
- **Headers**: `Authorization: Bearer <JWT>`
- **Request Body**:
```json
{
  "serviceId": 101,
  "providerId": 1,
  "petId": 1,
  "bookingDate": "2026-11-15",
  "timeSlot": "11:00 AM",
  "bookingNotes": "Routine dental and coat examination."
}
```
- **Response (200 OK)**: Created Booking entity with unique `bookingCode` (e.g. `BK-4321`) and status `PENDING`.
- **Response (409 Conflict)**: Returned if the provider already has a confirmed booking for the identical date and time slot.

### 4.2 Get User's Bookings
- **Endpoint**: `GET /api/bookings/my-bookings`
- **Headers**: `Authorization: Bearer <JWT>`

### 4.3 Update Booking Status (Provider / Admin)
- **Endpoint**: `PATCH /api/bookings/{id}/status?status=CONFIRMED`
- **Headers**: `Authorization: Bearer <JWT>`

---

## 5. AI Assistant & Recommendations Endpoints

### 5.1 Ask Pet Care Assistant
- **Endpoint**: `POST /api/ai/chat`
- **Request Body**:
```json
{
  "petId": 1,
  "message": "What vegetables are safe to feed my Golden Retriever?"
}
```
- **Response (200 OK)**:
```json
{
  "response": "🥗 Nutrition & Wellness Advice for Bruno (Golden Retriever):\n\n• Safe treats...",
  "isEmergency": false,
  "disclaimer": "Educational Pet Wellness Advisory: Not a substitute for clinical examination.",
  "mode": "INTELLIGENT_SAFE_DEMO"
}
```

### 5.2 Get Personalized Recommendations
- **Endpoint**: `GET /api/ai/recommendations?petId=1`
- **Response (200 OK)**: Array of matching service listings filtered for Bruno's profile.

---

## 6. Admin Endpoints

### 6.1 Platform Analytics & Stats
- **Endpoint**: `GET /api/admin/stats`
- **Headers**: `Authorization: Bearer <ADMIN_JWT>`
- **Response (200 OK)**:
```json
{
  "totalUsers": 8,
  "totalPetOwners": 1,
  "totalProviders": 6,
  "pendingProviders": 0,
  "totalBookings": 3,
  "totalServices": 12,
  "totalRevenue": 3000.00
}
```

### 6.2 Verify / Revoke Provider
- **Endpoint**: `PATCH /api/admin/providers/{id}/verify`
- **Headers**: `Authorization: Bearer <ADMIN_JWT>`
