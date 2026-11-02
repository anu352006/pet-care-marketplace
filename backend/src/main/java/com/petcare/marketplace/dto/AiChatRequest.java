package com.petcare.marketplace.dto;

public class AiChatRequest {
    private Long petId;
    private String message;

    public AiChatRequest() {}
    public AiChatRequest(Long petId, String message) {
        this.petId = petId;
        this.message = message;
    }

    public Long getPetId() { return petId; }
    public void setPetId(Long petId) { this.petId = petId; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
