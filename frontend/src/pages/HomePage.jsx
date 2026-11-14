import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMarketplace } from '../context/MarketplaceContext';
import { CATEGORIES, PROVIDERS, SAMPLE_REVIEWS, CITIES } from '../services/mockData';
import ServiceCard from '../components/ServiceCard';
import BookingModal from '../components/BookingModal';
import { 
  Search, 
  MapPin, 
  Sparkles, 
  ShieldCheck, 
  Clock, 
  Award, 
  ArrowRight, 
  Heart, 
  Star, 
  CheckCircle2, 
  Smile, 
  Users, 
  PhoneCall,
  Stethoscope,
  Scissors,
  Check
} from 'lucide-react';
import './HomePage.css';

const HomePage = () => {
  const { services, reviews } = useMarketplace();
  const navigate = useNavigate();

  // Search state
  const [selectedCity, setSelectedCity] = useState('All Cities');
  const [searchKeyword, setSearchKeyword] = useState('');

  // Booking modal state
  const [selectedServiceForBooking, setSelectedServiceForBooking] = useState(null);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    const params = new URLSearchParams();
    if (selectedCity && selectedCity !== 'All Cities') params.set('city', selectedCity);
    if (searchKeyword.trim()) params.set('q', searchKeyword.trim());
    navigate(`/services?${params.toString()}`);
  };

  const featuredServices = services.filter(s => s.featured).slice(0, 3);

  return (
    <div className="home-page">
      {/* 1. HERO SECTION */}
      <section className="hero-section">
        {/* Subtle decorative background blur blurs */}
        <div className="hero-bg-glow hero-glow-1"></div>
        <div className="hero-bg-glow hero-glow-2"></div>

        <div className="container hero-container">
          <div className="hero-content">
            <div className="hero-pill-badge">
              <span className="dot-pulse"></span>
              <span>India's Most Trusted Pet Wellness Network</span>
            </div>

            <h1 className="hero-title">
              Everything Your Pet Needs, <span className="highlight-text">All in One Place.</span>
            </h1>

            <p className="hero-subtitle">
              Connect with background-verified veterinary clinics, master groomers, luxury resort boarders, and canine behaviorists. Powered by 24/7 intelligent AI wellness triage.
            </p>

            {/* Quick Search & Location Bar */}
            <form onSubmit={handleSearchSubmit} className="hero-search-bar">
              <div className="search-input-group city-select-group">
                <MapPin size={18} className="search-icon" />
                <div className="search-field-wrap">
                  <span className="search-field-label">Location</span>
                  <select 
                    className="search-select"
                    value={selectedCity}
                    onChange={(e) => setSelectedCity(e.target.value)}
                  >
                    {CITIES.map(c => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="search-divider"></div>

              <div className="search-input-group flex-2">
                <Search size={18} className="search-icon" />
                <div className="search-field-wrap">
                  <span className="search-field-label">Service or Specialty</span>
                  <input 
                    type="text"
                    placeholder="E.g., Veterinary exam, grooming bath, puppy training..."
                    value={searchKeyword}
                    onChange={(e) => setSearchKeyword(e.target.value)}
                    className="search-field"
                  />
                </div>
              </div>

              <button type="submit" className="btn btn-primary search-submit-btn">
                <span>Find Services</span>
                <ArrowRight size={16} className="btn-arrow" />
              </button>
            </form>

            {/* Social Trust Metrics with Avatar Stack */}
            <div className="hero-trust-metrics">
              <div className="trust-avatars-stack">
                <img src="https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=120&q=80" alt="Pet Parent" className="trust-avatar" />
                <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=120&q=80" alt="Pet Parent" className="trust-avatar" />
                <img src="https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=120&q=80" alt="Pet Parent" className="trust-avatar" />
                <img src="https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=120&q=80" alt="Pet Parent" className="trust-avatar" />
              </div>

              <div className="trust-rating-block">
                <div className="trust-stars">
                  <Star size={15} className="star-gold" />
                  <Star size={15} className="star-gold" />
                  <Star size={15} className="star-gold" />
                  <Star size={15} className="star-gold" />
                  <Star size={15} className="star-gold" />
                  <strong className="trust-score">4.9/5</strong>
                </div>
                <span className="trust-caption">Over <strong>3,200+ happy pets</strong> served</span>
              </div>

              <div className="trust-divider-vertical"></div>

              <div className="trust-verified-pill">
                <ShieldCheck size={18} className="trust-shield-icon" />
                <span>100% Verified Specialists</span>
              </div>
            </div>
          </div>

          {/* Hero Visual Image */}
          <div className="hero-visual">
            <div className="hero-img-frame">
              <img 
                src="https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&w=800&q=80" 
                alt="Happy playful dog and kitten in green field" 
                className="hero-main-img" 
              />
              
              {/* Floating Hero Badges */}
              <div className="floating-badge top-right">
                <div className="badge-icon-wrap bg-terracotta">
                  <Sparkles size={18} />
                </div>
                <div>
                  <strong>AI Pet Assistant</strong>
                  <small>Instant diet & health advice</small>
                </div>
              </div>

              <div className="floating-badge bottom-left">
                <div className="badge-icon-wrap bg-sage">
                  <ShieldCheck size={18} />
                </div>
                <div>
                  <strong>Certified Doctors</strong>
                  <small>Registered clinical vet pros</small>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 2. POPULAR SERVICE CATEGORIES */}
      <section className="section categories-section">
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Explore Specialties</span>
            <h2 className="section-title">Popular Pet Care Categories</h2>
            <p className="section-subtitle">
              From routine clinical exams and luxurious coat spas to daily fitness walks and compassionate in-home pet sitting.
            </p>
          </div>

          <div className="categories-grid">
            {CATEGORIES.map(cat => (
              <Link 
                to={`/services?cat=${cat.id}`} 
                key={cat.id} 
                className="category-card card card-interactive"
              >
                <div className="cat-img-box">
                  <img src={cat.image} alt={cat.name} className="cat-thumbnail" />
                  <span className="cat-count-pill">{cat.count}</span>
                  <div className="cat-overlay"></div>
                </div>
                <div className="cat-info">
                  <h3 className="cat-title">{cat.name}</h3>
                  <p className="cat-desc">{cat.description}</p>
                  <span className="cat-link-text">
                    Browse Services <ArrowRight size={14} className="cat-arrow" />
                  </span>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* 3. FEATURED SERVICES MARKETPLACE PREVIEW */}
      <section className="section featured-services-section">
        <div className="container">
          <div className="section-header-row">
            <div>
              <span className="section-tag">Handpicked Specialists</span>
              <h2 className="section-title">Top-Rated Services Near You</h2>
              <p className="section-subtitle">
                Reserve real-time appointment slots with certified clinics, stylists, and boarding resorts.
              </p>
            </div>
            <Link to="/services" className="btn btn-outline view-all-btn">
              View All Services ({services.length})
              <ArrowRight size={16} />
            </Link>
          </div>

          <div className="services-grid">
            {featuredServices.map(service => (
              <ServiceCard 
                key={service.id} 
                service={service} 
                onBookNow={(s) => setSelectedServiceForBooking(s)}
              />
            ))}
          </div>
        </div>
      </section>

      {/* 4. AI PET CARE ASSISTANT PROMOTIONAL BANNER */}
      <section className="ai-promo-section">
        <div className="container ai-promo-container">
          <div className="ai-promo-content">
            <div className="ai-tag">
              <Sparkles size={16} />
              <span>AI-Powered Wellness Triage</span>
            </div>
            <h2>Meet Your 24/7 AI Pet Care Assistant</h2>
            <p>
              Got questions about sudden food allergies, puppy teething, coat grooming frequency, or core vaccine timelines? Chat with our intelligent assistant calibrated with strict veterinary safety guardrails.
            </p>

            <div className="ai-feature-checklist">
              <div className="check-item">
                <div className="check-circle-icon"><Check size={14} /></div>
                <span>Personalized guidance using your pet's breed, age & weight</span>
              </div>
              <div className="check-item">
                <div className="check-circle-icon"><Check size={14} /></div>
                <span>Nutrition & diet advice for sensitive stomachs</span>
              </div>
              <div className="check-item">
                <div className="check-circle-icon"><Check size={14} /></div>
                <span>Emergency symptom triage with instant emergency clinic referrals</span>
              </div>
            </div>

            <div className="ai-cta-group">
              <Link to="/ai-assistant" className="btn btn-accent btn-lg">
                <Sparkles size={18} />
                Try AI Assistant Now
              </Link>
              <span className="ai-free-badge">✓ 100% Free for Pet Parents</span>
            </div>
          </div>

          <div className="ai-promo-mockup card">
            <div className="mockup-header">
              <div className="mockup-header-title">
                <Sparkles size={16} className="text-accent" />
                <strong>PetCare Assistant</strong>
              </div>
              <span className="mockup-status-dot">Online</span>
            </div>

            <div className="mockup-chat-stream">
              <div className="chat-bubble user-bubble">
                "My 3-year-old Golden Retriever Bruno suddenly skipped his morning breakfast. Should I worry?"
              </div>
              <div className="chat-bubble ai-bubble">
                <div className="ai-bubble-sender">
                  <Sparkles size={14} /> PetCare Clinical Triage
                </div>
                "For an adult Golden Retriever like Bruno, a single skipped meal isn't alarming if he remains energetic and hydrated. Check if he drank fresh water and has normal gums. If lethargy, vomiting, or breathing distress appear, consult a licensed vet immediately."
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 5. HOW IT WORKS */}
      <section className="section how-it-works-section">
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Seamless Booking Flow</span>
            <h2 className="section-title">How PetCare Works</h2>
            <p className="section-subtitle">
              We make scheduling verified pet wellness services transparent, conflict-free, and effortless.
            </p>
          </div>

          <div className="steps-grid">
            <div className="step-card card">
              <div className="step-number-wrap">01</div>
              <h3>Discover & Filter</h3>
              <p>
                Browse verified vets, luxury spas, and boarding resorts. Filter by your city, price range, and peer ratings.
              </p>
            </div>

            <div className="step-card card">
              <div className="step-number-wrap">02</div>
              <h3>Select Pet & Schedule</h3>
              <p>
                Choose your companion's profile, pick an available real-time appointment slot, and leave custom clinical notes.
              </p>
            </div>

            <div className="step-card card">
              <div className="step-number-wrap">03</div>
              <h3>Relax & Review</h3>
              <p>
                Receive live status updates, enjoy compassionate care for your pet, and share your review with the community.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* 6. WHY CHOOSE US */}
      <section className="section why-choose-section">
        <div className="container">
          <div className="section-header">
            <span className="section-tag">The PetCare Advantage</span>
            <h2 className="section-title">Why 20,000+ Pet Parents Rely On Us</h2>
          </div>

          <div className="features-quad-grid">
            <div className="feature-item card">
              <div className="feature-icon-box bg-sage">
                <ShieldCheck size={26} />
              </div>
              <h4>Rigorous Specialist Vetting</h4>
              <p>Every veterinary license, grooming certificate, and boarding facility is thoroughly vetted by our compliance team.</p>
            </div>

            <div className="feature-item card">
              <div className="feature-icon-box bg-terracotta">
                <Clock size={26} />
              </div>
              <h4>Zero Conflicting Slots</h4>
              <p>Real-time slot reservation guarantees no overbooking and minimal waiting times at clinics and salons.</p>
            </div>

            <div className="feature-item card">
              <div className="feature-icon-box bg-sage">
                <Sparkles size={26} />
              </div>
              <h4>AI-Powered Health Triage</h4>
              <p>Smart pre-consultation summaries help identify symptoms early and match you to the right specialty provider.</p>
            </div>

            <div className="feature-item card">
              <div className="feature-icon-box bg-terracotta">
                <PhoneCall size={26} />
              </div>
              <h4>Emergency Pet Taxi Support</h4>
              <p>Access prioritized transport equipped with oxygen and animal stretchers for urgent clinic transfers.</p>
            </div>
          </div>
        </div>
      </section>

      {/* 7. CUSTOMER TESTIMONIALS */}
      <section className="section testimonials-section">
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Verified Stories</span>
            <h2 className="section-title">Loved by Pets, Trusted by Owners</h2>
          </div>

          <div className="testimonials-grid">
            {(reviews && reviews.length > 0 ? reviews.slice(0, 3) : SAMPLE_REVIEWS).map(rev => (
              <div key={rev.id} className="testimonial-card card">
                <div className="testimonial-stars">
                  {[...Array(rev.rating || 5)].map((_, i) => (
                    <Star key={i} size={16} className="star-gold" />
                  ))}
                </div>
                <p className="testimonial-text">"{rev.comment || rev.review}"</p>
                <div className="testimonial-author">
                  <div className="author-avatar-placeholder">
                    {(rev.userName || 'P')[0]}
                  </div>
                  <div>
                    <strong>{rev.userName || 'Verified Parent'}</strong>
                    <span>{rev.userCity || 'Bengaluru'} • Booked with {rev.providerName || 'Specialist'}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 8. CALL TO ACTION BANNER */}
      <section className="cta-banner-section">
        <div className="container cta-container card">
          <div className="cta-content">
            <h2>Ready to give your furry companion the royal care they deserve?</h2>
            <p>Join thousands of loving pet parents across Bengaluru, Mumbai, Delhi NCR, and Hyderabad.</p>
            <div className="cta-btn-wrap">
              <Link to="/services" className="btn btn-accent btn-lg">
                Explore All Services
              </Link>
              <Link to="/register" className="btn btn-outline-white btn-lg">
                Register as Provider
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Booking Modal Popup */}
      {selectedServiceForBooking && (
        <BookingModal 
          service={selectedServiceForBooking} 
          onClose={() => setSelectedServiceForBooking(null)}
          onBookingSuccess={() => {}}
        />
      )}
    </div>
  );
};

export default HomePage;
