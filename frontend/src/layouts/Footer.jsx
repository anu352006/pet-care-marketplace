import React from 'react';
import { Link } from 'react-router-dom';
import { Heart, Sparkles, ShieldCheck, Mail, Phone, MapPin } from 'lucide-react';
import './Footer.css';

const Footer = () => {
  return (
    <footer className="main-footer">
      <div className="container footer-content">
        <div className="footer-grid">
          {/* Brand & Mission */}
          <div className="footer-col brand-col">
            <div className="footer-brand">
              <div className="logo-icon-wrap small">
                <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
                  <circle cx="11" cy="4" r="2" fill="#E07A5F" />
                  <circle cx="18" cy="8" r="2" fill="#E07A5F" />
                  <circle cx="20" cy="16" r="2" fill="#E07A5F" />
                  <path d="M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.045Q6.52 17.48 4.46 16.84A3.5 3.5 0 0 1 5.5 10Z" fill="#FFFFFF" />
                </svg>
              </div>
              <span className="footer-brand-title">PetCare</span>
            </div>
            <p className="footer-desc">
              India's premium tech-enabled pet care ecosystem connecting responsible pet parents with verified veterinarians, master groomers, luxury boarding resorts, and AI wellness advisors.
            </p>
            <div className="security-badge">
              <ShieldCheck size={18} className="shield-icon" />
              <span>100% Background-Verified Service Specialists</span>
            </div>
          </div>

          {/* Service Categories */}
          <div className="footer-col">
            <h4 className="footer-heading">Services</h4>
            <ul className="footer-links">
              <li><Link to="/services?cat=vet">Veterinary Consultation</Link></li>
              <li><Link to="/services?cat=grooming">Pet Grooming & Spa</Link></li>
              <li><Link to="/services?cat=boarding">Pet Boarding & Resorts</Link></li>
              <li><Link to="/services?cat=walking">Dog Walking & Exercise</Link></li>
              <li><Link to="/services?cat=training">Behavioral Training</Link></li>
              <li><Link to="/services?cat=taxi">Pet Ambulance & Taxi</Link></li>
            </ul>
          </div>

          {/* Quick Platform Links */}
          <div className="footer-col">
            <h4 className="footer-heading">Platform</h4>
            <ul className="footer-links">
              <li><Link to="/">Home Marketplace</Link></li>
              <li><Link to="/ai-assistant">AI Pet Care Assistant</Link></li>
              <li><Link to="/about">About Us & Quality Standards</Link></li>
              <li><Link to="/contact">Contact Support</Link></li>
              <li><Link to="/register">Become a Service Provider</Link></li>
              <li><Link to="/login">Account Sign In</Link></li>
            </ul>
          </div>

          {/* Cities & Contact */}
          <div className="footer-col">
            <h4 className="footer-heading">Coverage & Help</h4>
            <div className="city-tags">
              <span className="city-pill">Bengaluru</span>
              <span className="city-pill">Mumbai</span>
              <span className="city-pill">Delhi NCR</span>
              <span className="city-pill">Hyderabad</span>
              <span className="city-pill">Pune</span>
              <span className="city-pill">Chennai</span>
            </div>
            <div className="footer-contact-items">
              <div className="contact-line">
                <Mail size={16} />
                <span>support@petcaremarketplace.com</span>
              </div>
              <div className="contact-line">
                <Phone size={16} />
                <span>+91 (080) 4567-8900</span>
              </div>
              <div className="contact-line">
                <MapPin size={16} />
                <span>Indiranagar, Bengaluru, KA 560038</span>
              </div>
            </div>
          </div>
        </div>

        {/* Veterinary Safety Disclaimer */}
        <div className="safety-disclaimer-card">
          <strong>Veterinary & Medical Advisory Disclaimer:</strong>
          <p>
            The PetCare platform and our AI Pet Care Assistant provide wellness, dietary, and general pet companionship information for educational purposes. Our assistant does not diagnose illnesses or prescribe veterinary drugs. In case of trauma, intoxication, breathing distress, or acute symptoms, always transport your pet directly to a licensed veterinary hospital immediately.
          </p>
        </div>

        {/* Bottom Bar */}
        <div className="footer-bottom">
          <p className="copyright-text">
            © {new Date().getFullYear()} PetCare & Services Marketplace. Developed for Master Program in AI Full Stack Development.
          </p>
          <div className="academic-tag">
            <Heart size={14} className="heart-icon" /> Built with ReactJS, Java 21, Spring Boot & MySQL
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
