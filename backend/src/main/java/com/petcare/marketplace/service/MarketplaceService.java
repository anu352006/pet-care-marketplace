package com.petcare.marketplace.service;

import com.petcare.marketplace.entity.Provider;
import com.petcare.marketplace.entity.ServiceListing;
import com.petcare.marketplace.repository.ProviderRepository;
import com.petcare.marketplace.repository.ServiceListingRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class MarketplaceService {

    private final ServiceListingRepository serviceRepository;
    private final ProviderRepository providerRepository;

    public MarketplaceService(ServiceListingRepository serviceRepository, ProviderRepository providerRepository) {
        this.serviceRepository = serviceRepository;
        this.providerRepository = providerRepository;
    }

    public List<ServiceListing> getAllServices() {
        return serviceRepository.findByActiveTrue();
    }

    public ServiceListing getServiceById(Long id) {
        return serviceRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Service listing not found: " + id));
    }

    public List<ServiceListing> searchServices(String category, Double maxPrice, String city, String keyword) {
        return serviceRepository.searchServices(
                category != null && !category.equalsIgnoreCase("all") ? category : null,
                maxPrice,
                city != null && !city.equalsIgnoreCase("All Cities") ? city : null,
                keyword != null && !keyword.isBlank() ? keyword : null
        );
    }

    public List<Provider> getAllProviders() {
        return providerRepository.findAll();
    }

    public Provider getProviderById(Long id) {
        return providerRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Provider not found: " + id));
    }

    public Provider toggleProviderVerification(Long providerId) {
        Provider provider = getProviderById(providerId);
        provider.setVerified(!provider.getVerified());
        return providerRepository.save(provider);
    }
}
