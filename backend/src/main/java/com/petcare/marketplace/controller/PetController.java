package com.petcare.marketplace.controller;

import com.petcare.marketplace.dto.PetDto;
import com.petcare.marketplace.entity.Pet;
import com.petcare.marketplace.service.PetService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/pets")
public class PetController {

    private final PetService petService;

    public PetController(PetService petService) {
        this.petService = petService;
    }

    @GetMapping
    public ResponseEntity<List<Pet>> getMyPets(@AuthenticationPrincipal UserDetails userDetails) {
        String email = userDetails != null ? userDetails.getUsername() : "priya.petowner@example.com";
        return ResponseEntity.ok(petService.getPetsByOwnerEmail(email));
    }

    @PostMapping
    public ResponseEntity<Pet> addPet(@AuthenticationPrincipal UserDetails userDetails, @RequestBody PetDto dto) {
        String email = userDetails != null ? userDetails.getUsername() : "priya.petowner@example.com";
        return ResponseEntity.ok(petService.addPet(email, dto));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Pet> updatePet(@PathVariable Long id, @RequestBody PetDto dto) {
        return ResponseEntity.ok(petService.updatePet(id, dto));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deletePet(@PathVariable Long id) {
        petService.deletePet(id);
        return ResponseEntity.ok(Map.of("message", "Pet profile deleted successfully"));
    }
}
