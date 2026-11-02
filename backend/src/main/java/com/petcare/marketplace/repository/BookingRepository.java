package com.petcare.marketplace.repository;

import com.petcare.marketplace.entity.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface BookingRepository extends JpaRepository<Booking, Long> {
    List<Booking> findByUserIdOrderByBookingDateDesc(Long userId);
    List<Booking> findByProviderIdOrderByBookingDateDesc(Long providerId);
    Optional<Booking> findByBookingCode(String bookingCode);

    boolean existsByProviderIdAndBookingDateAndTimeSlotAndStatusNot(
            Long providerId, LocalDate bookingDate, String timeSlot, Booking.BookingStatus status
    );
}
