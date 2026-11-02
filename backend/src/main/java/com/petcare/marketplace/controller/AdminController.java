package com.petcare.marketplace.controller;

import com.petcare.marketplace.dto.AdminStatsResponse;
import com.petcare.marketplace.entity.Booking;
import com.petcare.marketplace.entity.Provider;
import com.petcare.marketplace.entity.User;
import com.petcare.marketplace.repository.BookingRepository;
import com.petcare.marketplace.repository.ProviderRepository;
import com.petcare.marketplace.repository.ServiceListingRepository;
import com.petcare.marketplace.repository.UserRepository;
import com.petcare.marketplace.service.MarketplaceService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final UserRepository userRepository;
    private final ProviderRepository providerRepository;
    private final ServiceListingRepository serviceRepository;
    private final BookingRepository bookingRepository;
    private final MarketplaceService marketplaceService;

    public AdminController(UserRepository userRepository,
                           ProviderRepository providerRepository,
                           ServiceListingRepository serviceRepository,
                           BookingRepository bookingRepository,
                           MarketplaceService marketplaceService) {
        this.userRepository = userRepository;
        this.providerRepository = providerRepository;
        this.serviceRepository = serviceRepository;
        this.bookingRepository = bookingRepository;
        this.marketplaceService = marketplaceService;
    }

    @GetMapping("/stats")
    public ResponseEntity<AdminStatsResponse> getStats() {
        long totalUsers = userRepository.count();
        long totalPetOwners = userRepository.countByRole(User.Role.PET_OWNER);
        long totalProviders = providerRepository.count();
        long pendingProviders = providerRepository.countByVerifiedFalse();
        long totalBookings = bookingRepository.count();
        long totalServices = serviceRepository.count();

        double totalRevenue = bookingRepository.findAll().stream()
                .filter(b -> b.getStatus() == Booking.BookingStatus.CONFIRMED || b.getStatus() == Booking.BookingStatus.COMPLETED)
                .mapToDouble(Booking::getTotalPrice)
                .sum();

        return ResponseEntity.ok(new AdminStatsResponse(
                totalUsers, totalPetOwners, totalProviders, pendingProviders, totalBookings, totalServices, totalRevenue
        ));
    }

    @PatchMapping("/providers/{id}/verify")
    public ResponseEntity<Provider> verifyProvider(@PathVariable Long id) {
        return ResponseEntity.ok(marketplaceService.toggleProviderVerification(id));
    }

    @GetMapping("/users")
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }
}
