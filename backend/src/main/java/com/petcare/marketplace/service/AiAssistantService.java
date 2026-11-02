package com.petcare.marketplace.service;

import com.petcare.marketplace.dto.AiChatRequest;
import com.petcare.marketplace.dto.AiChatResponse;
import com.petcare.marketplace.entity.Pet;
import com.petcare.marketplace.entity.ServiceListing;
import com.petcare.marketplace.repository.PetRepository;
import com.petcare.marketplace.repository.ServiceListingRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Service
public class AiAssistantService {

    private final PetRepository petRepository;
    private final ServiceListingRepository serviceRepository;

    @Value("${app.ai.api-key:}")
    private String apiKey;

    @Value("${app.ai.enabled:false}")
    private boolean aiEnabled;

    public AiAssistantService(PetRepository petRepository, ServiceListingRepository serviceRepository) {
        this.petRepository = petRepository;
        this.serviceRepository = serviceRepository;
    }

    public AiChatResponse getCareAdvice(AiChatRequest request) {
        String userQuery = request.getMessage() != null ? request.getMessage().trim() : "";
        String qLower = userQuery.toLowerCase();

        Pet pet = null;
        if (request.getPetId() != null) {
            Optional<Pet> petOpt = petRepository.findById(request.getPetId());
            if (petOpt.isPresent()) pet = petOpt.get();
        }

        String petName = pet != null ? pet.getName() : "your pet";
        String breed = pet != null ? pet.getBreed() : "companion";

        // 1. Emergency Safety Filter
        if (qLower.contains("blood") || qLower.contains("choking") || qLower.contains("poison") ||
            qLower.contains("chocolate") || qLower.contains("collapse") || qLower.contains("unconscious") ||
            qLower.contains("seizure") || qLower.contains("pale gums") || qLower.contains("can't breathe")) {

            String emergencyMsg = "⚠️ URGENT VETERINARY ADVISORY: The symptoms or ingestion described (" + userQuery +
                    ") indicate a potential clinical emergency.\n\n" +
                    "• Immediate Step: Transport " + petName + " immediately to the nearest 24/7 emergency veterinary hospital.\n" +
                    "• Do not induce vomiting or administer human medicine without direct vet instruction.\n" +
                    "• If you require urgent transportation, please use our 24/7 Emergency Pet Taxi service.";

            return new AiChatResponse(
                    emergencyMsg,
                    true,
                    "Emergency Triage Protocol: Always consult a licensed veterinarian immediately for acute medical distress.",
                    aiEnabled && !apiKey.isBlank() ? "LIVE_AI" : "INTELLIGENT_SAFE_DEMO"
            );
        }

        // 2. Medication / Prescription Protection Barrier
        if (qLower.contains("paracetamol") || qLower.contains("crocin") || qLower.contains("ibuprofen") ||
            qLower.contains("dose") || qLower.contains("dosage") || qLower.contains("antibiotic")) {

            String medWarning = "🛑 IMPORTANT PHARMACOLOGICAL NOTICE: Never administer human fever or pain medications (such as Paracetamol, Crocin, Aspirin, or Ibuprofen) to dogs or cats. They cause fatal hepatic and renal failure.\n\n" +
                    "Only a certified veterinarian can prescribe pharmacological treatments and calculate safe dosages for " + petName + " based on verified body weight. Please schedule an examination with our certified veterinary specialists.";

            return new AiChatResponse(
                    medWarning,
                    false,
                    "Safety Guardrail: This AI does not prescribe drugs or calculate chemical dosages.",
                    "INTELLIGENT_SAFE_DEMO"
            );
        }

        // 3. Nutrition Guidance
        if (qLower.contains("food") || qLower.contains("diet") || qLower.contains("fruit") ||
            qLower.contains("vegetable") || qLower.contains("eat") || qLower.contains("feed")) {

            String nutritionGuide = "🥗 Nutrition & Wellness Advice for " + petName + " (" + breed + "):\n\n" +
                    "• Safe Fruits & Veggies: Steamed carrots, deseeded apple slices, plain pumpkin puree, blue berries, and boiled green beans in moderation.\n" +
                    "• Strictly Prohibited / Toxic: Grapes, raisins, onions, garlic, chocolate, caffeine, and products containing artificial Xylitol sweetener.\n" +
                    "• Breed Considerations: For " + breed + ", portion control and fresh filtered water are critical to prevent joint stress and digestive sensitivity.";

            return new AiChatResponse(
                    nutritionGuide,
                    false,
                    "General Dietary Guidance: Introduce new ingredients gradually to monitor for digestive sensitivity.",
                    aiEnabled && !apiKey.isBlank() ? "LIVE_AI" : "INTELLIGENT_SAFE_DEMO"
            );
        }

        // 4. Grooming & Hygiene
        if (qLower.contains("groom") || qLower.contains("bath") || qLower.contains("brush") ||
            qLower.contains("shed") || qLower.contains("coat")) {

            String groomGuide = "✂️ Grooming & Coat Hygiene for " + petName + " (" + breed + "):\n\n" +
                    "• Brushing: Brush 3-4 times weekly with an appropriate de-shedding undercoat rake to prevent hair mats and promote blood circulation.\n" +
                    "• Bathing: Once every 3-4 weeks using an organic, oatmeal-based hypoallergenic pet shampoo. Over-washing depletes protective dermal oils.\n" +
                    "• Paws & Ears: Clean ears weekly using a pH-balanced pet ear cleanser. Check our Marketplace for luxury spa and grooming appointments!";

            return new AiChatResponse(
                    groomGuide,
                    false,
                    "Grooming Care Protocol: Regular maintenance supports skin barrier and coat health.",
                    aiEnabled && !apiKey.isBlank() ? "LIVE_AI" : "INTELLIGENT_SAFE_DEMO"
            );
        }

        // 5. Default General Wellness Advice
        String defaultMsg = "🐾 PetCare Wellness Advice for " + petName + ":\n\n" +
                "Maintaining consistent daily exercise, high-protein balanced nutrition, and scheduled annual core vaccinations (Rabies and DHPPi/Tricat) are the foundation of vibrant pet health.\n\n" +
                "For query: \"" + userQuery + "\", if your pet shows any lethargy, appetite loss, or pain, we recommend booking a routine consultation with one of our verified veterinary clinic partners.";

        return new AiChatResponse(
                defaultMsg,
                false,
                "Educational Pet Wellness Advisory: Not a substitute for hands-on clinical veterinary examination.",
                aiEnabled && !apiKey.isBlank() ? "LIVE_AI" : "INTELLIGENT_SAFE_DEMO"
        );
    }

