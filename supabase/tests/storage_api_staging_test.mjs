// ============================================================================
// SUPABASE STORAGE API STAGING INTEGRATION TEST
// File: supabase/tests/storage_api_staging_test.mjs
//
// Execution:
//   cd frontend && node ../supabase/tests/storage_api_staging_test.mjs
//
// WARNING: Strictly for disposable staging environments. NEVER run against production.
// ============================================================================

import { createClient } from '@supabase/supabase-js';

// Minimal valid 1x1 transparent PNG buffer (valid image/png MIME fixture)
const TINY_PNG_BUFFER = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64'
);

function assert(condition, testName, details) {
  if (!condition) {
    process.exitCode = 1;
    const msg = `[ASSERTION FAILED] ${testName}: ${details}`;
    console.error(`\x1b[31m${msg}\x1b[0m`);
    throw new Error(msg);
  }
}

function isAuthOrRlsError(err) {
  if (!err) return false;
  const status = Number(err.statusCode || err.status || 0);
  const msg = (err.message || '').toLowerCase();
  const errorProp = (err.error || '').toLowerCase();
  
  // Confirms it is genuine authorization denial, NOT a 404 Not Found or 500 error
  return status === 403 
    || status === 401 
    || msg.includes('row-level security') 
    || msg.includes('unauthorized')
    || msg.includes('violates row-level security')
    || errorProp.includes('unauthorized');
}

