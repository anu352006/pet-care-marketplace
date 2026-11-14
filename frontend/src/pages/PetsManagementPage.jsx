import React, { useState } from 'react';
import { useMarketplace, getPetTypeDefaultImage } from '../context/MarketplaceContext';
import { uploadStorageFile } from '../services/supabaseClient';
import { PET_TYPES } from '../services/mockData';
import { 
  Heart, 
  Plus, 
  Edit3, 
  Trash2, 
  ShieldCheck, 
  FileText, 
  X, 
  Check, 
  AlertTriangle,
  Scale,
  Calendar,
  Sparkles,
  Upload,
  Filter
} from 'lucide-react';
import './PetsManagementPage.css';

const PetsManagementPage = () => {
  const { pets, addPet, updatePet, deletePet } = useMarketplace();

  // Filter state
  const [selectedTypeFilter, setSelectedTypeFilter] = useState('All');

  // Modal states
  const [showModal, setShowModal] = useState(false);
  const [editingPet, setEditingPet] = useState(null);
  const [deleteConfirmId, setDeleteConfirmId] = useState(null);

  // Form states
  const [name, setName] = useState('');
  const [type, setType] = useState('Dog');
  const [breed, setBreed] = useState('');
  const [age, setAge] = useState(2);
  const [gender, setGender] = useState('Male');
  const [weight, setWeight] = useState('');
  const [photo, setPhoto] = useState('');
  const [vaccinations, setVaccinations] = useState('');
  const [medicalHistory, setMedicalHistory] = useState('');
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const [formError, setFormError] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  const openAddModal = () => {
    setEditingPet(null);
    setFormError('');
    setName('');
    setType('Dog');
    setBreed('');
    setAge(2);
    setGender('Male');
    setWeight('');
    setPhoto('');
    setVaccinations('Rabies (Up to date), Core Boosters (Up to date)');
    setMedicalHistory('No known chronic allergies.');
    setShowModal(true);
  };

  const openEditModal = (pet) => {
    setEditingPet(pet);
    setFormError('');
    setName(pet.name);
    setType(pet.type);
    setBreed(pet.breed);
    setAge(pet.age);
    setGender(pet.gender);
    setWeight(pet.weight);
    setPhoto(pet.photo);
    setVaccinations(pet.vaccinations || '');
    setMedicalHistory(pet.medicalHistory || '');
    setShowModal(true);
  };

  const handleFileUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setFormError('');
    try {
      setUploadingPhoto(true);
      const uploadedUrl = await uploadStorageFile('pet-images', file, 'pets');
      setPhoto(uploadedUrl);
    } catch (err) {
      console.warn('Storage upload error:', err);
      setFormError('Failed to upload image to storage. Make sure your Supabase project is reachable.');
    } finally {
      setUploadingPhoto(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setFormError('');
    setIsSaving(true);

    const petPayload = {
      name,
      type,
      breed: breed || 'Mixed Breed',
      age: Number(age),
      gender,
      weight: weight ? (weight.includes('kg') || weight.includes('g') ? weight : `${weight} kg`) : '12 kg',
      photo: photo || getPetTypeDefaultImage(type),
      vaccinations,
      medicalHistory
    };

    try {
      if (editingPet) {
        await updatePet(editingPet.id, petPayload);
      } else {
        await addPet(petPayload);
      }
      setShowModal(false);
    } catch (err) {
      setFormError(err.message || 'Failed to save pet profile.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (id) => {
    await deletePet(id);
    setDeleteConfirmId(null);
  };

  const filteredPets = selectedTypeFilter === 'All' 
    ? pets 
    : pets.filter(p => (p.type || '').toLowerCase() === selectedTypeFilter.toLowerCase());

  return (
    <div className="pets-page section">
      <div className="container">
        {/* Header */}
        <div className="pets-header-row">
          <div>
            <span className="section-tag">Pet Profile Management</span>
            <h1 className="page-title">My Registered Companions</h1>
            <p className="page-subtitle">
              Maintain healthcare passports, vaccination records, and dietary preferences for dogs, cats, birds, rabbits, and small companions.
            </p>
          </div>
          <button className="btn btn-primary" onClick={openAddModal}>
            <Plus size={18} /> Register Companion
          </button>
        </div>

        {/* Animal Species Filter Pills */}
        <div className="pet-species-filter-bar">
          <button 
            className={`species-filter-pill ${selectedTypeFilter === 'All' ? 'active' : ''}`}
            onClick={() => setSelectedTypeFilter('All')}
          >
            All Companions ({pets.length})
          </button>
          {PET_TYPES.map(pt => {
            const count = pets.filter(p => (p.type || '').toLowerCase().includes(pt.id.toLowerCase())).length;
            return (
              <button 
                key={pt.id}
                className={`species-filter-pill ${selectedTypeFilter === pt.id ? 'active' : ''}`}
                onClick={() => setSelectedTypeFilter(pt.id)}
              >
                <span>{pt.icon}</span> {pt.name} ({count})
              </button>
            );
          })}
        </div>

        {/* Pets Grid */}
        <div className="pets-grid">
          {filteredPets.length === 0 ? (
            <div className="empty-results-card card" style={{ gridColumn: '1 / -1', padding: '3rem 1.5rem', textAlign: 'center' }}>
              <div className="empty-icon-wrap" style={{ margin: '0 auto 1rem' }}>
                <Heart size={36} className="text-accent" />
              </div>
              <h3>No Registered Pets in this Category</h3>
              <p style={{ maxWidth: '480px', margin: '0 auto 1.5rem', color: 'var(--text-muted)' }}>
                {selectedTypeFilter !== 'All' 
                  ? `You haven't registered any ${selectedTypeFilter} companions yet.` 
                  : 'Add your companion profile to book appointments and track medical passports.'}
              </p>
              <button className="btn btn-primary" onClick={openAddModal}>
                <Plus size={18} /> Register Companion
              </button>
            </div>
          ) : (
            filteredPets.map(pet => (
              <div key={pet.id} className="pet-profile-card card">
              <div className="pet-card-media">
                <img 
                  src={pet.photo || getPetTypeDefaultImage(pet.type)} 
                  alt={pet.name} 
                  className="pet-img-cover" 
                  loading="lazy"
                  onError={(e) => { e.target.src = getPetTypeDefaultImage(pet.type); }}
                />
                <span className="pet-type-tag">{pet.type}</span>
              </div>

              <div className="pet-card-details">
                <div className="pet-name-action-row">
                  <div>
                    <h3 className="pet-display-name">{pet.name}</h3>
                    <span className="pet-breed-tag">{pet.breed}</span>
                  </div>
                  <div className="pet-action-btns">
                    <button 
                      className="icon-action-btn" 
                      title="Edit Pet"
                      onClick={() => openEditModal(pet)}
                    >
                      <Edit3 size={16} />
                    </button>
                    <button 
                      className="icon-action-btn text-danger" 
                      title="Delete Pet"
                      onClick={() => setDeleteConfirmId(pet.id)}
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>

                <div className="pet-vitals-strip">
                  <div className="vital-item">
                    <span className="vital-lbl">Age</span>
                    <strong>{pet.age} {pet.age === 1 ? 'Year' : 'Years'}</strong>
                  </div>
                  <div className="vital-item">
                    <span className="vital-lbl">Gender</span>
                    <strong>{pet.gender}</strong>
                  </div>
                  <div className="vital-item">
                    <span className="vital-lbl">Weight</span>
                    <strong>{pet.weight}</strong>
                  </div>
                </div>

                {/* Health & Vaccine Badges */}
                <div className="pet-medical-section">
                  <div className="medical-line">
                    <ShieldCheck size={16} className="text-success" />
                    <div>
                      <strong>Vaccinations:</strong>
                      <p>{pet.vaccinations || 'Up to date with primary core vaccinations.'}</p>
                    </div>
                  </div>

                  <div className="medical-line">
                    <FileText size={16} className="text-accent" />
                    <div>
                      <strong>Medical & Dietary Notes:</strong>
                      <p>{pet.medicalHistory || 'No active clinical conditions reported.'}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )))}
        </div>

        {/* Delete Confirmation Modal */}
        {deleteConfirmId && (
          <div className="modal-backdrop" onClick={() => setDeleteConfirmId(null)}>
            <div className="modal-content confirmation-modal" onClick={e => e.stopPropagation()}>
              <div className="confirm-icon-box">
                <AlertTriangle size={32} className="text-danger" />
              </div>
              <h3>Remove Pet Profile?</h3>
              <p>Are you sure you want to remove this pet profile? Past completed appointment logs will remain intact.</p>
              <div className="confirm-btn-row">
                <button className="btn btn-outline" onClick={() => setDeleteConfirmId(null)}>
                  Cancel
                </button>
                <button className="btn btn-primary bg-danger text-white" onClick={() => handleDelete(deleteConfirmId)}>
                  Yes, Remove
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Add / Edit Pet Modal */}
        {showModal && (
          <div className="modal-backdrop" onClick={() => setShowModal(false)}>
            <div className="modal-content pet-form-modal" onClick={e => e.stopPropagation()}>
              <button className="modal-close-btn" onClick={() => setShowModal(false)}>
                <X size={20} />
              </button>

              <div className="pet-modal-header">
                <h2>{editingPet ? 'Update Pet Profile' : 'Register New Pet'}</h2>
                <p>Provide accurate information to help veterinarians and groomers customize care.</p>
              </div>

              {formError && (
                <div className="alert alert-danger" style={{ marginBottom: '1.25rem' }}>
                  <AlertTriangle size={18} />
                  <span>{formError}</span>
                </div>
              )}

              <form onSubmit={handleSave} className="pet-edit-form">
                <div className="form-row-2">
                  <div className="form-group">
                    <label className="form-label">Pet Name *</label>
                    <input 
                      type="text" 
                      className="form-control"
                      placeholder="e.g. Bruno"
                      value={name}
                      onChange={e => setName(e.target.value)}
                      required
                    />
                  </div>

                  <div className="form-group">
                    <label className="form-label">Animal Type *</label>
                    <select 
                      className="form-control"
                      value={type}
                      onChange={e => setType(e.target.value)}
                    >
                      {PET_TYPES.map(pt => (
                        <option key={pt.id} value={pt.id}>
                          {pt.icon} {pt.name}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="form-row-2">
                  <div className="form-group">
                    <label className="form-label">Breed *</label>
                    <input 
                      type="text" 
                      className="form-control"
                      placeholder="e.g. Golden Retriever, Persian..."
                      value={breed}
                      onChange={e => setBreed(e.target.value)}
                      required
                    />
                  </div>

                  <div className="form-group">
                    <label className="form-label">Age (Years)</label>
                    <input 
                      type="number" 
                      min="0" 
                      max="30" 
                      className="form-control"
                      value={age}
                      onChange={e => setAge(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-row-2">
                  <div className="form-group">
                    <label className="form-label">Gender</label>
                    <select 
                      className="form-control"
                      value={gender}
                      onChange={e => setGender(e.target.value)}
                    >
                      <option value="Male">Male</option>
                      <option value="Female">Female</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Weight</label>
                    <input 
                      type="text" 
                      className="form-control"
                      placeholder="e.g. 28 kg"
                      value={weight}
                      onChange={e => setWeight(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">Pet Photograph (Upload to Supabase Storage or Paste URL)</label>
                  
                  {/* Visual Photo Preview Card */}
                  <div className="pet-form-preview-card">
                    <img 
                      src={photo || getPetTypeDefaultImage(type)} 
                      alt="Companion Preview" 
                      className="pet-preview-thumb"
                      onError={(e) => { e.target.src = '/images/pets/pet-dog-golden.jpg'; }}
                    />
                    <div className="pet-preview-details">
                      <strong>{photo ? 'Custom Image Ready' : `Default Photo for ${type}`}</strong>
                      <small>{photo ? 'Stored and linked to pet profile' : 'Upload your companion\'s photo to replace with a personalized picture.'}</small>
                    </div>
                  </div>

                  <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '0.5rem', marginTop: '0.5rem' }}>
                    <label className="btn btn-outline btn-sm" style={{ cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: '0.4rem' }}>
                      <Upload size={15} />
                      <span>{uploadingPhoto ? 'Uploading to Bucket...' : 'Upload Image File'}</span>
                      <input 
                        type="file" 
                        accept="image/*" 
                        style={{ display: 'none' }}
                        onChange={handleFileUpload}
                        disabled={uploadingPhoto}
                      />
                    </label>
                    {photo && <span style={{ fontSize: '0.8rem', color: 'var(--color-primary)', alignSelf: 'center' }}>✓ Custom Photo Linked</span>}
                  </div>
                  <input 
                    type="url" 
                    className="form-control"
                    placeholder="Or enter image URL: https://images.unsplash.com/..."
                    value={photo}
                    onChange={e => setPhoto(e.target.value)}
                  />
                  <small className="form-text-hint">Leave blank to use an adorable automatic default photo for this species.</small>
                </div>

                <div className="form-group">
                  <label className="form-label">Vaccination History & Passports</label>
                  <input 
                    type="text" 
                    className="form-control"
                    placeholder="e.g. Rabies (valid till Dec 2026), DHPPi booster given"
                    value={vaccinations}
                    onChange={e => setVaccinations(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Medical History / Allergies</label>
                  <textarea 
                    className="form-control"
                    rows="2"
                    placeholder="e.g. Chicken protein allergy, anxious during loud nail trimming..."
                    value={medicalHistory}
                    onChange={e => setMedicalHistory(e.target.value)}
                  />
                </div>

                <div className="form-btn-actions">
                  <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={isSaving || uploadingPhoto}>
                    {isSaving ? 'Saving...' : editingPet ? 'Save Changes' : 'Register Pet'}
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

export default PetsManagementPage;
