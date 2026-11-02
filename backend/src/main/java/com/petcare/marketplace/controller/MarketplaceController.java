package com.petcare.marketplace.controller;

import com.petcare.marketplace.entity.Provider;
import com.petcare.marketplace.entity.ServiceListing;
import com.petcare.marketplace.service.MarketplaceService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
public class MarketplaceController {

    private final MarketplaceService marketplaceService;

    public MarketplaceController(MarketplaceService marketplaceService) {
        this.marketplaceService = marketplaceService;
    }

    @GetMapping("/services")
    public ResponseEntity<List<ServiceListing>> searchServices(
            @RequestParam(required = false) String category,
            @RequestParam(required = false) Double maxPrice,
            @RequestParam(required = false) String city,
            @RequestParam(required = false) String q
    ) {
        if (category == null && maxPrice == null && city == null && q == null) {
            return ResponseEntity.ok(marketplaceService.getAllServices());
        }
        return ResponseEntity.ok(marketplaceService.searchServices(category, maxPrice, city, q));
    }

    @GetMapping("/services/{id}")
    public ResponseEntity<ServiceListing> getServiceById(@PathVariable Long id) {
        return ResponseEntity.ok(marketplaceService.getServiceById(id));
    }

    @GetMapping("/providers")
    public ResponseEntity<List<Provider>> getAllProviders() {
        return ResponseEntity.ok(marketplaceService.getAllProviders());
    }

    @GetMapping("/providers/{id}")
    public ResponseEntity<Provider> getProviderById(@PathVariable Long id) {
        return ResponseEntity.ok(marketplaceService.getProviderById(id));
    }
}
