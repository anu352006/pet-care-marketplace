package com.petcare.marketplace.dto;

public class RegisterRequest {
    private String name;
    private String email;
    private String password;
    private String phone;
    private String role; // 'PET_OWNER' or 'SERVICE_PROVIDER'
    private String businessName;
    private String city;

    public RegisterRequest() {}

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public String getBusinessName() { return businessName; }
    public void setBusinessName(String businessName) { this.businessName = businessName; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
}