    public List<ServiceListing> getPersonalizedRecommendations(Long petId) {
        Optional<Pet> petOpt = petId != null ? petRepository.findById(petId) : Optional.empty();
        List<ServiceListing> allServices = serviceRepository.findByActiveTrue();

        if (petOpt.isEmpty()) {
            return allServices.stream().limit(4).toList();
        }

        Pet pet = petOpt.get();
        List<ServiceListing> recommendations = new ArrayList<>();

        for (ServiceListing s : allServices) {
            // Puppy basic training
            if (pet.getAge() <= 1 && "training".equalsIgnoreCase(s.getCategory())) {
                recommendations.add(s);
            }
            // Senior pet wellness
            else if (pet.getAge() >= 7 && "vet".equalsIgnoreCase(s.getCategory())) {
                recommendations.add(s);
            }
            // Long coat breed grooming
            else if ((pet.getBreed().toLowerCase().contains("retriever") ||
                     pet.getBreed().toLowerCase().contains("persian")) &&
                     "grooming".equalsIgnoreCase(s.getCategory())) {
                recommendations.add(s);
            }
            // Active breeds walking
            else if ((pet.getBreed().toLowerCase().contains("retriever") ||
                      pet.getBreed().toLowerCase().contains("beagle")) &&
                     "walking".equalsIgnoreCase(s.getCategory())) {
                recommendations.add(s);
            }
        }

        if (recommendations.isEmpty()) {
            return allServices.stream().limit(4).toList();
        }

        return recommendations.stream().limit(4).toList();
    }
}
