import React, { createContext, useContext, useState, useEffect } from 'react';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  // Pre-configured default demo users for seamless academic evaluation
  const defaultUser = {
    id: 10,
    name: 'Priya Sundaram',
    email: 'priya.petowner@example.com',
    role: 'PET_OWNER', // 'PET_OWNER' | 'SERVICE_PROVIDER' | 'ADMIN'
    phone: '+91 98765 43210',
    city: 'Bengaluru',
    avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80'
  };

  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('petcare_user');
    return saved ? JSON.parse(saved) : defaultUser;
  });

  const [token, setToken] = useState(() => {
    return localStorage.getItem('petcare_token') || 'demo-jwt-token-xyz-123';
  });

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

  const login = (email, password, requestedRole = 'PET_OWNER') => {
    let mockUser;
    if (requestedRole === 'ADMIN' || email.includes('admin')) {
      mockUser = {
        id: 1,
        name: 'System Administrator',
        email: email || 'admin@petcare.org',
        role: 'ADMIN',
        city: 'Bengaluru',
        avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=400&q=80'
      };
    } else if (requestedRole === 'SERVICE_PROVIDER' || email.includes('provider')) {
      mockUser = {
        id: 1, // Dr Aarav Sharma in PROVIDERS
        name: 'Dr. Aarav Sharma',
        businessName: 'Paws & Claws Veterinary Wellness',
        email: email || 'aarav.vet@example.com',
        role: 'SERVICE_PROVIDER',
        city: 'Bengaluru',
        avatar: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80'
      };
    } else {
      mockUser = {
        id: 10,
        name: 'Priya Sundaram',
        email: email || 'priya.petowner@example.com',
        role: 'PET_OWNER',
        phone: '+91 98765 43210',
        city: 'Bengaluru',
        avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80'
      };
    }
    setUser(mockUser);
    setToken('jwt-session-token-' + Date.now());
    return { success: true, user: mockUser };
  };

  const register = (userData) => {
    // Academic validation: Administrators cannot be self-registered publicly
    const assignedRole = userData.role === 'ADMIN' ? 'PET_OWNER' : (userData.role || 'PET_OWNER');
    
    const newUser = {
      id: Date.now(),
      name: userData.name,
      email: userData.email,
      role: assignedRole,
      phone: userData.phone || '+91 99000 00000',
      city: userData.city || 'Bengaluru',
      businessName: userData.businessName || '',
      avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80'
    };
    setUser(newUser);
    setToken('jwt-session-token-' + Date.now());
    return { success: true, user: newUser };
  };

  const switchRole = (newRole) => {
    if (newRole === 'ADMIN') {
      login('admin@petcare.org', 'admin123', 'ADMIN');
    } else if (newRole === 'SERVICE_PROVIDER') {
      login('aarav.vet@example.com', 'provider123', 'SERVICE_PROVIDER');
    } else {
      login('priya.petowner@example.com', 'owner123', 'PET_OWNER');
    }
  };

  const logout = () => {
    setUser(null);
    setToken(null);
    localStorage.removeItem('petcare_user');
    localStorage.removeItem('petcare_token');
  };

  return (
    <AuthContext.Provider value={{ user, token, isAuthenticated: !!user, login, register, logout, switchRole }}>
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
