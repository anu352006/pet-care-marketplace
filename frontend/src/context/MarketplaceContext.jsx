import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  SERVICES as INITIAL_SERVICES,
  PROVIDERS as INITIAL_PROVIDERS,
  SAMPLE_PETS as INITIAL_PETS,
  SAMPLE_BOOKINGS as INITIAL_BOOKINGS,
  SAMPLE_REVIEWS as INITIAL_REVIEWS
} from '../services/mockData';

const MarketplaceContext = createContext(null);

export const MarketplaceProvider = ({ children }) => {
  // Initialize services state with localStorage persistence
  const [services, setServices] = useState(() => {
    const saved = localStorage.getItem('petcare_services');
    return saved ? JSON.parse(saved) : INITIAL_SERVICES;
  });

  // Providers state
  const [providers, setProviders] = useState(() => {
    const saved = localStorage.getItem('petcare_providers');
    return saved ? JSON.parse(saved) : INITIAL_PROVIDERS;
  });

  // Pets state
  const [pets, setPets] = useState(() => {
    const saved = localStorage.getItem('petcare_pets');
    return saved ? JSON.parse(saved) : INITIAL_PETS;
  });

  // Bookings state
  const [bookings, setBookings] = useState(() => {
    const saved = localStorage.getItem('petcare_bookings');
    return saved ? JSON.parse(saved) : INITIAL_BOOKINGS;
  });

  // Reviews state
  const [reviews, setReviews] = useState(() => {
    const saved = localStorage.getItem('petcare_reviews');
    return saved ? JSON.parse(saved) : INITIAL_REVIEWS;
  });

  // Notifications state
  const [notifications, setNotifications] = useState([
    {
      id: 1,
      title: 'Appointment Confirmed',
      message: 'Dr. Aarav Sharma confirmed your wellness exam for Bruno on Nov 08.',
      time: '2 hours ago',
      read: false
    },
    {
      id: 2,
      title: 'Vaccination Due Reminder',
      message: 'Bruno is due for annual booster vaccination in 4 weeks.',
      time: '1 day ago',
      read: true
    }
  ]);

  // Persist to local storage
  useEffect(() => {
    localStorage.setItem('petcare_services', JSON.stringify(services));
  }, [services]);

  useEffect(() => {
    localStorage.setItem('petcare_providers', JSON.stringify(providers));
  }, [providers]);

  useEffect(() => {
    localStorage.setItem('petcare_pets', JSON.stringify(pets));
  }, [pets]);

  useEffect(() => {
    localStorage.setItem('petcare_bookings', JSON.stringify(bookings));
  }, [bookings]);

  useEffect(() => {
    localStorage.setItem('petcare_reviews', JSON.stringify(reviews));
  }, [reviews]);

  // PET MANAGEMENT (CRUD)
  const addPet = (petData) => {
    const newPet = {
      ...petData,
      id: Date.now(),
      ownerId: 10,
      photo: petData.photo || (petData.type === 'Cat' 
        ? 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80'
        : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=600&q=80')
    };
    setPets(prev => [newPet, ...prev]);
    return newPet;
  };

  const updatePet = (id, updatedFields) => {
    setPets(prev => prev.map(p => p.id === id ? { ...p, ...updatedFields } : p));
  };

  const deletePet = (id) => {
    setPets(prev => prev.filter(p => p.id !== id));
  };

  // BOOKING WORKFLOW & CONFLICT CHECKING
  const checkSlotAvailability = (providerId, date, timeSlot) => {
    const conflict = bookings.some(
      b => b.providerId === Number(providerId) &&
           b.date === date &&
           b.timeSlot === timeSlot &&
           b.status !== 'CANCELLED'
    );
    return !conflict;
  };

  const createBooking = (bookingData) => {
    // Prevent double booking conflict
    const isAvailable = checkSlotAvailability(
      bookingData.providerId,
      bookingData.date,
      bookingData.timeSlot
    );

    if (!isAvailable) {
      throw new Error(`The slot "${bookingData.timeSlot}" on ${bookingData.date} is already reserved for this provider. Please choose an alternative slot.`);
    }

    const newBooking = {
      ...bookingData,
      id: 'BK-' + Math.floor(1000 + Math.random() * 9000),
      status: 'PENDING',
      createdAt: new Date().toISOString().split('T')[0]
    };

    setBookings(prev => [newBooking, ...prev]);

    // Push notification
    setNotifications(prev => [
      {
        id: Date.now(),
        title: 'New Booking Created',
        message: `Booking request ${newBooking.id} placed for ${newBooking.serviceName}.`,
        time: 'Just now',
        read: false
      },
      ...prev
    ]);

    return newBooking;
  };

  const updateBookingStatus = (bookingId, newStatus) => {
    setBookings(prev => prev.map(b => b.id === bookingId ? { ...b, status: newStatus } : b));
    
    // Notify
    setNotifications(prev => [
      {
        id: Date.now(),
        title: `Booking ${newStatus}`,
        message: `Appointment ${bookingId} has been updated to ${newStatus}.`,
        time: 'Just now',
        read: false
      },
      ...prev
    ]);
  };

  // REVIEWS
  const addReview = (reviewData) => {
    const newRev = {
      ...reviewData,
      id: Date.now(),
      date: new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
    };
    setReviews(prev => [newRev, ...prev]);

    // Recalculate average rating for service
    if (reviewData.serviceId) {
      setServices(prev => prev.map(s => {
        if (s.id === Number(reviewData.serviceId)) {
          const updatedCount = (s.reviewsCount || 0) + 1;
          const updatedRating = Number((((s.rating * s.reviewsCount) + reviewData.rating) / updatedCount).toFixed(1));
          return { ...s, rating: updatedRating, reviewsCount: updatedCount };
        }
        return s;
      }));
    }
  };

  // PROVIDER VERIFICATION (ADMIN)
  const toggleProviderVerification = (providerId) => {
    setProviders(prev => prev.map(p => {
      if (p.id === providerId) {
        return { ...p, verified: !p.verified };
      }
      return p;
    }));
  };

  // SERVICE MANAGEMENT (PROVIDER / ADMIN)
  const addService = (serviceData) => {
    const newService = {
      ...serviceData,
      id: Date.now(),
      rating: 5.0,
      reviewsCount: 1,
      featured: false
    };
    setServices(prev => [newService, ...prev]);
    return newService;
  };

  const deleteService = (serviceId) => {
    setServices(prev => prev.filter(s => s.id !== serviceId));
  };

  // AI-BASED SERVICE RECOMMENDATIONS ENGINE
  const getPersonalizedRecommendations = (petId) => {
    const selectedPet = pets.find(p => p.id === Number(petId)) || pets[0];
    if (!selectedPet) return services.slice(0, 3);

    return services.filter(service => {
      // Logic for puppies or senior pets
      if (selectedPet.age <= 1 && service.category === 'training') return true;
      if (selectedPet.age >= 6 && service.category === 'vet') return true;
      
      // Breed specific grooming
      if ((selectedPet.breed.includes('Retriever') || selectedPet.breed.includes('Persian') || selectedPet.breed.includes('Poodle')) && service.category === 'grooming') {
        return true;
      }

      // High-energy breeds
      if ((selectedPet.breed.includes('Retriever') || selectedPet.breed.includes('Beagle') || selectedPet.breed.includes('German')) && (service.category === 'walking' || service.category === 'daycare')) {
        return true;
      }

      // Default to high rated services
      return service.rating >= 4.8;
    }).slice(0, 4);
  };

  return (
    <MarketplaceContext.Provider value={{
      services,
      providers,
      pets,
      bookings,
      reviews,
      notifications,
      addPet,
      updatePet,
      deletePet,
      checkSlotAvailability,
      createBooking,
      updateBookingStatus,
      addReview,
      toggleProviderVerification,
      addService,
      deleteService,
      getPersonalizedRecommendations
    }}>
      {children}
    </MarketplaceContext.Provider>
  );
};

export const useMarketplace = () => {
  const context = useContext(MarketplaceContext);
  if (!context) {
    throw new Error('useMarketplace must be used within a MarketplaceProvider');
  }
  return context;
};
