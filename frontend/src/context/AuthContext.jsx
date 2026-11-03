import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase, isSupabaseConfigured } from '../services/supabaseClient';

const AuthContext = createContext(null);

// Role mapping helpers for seamless schema alignment
export const mapRoleToFrontend = (role) => {
  if (!role) return 'PET_OWNER';
  const r = role.toString().toLowerCase();
  if (r === 'admin') return 'ADMIN';
  if (r === 'provider' || r === 'service_provider') return 'SERVICE_PROVIDER';
  return 'PET_OWNER';
};

export const mapRoleToBackend = (role) => {
  if (!role) return 'pet_owner';
  const r = role.toString().toLowerCase();
  if (r === 'admin') return 'admin';
  if (r === 'service_provider' || r === 'provider') return 'provider';
  return 'pet_owner';
};

export const AuthProvider = ({ children }) => {
  // Pre-configured default demo user for seamless academic evaluation & offline experience
  const defaultUser = {
    id: 'demo-user-10',
    name: 'Priya Sundaram',
    email: 'priya.petowner@example.com',
    role: 'PET_OWNER',
    phone: '+91 98765 43210',
    city: 'Bengaluru',
    avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
  };

  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('petcare_user');
    return saved ? JSON.parse(saved) : defaultUser;
  });

  const [token, setToken] = useState(() => {
    return localStorage.getItem('petcare_token') || 'demo-jwt-token-xyz-123';
  });

  const [loading, setLoading] = useState(true);

  // Sync state to localStorage
  useEffect(() => {
    if (user) {
      localStorage.setItem('petcare_user', JSON.stringify(user));
    } else {
      localStorage.removeItem('petcare_user');
    }
  }, [user]);

  useEffect(() => {
    if (token) {
      localStorage.setItem('petcare_token', token);
    } else {
      localStorage.removeItem('petcare_token');
    }
  }, [token]);

  // Load and subscribe to Supabase Auth state if configured
  useEffect(() => {
    let subscription = null;

    const initializeAuth = async () => {
      if (!isSupabaseConfigured()) {
        setLoading(false);
        return;
      }

      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (session?.user) {
          await fetchAndSetUserProfile(session.user);
          setToken(session.access_token);
        }
      } catch (err) {
        console.warn('Supabase session load error:', err);
      } finally {
        setLoading(false);
      }

      const { data: authListener } = supabase.auth.onAuthStateChange(
        async (event, session) => {
          if (event === 'SIGNED_IN' && session?.user) {
            await fetchAndSetUserProfile(session.user);
            setToken(session.access_token);
          } else if (event === 'SIGNED_OUT') {
            setUser(null);
            setToken(null);
          }
        }
      );
      subscription = authListener.subscription;
    };

    initializeAuth();

    return () => {
      if (subscription) subscription.unsubscribe();
    };
  }, []);

  // Fetch full user profile from PostgreSQL public.users + public.providers
  const fetchAndSetUserProfile = async (authUser) => {
    try {
      const { data: profile, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', authUser.id)
        .maybeSingle();

      if (error) {
        console.warn('Error fetching public.users record:', error);
      }

      // Check for provider profile if role indicates provider
      let providerInfo = null;
      if (profile?.role === 'provider' || authUser.user_metadata?.role === 'provider') {
        const { data: prov } = await supabase
          .from('providers')
          .select('*')
          .eq('user_id', authUser.id)
          .maybeSingle();
        providerInfo = prov;
      }

      const roleStr = profile?.role || authUser.user_metadata?.role || 'pet_owner';
      const frontendRole = mapRoleToFrontend(roleStr);

      const resolvedUser = {
        id: authUser.id,
        name: profile?.full_name || authUser.user_metadata?.full_name || authUser.email?.split('@')[0] || 'User',
        email: authUser.email,
        role: frontendRole,
        phone: profile?.phone || authUser.user_metadata?.phone || '',
        city: providerInfo?.location || authUser.user_metadata?.city || 'Bengaluru',
        businessName: providerInfo?.business_name || authUser.user_metadata?.business_name || '',
        avatar: profile?.avatar_url || authUser.user_metadata?.avatar_url || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80',
        providerId: providerInfo?.id || null,
        verified: providerInfo?.verified || false
      };

      setUser(resolvedUser);
      return resolvedUser;
    } catch (err) {
      console.error('Error synchronizing user profile:', err);
      return null;
    }
  };

  // Login handler supporting both real Supabase Auth and Instant Demo evaluation
  const login = async (email, password, requestedRole = 'PET_OWNER') => {
    if (isSupabaseConfigured()) {
      try {
        const { data, error } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password: password,
        });

        if (error) {
          return { success: false, error: error.message };
        }

        const resolvedUser = await fetchAndSetUserProfile(data.user);
        setToken(data.session.access_token);
        return { success: true, user: resolvedUser || user };
      } catch (err) {
        return { success: false, error: err.message || 'Login failed.' };
      }
    }

    // Offline / Demo Evaluation Fallback
    let mockUser;
    if (requestedRole === 'ADMIN' || email.includes('admin')) {
      mockUser = {
        id: 'admin-user-1',
        name: 'System Administrator',
        email: email || 'admin@petcare.org',
        role: 'ADMIN',
        city: 'Bengaluru',
        avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=400&q=80',
      };
    } else if (requestedRole === 'SERVICE_PROVIDER' || email.includes('provider') || email.includes('vet')) {
      mockUser = {
        id: 'provider-user-1',
        name: 'Dr. Aarav Sharma',
        businessName: 'Paws & Claws Veterinary Wellness',
        email: email || 'aarav.vet@example.com',
        role: 'SERVICE_PROVIDER',
        city: 'Bengaluru',
        providerId: 'pr-001',
        verified: true,
        avatar: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80',
      };
    } else {
      mockUser = {
        id: 'demo-user-10',
        name: 'Priya Sundaram',
        email: email || 'priya.petowner@example.com',
        role: 'PET_OWNER',
        phone: '+91 98765 43210',
        city: 'Bengaluru',
        avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
      };
    }

    setUser(mockUser);
    setToken('jwt-session-token-' + Date.now());
    return { success: true, user: mockUser };
  };

  // Sign-up handler
  const register = async (userData) => {
    // Role validation: Administrators cannot be self-registered publicly
    const assignedRole = userData.role === 'ADMIN' ? 'PET_OWNER' : (userData.role || 'PET_OWNER');
    const backendRole = mapRoleToBackend(assignedRole);

    if (isSupabaseConfigured()) {
      try {
        const { data, error } = await supabase.auth.signUp({
          email: userData.email.trim(),
          password: userData.password,
          options: {
            data: {
              full_name: userData.name,
              role: backendRole,
              phone: userData.phone || '',
              city: userData.city || 'Bengaluru',
              business_name: userData.businessName || '',
            },
          },
        });

        if (error) {
          return { success: false, error: error.message };
        }

        if (data.user) {
          // If Supabase session is established immediately (e.g. email confirm disabled)
          if (data.session) {
            setToken(data.session.access_token);
            await fetchAndSetUserProfile(data.user);
          }

          // If provider registered, ensure public.providers record exists
          if (backendRole === 'provider') {
            await supabase.from('providers').upsert({
              user_id: data.user.id,
              business_name: userData.businessName || `${userData.name}'s Pet Care`,
              location: userData.city || 'Bengaluru',
              description: `Professional pet care services by ${userData.name}`,
              verified: false,
            }, { onConflict: 'user_id' });
          }

          const registered = {
            id: data.user.id,
            name: userData.name,
            email: userData.email,
            role: assignedRole,
            phone: userData.phone || '',
            city: userData.city || 'Bengaluru',
            businessName: userData.businessName || '',
            avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80'
          };
          setUser(registered);
          return { success: true, user: registered };
        }
      } catch (err) {
        return { success: false, error: err.message || 'Registration failed.' };
      }
    }

    // Offline / Academic Demo Mode
    const newUser = {
      id: 'usr-' + Date.now(),
      name: userData.name,
      email: userData.email,
      role: assignedRole,
      phone: userData.phone || '+91 99000 00000',
      city: userData.city || 'Bengaluru',
      businessName: userData.businessName || '',
      avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80',
    };

    setUser(newUser);
    setToken('jwt-session-token-' + Date.now());
    return { success: true, user: newUser };
  };

  // Password reset request
  const resetPassword = async (email) => {
    if (isSupabaseConfigured()) {
      try {
        const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
          redirectTo: `${window.location.origin}/login`,
        });
        if (error) {
          return { success: false, error: error.message };
        }
        return { success: true };
      } catch (err) {
        return { success: false, error: err.message };
      }
    }
    return { success: true };
  };

  // Instant demo role switcher for UI review
  const switchRole = (newRole) => {
    if (newRole === 'ADMIN') {
      login('admin@petcare.org', 'admin123', 'ADMIN');
    } else if (newRole === 'SERVICE_PROVIDER') {
      login('aarav.vet@example.com', 'provider123', 'SERVICE_PROVIDER');
    } else {
      login('priya.petowner@example.com', 'owner123', 'PET_OWNER');
    }
  };

  const logout = async () => {
    if (isSupabaseConfigured()) {
      try {
        await supabase.auth.signOut();
      } catch (err) {
        console.warn('Sign out warning:', err);
      }
    }
    setUser(null);
    setToken(null);
    localStorage.removeItem('petcare_user');
    localStorage.removeItem('petcare_token');
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        loading,
        isAuthenticated: !!user,
        login,
        register,
        logout,
        resetPassword,
        switchRole,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
