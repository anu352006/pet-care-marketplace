package com.petcare.marketplace.repository;

import com.petcare.marketplace.entity.ServiceListing;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ServiceListingRepository extends JpaRepository<ServiceListing, Long> {
    List<ServiceListing> findByProviderId(Long providerId);
    List<ServiceListing> findByCategory(String category);
    List<ServiceListing> findByActiveTrue();
    List<ServiceListing> findByFeaturedTrue();

    @Query("SELECT s FROM ServiceListing s WHERE s.active = true " +
           "AND (:category IS NULL OR s.category = :category) " +
           "AND (:maxPrice IS NULL OR s.price <= :maxPrice) " +
           "AND (:city IS NULL OR LOWER(s.provider.city) = LOWER(:city)) " +
           "AND (:keyword IS NULL OR LOWER(s.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR LOWER(s.description) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<ServiceListing> searchServices(
            @Param("category") String category,
            @Param("maxPrice") Double maxPrice,
            @Param("city") String city,
            @Param("keyword") String keyword
    );
}
