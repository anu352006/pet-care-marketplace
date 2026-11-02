package com.petcare.marketplace.controller;

import com.petcare.marketplace.dto.AiChatRequest;
import com.petcare.marketplace.dto.AiChatResponse;
import com.petcare.marketplace.entity.ServiceListing;
import com.petcare.marketplace.service.AiAssistantService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/ai")
public class AiAssistantController {

    private final AiAssistantService aiService;

    public AiAssistantController(AiAssistantService aiService) {
        this.aiService = aiService;
    }

    @PostMapping("/chat")
    public ResponseEntity<AiChatResponse> askAssistant(@RequestBody AiChatRequest request) {
        return ResponseEntity.ok(aiService.getCareAdvice(request));
    }

    @GetMapping("/recommendations")
    public ResponseEntity<List<ServiceListing>> getRecommendations(@RequestParam(required = false) Long petId) {
        return ResponseEntity.ok(aiService.getPersonalizedRecommendations(petId));
    }
}
