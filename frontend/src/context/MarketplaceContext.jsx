import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase, isSupabaseConfigured } from '../services/supabaseClient';
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

// Category name resolver
const getCategoryTitle = (catSlug) => {
  const match = CATEGORIES.find(c => c.id === catSlug || c.slug === catSlug);
  return match ? match.name : 'Pet Care Service';
};

export const MarketplaceProvider = ({ children }) => {
  const { user } = useAuth();

  // State initialization with local cache fallback
  const [services, setServices] = useState(() => {
    const saved = localStorage.getItem('petcare_services');
    return saved ? JSON.parse(saved) : INITIAL_SERVICES;
  });

  const [providers, setProviders] = useState(() => {
    const saved = localStorage.getItem('petcare_providers');
    return saved ? JSON.parse(saved) : INITIAL_PROVIDERS;
  });

  const [pets, setPets] = useState(() => {
    const saved = localStorage.getItem('petcare_pets');
    return saved ? JSON.parse(saved) : INITIAL_PETS;
  });

  const [bookings, setBookings] = useState(() => {
    const saved = localStorage.getItem('petcare_bookings');
    return saved ? JSON.parse(saved) : INITIAL_BOOKINGS;
  });

  const [reviews, setReviews] = useState(() => {
    const saved = localStorage.getItem('petcare_reviews');
    return saved ? JSON.parse(saved) : INITIAL_REVIEWS;
  });

  const [notifications, setNotifications] = useState([
    {
      id: 'notif-1',
      title: 'Appointment Confirmed',
      message: 'Dr. Aarav Sharma confirmed your wellness exam for Bruno on Nov 08.',
      time: '2 hours ago',
      read: false
    },
    {
      id: 'notif-2',
      title: 'Vaccination Due Reminder',
      message: 'Bruno is due for annual booster vaccination in 4 weeks.',
      time: '1 day ago',
      read: true
    }
  ]);

  const [loading, setLoading] = useState(false);
  const [fetchError, setFetchError] = useState(null);

  // Synchronize state with Supabase PostgreSQL Database
  const fetchSupabaseData = useCallback(async () => {
    if (!isSupabaseConfigured()) {
      return;
    }

    setLoading(true);
    setFetchError(null);

    try {
      // 1. Fetch Providers with joined Users
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
          users:user_id (
            full_name,
            email,
            phone,
            avatar_url
          )
        `);

      if (!provErr && dbProviders && dbProviders.length > 0) {
        const mappedProviders = dbProviders.map(p => ({
          id: p.id,
          userId: p.user_id,
          name: p.users?.full_name || 'Verified Provider',
          businessName: p.business_name,
          email: p.users?.email || '',
          phone: p.users?.phone || '+91 98450 12345',
          city: p.location,
          area: p.location,
          address: `${p.business_name}, ${p.location}`,
          rating: Number(p.rating || 5.0),
          reviewsCount: p.reviews_count || 0,
          verified: !!p.verified,
          avatar: p.users?.avatar_url || 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80',
          bio: p.description || 'Dedicated pet care specialist.',
          servicesCount: 3
        }));
        setProviders(mappedProviders);
      }

      // 2. Fetch Services with joined Providers
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
          providers:provider_id (
            id,
            business_name,
            location,
            verified,
            users:user_id (
              full_name
            )
          )
        `)
        .eq('active', true);

      if (!servErr && dbServices && dbServices.length > 0) {
        const mappedServices = dbServices.map(s => ({
          id: s.id,
          name: s.title,
          category: s.category,
          categoryName: getCategoryTitle(s.category),
          providerId: s.provider_id,
          providerName: s.providers?.users?.full_name || s.providers?.business_name || 'Pet Care Specialist',
          businessName: s.providers?.business_name || 'Care Center',
          city: s.providers?.location || 'Bengaluru',
          area: s.providers?.location || 'Indiranagar',
          price: Number(s.price),
          priceUnit: 'per consultation',
          duration: s.duration || '45 mins',
          rating: Number(s.rating || 5.0),
          reviewsCount: 42,
          featured: !!s.featured,
          image: s.image_url || 'https://images.unsplash.com/photo-1628009368231-7bb7cfcb0def?auto=format&fit=crop&w=800&q=80',
          description: s.description,
          included: [
            'Professional clinical or hygiene care',
            'Safe, sterilized environment',
            'Dedicated handler support'
          ],
          availableSlots: s.available_slots || ['09:30 AM', '11:00 AM', '02:30 PM', '04:30 PM', '06:00 PM']
        }));
        setServices(mappedServices);
      }

      // 3. Fetch Pets (RLS isolates to owner unless admin)
      let petQuery = supabase.from('pets').select('*');
      if (user && user.role !== 'ADMIN') {
        petQuery = petQuery.eq('owner_id', user.id);
      }
      const { data: dbPets, error: petErr } = await petQuery;

      if (!petErr && dbPets && dbPets.length > 0) {
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

      // 4. Fetch Bookings
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
          services:service_id (title, category),
          providers:provider_id (business_name, location, users:user_id(full_name)),
          pets:pet_id (name, breed)
        `)
        .order('created_at', { ascending: false });

      if (user && user.role === 'SERVICE_PROVIDER' && user.providerId) {
        bkQuery = bkQuery.eq('provider_id', user.providerId);
      } else if (user && user.role !== 'ADMIN') {
        bkQuery = bkQuery.eq('user_id', user.id);
      }

      const { data: dbBookings, error: bkErr } = await bkQuery;
      if (!bkErr && dbBookings && dbBookings.length > 0) {
        const mappedBookings = dbBookings.map(b => ({
          id: b.id,
          serviceId: b.service_id,
          serviceName: b.services?.title || 'Pet Service',
          category: b.services?.category || 'vet',
          providerId: b.provider_id,
          providerName: b.providers?.users?.full_name || b.providers?.business_name || 'Care Specialist',
          businessName: b.providers?.business_name || 'Pet Clinic',
          petId: b.pet_id,
          petName: b.pets ? `${b.pets.name} (${b.pets.breed})` : 'Registered Companion',
          date: b.booking_date,
          timeSlot: b.booking_time,
          totalPrice: Number(b.total_price),
          status: b.status,
          bookingNotes: b.booking_notes || 'Standard booking.',
          createdAt: b.created_at?.split('T')[0] || new Date().toISOString().split('T')[0]
        }));
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
          users:user_id (full_name),
          services:service_id (title),
          providers:provider_id (business_name)
        `)
        .order('created_at', { ascending: false });

      if (!revErr && dbReviews && dbReviews.length > 0) {
        const mappedReviews = dbReviews.map(r => ({
          id: r.id,
          userName: r.users?.full_name || 'Happy Pet Parent',
          userCity: 'Bengaluru',
          serviceName: r.services?.title || 'Pet Care Service',
          providerName: r.providers?.business_name || 'Care Provider',
          rating: r.rating,
          date: new Date(r.created_at).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }),
          comment: r.review
        }));
        setReviews(mappedReviews);
      }

      // 6. Fetch Notifications
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
      console.warn('Supabase data synchronization notice:', err);
      setFetchError(err.message);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchSupabaseData();
  }, [fetchSupabaseData]);

  // Save to localStorage as secondary offline cache
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

  // ==========================================
  // PET PROFILE MANAGEMENT (CRUD)
  // ==========================================
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
      try {
        const { data, error } = await supabase
          .from('pets')
          .insert({
            owner_id: user.id,
            name: petData.name,
            animal_type: petData.type || 'Dog',
            breed: petData.breed,
            age: Number(petData.age) || 1,
            gender: petData.gender || 'Male',
            weight: petData.weight || '10 kg',
            vaccination_details: petData.vaccinations || '',
            medical_history: petData.medicalHistory || '',
            image_url: newPet.photo
          })
          .select()
          .single();

        if (error) throw error;
        if (data) {
          newPet.id = data.id;
        }
      } catch (err) {
        console.error('Supabase pet insertion failed:', err);
      }
    }

    setPets(prev => [newPet, ...prev]);
    return newPet;
  };

  const updatePet = async (id, updatedFields) => {
    if (isSupabaseConfigured()) {
      try {
        await supabase
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
      } catch (err) {
        console.error('Supabase pet update failed:', err);
      }
    }

    setPets(prev => prev.map(p => String(p.id) === String(id) ? { ...p, ...updatedFields } : p));
  };

  const deletePet = async (id) => {
    if (isSupabaseConfigured()) {
      try {
        await supabase.from('pets').delete().eq('id', id);
      } catch (err) {
        console.error('Supabase pet deletion failed:', err);
      }
    }

    setPets(prev => prev.filter(p => String(p.id) !== String(id)));
  };

  // ==========================================
  // BOOKING WORKFLOW & CONFLICT PREVENTION
  // ==========================================
  const checkSlotAvailability = (providerId, date, timeSlot) => {
    const conflict = bookings.some(
      b => String(b.providerId) === String(providerId) &&
           b.date === date &&
           b.timeSlot === timeSlot &&
           b.status !== 'CANCELLED'
    );
    return !conflict;
  };

  const createBooking = async (bookingData) => {
    // 1. Prevent conflicting double bookings for identical provider, date and slot
    const isAvailable = checkSlotAvailability(
      bookingData.providerId,
      bookingData.date,
      bookingData.timeSlot
    );

    if (!isAvailable) {
      throw new Error(`The slot "${bookingData.timeSlot}" on ${bookingData.date} is already reserved for this provider. Please select an alternative slot.`);
    }

    let newBooking = {
      ...bookingData,
      id: 'BK-' + Math.floor(1000 + Math.random() * 9000),
      status: 'PENDING',
      createdAt: new Date().toISOString().split('T')[0]
    };

    if (isSupabaseConfigured() && user) {
      try {
        // Query live Supabase table for double-booking conflict
        const { data: existingSlots } = await supabase
          .from('bookings')
          .select('id')
          .eq('provider_id', bookingData.providerId)
          .eq('booking_date', bookingData.date)
          .eq('booking_time', bookingData.timeSlot)
          .neq('status', 'CANCELLED');

        if (existingSlots && existingSlots.length > 0) {
          throw new Error(`The slot "${bookingData.timeSlot}" on ${bookingData.date} is already reserved in the database.`);
        }

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
          console.warn('Booking insert into Supabase returned notice:', insErr);
        } else if (dbBooking) {
          newBooking.id = dbBooking.id;
        }

        // Store notification
        await supabase.from('notifications').insert({
          user_id: user.id,
          title: 'New Booking Created',
          message: `Booking request placed for ${bookingData.serviceName} on ${bookingData.date}.`
        });
      } catch (err) {
        console.warn('Supabase booking notice:', err);
      }
    }

    setBookings(prev => [newBooking, ...prev]);

    // Push local notification
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
      try {
        await supabase
          .from('bookings')
          .update({ status: newStatus })
          .eq('id', bookingId);

        if (user) {
          await supabase.from('notifications').insert({
            user_id: user.id,
            title: `Booking ${newStatus}`,
            message: `Appointment ${bookingId} has been updated to ${newStatus}.`
          });
        }
      } catch (err) {
        console.error('Supabase booking status update error:', err);
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

  // ==========================================
  // REVIEWS & RATINGS
  // ==========================================
  const addReview = async (reviewData) => {
    const newRev = {
      ...reviewData,
      id: 'rev-' + Date.now(),
      date: new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
    };

    if (isSupabaseConfigured() && user) {
      try {
        await supabase.from('reviews').insert({
          user_id: user.id,
          booking_id: reviewData.bookingId || null,
          provider_id: reviewData.providerId || null,
          service_id: reviewData.serviceId || null,
          rating: Number(reviewData.rating),
          review: reviewData.comment || reviewData.review || ''
        });
      } catch (err) {
        console.error('Supabase review insertion error:', err);
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

  // ==========================================
  // PROVIDER VERIFICATION (ADMIN)
  // ==========================================
  const toggleProviderVerification = async (providerId) => {
    const currentProv = providers.find(p => String(p.id) === String(providerId));
    const nextVerified = currentProv ? !currentProv.verified : true;

    if (isSupabaseConfigured()) {
      try {
        await supabase
          .from('providers')
          .update({ verified: nextVerified })
          .eq('id', providerId);
      } catch (err) {
        console.error('Supabase provider verification update error:', err);
      }
    }

    setProviders(prev => prev.map(p => {
      if (String(p.id) === String(providerId)) {
        return { ...p, verified: nextVerified };
      }
      return p;
    }));
  };

  // ==========================================
  // SERVICE MANAGEMENT (PROVIDER / ADMIN)
  // ==========================================
  const addService = async (serviceData) => {
    let newService = {
      ...serviceData,
      id: 'srv-' + Date.now(),
      rating: 5.0,
      reviewsCount: 1,
      featured: false
    };

    if (isSupabaseConfigured() && user) {
      try {
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

        if (!error && data) {
          newService.id = data.id;
        }
      } catch (err) {
        console.error('Supabase service insertion error:', err);
      }
    }

    setServices(prev => [newService, ...prev]);
    return newService;
  };

  const deleteService = async (serviceId) => {
    if (isSupabaseConfigured()) {
      try {
        await supabase.from('services').delete().eq('id', serviceId);
      } catch (err) {
        console.error('Supabase service deletion error:', err);
      }
    }

    setServices(prev => prev.filter(s => String(s.id) !== String(serviceId)));
  };

  // ==========================================
  // AI-BASED SERVICE RECOMMENDATIONS
  // ==========================================
  const getPersonalizedRecommendations = (petId) => {
    const selectedPet = pets.find(p => String(p.id) === String(petId)) || pets[0];
    if (!selectedPet) return services.slice(0, 3);

    return services.filter(service => {
      // Logic for puppies or senior pets
      if (selectedPet.age <= 1 && service.category === 'training') return true;
      if (selectedPet.age >= 6 && service.category === 'vet') return true;
      
      // Breed specific grooming
      if ((selectedPet.breed?.includes('Retriever') || selectedPet.breed?.includes('Persian') || selectedPet.breed?.includes('Poodle')) && service.category === 'grooming') {
        return true;
      }

      // High-energy breeds
      if ((selectedPet.breed?.includes('Retriever') || selectedPet.breed?.includes('Beagle') || selectedPet.breed?.includes('German')) && (service.category === 'walking' || service.category === 'daycare')) {
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
      loading,
      fetchError,
      refreshData: fetchSupabaseData,
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
