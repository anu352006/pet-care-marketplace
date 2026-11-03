import { createClient } from '@supabase/supabase-js';

// Read Supabase environment variables configured in frontend/.env
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

// Determine whether valid live Supabase credentials have been configured
export const isSupabaseConfigured = () => {
  return (
    typeof supabaseUrl === 'string' &&
    supabaseUrl.trim().length > 0 &&
    !supabaseUrl.includes('your-project-id') &&
    typeof supabaseAnonKey === 'string' &&
    supabaseAnonKey.trim().length > 0 &&
    !supabaseAnonKey.includes('your-anon-key')
  );
};

// Fallback dummy URL and key to prevent createClient initialization errors in offline/demo mode
const safeUrl = isSupabaseConfigured() ? supabaseUrl : 'https://placeholder-project.supabase.co';
const safeAnonKey = isSupabaseConfigured() ? supabaseAnonKey : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder';

export const supabase = createClient(safeUrl, safeAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

/**
 * Upload an image to a Supabase Storage bucket
 * @param {string} bucket - 'pet-images' | 'provider-images' | 'service-images'
 * @param {File} file - The file object to upload
 * @param {string} folder - Optional subfolder/user ID prefix
 * @returns {Promise<string>} - The public URL of the uploaded file
 */
export const uploadStorageFile = async (bucket, file, folder = 'uploads') => {
  if (!isSupabaseConfigured()) {
    // Return a local Object URL for offline demo mode
    return URL.createObjectURL(file);
  }

  const fileExt = file.name.split('.').pop();
  const fileName = `${folder}/${Date.now()}-${Math.random().toString(36).substring(2, 9)}.${fileExt}`;

  const { error: uploadError } = await supabase.storage
    .from(bucket)
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: false,
    });

  if (uploadError) {
    console.error(`Error uploading to ${bucket}:`, uploadError);
    throw uploadError;
  }

  const { data } = supabase.storage.from(bucket).getPublicUrl(fileName);
  return data.publicUrl;
};
