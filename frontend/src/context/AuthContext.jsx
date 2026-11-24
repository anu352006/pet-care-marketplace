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
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('petcare_user');
    try {
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  const [token, setToken] = useState(() => {
    return localStorage.getItem('petcare_token') || null;
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
        } else {
          // No active Supabase session: ensure clean guest state
          setUser(null);
          setToken(null);
          localStorage.removeItem('petcare_user');
          localStorage.removeItem('petcare_token');
        }
      } catch (err) {
        console.warn('Supabase session load error:', err);
        setUser(null);
        setToken(null);
      } finally {
        setLoading(false);
      }

      const { data: authListener } = supabase.auth.onAuthStateChange(
        async (event, session) => {
          if ((event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED') && session?.user) {
            await fetchAndSetUserProfile(session.user);
            setToken(session.access_token);
          } else if (event === 'SIGNED_OUT') {
            setUser(null);
            setToken(null);
            localStorage.removeItem('petcare_user');
            localStorage.removeItem('petcare_token');
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

  // Login handler supporting real Supabase Auth
  const login = async (email, password, requestedRole = 'PET_OWNER') => {
    if (isSupabaseConfigured()) {
      try {
        const { data, error } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password: password,
        });

        if (error) {
          return { success: false, error: error.message || 'Invalid email or password.' };
        }

        if (data?.session?.user) {
          const resolvedUser = await fetchAndSetUserProfile(data.user);
          setToken(data.session.access_token);
          return { success: true, user: resolvedUser || user };
        }

        return { success: false, error: 'Authentication failed. Please verify your credentials.' };
      } catch (err) {
        return { success: false, error: err.message || 'Login failed.' };
      }
    }

    // Offline / Demo Evaluation Fallback only if Supabase credentials are not configured
    let mockUser;
    if (requestedRole === 'ADMIN' || email.includes('admin') || email.toLowerCase() === 'ananya03052006@gmail.com') {
      mockUser = {
        id: 'admin-user-1',
        name: 'System Administrator',
        email: email || 'ananya03052006@gmail.com',
        role: 'ADMIN',
        city: 'Bengaluru',
        avatar: '/images/testimonials/user-arun.jpg',
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
        avatar: '/images/providers/provider-aarav.jpg',
      };
    } else {
      mockUser = {
        id: 'demo-user-10',
        name: 'Priya Sundaram',
        email: email || 'priya.petowner@example.com',
        role: 'PET_OWNER',
        phone: '+91 98765 43210',
        city: 'Bengaluru',
        avatar: '/images/testimonials/user-kavita.jpg',
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
          } else {
            // Attempt immediate sign-in if email confirmation is not enforced
            try {
              const { data: signInAfterReg } = await supabase.auth.signInWithPassword({
                email: userData.email.trim(),
                password: userData.password,
              });
              if (signInAfterReg?.session) {
                setToken(signInAfterReg.session.access_token);
                await fetchAndSetUserProfile(signInAfterReg.user);
              }
            } catch {
              // Email confirmation required or pending
            }
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
            avatar: '/images/testimonials/user-kavita.jpg'
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
      avatar: '/images/testimonials/user-kavita.jpg',
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

  // Profile update handler
  const updateProfile = async (profileData) => {
    if (!user) throw new Error('Authentication required.');

    const updatedUser = {
      ...user,
      name: profileData.name !== undefined ? profileData.name : user.name,
      phone: profileData.phone !== undefined ? profileData.phone : user.phone,
      city: profileData.city !== undefined ? profileData.city : user.city,
      businessName: profileData.businessName !== undefined ? profileData.businessName : user.businessName,
      avatar: profileData.avatar !== undefined ? profileData.avatar : user.avatar,
    };

    if (isSupabaseConfigured() && user.id) {
      // 1. Update public.users
      const { error: userErr } = await supabase
        .from('users')
        .update({
          full_name: updatedUser.name,
          phone: updatedUser.phone,
          avatar_url: updatedUser.avatar,
        })
        .eq('id', user.id);

      if (userErr) {
        console.error('Failed to update public.users profile:', userErr);
        throw new Error(userErr.message || 'Failed to update profile.');
      }

      // 2. If provider, update public.providers
      if (user.role === 'SERVICE_PROVIDER' && user.providerId) {
        const { error: provErr } = await supabase
          .from('providers')
          .update({
            business_name: updatedUser.businessName,
            location: updatedUser.city,
          })
          .eq('id', user.providerId);

        if (provErr) {
          console.error('Failed to update provider record:', provErr);
        }
      }
    }

    setUser(updatedUser);
    localStorage.setItem('petcare_user', JSON.stringify(updatedUser));
    return updatedUser;
  };

  // Role switcher: signs out and clears current session for explicit re-authentication
  const switchRole = async () => {
    await logout();
    window.location.href = '/login';
    return { success: true };
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
        updateProfile,
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
