package com.petcare.marketplace.service;

import com.petcare.marketplace.dto.BookingRequest;
import com.petcare.marketplace.entity.*;
import com.petcare.marketplace.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Random;

@Service
public class BookingService {

    private final BookingRepository bookingRepository;
    private final ServiceListingRepository serviceRepository;
    private final ProviderRepository providerRepository;
    private final PetRepository petRepository;
    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;

    public BookingService(BookingRepository bookingRepository,
                          ServiceListingRepository serviceRepository,
                          ProviderRepository providerRepository,
                          PetRepository petRepository,
                          UserRepository userRepository,
                          NotificationRepository notificationRepository) {
        this.bookingRepository = bookingRepository;
        this.serviceRepository = serviceRepository;
        this.providerRepository = providerRepository;
        this.petRepository = petRepository;
        this.userRepository = userRepository;
        this.notificationRepository = notificationRepository;
    }

    @Transactional
    public Booking createBooking(String userEmail, BookingRequest request) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new RuntimeException("User not found: " + userEmail));

        ServiceListing service = serviceRepository.findById(request.getServiceId())
                .orElseThrow(() -> new RuntimeException("Service not found: " + request.getServiceId()));

        Provider provider = providerRepository.findById(request.getProviderId())
                .orElseThrow(() -> new RuntimeException("Provider not found: " + request.getProviderId()));

        Pet pet = petRepository.findById(request.getPetId())
                .orElseThrow(() -> new RuntimeException("Pet not found: " + request.getPetId()));

        // Conflict check: Prevent conflicting bookings for the same provider and time slot
        boolean hasConflict = bookingRepository.existsByProviderIdAndBookingDateAndTimeSlotAndStatusNot(
                provider.getId(),
                request.getBookingDate(),
                request.getTimeSlot(),
                Booking.BookingStatus.CANCELLED
        );

        if (hasConflict) {
            throw new IllegalStateException("The selected slot (" + request.getTimeSlot() + ") on " +
                    request.getBookingDate() + " is already reserved for " + provider.getBusinessName() +
                    ". Please choose an alternative slot.");
        }

        Booking booking = new Booking();
        booking.setBookingCode("BK-" + (1000 + new Random().nextInt(9000)));
        booking.setUser(user);
        booking.setService(service);
        booking.setProvider(provider);
        booking.setPet(pet);
        booking.setBookingDate(request.getBookingDate());
        booking.setTimeSlot(request.getTimeSlot());
        booking.setTotalPrice(service.getPrice());
        booking.setStatus(Booking.BookingStatus.PENDING);
        booking.setBookingNotes(request.getBookingNotes());

        Booking saved = bookingRepository.save(booking);

        // Create client notification
        Notification notif = new Notification();
        notif.setUser(user);
        notif.setTitle("Booking Request Placed");
        notif.setMessage("Appointment request " + saved.getBookingCode() + " for " + service.getName() + " has been transmitted to " + provider.getBusinessName() + ".");
        notificationRepository.save(notif);

        return saved;
    }

    public List<Booking> getUserBookings(String userEmail) {
        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new RuntimeException("User not found: " + userEmail));
        return bookingRepository.findByUserIdOrderByBookingDateDesc(user.getId());
    }

    public List<Booking> getProviderBookings(Long providerId) {
        return bookingRepository.findByProviderIdOrderByBookingDateDesc(providerId);
    }

    @Transactional
    public Booking updateStatus(Long bookingId, Booking.BookingStatus status) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new RuntimeException("Booking not found: " + bookingId));

        booking.setStatus(status);
        Booking updated = bookingRepository.save(booking);

        Notification notif = new Notification();
        notif.setUser(booking.getUser());
        notif.setTitle("Appointment " + status.name());
        notif.setMessage("Your appointment (" + booking.getBookingCode() + ") status has been updated to " + status.name() + ".");
        notificationRepository.save(notif);

        return updated;
    }
}
