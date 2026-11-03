import React from 'react';
import { Link } from 'react-router-dom';
import { Star, MapPin, Clock, Calendar, CheckCircle, ArrowRight, ShieldCheck } from 'lucide-react';
import './ServiceCard.css';

const ServiceCard = ({ service, onBookNow }) => {
  return (
    <div className="service-card card">
      {/* Service Image Banner with Badge Overlay */}
      <div className="service-img-container">
        <img src={service.image} alt={service.name} className="service-card-img" />
        <div className="service-img-vignette"></div>
        <span className="category-pill-badge">{service.categoryName}</span>
        {service.featured && <span className="featured-pill-badge">Popular Choice</span>}
      </div>

      <div className="service-card-body">
        {/* Rating and Duration */}
        <div className="service-meta-top">
          <div className="rating-pill">
            <Star size={14} className="star-fill" />
            <span className="rating-score">{service.rating}</span>
            <span className="reviews-num">({service.reviewsCount})</span>
          </div>
          <div className="duration-pill">
            <Clock size={13} />
            <span>{service.duration}</span>
          </div>
        </div>

        {/* Service Title */}
        <h3 className="service-card-title">
          <Link to={`/services/${service.id}`}>{service.name}</Link>
        </h3>

        {/* Short Description */}
        <p className="service-card-desc">{service.description}</p>

        {/* Provider Details Strip */}
        <div className="provider-info-strip">
          <div className="provider-name-box">
            <span className="provider-label">Provider</span>
            <div className="provider-name-line">
              <strong className="provider-name">{service.providerName}</strong>
              <ShieldCheck size={14} className="verified-icon" title="Verified Specialist" />
            </div>
          </div>
          <div className="provider-loc-box">
            <MapPin size={13} />
            <span>{service.area}, {service.city}</span>
          </div>
        </div>

        {/* Price & Actions Footer */}
        <div className="service-card-footer">
          <div className="price-tag-wrap">
            <span className="price-from">Starting at</span>
            <div className="price-val">
              <span className="currency">₹</span>
              <span className="amount">{service.price.toLocaleString('en-IN')}</span>
            </div>
            <span className="price-unit">{service.priceUnit}</span>
          </div>

          <div className="card-btn-group">
            <Link to={`/services/${service.id}`} className="btn btn-outline btn-sm">
              Details
            </Link>
            <button 
              className="btn btn-primary btn-sm"
              onClick={() => onBookNow(service)}
            >
              Book Now
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ServiceCard;
