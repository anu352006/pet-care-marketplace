import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase, isSupabaseConfigured } from '../lib/supabase';
import { useAuth } from './AuthContext';
import {
  SERVICES as INITIAL_SERVICES,
  PROVIDERS as INITIAL_PROVIDERS,
  SAMPLE_PETS as INITIAL_PETS,
  SAMPLE_BOOKINGS as INITIAL_BOOKINGS,
  SAMPLE_REVIEWS as INITIAL_REVIEWS,
  CATEGORIES
} from '../services/mockData';

const MarketplaceContext = createContext(null);

// Category name resolver helper
const getCategoryTitle = (catSlug) => {
  const match = CATEGORIES.find(c => c.id === catSlug || c.slug === catSlug);
  return match ? match.name : 'Pet Care Service';
};

export const MarketplaceProvider = ({ children }) => {
  const { user } = useAuth();

  // State initialization: when Supabase is configured we start fresh; otherwise fallback to sample data
  const [services, setServices] = useState(() => {
    if (isSupabaseConfigured()) return [];
    const saved = localStorage.getItem('petcare_services');
    return saved ? JSON.parse(saved) : INITIAL_SERVICES;
  });

  const [providers, setProviders] = useState(() => {
    if (isSupabaseConfigured()) return [];
    const saved = localStorage.getItem('petcare_providers');
    return saved ? JSON.parse(saved) : INITIAL_PROVIDERS;
  });

  const [pets, setPets] = useState(() => {
    if (isSupabaseConfigured()) return [];
    const saved = localStorage.getItem('petcare_pets');
    return saved ? JSON.parse(saved) : INITIAL_PETS;
  });

  const [bookings, setBookings] = useState(() => {
    if (isSupabaseConfigured()) return [];
    const saved = localStorage.getItem('petcare_bookings');
    return saved ? JSON.parse(saved) : INITIAL_BOOKINGS;
  });

  const [reviews, setReviews] = useState(() => {
    if (isSupabaseConfigured()) return [];
    const saved = localStorage.getItem('petcare_reviews');
    return saved ? JSON.parse(saved) : INITIAL_REVIEWS;
  });

  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [fetchError, setFetchError] = useState(null);

  // ==========================================================================
  // SYNCHRONIZE STATE WITH SUPABASE POSTGRESQL DATABASE
  // ==========================================================================
  const fetchSupabaseData = useCallback(async () => {
    if (!isSupabaseConfigured()) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setFetchError(null);

    try {
      // 1. Fetch Providers with joined Users profile
      const { data: dbProviders, error: provErr } = await supabase
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
          users (
            full_name,
            email,
            phone,
            avatar_url
          )
        `);

      if (provErr) {
        console.warn('Notice fetching providers from Supabase:', provErr);
      } else if (dbProviders) {
        const mappedProviders = dbProviders.map(p => {
          const u = Array.isArray(p.users) ? p.users[0] : p.users;
          return {
            id: p.id,
            userId: p.user_id,
            name: u?.full_name || p.business_name || 'Verified Provider',
            businessName: p.business_name,
            email: u?.email || '',
            phone: u?.phone || '+91 98450 12345',
            city: p.location || 'Bengaluru',
            area: p.location || 'Bengaluru',
            address: `${p.business_name}, ${p.location}`,
            rating: Number(p.rating || 5.0),
            reviewsCount: p.reviews_count || 0,
            verified: !!p.verified,
            avatar: u?.avatar_url || 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80',
            bio: p.description || 'Dedicated pet care specialist.',
            servicesCount: 2
          };
        });
        setProviders(mappedProviders);
      }

      // 2. Fetch Active Marketplace Services with joined Provider details
      const { data: dbServices, error: servErr } = await supabase
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
          available_slots,
          featured,
          active,
          providers (
            id,
            business_name,
            location,
            verified,
            users (
              full_name
            )
          )
        `)
        .eq('active', true)
        .order('created_at', { ascending: false });

      if (servErr) {
        console.warn('Notice fetching services from Supabase:', servErr);
      } else if (dbServices) {
        const mappedServices = dbServices.map(s => {
          const prov = Array.isArray(s.providers) ? s.providers[0] : s.providers;
          const provU = prov && Array.isArray(prov.users) ? prov.users[0] : prov?.users;

          // Parse available slots array
          let parsedSlots = ['09:30 AM', '11:00 AM', '02:30 PM', '04:30 PM', '06:00 PM'];
          if (Array.isArray(s.available_slots)) {
            parsedSlots = s.available_slots;
          } else if (typeof s.available_slots === 'string') {
            try {
              parsedSlots = JSON.parse(s.available_slots);
            } catch {
              parsedSlots = s.available_slots.split(',').map(str => str.trim());
            }
          }

          return {
            id: s.id,
            name: s.title,
            category: s.category,
            categoryName: getCategoryTitle(s.category),
            providerId: s.provider_id,
            providerName: provU?.full_name || prov?.business_name || 'Pet Care Specialist',
            businessName: prov?.business_name || 'Care Center',
            city: prov?.location || 'Bengaluru',
            area: prov?.location || 'Indiranagar',
            price: Number(s.price),
            priceUnit: 'per consultation',
            duration: s.duration || '45 mins',
            rating: Number(s.rating || 5.0),
            reviewsCount: 28,
            featured: !!s.featured,
            image: s.image_url || 'https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?auto=format&fit=crop&w=800&q=80',
            description: s.description,
            included: [
              'Professional clinical or grooming care',
              'Safe, sanitized, climate-controlled environment',
              'Post-appointment care recommendations'
            ],
            availableSlots: parsedSlots
          };
        });
        setServices(mappedServices);
      }

      // 3. Fetch Registered Pets (Filtered to logged-in owner unless admin)
      let petQuery = supabase.from('pets').select('*').order('created_at', { ascending: false });
      if (user && user.role !== 'ADMIN') {
        petQuery = petQuery.eq('owner_id', user.id);
      }

      const { data: dbPets, error: petErr } = await petQuery;
      if (petErr) {
        console.warn('Notice fetching pets from Supabase:', petErr);
      } else if (dbPets) {
        const mappedPets = dbPets.map(p => ({
          id: p.id,
          name: p.name,
          type: p.animal_type || 'Dog',
          breed: p.breed,
          age: p.age || 1,
          gender: p.gender || 'Male',
          weight: p.weight || '10 kg',
          photo: p.image_url || 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=600&q=80',
          vaccinations: p.vaccination_details || 'Up to date with primary vaccinations',
          medicalHistory: p.medical_history || 'No chronic health issues recorded',
          ownerId: p.owner_id
        }));
        setPets(mappedPets);
      }

      // 4. Fetch Bookings with relations
      let bkQuery = supabase
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
          providers (business_name, location, users (full_name)),
          pets (name, breed)
        `)
        .order('created_at', { ascending: false });

      if (user && user.role === 'SERVICE_PROVIDER' && user.providerId) {
        bkQuery = bkQuery.eq('provider_id', user.providerId);
      } else if (user && user.role !== 'ADMIN') {
        bkQuery = bkQuery.eq('user_id', user.id);
      }

      const { data: dbBookings, error: bkErr } = await bkQuery;
      if (bkErr) {
        console.warn('Notice fetching bookings from Supabase:', bkErr);
      } else if (dbBookings) {
        const mappedBookings = dbBookings.map(b => {
          const s = Array.isArray(b.services) ? b.services[0] : b.services;
          const pr = Array.isArray(b.providers) ? b.providers[0] : b.providers;
          const prU = pr && Array.isArray(pr.users) ? pr.users[0] : pr?.users;
          const pt = Array.isArray(b.pets) ? b.pets[0] : b.pets;

          return {
            id: b.id,
            serviceId: b.service_id,
            serviceName: s?.title || 'Pet Care Service',
            category: s?.category || 'vet',
            providerId: b.provider_id,
            providerName: prU?.full_name || pr?.business_name || 'Care Specialist',
            businessName: pr?.business_name || 'Pet Wellness Center',
            petId: b.pet_id,
            petName: pt ? `${pt.name} (${pt.breed})` : 'Registered Companion',
            date: b.booking_date,
            timeSlot: b.booking_time,
            totalPrice: Number(b.total_price),
            status: b.status,
            bookingNotes: b.booking_notes || 'Standard booking.',
            createdAt: b.created_at?.split('T')[0] || new Date().toISOString().split('T')[0]
          };
        });
        setBookings(mappedBookings);
      }

      // 5. Fetch Reviews
      const { data: dbReviews, error: revErr } = await supabase
        .from('reviews')
        .select(`
          id,
          rating,
          review,
          created_at,
          user_id,
          provider_id,
          service_id,
          users (full_name),
          services (title),
          providers (business_name)
        `)
        .order('created_at', { ascending: false });

      if (revErr) {
        console.warn('Notice fetching reviews from Supabase:', revErr);
      } else if (dbReviews) {
        const mappedReviews = dbReviews.map(r => {
          const u = Array.isArray(r.users) ? r.users[0] : r.users;
          const s = Array.isArray(r.services) ? r.services[0] : r.services;
          const p = Array.isArray(r.providers) ? r.providers[0] : r.providers;

          return {
            id: r.id,
            serviceId: r.service_id,
            providerId: r.provider_id,
            userName: u?.full_name || 'Verified Pet Parent',
            userCity: 'Bengaluru',
            serviceName: s?.title || 'Pet Care Service',
            providerName: p?.business_name || 'Care Provider',
            rating: Number(r.rating || 5),
            date: new Date(r.created_at).toLocaleDateString('en-IN', { month: 'long', day: 'numeric', year: 'numeric' }),
            comment: r.review
          };
        });
        setReviews(mappedReviews);
      }

      // 6. Fetch User Notifications
      if (user) {
        const { data: dbNotifs } = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', { ascending: false });

        if (dbNotifs && dbNotifs.length > 0) {
          setNotifications(dbNotifs.map(n => ({
            id: n.id,
            title: n.title,
            message: n.message,
            time: 'Recent',
            read: n.is_read
          })));
        }
      }
    } catch (err) {
      console.error('Supabase synchronization error:', err);
      setFetchError(err.message || 'Error fetching data from Supabase.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchSupabaseData();
  }, [fetchSupabaseData]);

  // Sync state to localStorage as secondary offline cache
  useEffect(() => {
    if (!isSupabaseConfigured()) {
      localStorage.setItem('petcare_services', JSON.stringify(services));
      localStorage.setItem('petcare_providers', JSON.stringify(providers));
      localStorage.setItem('petcare_pets', JSON.stringify(pets));
      localStorage.setItem('petcare_bookings', JSON.stringify(bookings));
      localStorage.setItem('petcare_reviews', JSON.stringify(reviews));
    }
  }, [services, providers, pets, bookings, reviews]);

  // ==========================================================================
  // PET PROFILE MANAGEMENT (CRUD)
  // ==========================================================================
  const addPet = async (petData) => {
    let newPet = {
      ...petData,
      id: 'pet-' + Date.now(),
      ownerId: user?.id || 'demo-user-10',
      photo: petData.photo || (petData.type === 'Cat' 
        ? 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=600&q=80'
        : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=600&q=80')
    };

    if (isSupabaseConfigured() && user) {
      const { data, error } = await supabase
        .from('pets')
        .insert({
          owner_id: user.id,
          name: petData.name,
          animal_type: petData.type || 'Dog',
          breed: petData.breed || 'Companion',
          age: Number(petData.age) || 1,
          gender: petData.gender || 'Male',
          weight: petData.weight || '10 kg',
          vaccination_details: petData.vaccinations || '',
          medical_history: petData.medicalHistory || '',
          image_url: newPet.photo
        })
        .select()
        .single();

      if (error) {
        console.error('Supabase pet insertion failed:', error);
        throw new Error(error.message || 'Failed to save pet profile.');
      }
      if (data) {
        newPet.id = data.id;
        newPet.ownerId = data.owner_id;
      }
    }

    setPets(prev => [newPet, ...prev]);
    return newPet;
  };

  const updatePet = async (id, updatedFields) => {
    if (isSupabaseConfigured()) {
      const { error } = await supabase
        .from('pets')
        .update({
          name: updatedFields.name,
          animal_type: updatedFields.type,
          breed: updatedFields.breed,
          age: Number(updatedFields.age) || 1,
          gender: updatedFields.gender,
          weight: updatedFields.weight,
          vaccination_details: updatedFields.vaccinations,
          medical_history: updatedFields.medicalHistory,
          image_url: updatedFields.photo
        })
        .eq('id', id);

      if (error) {
        console.error('Supabase pet update failed:', error);
        throw new Error(error.message || 'Failed to update pet profile.');
      }
    }

    setPets(prev => prev.map(p => String(p.id) === String(id) ? { ...p, ...updatedFields } : p));
  };

  const deletePet = async (id) => {
    if (isSupabaseConfigured()) {
      const { error } = await supabase
        .from('pets')
        .delete()
        .eq('id', id);

      if (error) {
        console.error('Supabase pet deletion failed:', error);
        throw new Error(error.message || 'Failed to delete pet profile.');
      }
    }

    setPets(prev => prev.filter(p => String(p.id) !== String(id)));
  };

  // ==========================================================================
  // BOOKING WORKFLOW & CONFLICT PREVENTION
  // ==========================================================================
  const checkSlotAvailability = (providerId, date, timeSlot) => {
    const conflict = bookings.some(
      b => String(b.providerId) === String(providerId) &&
           b.date === date &&
           b.timeSlot === timeSlot &&
           ['PENDING', 'CONFIRMED'].includes(b.status)
    );
    return !conflict;
  };

  const checkProviderAvailability = async (providerId, date) => {
    if (!isSupabaseConfigured()) {
      return { available: true, bookedSlots: [] };
    }
    try {
      const { data: bookedData } = await supabase
        .from('bookings')
        .select('booking_time')
        .eq('provider_id', providerId)
        .eq('booking_date', date)
        .in('status', ['PENDING', 'CONFIRMED']);

      const bookedSlots = bookedData ? bookedData.map(b => b.booking_time) : [];
      return { available: true, bookedSlots };
    } catch (err) {
      console.warn('Notice checking slot availability:', err);
      return { available: true, bookedSlots: [] };
    }
  };

  const createBooking = async (bookingData) => {
    let newBooking = {
      ...bookingData,
      id: 'BK-' + Math.floor(1000 + Math.random() * 9000),
      status: 'PENDING',
      createdAt: new Date().toISOString().split('T')[0]
    };

    if (isSupabaseConfigured() && user) {
      // 1. Verify availability in live Supabase table
      const { data: existingSlots, error: checkErr } = await supabase
        .from('bookings')
        .select('id, status')
        .eq('provider_id', bookingData.providerId)
        .eq('booking_date', bookingData.date)
        .eq('booking_time', bookingData.timeSlot)
        .in('status', ['PENDING', 'CONFIRMED']);

      if (existingSlots && existingSlots.length > 0) {
        throw new Error(`The slot "${bookingData.timeSlot}" on ${bookingData.date} is already reserved for this provider. Please select an alternative slot.`);
      }

      // 2. Insert into Supabase bookings table
      const { data: dbBooking, error: insErr } = await supabase
        .from('bookings')
        .insert({
          user_id: user.id,
          pet_id: bookingData.petId,
          service_id: bookingData.serviceId,
          provider_id: bookingData.providerId,
          booking_date: bookingData.date,
          booking_time: bookingData.timeSlot,
          status: 'PENDING',
          total_price: Number(bookingData.totalPrice),
          booking_notes: bookingData.bookingNotes || ''
        })
        .select()
        .single();

      if (insErr) {
        console.error('Booking insertion failed in Supabase:', insErr);
        if (insErr.code === '23505') {
          throw new Error(`Database Conflict: The slot "${bookingData.timeSlot}" on ${bookingData.date} is already occupied.`);
        }
        throw new Error(insErr.message || 'Failed to place booking.');
      }

      if (dbBooking) {
        newBooking.id = dbBooking.id;
        newBooking.createdAt = dbBooking.created_at?.split('T')[0] || newBooking.createdAt;
      }

      // 3. Store notification for user in Supabase
      try {
        await supabase.from('notifications').insert({
          user_id: user.id,
          title: 'New Booking Created',
          message: `Booking request placed for ${bookingData.serviceName} on ${bookingData.date} at ${bookingData.timeSlot}.`
        });
      } catch (notifErr) {
        console.warn('Notice creating booking notification:', notifErr);
      }
    } else {
      // Offline fallback conflict check
      const conflict = bookings.some(
        b => String(b.providerId) === String(bookingData.providerId) &&
             b.date === bookingData.date &&
             b.timeSlot === bookingData.timeSlot &&
             ['PENDING', 'CONFIRMED'].includes(b.status)
      );
      if (conflict) {
        throw new Error(`The slot "${bookingData.timeSlot}" on ${bookingData.date} is already reserved.`);
      }
    }

    setBookings(prev => [newBooking, ...prev]);

    // Local UI notification
    setNotifications(prev => [
      {
        id: 'notif-' + Date.now(),
        title: 'New Booking Created',
        message: `Booking request placed for ${newBooking.serviceName}.`,
        time: 'Just now',
        read: false
      },
      ...prev
    ]);

    return newBooking;
  };

  const updateBookingStatus = async (bookingId, newStatus) => {
    if (isSupabaseConfigured()) {
      const { error: updErr } = await supabase
        .from('bookings')
        .update({ status: newStatus })
        .eq('id', bookingId);

      if (updErr) {
        console.error('Supabase booking status update error:', updErr);
        throw new Error(updErr.message || 'Failed to update booking status.');
      }

      if (user) {
        try {
          await supabase.from('notifications').insert({
            user_id: user.id,
            title: `Booking ${newStatus}`,
            message: `Appointment ${bookingId} has been updated to ${newStatus}.`
          });
        } catch (nErr) {
          console.warn('Notice saving status notification:', nErr);
        }
      }
    }

    setBookings(prev => prev.map(b => String(b.id) === String(bookingId) ? { ...b, status: newStatus } : b));
    
    setNotifications(prev => [
      {
        id: 'notif-' + Date.now(),
        title: `Booking ${newStatus}`,
        message: `Appointment ${bookingId} has been updated to ${newStatus}.`,
        time: 'Just now',
        read: false
      },
      ...prev
    ]);
  };

  const cancelBooking = async (bookingId) => {
    return updateBookingStatus(bookingId, 'CANCELLED');
  };

  // ==========================================================================
  // REVIEWS & RATINGS
  // ==========================================================================
  const addReview = async (reviewData) => {
    const newRev = {
      ...reviewData,
      id: 'rev-' + Date.now(),
      date: new Date().toLocaleDateString('en-IN', { month: 'long', day: 'numeric', year: 'numeric' })
    };

    if (isSupabaseConfigured() && user) {
      const { data, error } = await supabase.from('reviews').insert({
        user_id: user.id,
        booking_id: reviewData.bookingId || null,
        provider_id: reviewData.providerId || null,
        service_id: reviewData.serviceId || null,
        rating: Number(reviewData.rating),
        review: reviewData.comment || reviewData.review || ''
      }).select().single();

      if (error) {
        console.error('Supabase review insertion error:', error);
        throw new Error(error.message || 'Failed to submit review.');
      }
      if (data) {
        newRev.id = data.id;
      }
    }

    setReviews(prev => [newRev, ...prev]);

    // Recalculate average rating for service locally
    if (reviewData.serviceId) {
      setServices(prev => prev.map(s => {
        if (String(s.id) === String(reviewData.serviceId)) {
          const updatedCount = (s.reviewsCount || 0) + 1;
          const updatedRating = Number((((s.rating * s.reviewsCount) + reviewData.rating) / updatedCount).toFixed(1));
          return { ...s, rating: updatedRating, reviewsCount: updatedCount };
        }
        return s;
      }));
    }
  };

  // ==========================================================================
  // PROVIDER VERIFICATION (ADMIN)
  // ==========================================================================
  const toggleProviderVerification = async (providerId) => {
    const currentProv = providers.find(p => String(p.id) === String(providerId));
    const nextVerified = currentProv ? !currentProv.verified : true;

    if (isSupabaseConfigured()) {
      const { error } = await supabase
        .from('providers')
        .update({ verified: nextVerified })
        .eq('id', providerId);

      if (error) {
        console.error('Supabase provider verification update error:', error);
        throw new Error(error.message || 'Failed to update verification status.');
      }
    }

    setProviders(prev => prev.map(p => {
      if (String(p.id) === String(providerId)) {
        return { ...p, verified: nextVerified };
      }
      return p;
    }));
  };

  // ==========================================================================
  // SERVICE MANAGEMENT (PROVIDER / ADMIN)
  // ==========================================================================
  const addService = async (serviceData) => {
    let newService = {
      ...serviceData,
      id: 'srv-' + Date.now(),
      rating: 5.0,
      reviewsCount: 1,
      featured: false
    };

    if (isSupabaseConfigured() && user) {
      const { data, error } = await supabase
        .from('services')
        .insert({
          provider_id: user.providerId || serviceData.providerId,
          category: serviceData.category,
          title: serviceData.name || serviceData.title,
          description: serviceData.description,
          price: Number(serviceData.price),
          image_url: serviceData.image || '',
          rating: 5.0
        })
        .select()
        .single();

      if (error) {
        console.error('Supabase service insertion error:', error);
        throw new Error(error.message || 'Failed to create service listing.');
      }
      if (data) {
        newService.id = data.id;
      }
    }

    setServices(prev => [newService, ...prev]);
    return newService;
  };

  const deleteService = async (serviceId) => {
    if (isSupabaseConfigured()) {
      const { error } = await supabase.from('services').delete().eq('id', serviceId);
      if (error) {
        console.error('Supabase service deletion error:', error);
        throw new Error(error.message || 'Failed to delete service listing.');
      }
    }

    setServices(prev => prev.filter(s => String(s.id) !== String(serviceId)));
  };

  // ==========================================================================
  // AI-BASED PERSONALIZED RECOMMENDATIONS
  // ==========================================================================
  const getPersonalizedRecommendations = (petId) => {
    const selectedPet = pets.find(p => String(p.id) === String(petId)) || pets[0];
    if (!selectedPet) return services.slice(0, 3);

    return services.filter(service => {
      if (selectedPet.age <= 1 && service.category === 'training') return true;
      if (selectedPet.age >= 6 && service.category === 'vet') return true;
      if ((selectedPet.breed?.includes('Retriever') || selectedPet.breed?.includes('Persian') || selectedPet.breed?.includes('Poodle')) && service.category === 'grooming') {
        return true;
      }
      if ((selectedPet.breed?.includes('Retriever') || selectedPet.breed?.includes('Beagle') || selectedPet.breed?.includes('German')) && (service.category === 'walking' || service.category === 'daycare')) {
        return true;
      }
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
      loading,
      fetchError,
      refreshData: fetchSupabaseData,
      addPet,
      updatePet,
      deletePet,
      checkSlotAvailability,
      checkProviderAvailability,
      createBooking,
      updateBookingStatus,
      cancelBooking,
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
