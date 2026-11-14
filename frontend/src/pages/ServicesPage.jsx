import React, { useState, useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useMarketplace } from '../context/MarketplaceContext';
import { CATEGORIES, CITIES } from '../services/mockData';
import ServiceCard from '../components/ServiceCard';
import BookingModal from '../components/BookingModal';
import { Search, Filter, MapPin, SlidersHorizontal, RotateCcw, Star } from 'lucide-react';
import './ServicesPage.css';

const ServicesPage = () => {
  const { services, loading, fetchError } = useMarketplace();
  const [searchParams, setSearchParams] = useSearchParams();

  // URL query params
  const initialCat = searchParams.get('cat') || 'all';
  const initialCity = searchParams.get('city') || 'All Cities';
  const initialQuery = searchParams.get('q') || '';

  // Filter states
  const [selectedCategory, setSelectedCategory] = useState(initialCat);
  const [selectedCity, setSelectedCity] = useState(initialCity);
  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [maxPrice, setMaxPrice] = useState(10000);
  const [minRating, setMinRating] = useState(0);

  // Booking modal
  const [selectedServiceForBooking, setSelectedServiceForBooking] = useState(null);

  // Filtered Services computation
  const filteredServices = useMemo(() => {
    return services.filter(service => {
      // Category filter
      if (selectedCategory !== 'all' && service.category !== selectedCategory) {
        return false;
      }
      // City filter
      if (selectedCity !== 'All Cities' && service.city !== selectedCity) {
        return false;
      }
      // Price filter
      if (service.price > maxPrice) {
        return false;
      }
      // Rating filter
      if (minRating > 0 && service.rating < minRating) {
        return false;
      }
      // Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesName = service.name.toLowerCase().includes(q);
        const matchesDesc = service.description.toLowerCase().includes(q);
        const matchesProvider = service.providerName.toLowerCase().includes(q);
        const matchesCategory = service.categoryName.toLowerCase().includes(q);
        if (!matchesName && !matchesDesc && !matchesProvider && !matchesCategory) {
          return false;
        }
      }
      return true;
    });
  }, [services, selectedCategory, selectedCity, maxPrice, minRating, searchQuery]);

  const handleResetFilters = () => {
    setSelectedCategory('all');
    setSelectedCity('All Cities');
    setSearchQuery('');
    setMaxPrice(10000);
    setMinRating(0);
    setSearchParams({});
  };

  return (
    <div className="services-page section">
      <div className="container">
        {/* Page Header */}
        <div className="services-page-header">
          <div>
            <span className="section-tag">Marketplace Catalog</span>
            <h1 className="page-title">Pet Care Services & Clinics</h1>
            <p className="page-subtitle">
              Discover verified veterinarians, master grooming salons, luxury boarding resorts and walkers.
            </p>
          </div>
        </div>

        {/* Layout: Sidebar Filter + Results */}
        <div className="services-layout">
          {/* Filters Sidebar */}
          <aside className="filters-sidebar card">
            <div className="filters-header">
              <div className="filters-title">
                <SlidersHorizontal size={18} />
                <span>Filters</span>
              </div>
              <button 
                type="button" 
                className="reset-btn" 
                onClick={handleResetFilters}
                title="Reset all filters"
              >
                <RotateCcw size={14} />
                <span>Reset</span>
              </button>
            </div>

            {/* Keyword Search */}
            <div className="filter-group">
              <label className="filter-label">Search Keyword</label>
              <div className="filter-input-wrap">
                <Search size={16} className="filter-icon" />
                <input 
                  type="text" 
                  className="form-control"
                  placeholder="Doctor, bath, training..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                />
              </div>
            </div>

            {/* City Filter */}
            <div className="filter-group">
              <label className="filter-label">Location / City</label>
              <select 
                className="form-control"
                value={selectedCity}
                onChange={e => setSelectedCity(e.target.value)}
              >
                {CITIES.map(c => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>

            {/* Service Category */}
            <div className="filter-group">
              <label className="filter-label">Service Category</label>
              <div className="category-radio-list">
                <label className={`radio-pill ${selectedCategory === 'all' ? 'active' : ''}`}>
                  <input 
                    type="radio" 
                    name="cat" 
                    value="all" 
                    checked={selectedCategory === 'all'} 
                    onChange={() => setSelectedCategory('all')} 
                  />
                  <span>All Categories ({services.length})</span>
                </label>
                {CATEGORIES.map(cat => {
                  const count = services.filter(s => s.category === cat.id).length;
                  return (
                    <label 
                      key={cat.id} 
                      className={`radio-pill ${selectedCategory === cat.id ? 'active' : ''}`}
                    >
                      <input 
                        type="radio" 
                        name="cat" 
                        value={cat.id} 
                        checked={selectedCategory === cat.id} 
                        onChange={() => setSelectedCategory(cat.id)} 
                      />
                      <span>{cat.name} ({count})</span>
                    </label>
                  );
                })}
              </div>
            </div>

            {/* Price Slider */}
            <div className="filter-group">
              <div className="price-label-row">
                <label className="filter-label">Max Price</label>
                <span className="price-tag-display">₹{maxPrice.toLocaleString('en-IN')}</span>
              </div>
              <input 
                type="range" 
                min="300" 
                max="10000" 
                step="100"
                value={maxPrice}
                onChange={e => setMaxPrice(Number(e.target.value))}
                className="price-slider"
              />
              <div className="price-range-minmax">
                <span>₹300</span>
                <span>₹10,000</span>
              </div>
            </div>

            {/* Minimum Rating */}
            <div className="filter-group">
              <label className="filter-label">Minimum Rating</label>
              <div className="rating-selector-row">
                {[0, 4.5, 4.8].map(r => (
                  <button
                    key={r}
                    type="button"
                    className={`rating-chip ${minRating === r ? 'active' : ''}`}
                    onClick={() => setMinRating(r)}
                  >
                    {r === 0 ? 'Any' : `${r}★ & up`}
                  </button>
                ))}
              </div>
            </div>
          </aside>

          {/* Results Area */}
          <main className="services-results-area">
            {fetchError && (
              <div className="alert alert-danger" style={{ marginBottom: '1.5rem' }}>
                <span>Notice from database: {fetchError}</span>
              </div>
            )}

            {/* Results Counter Bar */}
            <div className="results-status-bar">
              <span className="results-count">
                {loading ? (
                  <span>Loading services from Supabase...</span>
                ) : (
                  <>
                    Showing <strong>{filteredServices.length}</strong> services
                    {selectedCity !== 'All Cities' && ` in ${selectedCity}`}
                  </>
                )}
              </span>
            </div>

            {loading ? (
              <div className="empty-results-card card" style={{ padding: '3rem 1rem', textAlign: 'center' }}>
                <div className="empty-icon-wrap" style={{ animation: 'spin 1s linear infinite' }}>
                  <RotateCcw size={32} className="text-primary" />
                </div>
                <h3>Fetching Catalog</h3>
                <p>Retrieving verified pet care services from PostgreSQL database...</p>
              </div>
            ) : filteredServices.length > 0 ? (
              <div className="services-results-grid">
                {filteredServices.map(service => (
                  <ServiceCard 
                    key={service.id} 
                    service={service} 
                    onBookNow={(s) => setSelectedServiceForBooking(s)}
                  />
                ))}
              </div>
            ) : (
              <div className="empty-results-card card">
                <div className="empty-icon-wrap">
                  <Filter size={40} className="text-accent" />
                </div>
                <h3>No Matching Services Found</h3>
                <p>We couldn't find any services matching your selected filters or search keyword.</p>
                <button className="btn btn-outline" onClick={handleResetFilters}>
                  Clear All Filters
                </button>
              </div>
            )}
          </main>
        </div>
      </div>

      {/* Booking Modal */}
      {selectedServiceForBooking && (
        <BookingModal 
          service={selectedServiceForBooking} 
          onClose={() => setSelectedServiceForBooking(null)}
          onBookingSuccess={() => {}}
        />
      )}
    </div>
  );
};

export default ServicesPage;
