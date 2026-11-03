import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Mail, Lock, LogIn, AlertCircle, Sparkles, Shield, User } from 'lucide-react';
import './Auth.css';

const LoginPage = () => {
  const { login } = useAuth();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState('PET_OWNER'); // 'PET_OWNER' | 'SERVICE_PROVIDER' | 'ADMIN'
  const [errorMsg, setErrorMsg] = useState('');

  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg('');

    if (!email || !password) {
      setErrorMsg('Please enter both email and password.');
      return;
    }

    setSubmitting(true);
    try {
      const res = await login(email, password, role);
      if (res.success) {
        if (res.user.role === 'ADMIN') navigate('/admin');
        else if (res.user.role === 'SERVICE_PROVIDER') navigate('/provider-dashboard');
        else navigate('/owner-dashboard');
      } else {
        setErrorMsg(res.error || 'Invalid credentials or user not found.');
      }
    } catch (err) {
      setErrorMsg(err.message || 'An error occurred during login.');
    } finally {
      setSubmitting(false);
    }
  };

  // Quick fill demo shortcuts for evaluation
  const fillDemo = (demoRole) => {
    setRole(demoRole);
    if (demoRole === 'PET_OWNER') {
      setEmail('priya.petowner@example.com');
      setPassword('OwnerPass123!');
    } else if (demoRole === 'SERVICE_PROVIDER') {
      setEmail('aarav.vet@example.com');
      setPassword('ProviderPass123!');
    } else {
      setEmail('admin@petcare.org');
      setPassword('AdminPass123!');
    }
  };

  return (
    <div className="auth-page section">
      <div className="container auth-container">
        <div className="auth-card card">
          <div className="auth-header">
            <span className="badge badge-primary">Account Access</span>
            <h2>Welcome Back</h2>
            <p>Sign in to manage your pets, book appointments, or accept clients.</p>
          </div>

          {/* Quick Demo Pre-fill Pill Bar */}
          <div className="demo-fill-box">
            <span className="demo-fill-label">Instant Login Shortcuts:</span>
            <div className="demo-fill-buttons">
              <button 
                type="button" 
                className={`fill-chip ${role === 'PET_OWNER' ? 'active' : ''}`}
                onClick={() => fillDemo('PET_OWNER')}
              >
                Pet Owner
              </button>
              <button 
                type="button" 
                className={`fill-chip ${role === 'SERVICE_PROVIDER' ? 'active' : ''}`}
                onClick={() => fillDemo('SERVICE_PROVIDER')}
              >
                Service Provider
              </button>
              <button 
                type="button" 
                className={`fill-chip ${role === 'ADMIN' ? 'active' : ''}`}
                onClick={() => fillDemo('ADMIN')}
              >
                Admin
              </button>
            </div>
          </div>

          {errorMsg && (
            <div className="alert alert-danger">
              <AlertCircle size={18} />
              <span>{errorMsg}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="auth-form">
            {/* Role Select */}
            <div className="form-group">
              <label className="form-label">Signing in as:</label>
              <div className="role-selector-toggle">
                <button
                  type="button"
                  className={`role-toggle-btn ${role === 'PET_OWNER' ? 'selected' : ''}`}
                  onClick={() => setRole('PET_OWNER')}
                >
                  <User size={15} /> Pet Owner
                </button>
                <button
                  type="button"
                  className={`role-toggle-btn ${role === 'SERVICE_PROVIDER' ? 'selected' : ''}`}
                  onClick={() => setRole('SERVICE_PROVIDER')}
                >
                  <Sparkles size={15} /> Provider
                </button>
                <button
                  type="button"
                  className={`role-toggle-btn ${role === 'ADMIN' ? 'selected' : ''}`}
                  onClick={() => setRole('ADMIN')}
                >
                  <Shield size={15} /> Admin
                </button>
              </div>
            </div>

            {/* Email */}
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

            {/* Password */}
            <div className="form-group">
              <div className="password-label-row">
                <label className="form-label">Password</label>
                <Link to="/forgot-password" className="forgot-password-link">
                  Forgot password?
                </Link>
              </div>
              <div className="input-with-icon">
                <Lock size={18} className="input-icon" />
                <input 
                  type="password" 
                  className="form-control"
                  placeholder="••••••••"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  required
                />
              </div>
            </div>

            <button type="submit" className="btn btn-primary btn-lg auth-submit-btn">
              <LogIn size={18} />
              <span>Sign In</span>
            </button>
          </form>

          <div className="auth-footer-prompt">
            Don't have an account? <Link to="/register" className="auth-link">Create an account</Link>
          </div>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
