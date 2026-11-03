import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Mail, ArrowLeft, CheckCircle, AlertCircle } from 'lucide-react';
import './Auth.css';

const ForgotPasswordPage = () => {
  const { resetPassword } = useAuth();
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email) {
      setErrorMsg('Please enter your registered email address.');
      return;
    }
    setErrorMsg('');
    setLoading(true);
    try {
      const res = await resetPassword(email);
      if (res && res.success === false) {
        setErrorMsg(res.error || 'Failed to send recovery link.');
      } else {
        setSubmitted(true);
      }
    } catch (err) {
      setErrorMsg(err.message || 'Error communicating with authentication server.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page section">
      <div className="container auth-container">
        <div className="auth-card card">
          <Link to="/login" className="back-to-login">
            <ArrowLeft size={16} /> Back to Sign In
          </Link>

          <div className="auth-header">
            <h2>Reset Password</h2>
            <p>Enter the email address tied to your account and we'll send you recovery steps.</p>
          </div>

          {submitted ? (
            <div className="password-reset-success">
              <div className="success-icon-wrap">
                <CheckCircle size={48} className="text-success" />
              </div>
              <h3>Recovery Email Sent!</h3>
              <p>
                We have transmitted instructions to <strong>{email}</strong>. Please check your inbox and follow the secure link to choose a new password.
              </p>
              <Link to="/login" className="btn btn-primary">
                Return to Login
              </Link>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="auth-form">
              {errorMsg && (
                <div className="alert alert-danger">
                  <AlertCircle size={18} />
                  <span>{errorMsg}</span>
                </div>
              )}

              <div className="form-group">
                <label className="form-label">Registered Email</label>
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

              <button type="submit" className="btn btn-primary btn-lg auth-submit-btn">
                Send Reset Link
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};

export default ForgotPasswordPage;
