import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { CITIES } from '../services/mockData';
import { User, Mail, Lock, Phone, Building, AlertCircle, CheckCircle, ShieldCheck } from 'lucide-react';
import './Auth.css';

const RegisterPage = () => {
  const { register } = useAuth();
  const navigate = useNavigate();

  const [role, setRole] = useState('PET_OWNER'); // Only 'PET_OWNER' or 'SERVICE_PROVIDER'
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [businessName, setBusinessName] = useState('');
  const [city, setCity] = useState('Bengaluru');
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');

    if (password !== confirmPassword) {
      setErrorMsg('Passwords do not match. Please verify.');
      return;
    }

    if (password.length < 6) {
      setErrorMsg('Password should be at least 6 characters long.');
      return;
    }

    if (role === 'SERVICE_PROVIDER' && !businessName.trim()) {
      setErrorMsg('Please enter your Clinic, Salon, or Business name.');
      return;
    }

    // Role is strictly restricted to PET_OWNER or SERVICE_PROVIDER (No ADMIN self-registration)
    const result = register({
      name,
      email,
      phone,
      password,
      role: role === 'SERVICE_PROVIDER' ? 'SERVICE_PROVIDER' : 'PET_OWNER',
      businessName: role === 'SERVICE_PROVIDER' ? businessName : '',
      city
    });

    if (result.success) {
      setSuccessMsg('Account registered successfully! Redirecting to your dashboard...');
      setTimeout(() => {
        if (role === 'SERVICE_PROVIDER') navigate('/provider-dashboard');
        else navigate('/owner-dashboard');
      }, 1500);
    }
  };

  return (
    <div className="auth-page section">
      <div className="container auth-container">
        <div className="auth-card card">
          <div className="auth-header">
            <span className="badge badge-accent">Join PetCare</span>
            <h2>Create New Account</h2>
            <p>Connect with the best pet specialists or list your services.</p>
          </div>

          {errorMsg && (
            <div className="alert alert-danger">
              <AlertCircle size={18} />
              <span>{errorMsg}</span>
            </div>
          )}

          {successMsg && (
            <div className="alert alert-success">
              <CheckCircle size={18} />
              <span>{successMsg}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="auth-form">
            {/* Role Selection */}
            <div className="form-group">
              <label className="form-label">I want to join as a:</label>
              <div className="role-selector-toggle two-options">
                <button
                  type="button"
                  className={`role-toggle-btn ${role === 'PET_OWNER' ? 'selected' : ''}`}
                  onClick={() => setRole('PET_OWNER')}
                >
                  <User size={16} /> Pet Owner
                </button>
                <button
                  type="button"
                  className={`role-toggle-btn ${role === 'SERVICE_PROVIDER' ? 'selected' : ''}`}
                  onClick={() => setRole('SERVICE_PROVIDER')}
                >
                  <Building size={16} /> Service Provider
                </button>
              </div>
              <small className="form-text-hint">
                {role === 'PET_OWNER' 
                  ? 'Book vet visits, grooming, walking, and manage your companion pet profiles.'
                  : 'Receive appointment bookings, showcase services, and grow your client base.'}
              </small>
            </div>

            {/* Full Name */}
            <div className="form-group">
              <label className="form-label">Full Name</label>
              <div className="input-with-icon">
                <User size={18} className="input-icon" />
                <input 
                  type="text" 
                  className="form-control"
                  placeholder="e.g., Ananya Deshmukh"
                  value={name}
                  onChange={e => setName(e.target.value)}
                  required
                />
              </div>
            </div>

            {/* Provider Business Name (if Provider) */}
            {role === 'SERVICE_PROVIDER' && (
              <div className="form-group">
                <label className="form-label">Business / Clinic / Salon Name</label>
                <div className="input-with-icon">
                  <Building size={18} className="input-icon" />
                  <input 
                    type="text" 
                    className="form-control"
                    placeholder="e.g., Paws & Claws Veterinary Wellness"
                    value={businessName}
                    onChange={e => setBusinessName(e.target.value)}
                    required
                  />
                </div>
              </div>
            )}

            {/* Email Address */}
            <div className="form-group">
              <label className="form-label">Email Address</label>
              <div className="input-with-icon">
                <Mail size={18} className="input-icon" />
                <input 
                  type="email" 
                  className="form-control"
                  placeholder="name@example.com"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  required
                />
              </div>
            </div>

            {/* Phone & City Row */}
            <div className="form-row-2">
              <div className="form-group">
                <label className="form-label">Phone Number</label>
                <div className="input-with-icon">
                  <Phone size={18} className="input-icon" />
                  <input 
                    type="tel" 
                    className="form-control"
                    placeholder="+91 98765 43210"
                    value={phone}
                    onChange={e => setPhone(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">City</label>
                <select 
                  className="form-control"
                  value={city}
                  onChange={e => setCity(e.target.value)}
                >
                  {CITIES.filter(c => c !== 'All Cities').map(c => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                </select>
              </div>
            </div>

            {/* Passwords Row */}
            <div className="form-row-2">
              <div className="form-group">
                <label className="form-label">Password</label>
                <div className="input-with-icon">
                  <Lock size={18} className="input-icon" />
                  <input 
                    type="password" 
                    className="form-control"
                    placeholder="Min 6 characters"
                    value={password}
                    onChange={e => setPassword(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Confirm Password</label>
                <div className="input-with-icon">
                  <Lock size={18} className="input-icon" />
                  <input 
                    type="password" 
                    className="form-control"
                    placeholder="Re-enter password"
                    value={confirmPassword}
                    onChange={e => setConfirmPassword(e.target.value)}
                    required
                  />
                </div>
              </div>
            </div>

            <button type="submit" className="btn btn-primary btn-lg auth-submit-btn">
              Create My Account
            </button>
          </form>

          <div className="auth-footer-prompt">
            Already have an account? <Link to="/login" className="auth-link">Sign in here</Link>
          </div>
        </div>
      </div>
    </div>
  );
};

export default RegisterPage;
