import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { MarketplaceProvider } from './context/MarketplaceContext';
import Navbar from './layouts/Navbar';
import Footer from './layouts/Footer';
import ScrollToTop from './components/ScrollToTop';
import AdminRoute from './components/AdminRoute';

// Pages
import HomePage from './pages/HomePage';
import ServicesPage from './pages/ServicesPage';
import ServiceDetailPage from './pages/ServiceDetailPage';
import AIAssistantPage from './pages/AIAssistantPage';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import ForgotPasswordPage from './pages/ForgotPasswordPage';
import OwnerDashboardPage from './pages/OwnerDashboardPage';
import PetsManagementPage from './pages/PetsManagementPage';
import ProviderDashboardPage from './pages/ProviderDashboardPage';
import AdminDashboardPage from './pages/AdminDashboardPage';
import AboutPage from './pages/AboutPage';
import ContactPage from './pages/ContactPage';

import './styles/global.css';

function App() {
  return (
    <AuthProvider>
      <MarketplaceProvider>
        <BrowserRouter>
          <ScrollToTop />
          <div className="app-layout">
            <Navbar />
            <main className="main-content">
              <Routes>
                <Route path="/" element={<HomePage />} />
                <Route path="/services" element={<ServicesPage />} />
                <Route path="/services/:id" element={<ServiceDetailPage />} />
                <Route path="/ai-assistant" element={<AIAssistantPage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/register" element={<RegisterPage />} />
                <Route path="/forgot-password" element={<ForgotPasswordPage />} />
                <Route path="/owner-dashboard" element={<OwnerDashboardPage />} />
                <Route path="/pets" element={<PetsManagementPage />} />
                <Route path="/provider-dashboard" element={<ProviderDashboardPage />} />
                <Route 
                  path="/admin" 
                  element={
                    <AdminRoute>
                      <AdminDashboardPage />
                    </AdminRoute>
                  } 
                />
                <Route path="/about" element={<AboutPage />} />
                <Route path="/contact" element={<ContactPage />} />
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </main>
            <Footer />
          </div>
        </BrowserRouter>
      </MarketplaceProvider>
    </AuthProvider>
  );
}

export default App;
