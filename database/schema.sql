-- ============================================================================
-- WARNING: DO NOT RUN THIS SCRIPT IN SUPABASE!
-- ============================================================================
-- This file contains MySQL 8.0 DDL (ENGINE=InnoDB, utf8mb4, BIGINT AUTO_INCREMENT)
-- designed specifically for a standalone MySQL / Spring Boot backend.
--
-- Running this file in Supabase PostgreSQL WILL FAIL with:
--   ERROR: 42601: syntax error at or near "CHARACTER"
--
-- FOR SUPABASE (PostgreSQL 15+), PLEASE EXECUTE:
--   >>> supabase/schema.sql <<<
-- ============================================================================

-- Compatible with MySQL 8.0 & MySQL Workbench
-- Full-Stack AI-Powered Pet Care & Services Marketplace

DROP DATABASE IF EXISTS pet_care_marketplace;
CREATE DATABASE pet_care_marketplace CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_care_marketplace;

-- 1. USERS TABLE
CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    role ENUM('PET_OWNER', 'SERVICE_PROVIDER', 'ADMIN') NOT NULL DEFAULT 'PET_OWNER',
    city VARCHAR(80) DEFAULT 'Bengaluru',
    avatar_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_email (email),
    INDEX idx_user_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. SERVICE PROVIDERS TABLE
CREATE TABLE providers (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    business_name VARCHAR(150) NOT NULL,
    bio TEXT,
    area VARCHAR(100),
    city VARCHAR(80) NOT NULL,
    address VARCHAR(255),
    rating DECIMAL(2,1) DEFAULT 5.0,
    reviews_count INT DEFAULT 0,
    experience_years INT DEFAULT 1,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_provider_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_provider_city (city),
    INDEX idx_provider_verified (verified)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. PETS TABLE
CREATE TABLE pets (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    name VARCHAR(80) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'Dog', 'Cat', 'Bird', etc.
    breed VARCHAR(100) NOT NULL,
    age INT DEFAULT 1,
    gender VARCHAR(20) DEFAULT 'Male',
    weight VARCHAR(30) DEFAULT '10 kg',
    photo_url VARCHAR(500),
    vaccinations TEXT,
    medical_history TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_pet_owner FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_pet_owner (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. SERVICES TABLE
CREATE TABLE services (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    provider_id BIGINT NOT NULL,
    name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL, -- 'vet', 'grooming', 'boarding', 'walking', 'training', 'sitting', 'daycare', 'taxi'
    category_name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    price_unit VARCHAR(50) DEFAULT 'per session',
    duration VARCHAR(50) DEFAULT '45 mins',
    image_url VARCHAR(500),
    description TEXT NOT NULL,
    included_items TEXT, -- JSON or comma-separated list
    available_slots TEXT, -- Comma-separated default slots
    featured BOOLEAN DEFAULT FALSE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_service_provider FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE,
    INDEX idx_service_category (category),
    INDEX idx_service_price (price),
    INDEX idx_service_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. AVAILABILITY TABLE
CREATE TABLE availability (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    provider_id BIGINT NOT NULL,
    day_of_week VARCHAR(20) NOT NULL, -- 'Monday', 'Tuesday', etc.
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_avail_provider FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. BOOKINGS TABLE
CREATE TABLE bookings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    booking_code VARCHAR(30) NOT NULL UNIQUE,
    service_id BIGINT NOT NULL,
    provider_id BIGINT NOT NULL,
    pet_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    booking_date DATE NOT NULL,
    time_slot VARCHAR(50) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    status ENUM('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED') NOT NULL DEFAULT 'PENDING',
    booking_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_booking_service FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT,
    CONSTRAINT fk_booking_provider FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE RESTRICT,
    CONSTRAINT fk_booking_pet FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE RESTRICT,
    CONSTRAINT fk_booking_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    -- Prevent conflicting duplicate bookings for the same provider, date and slot
    UNIQUE KEY uq_provider_slot (provider_id, booking_date, time_slot, status),
    INDEX idx_booking_status (status),
    INDEX idx_booking_date (booking_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. REVIEWS TABLE
CREATE TABLE reviews (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    service_id BIGINT NOT NULL,
    provider_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    booking_id BIGINT,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_review_service FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
    CONSTRAINT fk_review_provider FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE,
    CONSTRAINT fk_review_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_review_service (service_id),
    INDEX idx_review_provider (provider_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. NOTIFICATIONS TABLE
CREATE TABLE notifications (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_notif_user_read (user_id, is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. CHAT HISTORY TABLE (AI Assistant Sessions)
CREATE TABLE chat_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT,
    pet_id BIGINT,
    user_message TEXT NOT NULL,
    ai_response TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_chat_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_chat_pet FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE SET NULL,
    INDEX idx_chat_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
