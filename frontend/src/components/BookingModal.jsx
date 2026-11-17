import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMarketplace } from '../context/MarketplaceContext';
import { useAuth } from '../context/AuthContext';
import { X, Calendar, Clock, CheckCircle2, AlertTriangle, Heart, User, ShieldCheck, LogIn } from 'lucide-react';
import './BookingModal.css';

const BookingModal = ({ service, onClose, onBookingSuccess }) => {
  const { pets, createBooking, checkSlotAvailability } = useMarketplace();
  const { user } = useAuth();

  // Form states
  const [selectedPetId, setSelectedPetId] = useState(pets.length > 0 ? pets[0].id : '');
  const [bookingDate, setBookingDate] = useState(() => {
    // Tomorrow as sensible default date
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    return tomorrow.toISOString().split('T')[0];
  });
  const [selectedTimeSlot, setSelectedTimeSlot] = useState(
    service.availableSlots && service.availableSlots.length > 0 ? service.availableSlots[0] : '10:00 AM'
  );
  const [notes, setNotes] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  const [confirmedBooking, setConfirmedBooking] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  // Available slots for this service
  const slots = service.availableSlots || ['09:30 AM', '11:00 AM', '02:30 PM', '04:30 PM'];

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg('');

    if (!user) {
      setErrorMsg('Please sign in or register an account before booking an appointment.');
      return;
    }

    if (!selectedPetId) {
      setErrorMsg('Please select a registered pet for this appointment.');
      return;
    }

    if (!bookingDate) {
      setErrorMsg('Please select an appointment date.');
      return;
    }

    if (!selectedTimeSlot) {
      setErrorMsg('Please select a time slot.');
      return;
    }

    const petObj = pets.find(p => String(p.id) === String(selectedPetId));

    setSubmitting(true);
    try {
      const created = await createBooking({
        serviceId: service.id,
        serviceName: service.name,
        category: service.category,
        providerId: service.providerId,
        providerName: service.providerName,
        businessName: service.businessName,
        petId: selectedPetId,
        petName: `${petObj?.name || 'Pet'} (${petObj?.breed || 'Companion'})`,
        date: bookingDate,
        timeSlot: selectedTimeSlot,
        totalPrice: service.price,
        bookingNotes: notes || 'Standard appointment booking.'
      });

      setConfirmedBooking(created);
      if (onBookingSuccess) onBookingSuccess(created);
    } catch (err) {
      setErrorMsg(err.message || 'Failed to complete booking.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-content booking-modal" onClick={e => e.stopPropagation()}>
        <button className="modal-close-btn" onClick={onClose} aria-label="Close">
          <X size={20} />
        </button>

        {!confirmedBooking ? (
          <>
            <div className="booking-modal-header">
              <span className="badge badge-primary">{service.categoryName}</span>
              <h2>Book Appointment</h2>
              <p className="subtitle">
                Schedule a slot with <strong>{service.providerName}</strong> ({service.businessName})
              </p>
            </div>

            {errorMsg && (
              <div className="alert alert-danger">
                <AlertTriangle size={18} />
                <span>{errorMsg}</span>
              </div>
            )}

            <form onSubmit={handleSubmit} className="booking-form">
              {/* Pet Selection */}
              <div className="form-group">
                <label className="form-label">
                  <Heart size={16} className="label-icon text-accent" />
                  Select Your Pet:
                </label>
                {pets.length > 0 ? (
                  <div className="pet-picker-grid">
                    {pets.map(p => (
                      <div 
                        key={p.id}
                        className={`pet-picker-card ${String(selectedPetId) === String(p.id) ? 'active' : ''}`}
                        onClick={() => setSelectedPetId(p.id)}
                      >
                        <img 
                          src={p.photo || '/images/pets/pet-dog-golden.jpg'} 
                          alt={p.name} 
                          className="pet-picker-img"
                          onError={(e) => { e.target.src = '/images/pets/pet-dog-golden.jpg'; }}
                        />
                        <div className="pet-picker-info">
                          <strong>{p.name}</strong>
                          <span>{p.breed} • {p.age} yr</span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : !user ? (
                  <div className="no-pets-notice alert alert-info" style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                    <LogIn size={20} className="text-primary" />
                    <div>
                      <span>Please <strong><Link to="/login" onClick={onClose} style={{ textDecoration: 'underline' }}>Sign In</Link></strong> or <strong><Link to="/register" onClick={onClose} style={{ textDecoration: 'underline' }}>Create an Account</Link></strong> to book an appointment with this specialist.</span>
                    </div>
                  </div>
                ) : (
                  <div className="no-pets-notice alert alert-warning" style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                    <Heart size={20} className="text-warning" />
                    <div>
                      <span>You haven't registered any pets yet. Please <strong><Link to="/pets" onClick={onClose} style={{ textDecoration: 'underline' }}>Add your pet</Link></strong> first to schedule an appointment.</span>
                    </div>
                  </div>
                )}
              </div>

              {/* Date Selection */}
              <div className="form-group">
                <label className="form-label">
                  <Calendar size={16} className="label-icon" />
                  Appointment Date:
                </label>
                <input 
                  type="date"
                  className="form-control"
                  value={bookingDate}
                  min={new Date().toISOString().split('T')[0]}
                  onChange={e => setBookingDate(e.target.value)}
                  required
                />
              </div>

              {/* Time Slots */}
              <div className="form-group">
                <label className="form-label">
                  <Clock size={16} className="label-icon" />
                  Select Available Time Slot:
                </label>
                <div className="slots-grid">
                  {slots.map(slot => {
                    const isAvailable = checkSlotAvailability(service.providerId, bookingDate, slot);
                    return (
                      <button
                        type="button"
                        key={slot}
                        disabled={!isAvailable}
                        className={`slot-chip ${selectedTimeSlot === slot ? 'active' : ''} ${!isAvailable ? 'disabled' : ''}`}
                        onClick={() => setSelectedTimeSlot(slot)}
                      >
                        {slot} {!isAvailable && '(Booked)'}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Special Instructions */}
              <div className="form-group">
                <label className="form-label">Special Notes or Instructions (Optional):</label>
                <textarea 
                  className="form-control"
                  rows="2"
                  placeholder="E.g., Pet has a mild allergy, gets nervous around loud dryers, prefers gentle handling..."
                  value={notes}
                  onChange={e => setNotes(e.target.value)}
                />
              </div>

              {/* Summary & Price */}
              <div className="booking-summary-strip">
                <div className="summary-left">
                  <span className="summary-label">Estimated Total Price:</span>
                  <div className="summary-amount">
                    ₹{service.price.toLocaleString('en-IN')} <small>({service.priceUnit})</small>
                  </div>
                </div>
                <button 
                  type="submit" 
                  className="btn btn-primary btn-lg"
                  disabled={submitting || !user || pets.length === 0}
                >
                  {submitting ? 'Confirming...' : 'Confirm Booking'}
                </button>
              </div>
            </form>
          </>
        ) : (
          /* Confirmation Success Screen */
          <div className="booking-success-view">
            <div className="success-icon-wrap">
              <CheckCircle2 size={54} className="text-success" />
            </div>
            <h2>Appointment Confirmed!</h2>
            <p className="success-subtitle">
              Your appointment request has been scheduled and transmitted to the provider.
            </p>

            <div className="receipt-card">
              <div className="receipt-row">
                <span>Booking ID:</span>
                <strong>{confirmedBooking.id}</strong>
              </div>
              <div className="receipt-row">
                <span>Service:</span>
                <strong>{confirmedBooking.serviceName}</strong>
              </div>
              <div className="receipt-row">
                <span>Provider:</span>
                <strong>{confirmedBooking.providerName}</strong>
              </div>
              <div className="receipt-row">
                <span>Pet:</span>
                <strong>{confirmedBooking.petName}</strong>
              </div>
              <div className="receipt-row">
                <span>Date & Slot:</span>
                <strong>{confirmedBooking.date} at {confirmedBooking.timeSlot}</strong>
              </div>
              <div className="receipt-row">
                <span>Total Amount:</span>
                <strong className="text-primary">₹{confirmedBooking.totalPrice.toLocaleString('en-IN')}</strong>
              </div>
              <div className="receipt-row">
                <span>Status:</span>
                <span className="badge badge-warning">PENDING PROVIDER CONFIRMATION</span>
              </div>
            </div>

            <div className="success-modal-actions">
              <button className="btn btn-outline" onClick={onClose}>
                Done
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default BookingModal;
