package com.petcare.marketplace.dto;

public class AdminStatsResponse {
    private long totalUsers;
    private long totalPetOwners;
    private long totalProviders;
    private long pendingProviders;
    private long totalBookings;
    private long totalServices;
    private double totalRevenue;

    public AdminStatsResponse() {}

    public AdminStatsResponse(long totalUsers, long totalPetOwners, long totalProviders,
                              long pendingProviders, long totalBookings, long totalServices, double totalRevenue) {
        this.totalUsers = totalUsers;
        this.totalPetOwners = totalPetOwners;
        this.totalProviders = totalProviders;
        this.pendingProviders = pendingProviders;
        this.totalBookings = totalBookings;
        this.totalServices = totalServices;
        this.totalRevenue = totalRevenue;
    }

    public long getTotalUsers() { return totalUsers; }
    public void setTotalUsers(long totalUsers) { this.totalUsers = totalUsers; }

    public long getTotalPetOwners() { return totalPetOwners; }
    public void setTotalPetOwners(long totalPetOwners) { this.totalPetOwners = totalPetOwners; }

    public long getTotalProviders() { return totalProviders; }
    public void setTotalProviders(long totalProviders) { this.totalProviders = totalProviders; }

    public long getPendingProviders() { return pendingProviders; }
    public void setPendingProviders(long pendingProviders) { this.pendingProviders = pendingProviders; }

    public long getTotalBookings() { return totalBookings; }
    public void setTotalBookings(long totalBookings) { this.totalBookings = totalBookings; }

    public long getTotalServices() { return totalServices; }
    public void setTotalServices(long totalServices) { this.totalServices = totalServices; }

    public double getTotalRevenue() { return totalRevenue; }
    public void setTotalRevenue(double totalRevenue) { this.totalRevenue = totalRevenue; }
}
