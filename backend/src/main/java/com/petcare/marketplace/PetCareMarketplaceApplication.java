package com.petcare.marketplace;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class PetCareMarketplaceApplication {

    public static void main(String[] args) {
        SpringApplication.run(PetCareMarketplaceApplication.class, args);
        System.out.println("==================================================");
        System.out.println("🐾 Pet Care & Services Marketplace API is RUNNING!");
        System.out.println("   Local URL: http://localhost:8080");
        System.out.println("==================================================");
    }
}
