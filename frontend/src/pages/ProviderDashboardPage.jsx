import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useMarketplace } from '../context/MarketplaceContext';
import { uploadStorageFile } from '../lib/supabase';
import { CATEGORIES } from '../services/mockData';
import { 
  Building, 
  Calendar, 
  Clock, 
  CheckCircle, 
  XCircle, 
  Plus, 
  Trash2, 
  IndianRupee, 
  Star, 
  ShieldCheck, 
  Users,
  MapPin,
  X
} from 'lucide-react';
import './ProviderDashboardPage.css';

const ProviderDashboardPage = () => {
  const { user } = useAuth();
  const { services, bookings, reviews, updateBookingStatus, addService, deleteService } = useMarketplace();

  // For service provider isolation
  const currentProviderId = user?.providerId || (user?.role === 'SERVICE_PROVIDER' ? user.id : null);
  const myServices = services.filter(s => currentProviderId && String(s.providerId) === String(currentProviderId));
  const myBookings = bookings.filter(b => currentProviderId && String(b.providerId) === String(currentProviderId));

  // Status counts
  const pendingBookings = myBookings.filter(b => b.status === 'PENDING');
  const confirmedBookings = myBookings.filter(b => b.status === 'CONFIRMED');
  const completedBookings = myBookings.filter(b => b.status === 'COMPLETED');

  // Revenue calculation: from COMPLETED appointments only (authoritative)
  const totalRevenue = myBookings
    .filter(b => b.status === 'COMPLETED')
    .reduce((sum, b) => sum + (b.totalPrice || 0), 0);

  // Add Service Modal state
  const [showAddModal, setShowAddModal] = useState(false);
  const [newServiceName, setNewServiceName] = useState('');
  const [newCategory, setNewCategory] = useState('vet');
  const [newPrice, setNewPrice] = useState(850);
  const [newDuration, setNewDuration] = useState('45 mins');
  const [newDesc, setNewDesc] = useState('');
  const [serviceImage, setServiceImage] = useState('');
  const [uploadingImage, setUploadingImage] = useState(false);
  const [imageError, setImageError] = useState('');

  const handleCreateService = async (e) => {
    e.preventDefault();
    const catObj = CATEGORIES.find(c => c.id === newCategory);

    try {
      await addService({
        name: newServiceName,
        category: newCategory,
        categoryName: catObj ? catObj.name : 'Care Service',
        providerId: currentProviderId,
        providerName: user?.name || 'Dr. Aarav Sharma',
        businessName: user?.businessName || 'Paws & Claws Veterinary Wellness',
        city: user?.city || 'Bengaluru',
        area: 'Indiranagar',
        price: Number(newPrice),
        priceUnit: 'per session',
        duration: newDuration,
        image: serviceImage || (catObj ? catObj.image : 'https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?auto=format&fit=crop&w=800&q=80'),
        description: newDesc,
        included: ['Professional clinic evaluation', 'Personalized care advice', 'Digital health summary'],
        availableSlots: ['10:00 AM', '01:00 PM', '04:00 PM', '06:00 PM']
      });

      setShowAddModal(false);
      setNewServiceName('');
      setNewDesc('');
      setServiceImage('');
    } catch (err) {
      alert(err.message || 'Failed to create service listing.');
    }
  };

  return (
    <div className="provider-dash-page section">
      <div className="container">
        {/* Header Strip */}
        <div className="provider-header-banner card">
          <div className="banner-provider-profile">
            <img 
              src={user?.avatar || '/images/providers/provider-aarav.jpg'} 
              alt={user?.name || 'Verified Provider'} 
              className="provider-banner-avatar"
              onError={(e) => { e.target.src = '/images/providers/provider-aarav.jpg'; }}
            />
            <div className="banner-left">
              <div className="provider-badge-row">
                <span className="badge badge-accent">Service Specialist Console</span>
                {user?.verified ? (
                  <span className="verified-pill"><ShieldCheck size={13} /> Verified Business</span>
                ) : (
                  <span className="badge badge-warning" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.3rem' }}>
                    <Clock size={13} /> Pending Admin Verification
                  </span>
                )}
              </div>
              <h1>{user?.businessName || 'Paws & Claws Veterinary Wellness'}</h1>
              <p className="banner-sub">
                Logged in as <strong>{user?.name || 'Dr. Aarav Sharma'}</strong> • {user?.city || 'Bengaluru'}
              </p>
            </div>
          </div>
          <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
            <Plus size={18} /> Add New Service
          </button>
        </div>

        {/* 4 Metric KPI Cards */}
        <div className="provider-kpi-grid">
          <div className="kpi-card card">
            <span className="kpi-label">Active Services</span>
            <strong className="kpi-num">{myServices.length}</strong>
            <span className="kpi-sub">Listings visible</span>
          </div>

          <div className="kpi-card card">
            <span className="kpi-label">Pending Requests</span>
            <strong className="kpi-num text-warning">{pendingBookings.length}</strong>
            <span className="kpi-sub">Awaiting confirmation</span>
          </div>

          <div className="kpi-card card">
            <span className="kpi-label">Confirmed Appointments</span>
            <strong className="kpi-num text-primary">{confirmedBookings.length}</strong>
            <span className="kpi-sub">Ready for service</span>
          </div>

          <div className="kpi-card card">
            <span className="kpi-label">Confirmed Revenue</span>
            <strong className="kpi-num text-success">₹{totalRevenue.toLocaleString('en-IN')}</strong>
            <span className="kpi-sub">From completed appointments only</span>
          </div>
        </div>

        {/* Two-Column Work Area */}
        <div className="provider-two-cols">
          {/* Left Column: Manage Booking Requests */}
          <div className="provider-col-left">
            <div className="card provider-card">
              <div className="card-header-row">
                <div className="header-with-icon">
                  <Calendar size={20} className="text-primary" />
                  <h3>Booking Requests & Appointments ({myBookings.length})</h3>
                </div>
              </div>

              {myBookings.length > 0 ? (
                <div className="provider-bookings-list">
                  {myBookings.map(b => (
                    <div key={b.id} className="provider-booking-row">
                      <div className="p-booking-meta">
                        <span className={`badge ${b.status === 'CONFIRMED' ? 'badge-success' : b.status === 'PENDING' ? 'badge-warning' : 'badge-primary'}`}>
                          {b.status}
                        </span>
                        <span className="p-booking-code">{b.id}</span>
                      </div>

                      <div className="p-booking-info">
                        <h4>{b.serviceName}</h4>
                        <div className="p-client-meta">
                          <span><strong>Pet:</strong> {b.petName}</span>
                          <span><strong>Slot:</strong> {b.date} at {b.timeSlot}</span>
                          <span><strong>Total:</strong> ₹{b.totalPrice}</span>
                        </div>
                        {b.bookingNotes && (
                          <div className="p-notes-quote">
                            "{b.bookingNotes}"
                          </div>
                        )}
                      </div>

                      <div className="p-booking-actions">
                        {b.status === 'PENDING' && (
                          <>
                            <button 
                              className="btn btn-primary btn-sm"
                              onClick={() => updateBookingStatus(b.id, 'CONFIRMED')}
                            >
                              <CheckCircle size={15} /> Accept
                            </button>
                            <button 
                              className="btn btn-outline btn-sm text-danger"
                              onClick={() => updateBookingStatus(b.id, 'REJECTED')}
                            >
                              <XCircle size={15} /> Reject
                            </button>
                          </>
                        )}

                        {b.status === 'CONFIRMED' && (
                          <button 
                            className="btn btn-outline btn-sm"
                            onClick={() => updateBookingStatus(b.id, 'COMPLETED')}
                          >
                            Mark Completed
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="no-data-msg">No appointments assigned to your provider profile yet.</p>
              )}
            </div>
          </div>

          {/* Right Column: Manage My Service Listings */}
          <div className="provider-col-right">
            <div className="card provider-card">
              <div className="card-header-row">
                <div className="header-with-icon">
                  <Building size={20} className="text-accent" />
                  <h3>My Service Listings ({myServices.length})</h3>
                </div>
              </div>

              <div className="provider-service-listings">
                {myServices.map(s => (
                  <div key={s.id} className="p-service-item">
                    <img 
                      src={s.image || '/images/services/service-vet-exam.jpg'} 
                      alt={s.name} 
                      className="p-service-thumb" 
                      loading="lazy"
                      onError={(e) => { e.target.src = '/images/services/service-vet-exam.jpg'; }}
                    />
                    <div className="p-service-details">
                      <h4>{s.name}</h4>
                      <span className="p-service-cat">{s.categoryName} • {s.duration}</span>
                      <strong className="p-service-price">₹{s.price}</strong>
                    </div>
                    <button 
                      className="icon-action-btn text-danger"
                      title="Remove Service"
                      onClick={() => deleteService(s.id)}
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Add Service Modal */}
        {showAddModal && (
          <div className="modal-backdrop" onClick={() => setShowAddModal(false)}>
            <div className="modal-content add-service-modal" onClick={e => e.stopPropagation()}>
              <button className="modal-close-btn" onClick={() => setShowAddModal(false)}>
                <X size={20} />
              </button>

              <div className="modal-header-block">
                <h2>Add New Service Listing</h2>
                <p>Publish an offering to pet owners across your city.</p>
              </div>

              <form onSubmit={handleCreateService} className="add-service-form">
                <div className="form-group">
                  <label className="form-label">Service Title *</label>
                  <input 
                    type="text" 
                    className="form-control"
                    placeholder="e.g. Senior Canine Arthritis Consultation"
                    value={newServiceName}
                    onChange={e => setNewServiceName(e.target.value)}
                    required
                  />
                </div>

                <div className="form-row-2">
                  <div className="form-group">
                    <label className="form-label">Category *</label>
                    <select 
                      className="form-control"
                      value={newCategory}
                      onChange={e => setNewCategory(e.target.value)}
                    >
                      {CATEGORIES.map(c => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Duration</label>
                    <input 
                      type="text" 
                      className="form-control"
                      placeholder="e.g. 45 mins"
                      value={newDuration}
                      onChange={e => setNewDuration(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">Price in INR (₹) *</label>
                  <input 
                    type="number" 
                    className="form-control"
                    placeholder="850"
                    value={newPrice}
                    onChange={e => setNewPrice(e.target.value)}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Short Description *</label>
                  <textarea 
                    className="form-control"
                    rows="3"
                    placeholder="Describe what pet parents can expect, preparation tips, and clinical focus..."
                    value={newDesc}
                    onChange={e => setNewDesc(e.target.value)}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Service Image (Optional)</label>
                  <input 
                    type="file" 
                    className="form-control"
                    accept="image/*"
                    onChange={async (e) => {
                      const file = e.target.files?.[0];
                      if (!file) return;
                      setImageError('');
                      try {
                        setUploadingImage(true);
                        const url = await uploadStorageFile('service-images', file, 'services');
                        setServiceImage(url);
                      } catch (err) {
                        console.error('[Provider Service Image Upload Error]', {
                          message: err.message,
                          statusCode: err.statusCode || err.status,
                          name: err.name,
                        });
                        setImageError(err.message || 'Failed to upload service image.');
                      } finally {
                        setUploadingImage(false);
                      }
                    }}
                  />
                  {uploadingImage && <small style={{ color: 'var(--primary)' }}>Uploading to service-images bucket...</small>}
                  {serviceImage && <small style={{ color: 'var(--accent-secondary)' }}>✓ Image uploaded successfully</small>}
                  {imageError && <small style={{ color: '#ef4444', display: 'block', marginTop: '0.25rem' }}>{imageError}</small>}
                </div>

                <div className="form-btn-actions">
                  <button type="button" className="btn btn-outline" onClick={() => setShowAddModal(false)}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={uploadingImage}>
                    Publish Service
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default ProviderDashboardPage;
