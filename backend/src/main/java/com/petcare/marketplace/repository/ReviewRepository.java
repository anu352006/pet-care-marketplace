package com.petcare.marketplace.repository;

import com.petcare.marketplace.entity.Review;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReviewRepository extends JpaRepository<Review, Long> {
    List<Review> findByServiceIdOrderByCreatedAtDesc(Long serviceId);
    List<Review> findByProviderIdOrderByCreatedAtDesc(Long providerId);
}
