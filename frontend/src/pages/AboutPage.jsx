import React from 'react';
import { Link } from 'react-router-dom';
import { ShieldCheck, Heart, Sparkles, Award, Users, CheckCircle } from 'lucide-react';
import './AboutPage.css';

const AboutPage = () => {
  return (
    <div className="about-page section">
      <div className="container">
        {/* Hero Header */}
        <div className="about-hero-card card">
          <span className="section-tag">Our Mission & Standards</span>
          <h1 className="about-title">Elevating the Standard of Pet Care in India</h1>
          <p className="about-lead">
            PetCare was conceptualized to bridge the gap between discerning pet parents and qualified, ethical veterinary specialists, master groomers, and safe boarding sanctuaries.
          </p>
        </div>

        {/* Pillars Grid */}
        <div className="pillars-grid">
          <div className="pillar-item card">
            <div className="pillar-icon bg-sage">
              <ShieldCheck size={28} />
            </div>
            <h3>100% Verified Credentials</h3>
            <p>Every veterinary practitioner on PetCare holds registered veterinary council certification, and every boarding facility undergoes on-site sanitary inspections.</p>
          </div>

          <div className="pillar-item card">
            <div className="pillar-icon bg-terracotta">
              <Sparkles size={28} />
            </div>
            <h3>AI-Assisted Wellness</h3>
            <p>Our intelligent pet care assistant synthesizes veterinary research to give parents instant guidance on diet, teething, vaccinations, and non-emergency symptom triage.</p>
          </div>

          <div className="pillar-item card">
            <div className="pillar-icon bg-sage">
              <Heart size={28} />
            </div>
            <h3>Pet-First Ethics</h3>
            <p>We advocate for fear-free clinical handling, positive-reinforcement behavior modification, and cage-free luxury boarding environments.</p>
          </div>
        </div>

        {/* Platform Architecture Overview */}
        <div className="academic-arch-card card">
          <div className="arch-header">
            <span className="badge badge-primary">Technical Architecture</span>
            <h2>Full-Stack System Design</h2>
            <p>Designed and engineered for Master Program in AI Full Stack Development.</p>
          </div>

          <div className="arch-specs-grid">
            <div className="arch-spec-item">
              <strong>Frontend Engineering</strong>
              <p>ReactJS, Vite, React Router v6, Responsive CSS3 Grid & Flexbox, Lucide Iconography, Context-Driven State.</p>
            </div>
            <div className="arch-spec-item">
              <strong>Backend Architecture</strong>
              <p>Java 21, Spring Boot 3, Spring Web, Spring Data JPA, Hibernate ORM, Spring Security with JWT tokens, Maven.</p>
            </div>
            <div className="arch-spec-item">
              <strong>Relational Persistence</strong>
              <p>MySQL 8.0, normalized schema across 9 relational tables, constraints, foreign keys, and indexes.</p>
            </div>
            <div className="arch-spec-item">
              <strong>AI Integration</strong>
              <p>Backend-orchestrated AI Assistant with clinical triage safety guardrails and rule-based service recommendation engine.</p>
            </div>
          </div>
        </div>

        {/* CTA */}
        <div className="about-cta-strip text-center">
          <h3>Experience the PetCare Difference</h3>
          <div className="cta-buttons">
            <Link to="/services" className="btn btn-primary btn-lg">Browse Services</Link>
            <Link to="/contact" className="btn btn-outline btn-lg">Contact Support</Link>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AboutPage;
