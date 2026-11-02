import React, { useState } from 'react';
import { useMarketplace } from '../context/MarketplaceContext';
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
  Star
} from 'lucide-react';
import './AdminDashboardPage.css';

const AdminDashboardPage = () => {
  const { 
    providers, 
    services, 
    bookings, 
    reviews, 
    toggleProviderVerification, 
    deleteService 
  } = useMarketplace();

  const [activeTab, setActiveTab] = useState('providers'); // 'providers' | 'services' | 'bookings' | 'reviews'

  // Metric stats
  const totalProviders = providers.length;
  const verifiedProviders = providers.filter(p => p.verified).length;
  const pendingProviders = totalProviders - verifiedProviders;
  const totalBookings = bookings.length;
  const totalServices = services.length;
  const totalVolume = bookings.reduce((acc, b) => acc + (b.totalPrice || 0), 0);

  return (
    <div className="admin-page section">
      <div className="container">
        {/* Admin Header */}
        <div className="admin-header-banner card">
          <div className="banner-left">
            <span className="badge badge-primary">Platform Governance</span>
            <h1>Administrator Master Console</h1>
            <p>Comprehensive oversight of verified healthcare providers, marketplace catalogs, and bookings.</p>
          </div>
          <div className="admin-system-status">
            <span className="status-live-dot"></span>
            <span>All Systems Operational (Spring Boot + MySQL Ready)</span>
          </div>
        </div>

        {/* 4 Stat Overview Cards */}
        <div className="admin-stats-grid">
          <div className="admin-stat-card card">
            <span className="stat-label">Total Providers</span>
            <strong className="stat-num">{totalProviders}</strong>
            <span className="stat-sub">{verifiedProviders} Verified Specialists</span>
          </div>

          <div className="admin-stat-card card">
            <span className="stat-label">Pending Verification</span>
            <strong className="stat-num text-warning">{pendingProviders}</strong>
            <span className="stat-sub">Review compliance</span>
          </div>

          <div className="admin-stat-card card">
            <span className="stat-label">Marketplace Services</span>
            <strong className="stat-num">{totalServices}</strong>
            <span className="stat-sub">Active listings</span>
          </div>

          <div className="admin-stat-card card">
            <span className="stat-label">Total Platform Volume</span>
            <strong className="stat-num text-primary">₹{totalVolume.toLocaleString('en-IN')}</strong>
            <span className="stat-sub">{totalBookings} Completed & Scheduled</span>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="admin-tabs-bar">
          <button 
            className={`admin-tab-btn ${activeTab === 'providers' ? 'active' : ''}`}
            onClick={() => setActiveTab('providers')}
          >
            <ShieldCheck size={16} /> Provider Verification ({totalProviders})
          </button>
          <button 
            className={`admin-tab-btn ${activeTab === 'services' ? 'active' : ''}`}
            onClick={() => setActiveTab('services')}
          >
            <Building size={16} /> Services Management ({totalServices})
          </button>
          <button 
            className={`admin-tab-btn ${activeTab === 'bookings' ? 'active' : ''}`}
            onClick={() => setActiveTab('bookings')}
          >
            <Calendar size={16} /> Bookings Monitor ({totalBookings})
          </button>
          <button 
            className={`admin-tab-btn ${activeTab === 'reviews' ? 'active' : ''}`}
            onClick={() => setActiveTab('reviews')}
          >
            <Star size={16} /> Reviews & Ratings ({reviews.length})
          </button>
        </div>

        {/* Tab 1: Provider Verification */}
        {activeTab === 'providers' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <h3>Specialist Providers & Compliance Status</h3>
              <p>Toggle verification badges to authenticate veterinary licenses and business credentials.</p>
            </div>
            <div className="table-responsive">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Provider</th>
                    <th>Business / Practice</th>
                    <th>City / Location</th>
                    <th>Rating</th>
                    <th>Verification</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {providers.map(prov => (
                    <tr key={prov.id}>
                      <td>
                        <div className="table-user-cell">
                          <img src={prov.avatar} alt={prov.name} className="table-avatar" />
                          <div>
                            <strong>{prov.name}</strong>
                            <span>{prov.email}</span>
                          </div>
                        </div>
                      </td>
                      <td>{prov.businessName}</td>
                      <td>{prov.area}, {prov.city}</td>
                      <td>{prov.rating} ★ ({prov.reviewsCount})</td>
                      <td>
                        {prov.verified ? (
                          <span className="badge badge-success">Verified</span>
                        ) : (
                          <span className="badge badge-warning">Pending Review</span>
                        )}
                      </td>
                      <td>
                        <button 
                          className={`btn btn-sm ${prov.verified ? 'btn-outline' : 'btn-primary'}`}
                          onClick={() => toggleProviderVerification(prov.id)}
                        >
                          {prov.verified ? 'Revoke Badge' : 'Approve & Verify'}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Tab 2: Service Management */}
        {activeTab === 'services' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <h3>Marketplace Service Catalog</h3>
              <p>Monitor active service offerings and maintain content hygiene across listings.</p>
            </div>
            <div className="table-responsive">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Service Name</th>
                    <th>Category</th>
                    <th>Provider</th>
                    <th>Price</th>
                    <th>Rating</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {services.map(srv => (
                    <tr key={srv.id}>
                      <td>
                        <div className="table-service-cell">
                          <img src={srv.image} alt={srv.name} className="table-thumb" />
                          <strong>{srv.name}</strong>
                        </div>
                      </td>
                      <td><span className="badge badge-primary">{srv.categoryName}</span></td>
                      <td>{srv.providerName}</td>
                      <td><strong>₹{srv.price}</strong> {srv.priceUnit}</td>
                      <td>{srv.rating} ★</td>
                      <td>
                        <button 
                          className="icon-action-btn text-danger"
                          title="Remove Listing"
                          onClick={() => deleteService(srv.id)}
                        >
                          <Trash2 size={16} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Tab 3: Bookings Monitor */}
        {activeTab === 'bookings' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <h3>All Platform Appointments</h3>
              <p>Real-time audit log of service appointments scheduled across the network.</p>
            </div>
            <div className="table-responsive">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Booking ID</th>
                    <th>Service</th>
                    <th>Pet</th>
                    <th>Provider</th>
                    <th>Date & Time</th>
                    <th>Amount</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {bookings.map(bk => (
                    <tr key={bk.id}>
                      <td><code>{bk.id}</code></td>
                      <td><strong>{bk.serviceName}</strong></td>
                      <td>{bk.petName}</td>
                      <td>{bk.providerName}</td>
                      <td>{bk.date} at {bk.timeSlot}</td>
                      <td><strong>₹{bk.totalPrice}</strong></td>
                      <td>
                        <span className={`badge ${bk.status === 'CONFIRMED' ? 'badge-success' : bk.status === 'PENDING' ? 'badge-warning' : 'badge-primary'}`}>
                          {bk.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Tab 4: Reviews & Complaints */}
        {activeTab === 'reviews' && (
          <div className="card admin-table-card">
            <div className="table-header-row">
              <h3>Client Reviews & Feedback Audit</h3>
              <p>Transparent public feedback submitted by pet owners for quality monitoring.</p>
            </div>
            <div className="admin-reviews-grid">
              {reviews.map(rev => (
                <div key={rev.id} className="admin-review-box">
                  <div className="rev-head">
                    <div>
                      <strong>{rev.userName}</strong> ({rev.userCity})
                      <span className="rev-target">For {rev.providerName} • {rev.serviceName}</span>
                    </div>
                    <div className="rev-stars">
                      {[...Array(rev.rating)].map((_, i) => (
                        <Star key={i} size={14} className="star-fill" />
                      ))}
                    </div>
                  </div>
                  <p className="rev-body">"{rev.comment}"</p>
                  <span className="rev-date">{rev.date}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default AdminDashboardPage;
