import React from 'react';
import { Navigate, useLocation, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Shield, ShieldAlert, AlertCircle } from 'lucide-react';

/**
 * ProtectedRoute: Enforces authentication and optional role restrictions.
 * - If still loading auth state, shows loading spinner.
 * - If not logged in, redirects to /login.
 * - If a specific role is required (e.g. SERVICE_PROVIDER) and user does not have it,
 *   shows an informative 403 Access Denied view.
 */
const ProtectedRoute = ({ children, requiredRole }) => {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="section" style={{ minHeight: '60vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ textAlign: 'center' }}>
          <Shield className="spin-animation" size={48} style={{ color: 'var(--color-primary, #0d9488)', marginBottom: '1rem' }} />
          <h3>Verifying Session...</h3>
          <p style={{ color: 'var(--color-text-muted, #64748b)' }}>Connecting to secure authentication service</p>
        </div>
      </div>
    );
  }

  // Unauthenticated user -> redirect to login
  if (!user) {
    return (
      <Navigate 
        to="/login" 
        state={{ 
          from: location, 
          message: 'Authentication required. Please sign in to access your dashboard.' 
        }} 
        replace 
      />
    );
  }

  // Specific role required and user doesn't match
  if (requiredRole && user.role !== requiredRole && user.role !== 'ADMIN') {
    return (
      <div className="section container" style={{ minHeight: '65vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '2rem 1rem' }}>
        <div className="card" style={{ maxWidth: '560px', width: '100%', padding: '3rem 2rem', textAlign: 'center', borderRadius: '16px', boxShadow: 'var(--shadow-md, 0 10px 25px rgba(0,0,0,0.08))' }}>
          <div style={{ 
            width: '64px', 
            height: '64px', 
            borderRadius: '50%', 
            background: 'rgba(239, 68, 68, 0.12)', 
            display: 'flex', 
            alignItems: 'center', 
            justifyContent: 'center',
            margin: '0 auto 1.5rem',
            color: '#dc2626'
          }}>
            <ShieldAlert size={32} />
          </div>
          <h2 style={{ fontSize: '1.5rem', marginBottom: '0.75rem', color: 'var(--color-text-dark, #1e293b)' }}>
            Access Restricted
          </h2>
          <p style={{ color: 'var(--color-text-muted, #64748b)', lineHeight: '1.6', marginBottom: '1.5rem' }}>
            This dashboard is reserved for <strong>{requiredRole === 'SERVICE_PROVIDER' ? 'Verified Service Providers' : requiredRole}</strong>. Your current active role is <strong>{user.role}</strong>.
          </p>
          <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link to={user.role === 'ADMIN' ? '/admin' : '/owner-dashboard'} className="btn btn-primary btn-sm">
              Go to My Dashboard
            </Link>
            <Link to="/services" className="btn btn-outline btn-sm">
              Explore Marketplace
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return children;
};

export default ProtectedRoute;
