import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useAuth } from '../context/AuthContext';
import { supabase, isSupabaseConfigured } from '../services/supabaseClient';
import { 
  ShieldCheck, 
  Users, 
  Calendar, 
  Building, 
  CheckCircle, 
  XCircle, 
  Trash2, 
  Eye, 
  BarChart3, 
  AlertCircle,
  FileText,
  Star,
  Search,
  Filter,
  RefreshCw,
  Plus,
  Shield,
  Heart,
  TrendingUp,
  Clock,
  DollarSign,
  AlertTriangle,
  X,
  Layers,
  Sparkles
} from 'lucide-react';
import './AdminDashboardPage.css';

const AdminDashboardPage = () => {
  const { user } = useAuth();

  // Active navigation tab
  const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'users' | 'providers' | 'services' | 'bookings' | 'reviews'

  // Supabase live database states
  const [dbUsers, setDbUsers] = useState([]);
  const [dbProviders, setDbProviders] = useState([]);
  const [dbServices, setDbServices] = useState([]);
  const [dbPets, setDbPets] = useState([]);
  const [dbBookings, setDbBookings] = useState([]);
  const [dbReviews, setDbReviews] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [actionNotice, setActionNotice] = useState(null);

  // Search & Filter states
  const [userSearch, setUserSearch] = useState('');
  const [userRoleFilter, setUserRoleFilter] = useState('ALL');

  const [providerSearch, setProviderSearch] = useState('');
  const [providerVerifiedFilter, setProviderVerifiedFilter] = useState('ALL');

  const [serviceSearch, setServiceSearch] = useState('');
  const [serviceCategoryFilter, setServiceCategoryFilter] = useState('ALL');
  const [serviceStatusFilter, setServiceStatusFilter] = useState('ALL');

  const [bookingSearch, setBookingSearch] = useState('');
  const [bookingStatusFilter, setBookingStatusFilter] = useState('ALL');

  const [reviewSearch, setReviewSearch] = useState('');
  const [reviewRatingFilter, setReviewRatingFilter] = useState('ALL');

  // Modal inspection states
  const [inspectedUser, setInspectedUser] = useState(null);
  const [inspectedProvider, setInspectedProvider] = useState(null);
  const [inspectedBooking, setInspectedBooking] = useState(null);
  const [confirmDialog, setConfirmDialog] = useState(null);

  // ==========================================================================
  // FETCH ALL ACTUAL SUPABASE RECORDS
  // ==========================================================================
  const fetchAllAdminData = useCallback(async () => {
    if (!isSupabaseConfigured()) {
      setLoading(false);
      return;
    }

    try {
      const [
        usersRes,
        providersRes,
        servicesRes,
        petsRes,
        bookingsRes,
        reviewsRes
      ] = await Promise.all([
        supabase
          .from('users')
          .select('id, full_name, email, role, phone, avatar_url, created_at')
          .order('created_at', { ascending: false }),
        
        supabase
          .from('providers')
          .select(`
            id,
            user_id,
            business_name,
            location,
            description,
            verified,
            rating,
            reviews_count,
            created_at,
            users (full_name, email, phone, avatar_url)
          `)
          .order('created_at', { ascending: false }),

        supabase
          .from('services')
          .select(`
            id,
            provider_id,
            category,
            title,
            description,
            price,
            image_url,
            rating,
            duration,
            featured,
            active,
            created_at,
            providers (business_name, location)
          `)
          .order('created_at', { ascending: false }),

        supabase
          .from('pets')
          .select(`
            id,
            owner_id,
            name,
            animal_type,
            breed,
            age,
            gender,
            weight,
            image_url,
            created_at
          `)
          .order('created_at', { ascending: false }),

        supabase
          .from('bookings')
          .select(`
            id,
            pet_id,
            service_id,
            provider_id,
            user_id,
            booking_date,
            booking_time,
            status,
            total_price,
            booking_notes,
            created_at,
            services (title, category),
            providers (business_name, location),
            pets (name, animal_type)
          `)
          .order('created_at', { ascending: false }),

        supabase
          .from('reviews')
          .select(`
            id,
            booking_id,
            user_id,
            provider_id,
            service_id,
            rating,
            review,
            created_at,
            providers (business_name),
            services (title)
          `)
          .order('created_at', { ascending: false })
      ]);

      if (usersRes.data) setDbUsers(usersRes.data);
      if (providersRes.data) setDbProviders(providersRes.data);
      if (servicesRes.data) setDbServices(servicesRes.data);
      if (petsRes.data) setDbPets(petsRes.data);
      if (bookingsRes.data) setDbBookings(bookingsRes.data);
      if (reviewsRes.data) setDbReviews(reviewsRes.data);

    } catch (err) {
      console.error('Admin data fetch error:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    fetchAllAdminData();
  }, [fetchAllAdminData]);

  const handleRefresh = async () => {
    setRefreshing(true);
    await fetchAllAdminData();
    showNotice('Database metrics refreshed successfully.');
  };

  const showNotice = (msg, type = 'success') => {
    setActionNotice({ message: msg, type });
    setTimeout(() => setActionNotice(null), 4500);
  };

  // ==========================================================================
  // REAL SUPABASE DATABASE STATISTICS
  // ==========================================================================
  const stats = useMemo(() => {
    const totalUsers = dbUsers.length;
    const petOwners = dbUsers.filter(u => u.role === 'pet_owner').length;
    const serviceProviders = dbProviders.length || dbUsers.filter(u => u.role === 'provider').length;
    const adminCount = dbUsers.filter(u => u.role === 'admin').length;

    const totalPets = dbPets.length;
    const totalServices = dbServices.length;
    const activeServices = dbServices.filter(s => s.active !== false).length;

    const totalBookings = dbBookings.length;
    const pendingBookings = dbBookings.filter(b => b.status === 'PENDING').length;
    const confirmedBookings = dbBookings.filter(b => b.status === 'CONFIRMED').length;
    const completedBookings = dbBookings.filter(b => b.status === 'COMPLETED').length;
    const cancelledBookings = dbBookings.filter(b => b.status === 'CANCELLED' || b.status === 'REJECTED').length;

    const totalReviews = dbReviews.length;

    // Actual revenue from COMPLETED bookings only (never treat pending/cancelled as revenue)
    const confirmedRevenue = dbBookings
      .filter(b => b.status === 'COMPLETED')
      .reduce((sum, b) => sum + Number(b.total_price || 0), 0);

    return {
      totalUsers,
      petOwners,
      serviceProviders,
      adminCount,
      totalPets,
      totalServices,
      activeServices,
      totalBookings,
      pendingBookings,
      confirmedBookings,
      completedBookings,
      cancelledBookings,
      totalReviews,
      confirmedRevenue
    };
  }, [dbUsers, dbProviders, dbServices, dbPets, dbBookings, dbReviews]);

  // ==========================================================================
  // ACTION HANDLERS
  // ==========================================================================

  // 1. Toggle Provider Verification
  const handleToggleVerification = async (providerId, currentVerified) => {
    const nextStatus = !currentVerified;
    try {
      const { error } = await supabase
        .from('providers')
        .update({ verified: nextStatus })
        .eq('id', providerId);

      if (error) throw error;

      setDbProviders(prev => prev.map(p => p.id === providerId ? { ...p, verified: nextStatus } : p));
      showNotice(`Provider verification ${nextStatus ? 'approved' : 'revoked'} successfully.`);
    } catch (err) {
      console.error('Verification update error:', err);
      showNotice(err.message || 'Failed to update provider status.', 'error');
    }
  };

  // 2. Toggle Service Active Status
  const handleToggleServiceActive = async (serviceId, currentActive) => {
    const nextActive = currentActive === false ? true : false;
    try {
      const { error } = await supabase
        .from('services')
        .update({ active: nextActive })
        .eq('id', serviceId);

      if (error) throw error;

      setDbServices(prev => prev.map(s => s.id === serviceId ? { ...s, active: nextActive } : s));
      showNotice(`Service listing ${nextActive ? 'activated' : 'suspended'} successfully.`);
    } catch (err) {
      console.error('Service status error:', err);
      showNotice(err.message || 'Failed to update service status.', 'error');
    }
  };

  // 3. Delete Service Safely
  const handleDeleteService = async (serviceId) => {
    // Check if bookings exist for this service
    const hasBookings = dbBookings.some(b => String(b.service_id) === String(serviceId));
    if (hasBookings) {
      showNotice('Cannot delete service: Active or historic bookings reference this service. Please deactivate the listing instead.', 'error');
      setConfirmDialog(null);
      return;
    }

    try {
      const { error } = await supabase
        .from('services')
        .delete()
        .eq('id', serviceId);

      if (error) throw error;

      setDbServices(prev => prev.filter(s => s.id !== serviceId));
      showNotice('Service deleted successfully.');
      setConfirmDialog(null);
    } catch (err) {
      console.error('Delete service error:', err);
      showNotice(err.message || 'Failed to delete service.', 'error');
    }
  };

  // 4. Update Booking Status (Admin override)
  const handleUpdateBookingStatus = async (bookingId, newStatus) => {
    try {
      const { error } = await supabase
        .from('bookings')
        .update({ status: newStatus })
        .eq('id', bookingId);

      if (error) throw error;

      setDbBookings(prev => prev.map(b => b.id === bookingId ? { ...b, status: newStatus } : b));
      showNotice(`Booking status changed to ${newStatus}.`);
    } catch (err) {
      console.error('Update booking status error:', err);
      showNotice(err.message || 'Failed to update booking status.', 'error');
    }
  };

  // 5. Delete / Moderate Review
  const handleDeleteReview = async (reviewId) => {
    try {
      const { error } = await supabase
        .from('reviews')
        .delete()
        .eq('id', reviewId);

      if (error) throw error;

      setDbReviews(prev => prev.filter(r => r.id !== reviewId));
      showNotice('Review removed from public marketplace.');
      setConfirmDialog(null);
    } catch (err) {
      console.error('Delete review error:', err);
      showNotice(err.message || 'Failed to delete review.', 'error');
    }
  };

  // ==========================================================================
  // FILTERED LISTS
  // ==========================================================================

  // Users Filter
  const filteredUsers = useMemo(() => {
    return dbUsers.filter(u => {
      const matchesSearch = 
        (u.full_name || '').toLowerCase().includes(userSearch.toLowerCase()) ||
        (u.email || '').toLowerCase().includes(userSearch.toLowerCase()) ||
        (u.phone || '').includes(userSearch);
      
      const matchesRole = 
        userRoleFilter === 'ALL' || 
        (userRoleFilter === 'pet_owner' && u.role === 'pet_owner') ||
        (userRoleFilter === 'provider' && u.role === 'provider') ||
        (userRoleFilter === 'admin' && u.role === 'admin');

      return matchesSearch && matchesRole;
    });
  }, [dbUsers, userSearch, userRoleFilter]);

  // Providers Filter
  const filteredProviders = useMemo(() => {
    return dbProviders.filter(p => {
      const u = Array.isArray(p.users) ? p.users[0] : p.users;
      const matchesSearch = 
        (p.business_name || '').toLowerCase().includes(providerSearch.toLowerCase()) ||
        (p.location || '').toLowerCase().includes(providerSearch.toLowerCase()) ||
        (u?.full_name || '').toLowerCase().includes(providerSearch.toLowerCase()) ||
        (u?.email || '').toLowerCase().includes(providerSearch.toLowerCase());

      const matchesStatus = 
        providerVerifiedFilter === 'ALL' ||
        (providerVerifiedFilter === 'VERIFIED' && p.verified) ||
        (providerVerifiedFilter === 'PENDING' && !p.verified);

      return matchesSearch && matchesStatus;
    });
  }, [dbProviders, providerSearch, providerVerifiedFilter]);

  // Services Filter
  const filteredServices = useMemo(() => {
    return dbServices.filter(s => {
      const pr = Array.isArray(s.providers) ? s.providers[0] : s.providers;
      const matchesSearch = 
        (s.title || '').toLowerCase().includes(serviceSearch.toLowerCase()) ||
        (s.category || '').toLowerCase().includes(serviceSearch.toLowerCase()) ||
        (pr?.business_name || '').toLowerCase().includes(serviceSearch.toLowerCase());

      const matchesCategory = 
        serviceCategoryFilter === 'ALL' || 
        s.category?.toLowerCase() === serviceCategoryFilter.toLowerCase();

      const matchesStatus = 
        serviceStatusFilter === 'ALL' ||
        (serviceStatusFilter === 'ACTIVE' && s.active !== false) ||
        (serviceStatusFilter === 'INACTIVE' && s.active === false);

      return matchesSearch && matchesCategory && matchesStatus;
    });
  }, [dbServices, serviceSearch, serviceCategoryFilter, serviceStatusFilter]);

  // Bookings Filter
  const filteredBookings = useMemo(() => {
    return dbBookings.filter(b => {
      const s = Array.isArray(b.services) ? b.services[0] : b.services;
      const pr = Array.isArray(b.providers) ? b.providers[0] : b.providers;
      const pt = Array.isArray(b.pets) ? b.pets[0] : b.pets;

      const matchesSearch = 
        String(b.id).toLowerCase().includes(bookingSearch.toLowerCase()) ||
        (s?.title || '').toLowerCase().includes(bookingSearch.toLowerCase()) ||
        (pr?.business_name || '').toLowerCase().includes(bookingSearch.toLowerCase()) ||
        (pt?.name || '').toLowerCase().includes(bookingSearch.toLowerCase());

      const matchesStatus = 
        bookingStatusFilter === 'ALL' || 
        b.status === bookingStatusFilter;

      return matchesSearch && matchesStatus;
    });
  }, [dbBookings, bookingSearch, bookingStatusFilter]);

  // Reviews Filter
  const filteredReviews = useMemo(() => {
    return dbReviews.filter(r => {
      const pr = Array.isArray(r.providers) ? r.providers[0] : r.providers;
      const s = Array.isArray(r.services) ? r.services[0] : r.services;

      const matchesSearch = 
        (r.review || '').toLowerCase().includes(reviewSearch.toLowerCase()) ||
        (pr?.business_name || '').toLowerCase().includes(reviewSearch.toLowerCase()) ||
        (s?.title || '').toLowerCase().includes(reviewSearch.toLowerCase());

      const matchesRating = 
        reviewRatingFilter === 'ALL' || 
        Number(r.rating) === Number(reviewRatingFilter);

      return matchesSearch && matchesRating;
    });
  }, [dbReviews, reviewSearch, reviewRatingFilter]);

  return (
    <div className="admin-page section">
      <div className="container">
        
        {/* Floating Action Notice Toast */}
        {actionNotice && (
          <div style={{
            position: 'fixed',
            bottom: '2rem',
            right: '2rem',
            background: actionNotice.type === 'error' ? '#EF4444' : '#0D9488',
            color: '#FFFFFF',
            padding: '1rem 1.5rem',
            borderRadius: '12px',
            boxShadow: '0 10px 25px rgba(0,0,0,0.2)',
            zIndex: 9999,
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
            fontSize: '0.9rem',
            fontWeight: '600'
          }}>
            {actionNotice.type === 'error' ? <AlertTriangle size={18} /> : <CheckCircle size={18} />}
            <span>{actionNotice.message}</span>
            <button 
              onClick={() => setActionNotice(null)} 
              style={{ background: 'none', border: 'none', color: '#fff', cursor: 'pointer', marginLeft: '0.5rem' }}
            >
              <X size={16} />
            </button>
          </div>
        )}

        {/* Admin Header Banner */}
        <div className="admin-header-banner card">
          <div className="banner-left">
            <span className="badge badge-primary">Platform Governance</span>
            <h1>Administrator Master Console</h1>
            <p>Comprehensive oversight of Supabase PostgreSQL tables, accounts, service catalogs, and verified revenue.</p>
          </div>
          
          <div className="admin-header-actions">
            <button 
              className="btn btn-outline btn-sm" 
              onClick={handleRefresh} 
              disabled={refreshing}
              style={{ display: 'inline-flex', alignItems: 'center', gap: '0.4rem' }}
            >
              <RefreshCw size={14} className={refreshing ? 'spin-animation' : ''} />
              <span>{refreshing ? 'Refreshing...' : 'Refresh DB'}</span>
            </button>

            <div className="admin-system-status">
              <span className="status-live-dot"></span>
              <span>Supabase Backend (Live PostgreSQL)</span>
            </div>
          </div>
        </div>

        {/* Primary 4 Metric Overview Cards (Real Database Figures) */}
        <div className="admin-stats-grid">
          <div className="admin-stat-card card">
            <span className="stat-label">Total Registered Users</span>
            <strong className="stat-num">{stats.totalUsers}</strong>
            <span className="stat-sub">{stats.petOwners} Owners • {stats.serviceProviders} Providers</span>
            <Users className="stat-icon-watermark" size={72} />
          </div>

          <div className="admin-stat-card card">
            <span className="stat-label">Verified Providers</span>
            <strong className="stat-num text-success">
              {dbProviders.filter(p => p.verified).length}
            </strong>
            <span className="stat-sub">
              {dbProviders.filter(p => !p.verified).length} pending verification reviews
            </span>
            <ShieldCheck className="stat-icon-watermark" size={72} />
          </div>

          <div className="admin-stat-card card">
            <span className="stat-label">Total Platform Bookings</span>
            <strong className="stat-num">{stats.totalBookings}</strong>
            <span className="stat-sub">
              {stats.completedBookings} Completed • {stats.pendingBookings} Pending
            </span>
            <Calendar className="stat-icon-watermark" size={72} />
          </div>

          <div className="admin-stat-card card">
            <span className="stat-label">Confirmed Revenue</span>
            <strong className="stat-num text-primary">₹{stats.confirmedRevenue.toLocaleString('en-IN')}</strong>
            <span className="stat-sub">From completed appointments only</span>
            <DollarSign className="stat-icon-watermark" size={72} />
          </div>
        </div>

        {/* Secondary 6-Metric Breakdown Strip */}
        <div className="admin-metrics-row">
          <div className="metric-pill-box">
            <span className="metric-pill-label">Registered Pets</span>
            <span className="metric-pill-val">{stats.totalPets}</span>
          </div>
          <div className="metric-pill-box">
            <span className="metric-pill-label">Active Services</span>
            <span className="metric-pill-val">{stats.activeServices}</span>
          </div>
          <div className="metric-pill-box">
            <span className="metric-pill-label">Pending Bookings</span>
            <span className="metric-pill-val" style={{ color: '#d97706' }}>{stats.pendingBookings}</span>
          </div>
          <div className="metric-pill-box">
            <span className="metric-pill-label">Confirmed Bookings</span>
            <span className="metric-pill-val" style={{ color: '#0d9488' }}>{stats.confirmedBookings}</span>
          </div>
          <div className="metric-pill-box">
            <span className="metric-pill-label">Cancelled / Rejected</span>
            <span className="metric-pill-val" style={{ color: '#ef4444' }}>{stats.cancelledBookings}</span>
          </div>
          <div className="metric-pill-box">
            <span className="metric-pill-label">Client Reviews</span>
            <span className="metric-pill-val">{stats.totalReviews}</span>
          </div>
        </div>

        {/* Governance Navigation Tabs Bar */}
        <div className="admin-tabs-bar">
          <button 
            className={`admin-tab-btn ${activeTab === 'overview' ? 'active' : ''}`}
            onClick={() => setActiveTab('overview')}
          >
            <BarChart3 size={16} /> Overview & Analytics
          </button>
          <button 
            className={`admin-tab-btn ${activeTab === 'users' ? 'active' : ''}`}
            onClick={() => setActiveTab('users')}
          >
            <Users size={16} /> User Directory ({stats.totalUsers})
          </button>
          <button 
            className={`admin-tab-btn ${activeTab === 'providers' ? 'active' : ''}`}
            onClick={() => setActiveTab('providers')}
          >
            <ShieldCheck size={16} /> Providers Compliance ({stats.serviceProviders})
          </button>
          <button 
            className={`admin-tab-btn ${activeTab === 'services' ? 'active' : ''}`}
            onClick={() => setActiveTab('services')}
          >
            <Building size={16} /> Service Catalog ({stats.totalServices})
          </button>
          <button 
            className={`admin-tab-btn ${activeTab === 'bookings' ? 'active' : ''}`}
            onClick={() => setActiveTab('bookings')}
          >
            <Calendar size={16} /> Bookings Monitor ({stats.totalBookings})
          </button>
          <button 
            className={`admin-tab-btn ${activeTab === 'reviews' ? 'active' : ''}`}
            onClick={() => setActiveTab('reviews')}
          >
            <Star size={16} /> Reviews & Ratings ({stats.totalReviews})
          </button>
        </div>

        {/* ================================================================== */}
        {/* TAB 0: OVERVIEW & ANALYTICS                                        */}
        {/* ================================================================== */}
        {activeTab === 'overview' && (
          <div className="admin-overview-grid">
            {/* User Composition Card */}
            <div className="admin-card-section">
              <h4><Users size={18} /> User Account Distribution</h4>
              <div className="distribution-list">
                <div className="distribution-item">
                  <div className="dist-meta">
                    <span>Pet Owners</span>
                    <span>{stats.petOwners} ({stats.totalUsers > 0 ? Math.round((stats.petOwners / stats.totalUsers) * 100) : 0}%)</span>
                  </div>
                  <div className="dist-bar-track">
                    <div 
                      className="dist-bar-fill" 
                      style={{ 
                        width: `${stats.totalUsers > 0 ? (stats.petOwners / stats.totalUsers) * 100 : 0}%`,
                        background: '#0D9488'
                      }}
                    />
                  </div>
                </div>

                <div className="distribution-item">
                  <div className="dist-meta">
                    <span>Service Providers</span>
                    <span>{stats.serviceProviders} ({stats.totalUsers > 0 ? Math.round((stats.serviceProviders / stats.totalUsers) * 100) : 0}%)</span>
                  </div>
                  <div className="dist-bar-track">
                    <div 
                      className="dist-bar-fill" 
                      style={{ 
                        width: `${stats.totalUsers > 0 ? (stats.serviceProviders / stats.totalUsers) * 100 : 0}%`,
                        background: '#2563EB'
                      }}
                    />
                  </div>
                </div>

                <div className="distribution-item">
                  <div className="dist-meta">
                    <span>Administrators</span>
                    <span>{stats.adminCount} ({stats.totalUsers > 0 ? Math.round((stats.adminCount / stats.totalUsers) * 100) : 0}%)</span>
                  </div>
                  <div className="dist-bar-track">
                    <div 
                      className="dist-bar-fill" 
                      style={{ 
                        width: `${stats.totalUsers > 0 ? (stats.adminCount / stats.totalUsers) * 100 : 0}%`,
                        background: '#7C3AED'
                      }}
                    />
                  </div>
                </div>
              </div>
            </div>

            {/* Booking Status Distribution */}
            <div className="admin-card-section">
              <h4><Calendar size={18} /> Appointment Status Breakdown</h4>
              <div className="distribution-list">
                <div className="distribution-item">
                  <div className="dist-meta">
                    <span>Completed Appointments</span>
                    <span style={{ color: '#059669' }}>{stats.completedBookings}</span>
                  </div>
                  <div className="dist-bar-track">
                    <div 
                      className="dist-bar-fill" 
                      style={{ 
                        width: `${stats.totalBookings > 0 ? (stats.completedBookings / stats.totalBookings) * 100 : 0}%`,
                        background: '#10B981'
                      }}
                    />
                  </div>
                </div>

                <div className="distribution-item">
                  <div className="dist-meta">
                    <span>Confirmed & Scheduled</span>
                    <span style={{ color: '#0284c7' }}>{stats.confirmedBookings}</span>
                  </div>
                  <div className="dist-bar-track">
                    <div 
                      className="dist-bar-fill" 
                      style={{ 
                        width: `${stats.totalBookings > 0 ? (stats.confirmedBookings / stats.totalBookings) * 100 : 0}%`,
                        background: '#38BDF8'
                      }}
                    />
                  </div>
                </div>

                <div className="distribution-item">
                  <div className="dist-meta">
                    <span>Pending Provider Review</span>
                    <span style={{ color: '#d97706' }}>{stats.pendingBookings}</span>
                  </div>
                  <div className="dist-bar-track">
                    <div 
                      className="dist-bar-fill" 
                      style={{ 
                        width: `${stats.totalBookings > 0 ? (stats.pendingBookings / stats.totalBookings) * 100 : 0}%`,
                        background: '#F59E0B'
                      }}
                    />
                  </div>
                </div>

                <div className="distribution-item">
                  <div className="dist-meta">
                    <span>Cancelled / Rejected</span>
                    <span style={{ color: '#DC2626' }}>{stats.cancelledBookings}</span>
                  </div>
                  <div className="dist-bar-track">
                    <div 
                      className="dist-bar-fill" 
                      style={{ 
                        width: `${stats.totalBookings > 0 ? (stats.cancelledBookings / stats.totalBookings) * 100 : 0}%`,
                        background: '#EF4444'
                      }}
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ================================================================== */}
        {/* TAB 1: USER MANAGEMENT (Requirement 3)                             */}
        {/* ================================================================== */}
        {activeTab === 'users' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <div>
                <h3>Registered User Directory</h3>
                <p>Monitor user accounts, roles, registration dates, and security profiles.</p>
              </div>
              <span className="badge badge-primary">{filteredUsers.length} Users Listed</span>
            </div>

            {/* Toolbar */}
            <div className="admin-toolbar">
              <div className="admin-search-box">
                <Search size={16} className="admin-search-icon" />
                <input 
                  type="text" 
                  placeholder="Search by name, email, or phone..."
                  value={userSearch}
                  onChange={e => setUserSearch(e.target.value)}
                />
              </div>

              <div className="admin-filter-pills">
                <button 
                  className={`filter-pill-btn ${userRoleFilter === 'ALL' ? 'active' : ''}`}
                  onClick={() => setUserRoleFilter('ALL')}
                >
                  All ({dbUsers.length})
                </button>
                <button 
                  className={`filter-pill-btn ${userRoleFilter === 'pet_owner' ? 'active' : ''}`}
                  onClick={() => setUserRoleFilter('pet_owner')}
                >
                  Pet Owners ({stats.petOwners})
                </button>
                <button 
                  className={`filter-pill-btn ${userRoleFilter === 'provider' ? 'active' : ''}`}
                  onClick={() => setUserRoleFilter('provider')}
                >
                  Providers ({stats.serviceProviders})
                </button>
                <button 
                  className={`filter-pill-btn ${userRoleFilter === 'admin' ? 'active' : ''}`}
                  onClick={() => setUserRoleFilter('admin')}
                >
                  Admins ({stats.adminCount})
                </button>
              </div>
            </div>

            {/* Table */}
            <div className="table-responsive">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>User</th>
                    <th>Email Address</th>
                    <th>Role</th>
                    <th>Phone</th>
                    <th>Registration Date</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredUsers.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="admin-empty-state">
                        <Users size={36} style={{ margin: '0 auto 0.5rem auto', color: '#94a3b8' }} />
                        <h4>No matching users found</h4>
                        <p>Try adjusting your search criteria or role filters.</p>
                      </td>
                    </tr>
                  ) : (
                    filteredUsers.map(u => (
                      <tr key={u.id}>
                        <td>
                          <div className="table-user-cell">
                            <img 
                              src={u.avatar_url || '/images/testimonials/user-kavita.jpg'} 
                              alt={u.full_name} 
                              className="table-avatar"
                              onError={(e) => { e.target.src = '/images/testimonials/user-kavita.jpg'; }}
                            />
                            <div>
                              <strong>{u.full_name || 'Anonymous User'}</strong>
                              <span>UUID: {u.id.substring(0, 8)}...</span>
                            </div>
                          </div>
                        </td>
                        <td><code>{u.email}</code></td>
                        <td>
                          <span className={`badge ${
                            u.role === 'admin' ? 'badge-primary' : 
                            u.role === 'provider' ? 'badge-success' : 'badge-warning'
                          }`} style={{ textTransform: 'capitalize' }}>
                            {u.role ? u.role.replace('_', ' ') : 'Pet Owner'}
                          </span>
                        </td>
                        <td>{u.phone || '—'}</td>
                        <td>
                          {u.created_at ? new Date(u.created_at).toLocaleDateString('en-IN', {
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric'
                          }) : '—'}
                        </td>
                        <td>
                          <div className="action-btn-group">
                            <button 
                              className="icon-action-btn"
                              title="Inspect User Details"
                              onClick={() => setInspectedUser(u)}
                            >
                              <Eye size={15} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ================================================================== */}
        {/* TAB 2: PROVIDER MANAGEMENT (Requirement 4)                         */}
        {/* ================================================================== */}
        {activeTab === 'providers' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <div>
                <h3>Specialist Providers & Compliance Status</h3>
                <p>Review credentials, business practices, ratings, and toggle official verification badges.</p>
              </div>
              <span className="badge badge-primary">{filteredProviders.length} Providers</span>
            </div>

            {/* Toolbar */}
            <div className="admin-toolbar">
              <div className="admin-search-box">
                <Search size={16} className="admin-search-icon" />
                <input 
                  type="text" 
                  placeholder="Search providers by business, doctor, or city..."
                  value={providerSearch}
                  onChange={e => setProviderSearch(e.target.value)}
                />
              </div>

              <div className="admin-filter-pills">
                <button 
                  className={`filter-pill-btn ${providerVerifiedFilter === 'ALL' ? 'active' : ''}`}
                  onClick={() => setProviderVerifiedFilter('ALL')}
                >
                  All ({dbProviders.length})
                </button>
                <button 
                  className={`filter-pill-btn ${providerVerifiedFilter === 'VERIFIED' ? 'active' : ''}`}
                  onClick={() => setProviderVerifiedFilter('VERIFIED')}
                >
                  Verified ({dbProviders.filter(p => p.verified).length})
                </button>
                <button 
                  className={`filter-pill-btn ${providerVerifiedFilter === 'PENDING' ? 'active' : ''}`}
                  onClick={() => setProviderVerifiedFilter('PENDING')}
                >
                  Pending ({dbProviders.filter(p => !p.verified).length})
                </button>
              </div>
            </div>

            {/* Table */}
            <div className="table-responsive">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Specialist / Provider</th>
                    <th>Business / Practice</th>
                    <th>Location</th>
                    <th>Performance</th>
                    <th>Status</th>
                    <th>Compliance Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredProviders.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="admin-empty-state">
                        <ShieldCheck size={36} style={{ margin: '0 auto 0.5rem auto', color: '#94a3b8' }} />
                        <h4>No providers found matching filters</h4>
                      </td>
                    </tr>
                  ) : (
                    filteredProviders.map(prov => {
                      const u = Array.isArray(prov.users) ? prov.users[0] : prov.users;
                      return (
                        <tr key={prov.id}>
                          <td>
                            <div className="table-user-cell">
                              <img 
                                src={u?.avatar_url || '/images/providers/provider-aarav.jpg'} 
                                alt={prov.business_name} 
                                className="table-avatar"
                                onError={(e) => { e.target.src = '/images/providers/provider-aarav.jpg'; }}
                              />
                              <div>
                                <strong>{u?.full_name || 'Specialist Provider'}</strong>
                                <span>{u?.email || 'Registered Specialist'}</span>
                              </div>
                            </div>
                          </td>
                          <td><strong>{prov.business_name}</strong></td>
                          <td>{prov.location}</td>
                          <td>
                            <strong>{prov.rating || 5.0} ★</strong> ({prov.reviews_count || 0} reviews)
                          </td>
                          <td>
                            {prov.verified ? (
                              <span className="badge badge-success">✓ Verified</span>
                            ) : (
                              <span className="badge badge-warning">Pending Review</span>
                            )}
                          </td>
                          <td>
                            <div className="action-btn-group">
                              <button 
                                className={`btn btn-sm ${prov.verified ? 'btn-outline' : 'btn-primary'}`}
                                onClick={() => handleToggleVerification(prov.id, prov.verified)}
                              >
                                {prov.verified ? 'Revoke Badge' : 'Approve & Verify'}
                              </button>
                              <button 
                                className="icon-action-btn"
                                title="Inspect Provider Profile"
                                onClick={() => setInspectedProvider(prov)}
                              >
                                <Eye size={15} />
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ================================================================== */}
        {/* TAB 3: SERVICE MANAGEMENT (Requirement 5)                          */}
        {/* ================================================================== */}
        {activeTab === 'services' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <div>
                <h3>Marketplace Service Catalog</h3>
                <p>Manage active marketplace listings, pricing hygiene, and provider offerings.</p>
              </div>
              <span className="badge badge-primary">{filteredServices.length} Services</span>
            </div>

            {/* Toolbar */}
            <div className="admin-toolbar">
              <div className="admin-search-box">
                <Search size={16} className="admin-search-icon" />
                <input 
                  type="text" 
                  placeholder="Search service title, category, or provider..."
                  value={serviceSearch}
                  onChange={e => setServiceSearch(e.target.value)}
                />
              </div>

              <div className="admin-filter-pills">
                <button 
                  className={`filter-pill-btn ${serviceStatusFilter === 'ALL' ? 'active' : ''}`}
                  onClick={() => setServiceStatusFilter('ALL')}
                >
                  All ({dbServices.length})
                </button>
                <button 
                  className={`filter-pill-btn ${serviceStatusFilter === 'ACTIVE' ? 'active' : ''}`}
                  onClick={() => setServiceStatusFilter('ACTIVE')}
                >
                  Active ({stats.activeServices})
                </button>
                <button 
                  className={`filter-pill-btn ${serviceStatusFilter === 'INACTIVE' ? 'active' : ''}`}
                  onClick={() => setServiceStatusFilter('INACTIVE')}
                >
                  Inactive ({stats.totalServices - stats.activeServices})
                </button>
              </div>
            </div>

            {/* Table */}
            <div className="table-responsive">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Service Title</th>
                    <th>Category</th>
                    <th>Provider Business</th>
                    <th>Price</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredServices.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="admin-empty-state">
                        <Building size={36} style={{ margin: '0 auto 0.5rem auto', color: '#94a3b8' }} />
                        <h4>No services found matching filters</h4>
                      </td>
                    </tr>
                  ) : (
                    filteredServices.map(srv => {
                      const pr = Array.isArray(srv.providers) ? srv.providers[0] : srv.providers;
                      const isActive = srv.active !== false;
                      return (
                        <tr key={srv.id}>
                          <td>
                            <div className="table-service-cell">
                              <img 
                                src={srv.image_url || '/images/services/service-vet-exam.jpg'} 
                                alt={srv.title} 
                                className="table-thumb"
                                onError={(e) => { e.target.src = '/images/services/service-vet-exam.jpg'; }}
                              />
                              <div>
                                <strong>{srv.title}</strong>
                                <span>{srv.duration || '45 mins'}</span>
                              </div>
                            </div>
                          </td>
                          <td>
                            <span className="badge badge-primary" style={{ textTransform: 'capitalize' }}>
                              {srv.category}
                            </span>
                          </td>
                          <td>{pr?.business_name || 'Specialist Provider'}</td>
                          <td><strong>₹{srv.price}</strong></td>
                          <td>
                            {isActive ? (
                              <span className="badge badge-success">Active</span>
                            ) : (
                              <span className="badge badge-warning">Suspended</span>
                            )}
                          </td>
                          <td>
                            <div className="action-btn-group">
                              <button 
                                className={`btn btn-sm ${isActive ? 'btn-outline' : 'btn-primary'}`}
                                onClick={() => handleToggleServiceActive(srv.id, srv.active)}
                                title={isActive ? 'Deactivate listing' : 'Activate listing'}
                              >
                                {isActive ? 'Suspend' : 'Activate'}
                              </button>
                              
                              <button 
                                className="icon-action-btn text-danger"
                                title="Delete Listing"
                                onClick={() => setConfirmDialog({
                                  title: 'Delete Service Listing',
                                  message: `Are you sure you want to permanently delete "${srv.title}"?`,
                                  onConfirm: () => handleDeleteService(srv.id)
                                })}
                              >
                                <Trash2 size={15} />
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ================================================================== */}
        {/* TAB 4: BOOKING MANAGEMENT (Requirement 6)                          */}
        {/* ================================================================== */}
        {activeTab === 'bookings' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <div>
                <h3>Platform Appointments & Bookings Monitor</h3>
                <p>Real-time audit log of scheduled, confirmed, and completed healthcare appointments.</p>
              </div>
              <span className="badge badge-primary">{filteredBookings.length} Bookings</span>
            </div>

            {/* Toolbar */}
            <div className="admin-toolbar">
              <div className="admin-search-box">
                <Search size={16} className="admin-search-icon" />
                <input 
                  type="text" 
                  placeholder="Search booking ID, client, pet, or service..."
                  value={bookingSearch}
                  onChange={e => setBookingSearch(e.target.value)}
                />
              </div>

              <div className="admin-filter-pills">
                <button 
                  className={`filter-pill-btn ${bookingStatusFilter === 'ALL' ? 'active' : ''}`}
                  onClick={() => setBookingStatusFilter('ALL')}
                >
                  All ({dbBookings.length})
                </button>
                <button 
                  className={`filter-pill-btn ${bookingStatusFilter === 'PENDING' ? 'active' : ''}`}
                  onClick={() => setBookingStatusFilter('PENDING')}
                >
                  Pending ({stats.pendingBookings})
                </button>
                <button 
                  className={`filter-pill-btn ${bookingStatusFilter === 'CONFIRMED' ? 'active' : ''}`}
                  onClick={() => setBookingStatusFilter('CONFIRMED')}
                >
                  Confirmed ({stats.confirmedBookings})
                </button>
                <button 
                  className={`filter-pill-btn ${bookingStatusFilter === 'COMPLETED' ? 'active' : ''}`}
                  onClick={() => setBookingStatusFilter('COMPLETED')}
                >
                  Completed ({stats.completedBookings})
                </button>
                <button 
                  className={`filter-pill-btn ${bookingStatusFilter === 'CANCELLED' ? 'active' : ''}`}
                  onClick={() => setBookingStatusFilter('CANCELLED')}
                >
                  Cancelled ({stats.cancelledBookings})
                </button>
              </div>
            </div>

            {/* Table */}
            <div className="table-responsive">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Booking ID</th>
                    <th>Service & Companion</th>
                    <th>Provider</th>
                    <th>Date & Time</th>
                    <th>Amount</th>
                    <th>Status</th>
                    <th>Status Override</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredBookings.length === 0 ? (
                    <tr>
                      <td colSpan="7" className="admin-empty-state">
                        <Calendar size={36} style={{ margin: '0 auto 0.5rem auto', color: '#94a3b8' }} />
                        <h4>No appointments found</h4>
                        <p>No bookings match the selected filters.</p>
                      </td>
                    </tr>
                  ) : (
                    filteredBookings.map(bk => {
                      const s = Array.isArray(bk.services) ? bk.services[0] : bk.services;
                      const pr = Array.isArray(bk.providers) ? bk.providers[0] : bk.providers;
                      const pt = Array.isArray(bk.pets) ? bk.pets[0] : bk.pets;

                      return (
                        <tr key={bk.id}>
                          <td><code>{bk.id.substring(0, 8)}...</code></td>
                          <td>
                            <strong>{s?.title || 'Pet Care Service'}</strong>
                            <div style={{ fontSize: '0.78rem', color: 'var(--color-text-muted)' }}>
                              Pet: {pt?.name || 'Companion'} ({pt?.animal_type || 'Pet'})
                            </div>
                          </td>
                          <td>{pr?.business_name || 'Care Specialist'}</td>
                          <td>
                            {bk.booking_date} at {bk.booking_time}
                          </td>
                          <td><strong>₹{bk.total_price}</strong></td>
                          <td>
                            <span className={`badge ${
                              bk.status === 'COMPLETED' ? 'badge-success' :
                              bk.status === 'CONFIRMED' ? 'badge-primary' :
                              bk.status === 'PENDING' ? 'badge-warning' : 'badge-danger'
                            }`}>
                              {bk.status}
                            </span>
                          </td>
                          <td>
                            <select 
                              className="form-control"
                              style={{ padding: '0.35rem 0.65rem', fontSize: '0.8rem', width: 'auto' }}
                              value={bk.status}
                              onChange={(e) => handleUpdateBookingStatus(bk.id, e.target.value)}
                            >
                              <option value="PENDING">PENDING</option>
                              <option value="CONFIRMED">CONFIRMED</option>
                              <option value="COMPLETED">COMPLETED</option>
                              <option value="CANCELLED">CANCELLED</option>
                              <option value="REJECTED">REJECTED</option>
                            </select>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* ================================================================== */}
        {/* TAB 5: REVIEWS & MODERATION (Requirement 7)                        */}
        {/* ================================================================== */}
        {activeTab === 'reviews' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <div>
                <h3>Client Reviews & Quality Moderation</h3>
                <p>Monitor public feedback, prevent abuse, and safeguard professional marketplace integrity.</p>
              </div>
              <span className="badge badge-primary">{filteredReviews.length} Reviews</span>
            </div>

            {/* Toolbar */}
            <div className="admin-toolbar">
              <div className="admin-search-box">
                <Search size={16} className="admin-search-icon" />
                <input 
                  type="text" 
                  placeholder="Search reviews by content, provider, or service..."
                  value={reviewSearch}
                  onChange={e => setReviewSearch(e.target.value)}
                />
              </div>

              <div className="admin-filter-pills">
                <button 
                  className={`filter-pill-btn ${reviewRatingFilter === 'ALL' ? 'active' : ''}`}
                  onClick={() => setReviewRatingFilter('ALL')}
                >
                  All ({dbReviews.length})
                </button>
                <button 
                  className={`filter-pill-btn ${reviewRatingFilter === '5' ? 'active' : ''}`}
                  onClick={() => setReviewRatingFilter('5')}
                >
                  5 ★ ({dbReviews.filter(r => r.rating === 5).length})
                </button>
                <button 
                  className={`filter-pill-btn ${reviewRatingFilter === '4' ? 'active' : ''}`}
                  onClick={() => setReviewRatingFilter('4')}
                >
                  4 ★ ({dbReviews.filter(r => r.rating === 4).length})
                </button>
                <button 
                  className={`filter-pill-btn ${reviewRatingFilter === '1' ? 'active' : ''}`}
                  onClick={() => setReviewRatingFilter('1')}
                >
                  1 ★ ({dbReviews.filter(r => r.rating === 1).length})
                </button>
              </div>
            </div>

            {/* Reviews Grid */}
            <div className="admin-reviews-grid">
              {filteredReviews.length === 0 ? (
                <div className="admin-empty-state" style={{ gridColumn: 'span 2' }}>
                  <Star size={36} style={{ margin: '0 auto 0.5rem auto', color: '#94a3b8' }} />
                  <h4>No client reviews found</h4>
                </div>
              ) : (
                filteredReviews.map(rev => {
                  const pr = Array.isArray(rev.providers) ? rev.providers[0] : rev.providers;
                  const s = Array.isArray(rev.services) ? rev.services[0] : rev.services;
                  return (
                    <div key={rev.id} className="admin-review-box">
                      <div className="rev-head">
                        <div>
                          <strong>Verified Client</strong>
                          <span className="rev-target">For {pr?.business_name || 'Care Specialist'} • {s?.title || 'Service'}</span>
                        </div>
                        <div className="rev-stars">
                          {[...Array(Number(rev.rating) || 5)].map((_, i) => (
                            <Star key={i} size={14} fill="#F59E0B" color="#F59E0B" />
                          ))}
                        </div>
                      </div>
                      <p className="rev-body">"{rev.review}"</p>
                      <div className="rev-footer">
                        <span className="rev-date">
                          {rev.created_at ? new Date(rev.created_at).toLocaleDateString() : 'Recent review'}
                        </span>
                        <button 
                          className="btn btn-outline btn-sm text-danger"
                          style={{ padding: '0.25rem 0.65rem', fontSize: '0.78rem' }}
                          onClick={() => setConfirmDialog({
                            title: 'Moderate Inappropriate Review',
                            message: 'Are you sure you want to remove this review from the public marketplace?',
                            onConfirm: () => handleDeleteReview(rev.id)
                          })}
                        >
                          <Trash2 size={13} style={{ marginRight: '4px' }} /> Remove Review
                        </button>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        )}

        {/* ================================================================== */}
        {/* INSPECT USER MODAL                                                 */}
        {/* ================================================================== */}
        {inspectedUser && (
          <div className="admin-modal-backdrop" onClick={() => setInspectedUser(null)}>
            <div className="admin-modal-card" onClick={e => e.stopPropagation()}>
              <div className="admin-modal-header">
                <h3>User Account Profile</h3>
                <button className="icon-btn" onClick={() => setInspectedUser(null)}><X size={18} /></button>
              </div>
              <div className="admin-modal-body">
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '0.5rem' }}>
                  <img 
                    src={inspectedUser.avatar_url || '/images/testimonials/user-kavita.jpg'} 
                    alt={inspectedUser.full_name} 
                    style={{ width: '64px', height: '64px', borderRadius: '50%', objectFit: 'cover' }}
                  />
                  <div>
                    <h4 style={{ margin: 0, fontSize: '1.2rem' }}>{inspectedUser.full_name}</h4>
                    <span className="badge badge-primary" style={{ textTransform: 'capitalize', marginTop: '0.25rem' }}>
                      {inspectedUser.role?.replace('_', ' ')}
                    </span>
                  </div>
                </div>

                <div className="modal-info-grid">
                  <div className="modal-info-item">
                    <label>Database UUID</label>
                    <span>{inspectedUser.id}</span>
                  </div>
                  <div className="modal-info-item">
                    <label>Email Address</label>
                    <span>{inspectedUser.email}</span>
                  </div>
                  <div className="modal-info-item">
                    <label>Phone Number</label>
                    <span>{inspectedUser.phone || 'Not provided'}</span>
                  </div>
                  <div className="modal-info-item">
                    <label>Member Since</label>
                    <span>{inspectedUser.created_at ? new Date(inspectedUser.created_at).toLocaleString() : '—'}</span>
                  </div>
                </div>
              </div>
              <div className="admin-modal-footer">
                <button className="btn btn-outline" onClick={() => setInspectedUser(null)}>Close</button>
              </div>
            </div>
          </div>
        )}

        {/* ================================================================== */}
        {/* INSPECT PROVIDER MODAL                                             */}
        {/* ================================================================== */}
        {inspectedProvider && (
          <div className="admin-modal-backdrop" onClick={() => setInspectedProvider(null)}>
            <div className="admin-modal-card" onClick={e => e.stopPropagation()}>
              <div className="admin-modal-header">
                <h3>Provider Compliance Profile</h3>
                <button className="icon-btn" onClick={() => setInspectedProvider(null)}><X size={18} /></button>
              </div>
              <div className="admin-modal-body">
                <h4 style={{ margin: 0, fontSize: '1.25rem' }}>{inspectedProvider.business_name}</h4>
                <p style={{ color: 'var(--color-text-muted)' }}>{inspectedProvider.description || 'Dedicated pet healthcare practice.'}</p>
                
                <div className="modal-info-grid">
                  <div className="modal-info-item">
                    <label>Location / City</label>
                    <span>{inspectedProvider.location}</span>
                  </div>
                  <div className="modal-info-item">
                    <label>Verification Badge</label>
                    <span>{inspectedProvider.verified ? '✓ Verified by Admin' : 'Pending Verification'}</span>
                  </div>
                  <div className="modal-info-item">
                    <label>Marketplace Rating</label>
                    <span>{inspectedProvider.rating || 5.0} ★</span>
                  </div>
                  <div className="modal-info-item">
                    <label>Total Client Reviews</label>
                    <span>{inspectedProvider.reviews_count || 0} reviews</span>
                  </div>
                </div>
              </div>
              <div className="admin-modal-footer">
                <button 
                  className={`btn ${inspectedProvider.verified ? 'btn-outline' : 'btn-primary'}`}
                  onClick={() => {
                    handleToggleVerification(inspectedProvider.id, inspectedProvider.verified);
                    setInspectedProvider(null);
                  }}
                >
                  {inspectedProvider.verified ? 'Revoke Verification' : 'Approve & Verify'}
                </button>
                <button className="btn btn-outline" onClick={() => setInspectedProvider(null)}>Close</button>
              </div>
            </div>
          </div>
        )}

        {/* ================================================================== */}
        {/* CONFIRMATION ACTION DIALOG                                         */}
        {/* ================================================================== */}
        {confirmDialog && (
          <div className="admin-modal-backdrop" onClick={() => setConfirmDialog(null)}>
            <div className="admin-modal-card" style={{ maxWidth: '440px' }} onClick={e => e.stopPropagation()}>
              <div style={{ textAlign: 'center', marginBottom: '1.25rem' }}>
                <AlertTriangle size={42} style={{ color: '#EF4444', margin: '0 auto 0.75rem auto' }} />
                <h3 style={{ marginBottom: '0.5rem' }}>{confirmDialog.title}</h3>
                <p style={{ color: 'var(--color-text-muted)', fontSize: '0.925rem' }}>{confirmDialog.message}</p>
              </div>
              <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center' }}>
                <button className="btn btn-outline" onClick={() => setConfirmDialog(null)}>Cancel</button>
                <button className="btn btn-primary" style={{ background: '#EF4444', borderColor: '#EF4444' }} onClick={confirmDialog.onConfirm}>
                  Confirm Action
                </button>
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
};

export default AdminDashboardPage;
