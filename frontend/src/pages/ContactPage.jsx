import React, { useState } from 'react';
import { Mail, Phone, MapPin, Send, CheckCircle, Clock } from 'lucide-react';
import './ContactPage.css';

const ContactPage = () => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [subject, setSubject] = useState('General Inquiry');
  const [message, setMessage] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    setSubmitted(true);
    setTimeout(() => {
      setName('');
      setEmail('');
      setMessage('');
      setSubmitted(false);
    }, 4000);
  };

  return (
    <div className="contact-page section">
      <div className="container">
        <div className="contact-layout">
          {/* Contact Details Left Col */}
          <div className="contact-info-col">
            <span className="section-tag">24/7 Assistance</span>
            <h1 className="contact-title">We'd Love to Hear From You</h1>
            <p className="contact-desc">
              Have questions regarding booking assistance, clinic verification, or partnership inquiries? Our pet parent support desk is here for you.
            </p>

            <div className="contact-cards-stack">
              <div className="contact-item-card card">
                <div className="contact-icon bg-sage">
                  <Phone size={22} />
                </div>
                <div>
                  <strong>Phone Support</strong>
                  <p>+91 (080) 4567-8900</p>
                  <small>Mon - Sun, 8:00 AM - 9:00 PM IST</small>
                </div>
              </div>

              <div className="contact-item-card card">
                <div className="contact-icon bg-terracotta">
                  <Mail size={22} />
                </div>
                <div>
                  <strong>Email Inquiries</strong>
                  <p>support@petcaremarketplace.com</p>
                  <small>Average response time: &lt; 2 hours</small>
                </div>
              </div>

              <div className="contact-item-card card">
                <div className="contact-icon bg-sage">
                  <MapPin size={22} />
                </div>
                <div>
                  <strong>Headquarters</strong>
                  <p>14, 100ft Road, Indiranagar</p>
                  <small>Bengaluru, Karnataka 560038, India</small>
                </div>
              </div>
            </div>
          </div>

          {/* Form Right Col */}
          <div className="contact-form-col card">
            <h2>Send Us a Message</h2>
            <p className="form-sub">Fill out the form below and an agent will follow up shortly.</p>

            {submitted && (
              <div className="alert alert-success">
                <CheckCircle size={18} />
                <span>Thank you! Your message has been received. Our team will contact you shortly.</span>
              </div>
            )}

            <form onSubmit={handleSubmit} className="contact-form">
              <div className="form-group">
                <label className="form-label">Full Name *</label>
                <input 
                  type="text" 
                  className="form-control"
                  placeholder="e.g. Ramesh Krishnan"
                  value={name}
                  onChange={e => setName(e.target.value)}
                  required
                />
              </div>

              <div className="form-group">
                <label className="form-label">Email Address *</label>
                <input 
                  type="email" 
                  className="form-control"
                  placeholder="name@example.com"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  required
                />
              </div>

              <div className="form-group">
                <label className="form-label">Subject</label>
                <select 
                  className="form-control"
                  value={subject}
                  onChange={e => setSubject(e.target.value)}
                >
                  <option value="General Inquiry">General Inquiry</option>
                  <option value="Booking Help">Booking Help</option>
                  <option value="Provider Verification">Provider Verification Application</option>
                  <option value="Technical Support">Technical Support / Bug Report</option>
                  <option value="Feedback">Feedback / Suggestions</option>
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">Message *</label>
                <textarea 
                  className="form-control"
                  rows="4"
                  placeholder="Please describe your inquiry or requirements in detail..."
                  value={message}
                  onChange={e => setMessage(e.target.value)}
                  required
                />
              </div>

              <button type="submit" className="btn btn-primary btn-lg w-100">
                <Send size={18} />
                <span>Transmit Message</span>
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ContactPage;
