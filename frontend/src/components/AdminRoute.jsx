import React from 'react';
import { Navigate, useLocation, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { ShieldAlert, Shield } from 'lucide-react';

/**
 * Protected Route wrapper for the Administrator Master Console.
 * Strictly enforces that only authenticated users with role === 'ADMIN' can access.
 * Non-admin users are shown a clean 403 Forbidden view, and unauthenticated users are redirected to login.
 */
const AdminRoute = ({ children }) => {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="section" style={{ minHeight: '60vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ textAlign: 'center' }}>
          <Shield className="spin-animation" size={48} style={{ color: 'var(--color-primary, #0d9488)', marginBottom: '1rem' }} />
          <h3>Verifying Administrator Credentials...</h3>
          <p style={{ color: 'var(--color-text-muted, #64748b)' }}>Connecting to Supabase governance backend</p>
        </div>
      </div>
    );
  }

  // If not logged in, redirect to login
  if (!user) {
    return (
      <Navigate 
        to="/login" 
        state={{ 
          from: location, 
          message: 'Administrator authentication required. Please sign in with your administrative credentials.' 
        }} 
        replace 
      />
    );
  }

  // If logged in but NOT an Administrator (e.g. Pet Owner or Service Provider)
  if (user.role !== 'ADMIN') {
    return (
      <div className="section container" style={{ minHeight: '65vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '2rem 1rem' }}>
        <div className="card" style={{ maxWidth: '580px', width: '100%', padding: '3rem 2rem', textAlign: 'center', borderRadius: '16px', boxShadow: 'var(--shadow-md, 0 10px 25px rgba(0,0,0,0.08))' }}>
          <div style={{ 
            width: '72px', 
            height: '72px', 
            borderRadius: '50%', 
            background: 'rgba(239, 68, 68, 0.12)', 
            display: 'flex', 
            alignItems: 'center', 
            justifyContent: 'center',
            margin: '0 auto 1.5rem auto'
          }}>
            <ShieldAlert size={40} style={{ color: '#ef4444' }} />
          </div>

          <h2 style={{ marginBottom: '0.75rem', fontSize: '1.75rem', fontWeight: '700' }}>
            Access Denied (403 Forbidden)
          </h2>

          <p style={{ color: 'var(--color-text-muted, #64748b)', lineHeight: '1.6', marginBottom: '1.75rem' }}>
            You are signed in as <strong>{user.name}</strong> with role <span className="badge badge-warning" style={{ textTransform: 'capitalize' }}>{user.role}</span>. The Administrator Master Console is restricted strictly to governance administrators.
          </p>

          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link to="/" className="btn btn-outline">
              Return to Marketplace
            </Link>
            <Link to="/login" className="btn btn-primary">
              Sign In as Administrator
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return children;
};

export default AdminRoute;
