import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useMarketplace } from '../context/MarketplaceContext';
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
  Stethoscope
} from 'lucide-react';
import './OwnerDashboardPage.css';

const OwnerDashboardPage = () => {
  const { user } = useAuth();
  const { pets, bookings, getPersonalizedRecommendations, cancelBooking } = useMarketplace();

  // Active bookings
  const upcomingBookings = bookings.filter(b => b.status === 'CONFIRMED' || b.status === 'PENDING');
  const pastBookings = bookings.filter(b => b.status === 'COMPLETED' || b.status === 'CANCELLED');

  // AI recommendations for primary pet
  const primaryPet = pets[0];
  const recommendedServices = getPersonalizedRecommendations(primaryPet?.id);

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
              <strong className="metric-val">{pastBookings.length}</strong>
            </div>
          </div>
        </div>

        {/* Main Dashboard Row: Appointments + Pet Profiles */}
        <div className="dashboard-two-cols">
          {/* Left: Bookings Schedule */}
          <div className="dashboard-col-left">
            <div className="card dashboard-card">
              <div className="card-header-row">
                <div className="header-with-icon">
                  <Calendar size={20} className="text-primary" />
                  <h3>Upcoming Appointments ({upcomingBookings.length})</h3>
                </div>
                <Link to="/services" className="link-subtle">
                  Book New Slot <ArrowRight size={14} />
                </Link>
              </div>

              {upcomingBookings.length > 0 ? (
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
                          <button
                            type="button"
                            className="btn btn-outline btn-sm text-danger"
                            style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
                            onClick={() => cancelBooking(b.id)}
                            title="Cancel appointment"
                          >
                            Cancel Slot
                          </button>
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
    </div>
  );
};

export default OwnerDashboardPage;
