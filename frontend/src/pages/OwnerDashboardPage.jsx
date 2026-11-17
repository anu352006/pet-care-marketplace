import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useMarketplace } from '../context/MarketplaceContext';
import { uploadStorageFile } from '../lib/supabase';
import { 
  Heart, 
  Calendar, 
  Clock, 
  Sparkles, 
  Plus, 
  CheckCircle2, 
  AlertCircle, 
  ArrowRight, 
  ShieldCheck, 
  Stethoscope,
  Star,
  RotateCcw,
  Edit2,
  X,
  User,
  Upload,
  MessageSquare
} from 'lucide-react';
import './OwnerDashboardPage.css';

const OwnerDashboardPage = () => {
  const { user, updateProfile } = useAuth();
  const { 
    pets, 
    bookings, 
    reviews, 
    getPersonalizedRecommendations, 
    cancelBooking, 
    rescheduleBooking, 
    addReview,
    checkSlotAvailability 
  } = useMarketplace();

  // Active navigation tab for bookings
  const [activeTab, setActiveTab] = useState('upcoming'); // 'upcoming' | 'history'

  // Modal states
  const [reschedulingBooking, setReschedulingBooking] = useState(null);
  const [newDate, setNewDate] = useState('');
  const [newSlot, setNewSlot] = useState('');
  const [rescheduleError, setRescheduleError] = useState('');
  const [rescheduleSubmitting, setRescheduleSubmitting] = useState(false);

  const [reviewingBooking, setReviewingBooking] = useState(null);
  const [reviewRating, setReviewRating] = useState(5);
  const [reviewComment, setReviewComment] = useState('');
  const [reviewError, setReviewError] = useState('');
  const [reviewSubmitting, setReviewSubmitting] = useState(false);

  const [showProfileModal, setShowProfileModal] = useState(false);
  const [profileName, setProfileName] = useState(user?.name || '');
  const [profilePhone, setProfilePhone] = useState(user?.phone || '');
  const [profileCity, setProfileCity] = useState(user?.city || 'Bengaluru');
  const [profileAvatar, setProfileAvatar] = useState(user?.avatar || '');
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [profileError, setProfileError] = useState('');
  const [profileSuccess, setProfileSuccess] = useState('');
  const [profileSaving, setProfileSaving] = useState(false);

  // Active and historical bookings
  const upcomingBookings = bookings.filter(b => b.status === 'CONFIRMED' || b.status === 'PENDING');
  const pastBookings = bookings.filter(b => b.status === 'COMPLETED' || b.status === 'CANCELLED');

  // AI recommendations for primary pet
  const primaryPet = pets[0];
  const recommendedServices = getPersonalizedRecommendations(primaryPet?.id);

  // Check if a completed booking has already been reviewed
  const isBookingReviewed = (bookingId) => {
    return reviews.some(r => String(r.bookingId || r.id) === String(bookingId));
  };

  // Open reschedule modal
  const handleOpenReschedule = (b) => {
    setReschedulingBooking(b);
    setNewDate(b.date);
    setNewSlot(b.timeSlot);
    setRescheduleError('');
  };

  const handleConfirmReschedule = async (e) => {
    e.preventDefault();
    if (!reschedulingBooking || !newDate || !newSlot) return;

    setRescheduleError('');
    setRescheduleSubmitting(true);
    try {
      await rescheduleBooking(reschedulingBooking.id, newDate, newSlot);
      setReschedulingBooking(null);
    } catch (err) {
      setRescheduleError(err.message || 'Failed to reschedule appointment.');
    } finally {
      setRescheduleSubmitting(false);
    }
  };

  // Open review modal
  const handleOpenReview = (b) => {
    setReviewingBooking(b);
    setReviewRating(5);
    setReviewComment('');
    setReviewError('');
  };

  const handleConfirmReview = async (e) => {
    e.preventDefault();
    if (!reviewingBooking) return;
    if (!reviewComment.trim()) {
      setReviewError('Please write a brief feedback comment.');
      return;
    }

    setReviewError('');
    setReviewSubmitting(true);
    try {
      await addReview({
        bookingId: reviewingBooking.id,
        serviceId: reviewingBooking.serviceId,
        serviceName: reviewingBooking.serviceName,
        providerId: reviewingBooking.providerId,
        providerName: reviewingBooking.providerName,
        userName: user?.name || 'Verified Pet Parent',
        rating: Number(reviewRating),
        comment: reviewComment.trim()
      });
      setReviewingBooking(null);
    } catch (err) {
      setReviewError(err.message || 'Failed to submit review.');
    } finally {
      setReviewSubmitting(false);
    }
  };

  // Open profile modal
  const handleOpenProfileModal = () => {
    setProfileName(user?.name || '');
    setProfilePhone(user?.phone || '');
    setProfileCity(user?.city || 'Bengaluru');
    setProfileAvatar(user?.avatar || '');
    setProfileError('');
    setProfileSuccess('');
    setShowProfileModal(true);
  };

  const handleAvatarUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setProfileError('');
    try {
      setUploadingAvatar(true);
      const url = await uploadStorageFile('pet-images', file, 'avatars');
      setProfileAvatar(url);
    } catch (err) {
      setProfileError(err.message || 'Failed to upload photo.');
    } finally {
      setUploadingAvatar(false);
    }
  };

  const handleSaveProfile = async (e) => {
    e.preventDefault();
    setProfileError('');
    setProfileSuccess('');
    setProfileSaving(true);
    try {
      await updateProfile({
        name: profileName,
        phone: profilePhone,
        city: profileCity,
        avatar: profileAvatar
      });
      setProfileSuccess('Profile updated successfully!');
      setTimeout(() => setShowProfileModal(false), 1200);
    } catch (err) {
      setProfileError(err.message || 'Failed to update profile.');
    } finally {
      setProfileSaving(false);
    }
  };

  const slots = ['09:30 AM', '11:00 AM', '02:30 PM', '04:30 PM', '06:00 PM'];

  return (
    <div className="dashboard-page section">
      <div className="container">
        {/* Welcome Banner */}
        <div className="dashboard-welcome-banner card">
          <div className="welcome-content">
            <span className="badge badge-primary">Pet Owner Dashboard</span>
            <h1>Welcome back, {user ? user.name : 'Pet Parent'}! 🐾</h1>
            <p>
              Here is what is happening with your beloved furry companions and upcoming wellness schedules.
            </p>
            <div className="quick-action-btns">
              <Link to="/services" className="btn btn-primary btn-sm">
                <Plus size={16} /> Book Appointment
              </Link>
              <Link to="/pets" className="btn btn-outline btn-sm">
                <Heart size={16} /> Manage Pets ({pets.length})
              </Link>
              <Link to="/ai-assistant" className="btn btn-accent btn-sm">
                <Sparkles size={16} /> AI Pet Care Assistant
              </Link>
              <button 
                type="button" 
                className="btn btn-ghost btn-sm"
                onClick={handleOpenProfileModal}
              >
                <Edit2 size={16} /> Edit Profile
              </button>
            </div>
          </div>
          
          <div className="welcome-banner-right">
            {primaryPet && (
              <div className="primary-pet-pill">
                <img 
                  src={primaryPet.photo || '/images/pets/pet-dog-golden.jpg'} 
                  alt={primaryPet.name} 
                  className="primary-pet-avatar"
                  onError={(e) => { e.target.src = '/images/pets/pet-dog-golden.jpg'; }}
                />
                <div>
                  <strong>{primaryPet.name}</strong>
                  <span>{primaryPet.breed} • {primaryPet.age} yrs</span>
                </div>
              </div>
            )}
            <img 
              src="/images/hero/hero-lifestyle.jpg" 
              alt="Happy pet parent with companion" 
              className="welcome-lifestyle-badge-img"
              loading="lazy"
            />
          </div>
        </div>

        {/* Dashboard Stat Counters */}
        <div className="stats-metric-grid">
          <div className="metric-card card">
            <div className="metric-icon-box bg-sage">
              <Heart size={24} />
            </div>
            <div className="metric-info">
              <span className="metric-label">Registered Pets</span>
              <strong className="metric-val">{pets.length}</strong>
            </div>
          </div>

          <div className="metric-card card">
            <div className="metric-icon-box bg-terracotta">
              <Calendar size={24} />
            </div>
            <div className="metric-info">
              <span className="metric-label">Upcoming Bookings</span>
              <strong className="metric-val">{upcomingBookings.length}</strong>
            </div>
          </div>

          <div className="metric-card card">
            <div className="metric-icon-box bg-sage">
              <CheckCircle2 size={24} />
            </div>
            <div className="metric-info">
              <span className="metric-label">Completed Sessions</span>
              <strong className="metric-val">{pastBookings.filter(b => b.status === 'COMPLETED').length}</strong>
            </div>
          </div>
        </div>

        {/* Main Dashboard Row: Appointments + Pet Profiles */}
        <div className="dashboard-two-cols">
          {/* Left: Bookings Schedule */}
          <div className="dashboard-col-left">
            <div className="card dashboard-card">
              <div className="card-header-row" style={{ flexWrap: 'wrap', gap: '0.75rem' }}>
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                  <button 
                    className={`btn btn-sm ${activeTab === 'upcoming' ? 'btn-primary' : 'btn-ghost'}`}
                    onClick={() => setActiveTab('upcoming')}
                  >
                    <Calendar size={16} /> Upcoming ({upcomingBookings.length})
                  </button>
                  <button 
                    className={`btn btn-sm ${activeTab === 'history' ? 'btn-primary' : 'btn-ghost'}`}
                    onClick={() => setActiveTab('history')}
                  >
                    <CheckCircle2 size={16} /> History ({pastBookings.length})
                  </button>
                </div>
                <Link to="/services" className="link-subtle">
                  Book New Slot <ArrowRight size={14} />
                </Link>
              </div>

              {/* UPCOMING BOOKINGS VIEW */}
              {activeTab === 'upcoming' && (
                upcomingBookings.length > 0 ? (
                  <div className="appointments-list">
                    {upcomingBookings.map(b => (
                      <div key={b.id} className="appointment-item">
                        <div className="app-status-indicator">
                          <span className={`badge ${b.status === 'CONFIRMED' ? 'badge-success' : 'badge-warning'}`}>
                            {b.status}
                          </span>
                          <span className="app-booking-id">{b.id}</span>
                        </div>

                        <div className="app-main-details">
                          <h4>{b.serviceName}</h4>
                          <p className="app-provider-line">
                            With <strong>{b.providerName}</strong> ({b.businessName})
                          </p>
                          <div className="app-meta-tags">
                            <span className="tag-pill">
                              <Heart size={12} /> {b.petName}
                            </span>
                            <span className="tag-pill">
                              <Calendar size={12} /> {b.date}
                            </span>
                            <span className="tag-pill">
                              <Clock size={12} /> {b.timeSlot}
                            </span>
                          </div>
                        </div>

                        <div className="app-price-box" style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '0.4rem' }}>
                          <span className="app-price">₹{b.totalPrice.toLocaleString('en-IN')}</span>
                          {b.status === 'PENDING' && (
                            <div style={{ display: 'flex', gap: '0.4rem' }}>
                              <button
                                type="button"
                                className="btn btn-outline btn-sm"
                                style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
                                onClick={() => handleOpenReschedule(b)}
                                title="Reschedule appointment"
                              >
                                <RotateCcw size={12} /> Reschedule
                              </button>
                              <button
                                type="button"
                                className="btn btn-outline btn-sm text-danger"
                                style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
                                onClick={() => cancelBooking(b.id)}
                                title="Cancel appointment"
                              >
                                Cancel
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="empty-dash-box">
                    <p>No upcoming appointments scheduled.</p>
                    <Link to="/services" className="btn btn-outline btn-sm">Explore Services</Link>
                  </div>
                )
              )}

              {/* BOOKING HISTORY VIEW */}
              {activeTab === 'history' && (
                pastBookings.length > 0 ? (
                  <div className="appointments-list">
                    {pastBookings.map(b => (
                      <div key={b.id} className="appointment-item">
                        <div className="app-status-indicator">
                          <span className={`badge ${b.status === 'COMPLETED' ? 'badge-success' : 'badge-neutral'}`}>
                            {b.status}
                          </span>
                          <span className="app-booking-id">{b.id}</span>
                        </div>

                        <div className="app-main-details">
                          <h4>{b.serviceName}</h4>
                          <p className="app-provider-line">
                            With <strong>{b.providerName}</strong> ({b.businessName})
                          </p>
                          <div className="app-meta-tags">
                            <span className="tag-pill">
                              <Heart size={12} /> {b.petName}
                            </span>
                            <span className="tag-pill">
                              <Calendar size={12} /> {b.date}
                            </span>
                            <span className="tag-pill">
                              <Clock size={12} /> {b.timeSlot}
                            </span>
                          </div>
                        </div>

                        <div className="app-price-box" style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '0.4rem' }}>
                          <span className="app-price">₹{b.totalPrice.toLocaleString('en-IN')}</span>
                          {b.status === 'COMPLETED' && (
                            isBookingReviewed(b.id) ? (
                              <span className="badge badge-success" style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}>
                                <CheckCircle2 size={12} /> Reviewed
                              </span>
                            ) : (
                              <button
                                type="button"
                                className="btn btn-primary btn-sm"
                                style={{ fontSize: '0.75rem', padding: '0.2rem 0.6rem' }}
                                onClick={() => handleOpenReview(b)}
                              >
                                <Star size={12} /> Leave Review
                              </button>
                            )
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="empty-dash-box">
                    <p>No past or completed bookings recorded yet.</p>
                  </div>
                )
              )}
            </div>

            {/* AI Personalized Recommendations Section */}
            <div className="card dashboard-card ai-recommendations-card">
              <div className="card-header-row">
                <div className="header-with-icon">
                  <Sparkles size={20} className="text-accent" />
                  <div>
                    <h3>AI Recommended for {primaryPet?.name || 'Your Pet'}</h3>
                    <small className="header-subtitle">
                      Curated based on breed ({primaryPet?.breed}), age ({primaryPet?.age} yrs), and seasonal wellness
                    </small>
                  </div>
                </div>
              </div>

              <div className="recs-grid">
                {recommendedServices.map(service => (
                  <div key={service.id} className="rec-mini-card">
                    <img 
                      src={service.image || '/images/services/service-vet-exam.jpg'} 
                      alt={service.name} 
                      className="rec-img"
                      loading="lazy"
                      onError={(e) => { e.target.src = '/images/services/service-vet-exam.jpg'; }}
                    />
                    <div className="rec-info">
                      <span className="rec-cat">{service.categoryName}</span>
                      <h4>{service.name}</h4>
                      <div className="rec-price-row">
                        <span className="rec-price">₹{service.price}</span>
                        <Link to={`/services/${service.id}`} className="btn btn-primary btn-sm">
                          View
                        </Link>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Right: Companions Overview */}
          <div className="dashboard-col-right">
            <div className="card dashboard-card">
              <div className="card-header-row">
                <div className="header-with-icon">
                  <Heart size={20} className="text-accent" />
                  <h3>My Pets ({pets.length})</h3>
                </div>
                <Link to="/pets" className="link-subtle">
                  Manage All <ArrowRight size={14} />
                </Link>
              </div>

              <div className="dash-pets-list">
                {pets.map(p => (
                  <div key={p.id} className="dash-pet-item">
                    <img 
                      src={p.photo || '/images/pets/pet-dog-golden.jpg'} 
                      alt={p.name} 
                      className="dash-pet-avatar"
                      loading="lazy"
                      onError={(e) => { e.target.src = '/images/pets/pet-dog-golden.jpg'; }}
                    />
                    <div className="dash-pet-details">
                      <h4>{p.name}</h4>
                      <span className="dash-pet-breed">{p.type} • {p.breed}</span>
                      <span className="dash-pet-vax">
                        <ShieldCheck size={13} className="text-success" />
                        Vaccines: Up to date
                      </span>
                    </div>
                  </div>
                ))}
              </div>

              <div className="add-pet-cta-wrap">
                <Link to="/pets" className="btn btn-outline btn-sm w-100">
                  <Plus size={16} /> Add Another Pet
                </Link>
              </div>
            </div>

            {/* AI Assistant Shortcut Card */}
            <div className="card ai-shortcut-card">
              <div className="ai-shortcut-header">
                <Sparkles size={24} className="text-accent" />
                <h4>Need Health Advice?</h4>
              </div>
              <p>
                Ask our AI Pet Care Assistant about food allergies, behavioral tricks, or vaccine questions for {primaryPet?.name || 'your pet'}.
              </p>
              <Link to="/ai-assistant" className="btn btn-accent btn-sm">
                Start AI Consultation
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* 1. RESCHEDULE APPOINTMENT MODAL */}
      {/* ==================================================================== */}
      {reschedulingBooking && (
        <div className="modal-backdrop" onClick={() => setReschedulingBooking(null)}>
          <div className="modal-content" style={{ maxWidth: '480px', width: '100%' }} onClick={e => e.stopPropagation()}>
            <button className="modal-close-btn" onClick={() => setReschedulingBooking(null)}>
              <X size={20} />
            </button>
            <div className="modal-header-block" style={{ marginBottom: '1.25rem' }}>
              <h2>Reschedule Appointment</h2>
              <p style={{ color: 'var(--color-text-muted)' }}>
                {reschedulingBooking.serviceName} with {reschedulingBooking.providerName}
              </p>
            </div>

            {rescheduleError && (
              <div className="alert alert-danger" style={{ marginBottom: '1rem' }}>
                <AlertCircle size={18} />
                <span>{rescheduleError}</span>
              </div>
            )}

            <form onSubmit={handleConfirmReschedule}>
              <div className="form-group" style={{ marginBottom: '1rem' }}>
                <label className="form-label">Select New Date *</label>
                <input 
                  type="date"
                  className="form-control"
                  min={new Date().toISOString().split('T')[0]}
                  value={newDate}
                  onChange={e => setNewDate(e.target.value)}
                  required
                />
              </div>

              <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                <label className="form-label">Select Available Slot *</label>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: '0.5rem' }}>
                  {slots.map(s => {
                    const isAvail = checkSlotAvailability(reschedulingBooking.providerId, newDate, s);
                    return (
                      <button
                        key={s}
                        type="button"
                        disabled={!isAvail}
                        className={`slot-chip ${newSlot === s ? 'active' : ''} ${!isAvail ? 'disabled' : ''}`}
                        onClick={() => setNewSlot(s)}
                        style={{ padding: '0.5rem', textAlign: 'center', fontSize: '0.825rem' }}
                      >
                        {s} {!isAvail && '(Booked)'}
                      </button>
                    );
                  })}
                </div>
              </div>

              <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'flex-end' }}>
                <button 
                  type="button" 
                  className="btn btn-outline btn-sm"
                  onClick={() => setReschedulingBooking(null)}
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  className="btn btn-primary btn-sm"
                  disabled={rescheduleSubmitting || !newDate || !newSlot}
                >
                  {rescheduleSubmitting ? 'Rescheduling...' : 'Confirm Reschedule'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ==================================================================== */}
      {/* 2. LEAVE REVIEW MODAL */}
      {/* ==================================================================== */}
      {reviewingBooking && (
        <div className="modal-backdrop" onClick={() => setReviewingBooking(null)}>
          <div className="modal-content" style={{ maxWidth: '500px', width: '100%' }} onClick={e => e.stopPropagation()}>
            <button className="modal-close-btn" onClick={() => setReviewingBooking(null)}>
              <X size={20} />
            </button>
            <div className="modal-header-block" style={{ marginBottom: '1.25rem' }}>
              <h2>Review Your Appointment</h2>
              <p style={{ color: 'var(--color-text-muted)' }}>
                {reviewingBooking.serviceName} • {reviewingBooking.providerName}
              </p>
            </div>

            {reviewError && (
              <div className="alert alert-danger" style={{ marginBottom: '1rem' }}>
                <AlertCircle size={18} />
                <span>{reviewError}</span>
              </div>
            )}

            <form onSubmit={handleConfirmReview}>
              <div className="form-group" style={{ marginBottom: '1rem', textAlign: 'center' }}>
                <label className="form-label" style={{ display: 'block', marginBottom: '0.5rem' }}>
                  Your Rating
                </label>
                <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem' }}>
                  {[1, 2, 3, 4, 5].map(star => (
                    <button
                      key={star}
                      type="button"
                      onClick={() => setReviewRating(star)}
                      style={{
                        background: 'none',
                        border: 'none',
                        cursor: 'pointer',
                        color: star <= reviewRating ? '#f59e0b' : '#cbd5e1',
                        padding: '0.25rem'
                      }}
                    >
                      <Star size={28} fill={star <= reviewRating ? '#f59e0b' : 'none'} />
                    </button>
                  ))}
                </div>
              </div>

              <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                <label className="form-label">Review Feedback *</label>
                <textarea 
                  className="form-control"
                  rows="3"
                  placeholder="Share details of your experience with this specialist..."
                  value={reviewComment}
                  onChange={e => setReviewComment(e.target.value)}
                  required
                />
              </div>

              <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'flex-end' }}>
                <button 
                  type="button" 
                  className="btn btn-outline btn-sm"
                  onClick={() => setReviewingBooking(null)}
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  className="btn btn-primary btn-sm"
                  disabled={reviewSubmitting || !reviewComment.trim()}
                >
                  {reviewSubmitting ? 'Submitting...' : 'Submit Review'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ==================================================================== */}
      {/* 3. EDIT PROFILE MODAL */}
      {/* ==================================================================== */}
      {showProfileModal && (
        <div className="modal-backdrop" onClick={() => setShowProfileModal(false)}>
          <div className="modal-content" style={{ maxWidth: '520px', width: '100%' }} onClick={e => e.stopPropagation()}>
            <button className="modal-close-btn" onClick={() => setShowProfileModal(false)}>
              <X size={20} />
            </button>
            <div className="modal-header-block" style={{ marginBottom: '1.25rem' }}>
              <h2>Edit Personal Profile</h2>
              <p style={{ color: 'var(--color-text-muted)' }}>
                Keep your contact details up to date for clinic appointments.
              </p>
            </div>

            {profileError && (
              <div className="alert alert-danger" style={{ marginBottom: '1rem' }}>
                <AlertCircle size={18} />
                <span>{profileError}</span>
              </div>
            )}

            {profileSuccess && (
              <div className="alert alert-success" style={{ marginBottom: '1rem' }}>
                <CheckCircle2 size={18} />
                <span>{profileSuccess}</span>
              </div>
            )}

            <form onSubmit={handleSaveProfile}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1.25rem' }}>
                <img 
                  src={profileAvatar || '/images/testimonials/user-kavita.jpg'} 
                  alt="Avatar Preview" 
                  style={{ width: '64px', height: '64px', borderRadius: '50%', objectFit: 'cover', border: '2px solid var(--color-primary)' }}
                  onError={(e) => { e.target.src = '/images/testimonials/user-kavita.jpg'; }}
                />
                <div>
                  <label className="btn btn-outline btn-sm" style={{ cursor: 'pointer' }}>
                    <Upload size={14} /> {uploadingAvatar ? 'Uploading...' : 'Upload Photo'}
                    <input 
                      type="file" 
                      accept="image/*" 
                      style={{ display: 'none' }}
                      onChange={handleAvatarUpload}
                      disabled={uploadingAvatar}
                    />
                  </label>
                  <small style={{ display: 'block', color: 'var(--color-text-muted)', marginTop: '0.25rem' }}>
                    JPG, PNG or WebP up to 5MB
                  </small>
                </div>
              </div>

              <div className="form-group" style={{ marginBottom: '1rem' }}>
                <label className="form-label">Full Name *</label>
                <input 
                  type="text" 
                  className="form-control"
                  value={profileName}
                  onChange={e => setProfileName(e.target.value)}
                  required
                />
              </div>

              <div className="form-row-2" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1.25rem' }}>
                <div className="form-group">
                  <label className="form-label">Phone Number</label>
                  <input 
                    type="tel" 
                    className="form-control"
                    value={profilePhone}
                    onChange={e => setProfilePhone(e.target.value)}
                    placeholder="+91 98765 43210"
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">City</label>
                  <input 
                    type="text" 
                    className="form-control"
                    value={profileCity}
                    onChange={e => setProfileCity(e.target.value)}
                    placeholder="Bengaluru"
                  />
                </div>
              </div>

              <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'flex-end' }}>
                <button 
                  type="button" 
                  className="btn btn-outline btn-sm"
                  onClick={() => setShowProfileModal(false)}
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  className="btn btn-primary btn-sm"
                  disabled={profileSaving || uploadingAvatar}
                >
                  {profileSaving ? 'Saving...' : 'Save Profile'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default OwnerDashboardPage;
