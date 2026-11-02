import React, { useState } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useMarketplace } from '../context/MarketplaceContext';
import { 
  Heart, 
  Menu, 
  X, 
  User, 
  LogOut, 
  Sparkles, 
  Calendar, 
  ShieldCheck, 
  Bell, 
  ChevronDown,
  Layers,
  SlidersHorizontal
} from 'lucide-react';
import './Navbar.css';

const Navbar = () => {
  const { user, isAuthenticated, logout, switchRole } = useAuth();
  const { notifications } = useMarketplace();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [userDropdownOpen, setUserDropdownOpen] = useState(false);
  const [roleSwitcherOpen, setRoleSwitcherOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const navigate = useNavigate();

  const unreadCount = notifications.filter(n => !n.read).length;

  const handleLogout = () => {
    logout();
    setUserDropdownOpen(false);
    navigate('/');
  };

  const getDashboardLink = () => {
    if (!user) return '/login';
    if (user.role === 'ADMIN') return '/admin';
    if (user.role === 'SERVICE_PROVIDER') return '/provider-dashboard';
    return '/owner-dashboard';
  };

  return (
    <header className="navbar-header">
      {/* Demo Evaluation Role Banner */}
      <div className="demo-top-bar">
        <div className="container demo-top-bar-content">
          <div className="demo-role-badge">
            <span className="demo-dot"></span>
            <strong>Academic Demo Mode:</strong> Viewing as <span className="active-role-text">{user ? user.role.replace('_', ' ') : 'Guest'}</span>
          </div>
          <div className="demo-switch-actions">
            <span className="demo-switch-label">Switch Role:</span>
            <button 
              className={`demo-pill ${user?.role === 'PET_OWNER' ? 'active' : ''}`}
              onClick={() => switchRole('PET_OWNER')}
            >
              Pet Owner
            </button>
            <button 
              className={`demo-pill ${user?.role === 'SERVICE_PROVIDER' ? 'active' : ''}`}
              onClick={() => switchRole('SERVICE_PROVIDER')}
            >
              Service Provider
            </button>
            <button 
              className={`demo-pill ${user?.role === 'ADMIN' ? 'active' : ''}`}
              onClick={() => switchRole('ADMIN')}
            >
              Administrator
            </button>
          </div>
        </div>
      </div>

      {/* Main Navigation Bar */}
      <nav className="main-navbar">
        <div className="container nav-container">
          {/* Brand Logo */}
          <Link to="/" className="brand-logo" onClick={() => setMobileMenuOpen(false)}>
            <div className="logo-icon-wrap">
              <svg viewBox="0 0 24 24" width="26" height="26" fill="currentColor">
                <circle cx="11" cy="4" r="2" fill="#E07A5F" />
                <circle cx="18" cy="8" r="2" fill="#E07A5F" />
                <circle cx="20" cy="16" r="2" fill="#E07A5F" />
                <path d="M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.045Q6.52 17.48 4.46 16.84A3.5 3.5 0 0 1 5.5 10Z" fill="#1E3F20" />
              </svg>
            </div>
            <div className="brand-text">
              <span className="brand-title">PetCare</span>
              <span className="brand-badge">Marketplace</span>
            </div>
          </Link>

          {/* Desktop Links */}
          <div className="nav-links-desktop">
            <NavLink to="/" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              Home
            </NavLink>
            <NavLink to="/services" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              Services
            </NavLink>
            <NavLink to="/ai-assistant" className={({ isActive }) => `nav-link ai-nav-link ${isActive ? 'active' : ''}`}>
              <Sparkles size={16} className="sparkle-icon" />
              AI Assistant
            </NavLink>
            <NavLink to="/about" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              About
            </NavLink>
            <NavLink to="/contact" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              Contact
            </NavLink>
          </div>

          {/* Action Buttons */}
          <div className="nav-actions">
            {isAuthenticated ? (
              <div className="user-nav-group">
                {/* Notification Bell */}
                <div className="notification-bell-wrap">
                  <button 
                    className="icon-btn" 
                    title="Notifications"
                    onClick={() => setShowNotifications(!showNotifications)}
                  >
                    <Bell size={20} />
                    {unreadCount > 0 && <span className="notification-dot">{unreadCount}</span>}
                  </button>

                  {showNotifications && (
                    <div className="notification-flyout card">
                      <div className="flyout-header">
                        <h4>Notifications ({notifications.length})</h4>
                      </div>
                      <div className="flyout-list">
                        {notifications.map(n => (
                          <div key={n.id} className={`flyout-item ${!n.read ? 'unread' : ''}`}>
                            <div className="flyout-item-title">{n.title}</div>
                            <div className="flyout-item-msg">{n.message}</div>
                            <div className="flyout-item-time">{n.time}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* Dashboard Direct Button */}
                <Link to={getDashboardLink()} className="btn btn-primary btn-sm dashboard-btn">
                  <Layers size={16} />
                  Dashboard
                </Link>

                {/* User Dropdown */}
                <div className="user-profile-menu">
                  <button 
                    className="avatar-btn" 
                    onClick={() => setUserDropdownOpen(!userDropdownOpen)}
                  >
                    <img src={user.avatar} alt={user.name} className="user-avatar-img" />
                    <span className="user-firstname">{user.name.split(' ')[0]}</span>
                    <ChevronDown size={14} />
                  </button>

                  {userDropdownOpen && (
                    <div className="dropdown-menu card">
                      <div className="dropdown-user-info">
                        <strong>{user.name}</strong>
                        <span>{user.email}</span>
                        <span className="user-role-tag">{user.role}</span>
                      </div>
                      <hr className="dropdown-divider" />
                      <Link 
                        to={getDashboardLink()} 
                        className="dropdown-item"
                        onClick={() => setUserDropdownOpen(false)}
                      >
                        <Layers size={16} /> My Dashboard
                      </Link>
                      {user.role === 'PET_OWNER' && (
                        <Link 
                          to="/pets" 
                          className="dropdown-item"
                          onClick={() => setUserDropdownOpen(false)}
                        >
                          <Heart size={16} /> My Pets
                        </Link>
                      )}
                      <button className="dropdown-item text-danger" onClick={handleLogout}>
                        <LogOut size={16} /> Log Out
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ) : (
              <div className="auth-buttons">
                <Link to="/login" className="btn btn-ghost btn-sm">
                  Log In
                </Link>
                <Link to="/register" className="btn btn-primary btn-sm">
                  Get Started
                </Link>
              </div>
            )}

            {/* Mobile Hamburger Toggle */}
            <button 
              className="mobile-toggle-btn"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
            </button>
          </div>
        </div>

        {/* Mobile Navigation Drawer */}
        {mobileMenuOpen && (
          <div className="mobile-drawer">
            <div className="mobile-links">
              <NavLink 
                to="/" 
                className="mobile-link" 
                onClick={() => setMobileMenuOpen(false)}
              >
                Home
              </NavLink>
              <NavLink 
                to="/services" 
                className="mobile-link" 
                onClick={() => setMobileMenuOpen(false)}
              >
                Services Marketplace
              </NavLink>
              <NavLink 
                to="/ai-assistant" 
                className="mobile-link ai-link" 
                onClick={() => setMobileMenuOpen(false)}
              >
                <Sparkles size={18} /> AI Pet Care Assistant
              </NavLink>
              <NavLink 
                to="/about" 
                className="mobile-link" 
                onClick={() => setMobileMenuOpen(false)}
              >
                About Us
              </NavLink>
              <NavLink 
                to="/contact" 
                className="mobile-link" 
                onClick={() => setMobileMenuOpen(false)}
              >
                Contact & Support
              </NavLink>

              <hr />

              {isAuthenticated ? (
                <>
                  <Link 
                    to={getDashboardLink()} 
                    className="mobile-link highlight" 
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    Go to Dashboard ({user.role})
                  </Link>
                  <button className="mobile-link text-danger" onClick={handleLogout}>
                    Log Out
                  </button>
                </>
              ) : (
                <div className="mobile-auth-cta">
                  <Link 
                    to="/login" 
                    className="btn btn-outline" 
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    Log In
                  </Link>
                  <Link 
                    to="/register" 
                    className="btn btn-primary" 
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    Register as Owner / Provider
                  </Link>
                </div>
              )}
            </div>
          </div>
        )}
      </nav>
    </header>
  );
};

export default Navbar;
