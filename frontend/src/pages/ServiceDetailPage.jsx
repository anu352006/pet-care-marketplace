import React, { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useMarketplace } from '../context/MarketplaceContext';
import { useAuth } from '../context/AuthContext';
import BookingModal from '../components/BookingModal';
import { 
  Star, 
  MapPin, 
  Clock, 
  ShieldCheck, 
  CheckCircle2, 
  User, 
  Phone, 
  Mail, 
  Calendar, 
  ArrowLeft,
  MessageSquare
} from 'lucide-react';
import './ServiceDetailPage.css';

const ServiceDetailPage = () => {
  const { id } = useParams();
  const { services, providers, reviews, addReview, loading } = useMarketplace();
  const { user } = useAuth();

  const service = services.find(s => String(s.id) === String(id)) || (!loading ? services[0] : null);
  const provider = providers.find(p => String(p.id) === String(service?.providerId)) || providers[0];

  // Reviews for this service
  const serviceReviews = reviews.filter(r => 
    String(r.serviceId) === String(service?.id) || 
    r.serviceName === service?.name || 
    r.providerName === service?.providerName
  );

  // Booking modal
  const [showBookingModal, setShowBookingModal] = useState(false);

  // Review submission state
  const [newRating, setNewRating] = useState(5);
  const [newComment, setNewComment] = useState('');
  const [reviewSubmitted, setReviewSubmitted] = useState(false);
  const [reviewError, setReviewError] = useState('');

  const handleReviewSubmit = async (e) => {
    e.preventDefault();
    if (!newComment.trim()) return;
    setReviewError('');

    try {
      await addReview({
        serviceId: service.id,
        serviceName: service.name,
        providerId: service.providerId,
        providerName: service.providerName,
        userName: user ? user.name : 'Verified Pet Parent',
        userCity: user?.city || 'Bengaluru',
        rating: Number(newRating),
        comment: newComment.trim()
      });

      setNewComment('');
      setReviewSubmitted(true);
      setTimeout(() => setReviewSubmitted(false), 4000);
    } catch (err) {
      setReviewError(err.message || 'Failed to submit review.');
    }
  };

  if (loading && !service) {
    return (
      <div className="container section text-center" style={{ padding: '6rem 1rem' }}>
        <p>Loading service details from Supabase...</p>
      </div>
    );
  }

  if (!service) {
    return (
      <div className="container section text-center">
        <h2>Service Not Found</h2>
        <Link to="/services" className="btn btn-primary">Back to Catalog</Link>
      </div>
    );
  }

  return (
    <div className="service-detail-page section">
      <div className="container">
        {/* Breadcrumb Back */}
        <Link to="/services" className="back-link">
          <ArrowLeft size={16} />
          <span>Back to All Services</span>
        </Link>

        <div className="detail-grid">
          {/* Main Service Content */}
          <div className="detail-main-col">
            <div className="detail-hero-card card">
              <div className="detail-img-box">
                <img 
                  src={service.image || '/images/services/service-vet-exam.jpg'} 
                  alt={service.name} 
                  className="detail-main-img" 
                  onError={(e) => { e.target.src = '/images/services/service-vet-exam.jpg'; }}
                />
                <span className="badge badge-primary detail-cat-badge">{service.categoryName}</span>
              </div>

              <div className="detail-content-wrap">
                <div className="detail-header-meta">
                  <div className="rating-pill">
                    <Star size={18} className="star-fill" />
                    <strong>{service.rating}</strong>
                    <span>({service.reviewsCount} customer reviews)</span>
                  </div>
                  <div className="duration-pill">
                    <Clock size={16} />
                    <span>Duration: {service.duration}</span>
                  </div>
                </div>

                <h1 className="detail-title">{service.name}</h1>
                <p className="detail-description">{service.description}</p>

                {/* What's Included */}
                {service.included && service.included.length > 0 && (
                  <div className="included-section">
                    <h3>What is Included in This Service:</h3>
                    <div className="included-list">
                      {service.included.map((item, idx) => (
                        <div key={idx} className="included-item">
                          <CheckCircle2 size={18} className="check-icon" />
                          <span>{item}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Provider Spotlight */}
            <div className="provider-spotlight-card card">
              <div className="provider-card-header">
                <img 
                  src={provider.avatar || '/images/providers/provider-aarav.jpg'} 
                  alt={provider.name} 
                  className="provider-avatar-lg" 
                  onError={(e) => { e.target.src = '/images/providers/provider-aarav.jpg'; }}
                />
                <div>
                  <div className="provider-name-row">
                    <h3>{provider.name}</h3>
                    {provider.verified && (
                      <span className="verified-badge-pill" title="Verified PetCare Specialist">
                        <ShieldCheck size={14} /> Verified Specialist
                      </span>
                    )}
                  </div>
                  <p className="provider-business-sub">{provider.businessName}</p>
                  <div className="provider-loc-meta">
                    <MapPin size={15} />
                    <span>{provider.address}</span>
                  </div>
                </div>
              </div>

              <p className="provider-bio-text">{provider.bio}</p>

              <div className="provider-stats-strip">
                <div className="stat-box">
                  <strong>{provider.experienceYears}+ Years</strong>
                  <span>Clinical Experience</span>
                </div>
                <div className="stat-box">
                  <strong>{provider.rating} ★</strong>
                  <span>Provider Rating</span>
                </div>
                <div className="stat-box">
                  <strong>{provider.servicesCount} Active</strong>
                  <span>Service Offerings</span>
                </div>
              </div>
            </div>

            {/* Ratings & Reviews Section */}
            <div className="reviews-section-card card">
              <div className="reviews-section-header">
                <div>
                  <h3>Customer Reviews & Experiences</h3>
                  <p className="subtitle">Real feedback from verified pet parents</p>
                </div>
                <div className="avg-rating-badge">
                  <Star size={20} className="star-fill" />
                  <span>{service.rating} / 5</span>
                </div>
              </div>

              {/* Review Submission Form */}
              <form onSubmit={handleReviewSubmit} className="add-review-form">
                <h4>Share Your Experience</h4>
                {reviewSubmitted && (
                  <div className="alert alert-success">
                    Thank you! Your verified review has been published.
                  </div>
                )}
                <div className="form-group">
                  <label className="form-label">Your Rating:</label>
                  <select 
                    className="form-control rating-select"
                    value={newRating}
                    onChange={e => setNewRating(e.target.value)}
                  >
                    <option value="5">★★★★★ (5 - Excellent)</option>
                    <option value="4">★★★★☆ (4 - Very Good)</option>
                    <option value="3">★★★☆☆ (3 - Good)</option>
                    <option value="2">★★☆☆☆ (2 - Fair)</option>
                    <option value="1">★☆☆☆☆ (1 - Poor)</option>
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label">Your Review & Comments:</label>
                  <textarea 
                    className="form-control"
                    rows="3"
                    placeholder="How did your pet respond? Was the specialist gentle, punctual, and knowledgeable?"
                    value={newComment}
                    onChange={e => setNewComment(e.target.value)}
                    required
                  />
                </div>
                <button type="submit" className="btn btn-outline btn-sm">
                  <MessageSquare size={16} /> Submit Review
                </button>
              </form>

              {/* Reviews List */}
              <div className="reviews-stream">
                {serviceReviews.length > 0 ? (
                  serviceReviews.map(r => (
                    <div key={r.id} className="review-stream-item">
                      <div className="review-stream-top">
                        <div className="review-author-meta">
                          <img 
                            src={r.userAvatar || `/images/testimonials/user-${((r.id || 1) % 4) + 1}.jpg`} 
                            alt={r.userName} 
                            className="author-avatar-sm-img"
                            onError={(e) => { e.target.src = '/images/testimonials/user-kavita.jpg'; }}
                          />
                          <div>
                            <strong>{r.userName}</strong>
                            <span className="author-city">{r.userCity}</span>
                          </div>
                        </div>
                        <div className="review-date-rating">
                          <div className="stars-row">
                            {[...Array(r.rating)].map((_, i) => (
                              <Star key={i} size={14} className="star-fill" />
                            ))}
                          </div>
                          <span className="review-date-text">{r.date}</span>
                        </div>
                      </div>
                      <p className="review-stream-comment">"{r.comment}"</p>
                    </div>
                  ))
                ) : (
                  <p className="no-reviews-note">No reviews for this specific service yet. Be the first to share your experience!</p>
                )}
              </div>
            </div>
          </div>

          {/* Sticky Booking Action Card */}
          <div className="detail-sidebar-col">
            <div className="booking-action-card card">
              <div className="pricing-box">
                <span className="price-label">Transparent Price</span>
                <div className="main-price">
                  <span className="curr">₹</span>
                  <span className="num">{service.price.toLocaleString('en-IN')}</span>
                </div>
                <span className="unit-label">{service.priceUnit}</span>
              </div>

              <div className="slot-peek-box">
                <div className="slot-peek-title">
                  <Calendar size={16} />
                  <span>Available Next Slots:</span>
                </div>
                <div className="slot-chips-preview">
                  {service.availableSlots?.slice(0, 4).map(s => (
                    <span key={s} className="slot-chip-preview">{s}</span>
                  ))}
                </div>
              </div>

              <button 
                className="btn btn-primary btn-lg book-sticky-btn"
                onClick={() => setShowBookingModal(true)}
              >
                Book Appointment Now
              </button>

              <div className="reassurance-list">
                <div className="reassurance-item">
                  <ShieldCheck size={16} className="text-success" />
                  <span>Zero pre-cancellation penalties</span>
                </div>
                <div className="reassurance-item">
                  <Clock size={16} className="text-success" />
                  <span>Instant SMS & Email confirmation</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Booking Modal */}
      {showBookingModal && (
        <BookingModal 
          service={service} 
          onClose={() => setShowBookingModal(false)}
          onBookingSuccess={() => {}}
        />
      )}
    </div>
  );
};

export default ServiceDetailPage;
