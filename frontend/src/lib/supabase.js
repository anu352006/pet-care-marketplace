import { createClient } from '@supabase/supabase-js';

// Read environment variables
const rawUrl = import.meta.env.VITE_SUPABASE_URL || '';
// Strip trailing slash and optional '/rest/v1' suffix if user provided the REST endpoint URL
const supabaseUrl = typeof rawUrl === 'string' 
  ? rawUrl.trim().replace(/\/rest\/v1\/?$/i, '').replace(/\/+$/, '') 
  : '';

// Support both standard VITE_SUPABASE_PUBLISHABLE_KEY and VITE_SUPABASE_ANON_KEY
const supabasePublishableKey = (
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 
  import.meta.env.VITE_SUPABASE_ANON_KEY || 
  ''
).trim();

/**
 * Validates whether valid live Supabase credentials have been configured
 * @returns {boolean}
 */
export const isSupabaseConfigured = () => {
  return (
    typeof supabaseUrl === 'string' &&
    supabaseUrl.trim().length > 0 &&
    !supabaseUrl.includes('your-project-id') &&
    typeof supabasePublishableKey === 'string' &&
    supabasePublishableKey.trim().length > 0 &&
    !supabasePublishableKey.includes('your-publishable-key') &&
    !supabasePublishableKey.includes('your-anon-key')
  );
};

// Fallback placeholder URL and key to avoid runtime crash when .env is unconfigured
const safeUrl = isSupabaseConfigured() ? supabaseUrl.trim() : 'https://placeholder-project.supabase.co';
const safeKey = isSupabaseConfigured() ? supabasePublishableKey.trim() : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder';

/**
 * Canonical Supabase client instance configured with public publishable key
 * (Service role and secret keys are never exposed on the frontend)
 */
export const supabase = createClient(safeUrl, safeKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

/**
 * Upload an image file to a Supabase Storage bucket
 * @param {'pet-images' | 'provider-images' | 'service-images'} bucket
 * @param {File} file
 * @param {string} [folder='uploads']
 * @returns {Promise<string>} Public URL of the uploaded image
 */
export const uploadStorageFile = async (bucket, file, folder = 'uploads') => {
  if (!isSupabaseConfigured()) {
    return URL.createObjectURL(file);
  }

  const fileExt = file.name.split('.').pop();
  const cleanBaseName = file.name.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 20);
  const fileName = `${folder}/${Date.now()}-${cleanBaseName}.${fileExt}`;

  const { error: uploadError } = await supabase.storage
    .from(bucket)
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: false,
    });

  if (uploadError) {
    console.error(`Error uploading to storage bucket "${bucket}":`, uploadError);
    throw uploadError;
  }

  const { data } = supabase.storage.from(bucket).getPublicUrl(fileName);
  return data.publicUrl;
};

export default supabase;
