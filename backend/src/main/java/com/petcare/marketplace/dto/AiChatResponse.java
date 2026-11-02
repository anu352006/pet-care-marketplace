package com.petcare.marketplace.dto;

public class AiChatResponse {
    private String response;
    private boolean isEmergency;
    private String disclaimer;
    private String mode; // 'LIVE_AI' or 'INTELLIGENT_SAFE_DEMO'

    public AiChatResponse() {}

    public AiChatResponse(String response, boolean isEmergency, String disclaimer, String mode) {
        this.response = response;
        this.isEmergency = isEmergency;
        this.disclaimer = disclaimer;
        this.mode = mode;
    }

    public String getResponse() { return response; }
    public void setResponse(String response) { this.response = response; }

    public boolean isEmergency() { return isEmergency; }
    public void setEmergency(boolean emergency) { isEmergency = emergency; }

    public String getDisclaimer() { return disclaimer; }
    public void setDisclaimer(String disclaimer) { this.disclaimer = disclaimer; }

    public String getMode() { return mode; }
    public void setMode(String mode) { this.mode = mode; }
}
