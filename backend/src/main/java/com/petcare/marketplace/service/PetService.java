package com.petcare.marketplace.service;

import com.petcare.marketplace.dto.PetDto;
import com.petcare.marketplace.entity.Pet;
import com.petcare.marketplace.entity.User;
import com.petcare.marketplace.repository.PetRepository;
import com.petcare.marketplace.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PetService {

    private final PetRepository petRepository;
    private final UserRepository userRepository;

    public PetService(PetRepository petRepository, UserRepository userRepository) {
        this.petRepository = petRepository;
        this.userRepository = userRepository;
    }

    public List<Pet> getPetsByOwnerEmail(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return petRepository.findByOwnerId(user.getId());
    }

    public Pet addPet(String ownerEmail, PetDto dto) {
        User user = userRepository.findByEmail(emailClean(ownerEmail))
                .orElseThrow(() -> new RuntimeException("User not found"));

        Pet pet = new Pet();
        pet.setOwner(user);
        pet.setName(dto.getName());
        pet.setType(dto.getType());
        pet.setBreed(dto.getBreed());
        pet.setAge(dto.getAge());
        pet.setGender(dto.getGender());
        pet.setWeight(dto.getWeight());
        pet.setPhotoUrl(dto.getPhotoUrl() != null && !dto.getPhotoUrl().isBlank()
                ? dto.getPhotoUrl()
                : "https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=600&q=80");
        pet.setVaccinations(dto.getVaccinations());
        pet.setMedicalHistory(dto.getMedicalHistory());

        return petRepository.save(pet);
    }

    public Pet updatePet(Long petId, PetDto dto) {
        Pet pet = petRepository.findById(petId)
                .orElseThrow(() -> new RuntimeException("Pet not found: " + petId));

        if (dto.getName() != null) pet.setName(dto.getName());
        if (dto.getType() != null) pet.setType(dto.getType());
        if (dto.getBreed() != null) pet.setBreed(dto.getBreed());
        if (dto.getAge() != null) pet.setAge(dto.getAge());
        if (dto.getGender() != null) pet.setGender(dto.getGender());
        if (dto.getWeight() != null) pet.setWeight(dto.getWeight());
        if (dto.getPhotoUrl() != null) pet.setPhotoUrl(dto.getPhotoUrl());
        if (dto.getVaccinations() != null) pet.setVaccinations(dto.getVaccinations());
        if (dto.getMedicalHistory() != null) pet.setMedicalHistory(dto.getMedicalHistory());

        return petRepository.save(pet);
    }

    public void deletePet(Long petId) {
        petRepository.deleteById(petId);
    }

    private String emailClean(String email) {
        return email != null ? email.trim() : "";
    }
}