export async function runStorageStagingSuite({
  stagingUrl,
  anonKey,
  ownerToken,
  ownerId,
  victimToken,
  victimId,
  providerToken,
  providerId
}) {
  console.log('--- Starting Storage API Staging Test Suite ---');

  const ownerClient = createClient(stagingUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${ownerToken}` } }
  });

  const victimClient = createClient(stagingUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${victimToken}` } }
  });

  const providerClient = createClient(stagingUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${providerToken}` } }
  });

  const ownerFiles = [];
  const victimFiles = [];
  const providerFiles = [];

  try {
    // ------------------------------------------------------------------------
    // TEST 1: Pet owner uploads valid image to own folder in 'pet-images' -> SUCCESS
    // ------------------------------------------------------------------------
    const ownerFile = `${ownerId}/staging_test_${Date.now()}.png`;
    console.log(`[TEST 1] Pet owner uploading to own folder: pet-images/${ownerFile}...`);
    
    const { data: ownUpload, error: ownErr } = await ownerClient.storage
      .from('pet-images')
      .upload(ownerFile, TINY_PNG_BUFFER, { contentType: 'image/png', upsert: false });

    assert(!ownErr, 'TEST 1: Own Folder Upload', ownErr ? JSON.stringify(ownErr) : '');
    assert(ownUpload?.path, 'TEST 1: Upload Payload Path', 'Missing upload path');
    ownerFiles.push(ownerFile);
    console.log('\x1b[32m[PASS] TEST 1: Pet owner own-folder upload succeeded.\x1b[0m');

    // ------------------------------------------------------------------------
    // STEP 2A: Victim creates real object in victim's own folder
    // ------------------------------------------------------------------------
    const victimFile = `${victimId}/victim_target_${Date.now()}.png`;
    console.log(`[SETUP] Victim uploading real object: pet-images/${victimFile}...`);
    
    const { data: vicUpload, error: vicErr } = await victimClient.storage
      .from('pet-images')
      .upload(victimFile, TINY_PNG_BUFFER, { contentType: 'image/png', upsert: false });

    assert(!vicErr, 'SETUP: Victim Target Creation', vicErr ? JSON.stringify(vicErr) : '');
    victimFiles.push(victimFile);

    // ------------------------------------------------------------------------
    // TEST 2: Pet owner attempts cross-user upload into victim's folder -> DENIED
    // ------------------------------------------------------------------------
    const crossUploadFile = `${victimId}/exploit_upload_${Date.now()}.png`;
    console.log(`[TEST 2] Pet owner attempting upload into victim folder: pet-images/${crossUploadFile}...`);

    const { data: crossUpload, error: crossErr } = await ownerClient.storage
      .from('pet-images')
      .upload(crossUploadFile, TINY_PNG_BUFFER, { contentType: 'image/png', upsert: false });

    assert(crossErr !== null, 'TEST 2: Cross-User Upload Denial', 'Upload into victim folder unexpectedly succeeded!');
    assert(
      isAuthOrRlsError(crossErr), 
      'TEST 2: Genuine RLS Error Check', 
      `Expected authorization/RLS denial (403), but received: ${JSON.stringify(crossErr)}`
    );
    console.log(`\x1b[32m[PASS] TEST 2: Cross-user upload denied with expected authorization error: ${crossErr.message || crossErr.statusCode}\x1b[0m`);

    // ------------------------------------------------------------------------
    // TEST 3: Pet owner attempts cross-user overwrite of REAL existing victim file -> DENIED
    // ------------------------------------------------------------------------
    console.log(`[TEST 3] Pet owner attempting to overwrite victim's real file: pet-images/${victimFile}...`);

    const { data: updateData, error: updateErr } = await ownerClient.storage
      .from('pet-images')
      .update(victimFile, TINY_PNG_BUFFER, { contentType: 'image/png' });

    assert(updateErr !== null, 'TEST 3: Cross-User Overwrite Denial', 'Overwrite of real victim file unexpectedly succeeded!');
    assert(
      isAuthOrRlsError(updateErr),
      'TEST 3: Genuine RLS Error Check',
      `Expected authorization/RLS denial (403), but received: ${JSON.stringify(updateErr)}`
    );
    console.log(`\x1b[32m[PASS] TEST 3: Cross-user overwrite of real file denied with authorization error.\x1b[0m`);

    // ------------------------------------------------------------------------
    // TEST 4: Legitimate provider uploads to 'provider-images' -> SUCCESS
    // ------------------------------------------------------------------------
    const provFile = `${providerId}/clinic_cert_${Date.now()}.png`;
    console.log(`[TEST 4] Provider uploading to own folder: provider-images/${provFile}...`);

    const { data: provData, error: provErr } = await providerClient.storage
      .from('provider-images')
      .upload(provFile, TINY_PNG_BUFFER, { contentType: 'image/png', upsert: false });

    assert(!provErr, 'TEST 4: Provider Upload Success', provErr ? JSON.stringify(provErr) : '');
    providerFiles.push(provFile);
    console.log('\x1b[32m[PASS] TEST 4: Legitimate provider upload to provider-images succeeded.\x1b[0m');

    // ------------------------------------------------------------------------
    // TEST 5: Pet owner attempts upload to 'provider-images' bucket -> DENIED
    // ------------------------------------------------------------------------
    const illegalProvFile = `${ownerId}/unauthorized_cert_${Date.now()}.png`;
    console.log(`[TEST 5] Pet owner attempting upload to provider-images: provider-images/${illegalProvFile}...`);

    const { data: illegalData, error: illegalErr } = await ownerClient.storage
      .from('provider-images')
      .upload(illegalProvFile, TINY_PNG_BUFFER, { contentType: 'image/png', upsert: false });

    assert(illegalErr !== null, 'TEST 5: Non-Provider Denial on provider-images', 'Pet owner upload to provider-images unexpectedly succeeded!');
    assert(
      isAuthOrRlsError(illegalErr),
      'TEST 5: Genuine RLS Error Check',
      `Expected 403 / RLS error on provider-images, but received: ${JSON.stringify(illegalErr)}`
    );
    console.log(`\x1b[32m[PASS] TEST 5: Non-provider upload to provider-images denied with authorization error.\x1b[0m`);

  } finally {
    // ------------------------------------------------------------------------
    // CLEANUP: Using owning clients to remove their respective objects
    // ------------------------------------------------------------------------
    console.log('--- Cleaning up staging storage fixtures using owning sessions ---');
    for (const f of ownerFiles) {
      try { await ownerClient.storage.from('pet-images').remove([f]); } catch (_) {}
    }
    for (const f of victimFiles) {
      try { await victimClient.storage.from('pet-images').remove([f]); } catch (_) {}
    }
    for (const f of providerFiles) {
      try { await providerClient.storage.from('provider-images').remove([f]); } catch (_) {}
    }
  }

  console.log('\x1b[32m[ALL STORAGE API STAGING TESTS PASSED]\x1b[0m');
}
