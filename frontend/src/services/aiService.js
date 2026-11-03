// AI Service Connector
// Securely interacts with Supabase Edge Function 'ai-assistant'
// Preserves clinical triage and service recommendations in all operating modes

import { supabase, isSupabaseConfigured } from './supabaseClient';

/**
 * Ask the AI Pet Care Assistant
 * @param {Object} params
 * @param {string} params.question - User's query
 * @param {Object} params.pet - Active pet details (name, breed, age, species, etc.)
 * @param {string} params.userId - Authenticated user UUID
 * @returns {Promise<string>} - Assistant's response text
 */
export const askAiAssistant = async ({ question, pet, userId }) => {
  // 1. If Supabase is fully configured, invoke the Edge Function
  if (isSupabaseConfigured()) {
    try {
      const { data, error } = await supabase.functions.invoke('ai-assistant', {
        body: {
          question,
          pet: pet ? {
            id: pet.id,
            name: pet.name,
            animal_type: pet.type || pet.animal_type || 'Dog',
            breed: pet.breed,
            age: pet.age,
            gender: pet.gender,
            weight: pet.weight
          } : null,
          userId
        }
      });

      if (error) {
        console.warn('Edge function error, invoking local safety triage engine:', error);
      } else if (data && data.answer) {
        return data.answer;
      }
    } catch (invokeErr) {
      console.warn('Network issue calling Edge Function, using local intelligence engine:', invokeErr);
    }
  }

  // 2. Local Intelligent Fallback (runs offline, during demos, or if network drops)
  return generateLocalAssistantResponse(question, pet);
};

/**
 * Client-Side Clinical Safety & Pet Care Triage Engine
 */
export const generateLocalAssistantResponse = (query, pet) => {
  const q = query.toLowerCase();
  const petName = pet ? pet.name : 'your pet';
  const petBreed = pet ? pet.breed : 'your companion';
  const petAge = pet?.age ? `${pet.age}-year-old` : 'young';

  // Emergency Triage Trigger
  if (
    q.includes('blood') ||
    q.includes('choking') ||
    q.includes('poison') ||
    q.includes('chocolate') ||
    q.includes('collapse') ||
    q.includes('unconscious') ||
    q.includes('seizure') ||
    q.includes('pale gums') ||
    q.includes("can't breathe") ||
    q.includes('bloat') ||
    q.includes('vomit blood')
  ) {
    return `⚠️ **URGENT VETERINARY ADVISORY**: The symptoms or substance you reported (${query}) indicate an acute medical emergency.\n\n` +
      `• **Immediate Action**: Please do not wait or attempt home remedies. Transport ${petName} directly to the nearest 24/7 emergency veterinary clinic immediately.\n` +
      `• **Critical Step**: If toxic ingestion is suspected, bring the packaging or sample of what was consumed.\n` +
      `• **Emergency Transport**: You can book equipped transit via our **Pet Taxi** category in the marketplace for urgent transfer.`;
  }

  // Prescription / Medication Safety Barrier
  if (
    q.includes('paracetamol') ||
    q.includes('crocin') ||
    q.includes('ibuprofen') ||
    q.includes('aspirin') ||
    q.includes('dose') ||
    q.includes('antibiotic') ||
    q.includes('calpol') ||
    q.includes('human medicine')
  ) {
    return `🛑 **IMPORTANT SAFETY NOTICE**: Never administer human medications like Paracetamol, Crocin, Aspirin, or Ibuprofen to dogs or cats—they can cause fatal liver and kidney failure even in microscopic doses.\n\n` +
      `Only a licensed veterinarian can accurately diagnose diseases and calculate pharmacological dosages based on ${petName}'s verified weight (${pet?.weight || 'monitored weight'}). Please book a clinical consultation with one of our verified veterinarians.`;
  }

  // Nutrition & Feeding
  if (
    q.includes('fruit') ||
    q.includes('food') ||
    q.includes('diet') ||
    q.includes('eat') ||
    q.includes('feed') ||
    q.includes('vegetable')
  ) {
    return `🥗 **Nutrition & Feeding Guide for ${petName} (${petBreed})**:\n\n` +
      `• **Safe Treats to Feed**: Steamed carrots, deseeded apple slices, plain pumpkin puree, blueberries, and boiled green beans in moderation.\n` +
      `• **Strictly Avoid / Toxic**: Grapes, raisins, onions, garlic, chocolate, caffeine, macadamia nuts, and any item sweetened with Xylitol.\n` +
      `• **Breed Consideration**: For ${petBreed}, maintain portion-controlled meals to prevent excessive joint strain and gastric upset. Always ensure fresh filtered drinking water is available 24/7.\n\n` +
      `📌 **Recommended Service**: *Comprehensive Veterinary Consultation & Nutrition Screening*`;
  }

  // Grooming & Coat Care
  if (
    q.includes('groom') ||
    q.includes('bath') ||
    q.includes('brush') ||
    q.includes('hair') ||
    q.includes('shed') ||
    q.includes('coat') ||
    q.includes('nail')
  ) {
    return `✂️ **Grooming Advice for ${petName} (${petBreed})**:\n\n` +
      `• **Brushing**: For a ${petBreed}, gentle brushing 3-4 times a week with an undercoat de-shedding comb helps prevent mats and distributes healthy natural skin oils.\n` +
      `• **Bathing Frequency**: Once every 3 to 4 weeks using an organic, hypoallergenic, oatmeal-based pet shampoo. Over-bathing strips protective skin lipids.\n` +
      `• **Ears & Nails**: Check ears weekly for moisture or wax buildup, and keep nails trimmed.\n\n` +
      `📌 **Recommended Service**: *Royal Spa, Deshedding Bath & Nail Care* with our certified groomers!`;
  }

  // Vaccines & Immunization
  if (
    q.includes('vaccin') ||
    q.includes('rabies') ||
    q.includes('shot') ||
    q.includes('deworm') ||
    q.includes('preventive')
  ) {
    return `💉 **Preventive Immunization Blueprint**:\n\n` +
      `• **Core Canine Vaccines**: Anti-Rabies (mandatory annually) and DHPPi (protects against Distemper, Hepatitis, Parvovirus, and Parainfluenza).\n` +
      `• **Core Feline Vaccines**: Tricat (Feline Rhinotracheitis, Calicivirus, Panleukopenia) + Rabies.\n` +
      `• **Deworming Schedule**: Adult pets should typically receive broad-spectrum deworming every 3 months based on veterinarian guidance.\n\n` +
      `Check ${petName}'s health card in your **Pet Profile** to verify current validity dates!`;
  }

  // Training & Behavior
  if (
    q.includes('train') ||
    q.includes('bite') ||
    q.includes('bark') ||
    q.includes('potty') ||
    q.includes('behavior') ||
    q.includes('chew')
  ) {
    return `🐾 **Positive Reinforcement Tips for ${petName}**:\n\n` +
      `• **Redirect Chewing**: Whenever ${petName} mouths hands or furniture, immediately swap in a durable rubber chew toy (like a chilled KONG) and praise warmly.\n` +
      `• **Short, Fun Sessions**: Keep training lessons to 5-10 minutes max with high-value treats like cooked chicken bits or freeze-dried liver.\n` +
      `• **Never Punish**: Never yell or use physical force. Consistency and clear reward timing create happy, confident companions.\n\n` +
      `📌 **Recommended Service**: *1-on-1 Certified Puppy & Dog Obedience Training*`;
  }

  // Default Friendly Response with Service Recommendations
  return `🐾 **PetCare Wellness Assistant Note for ${petName}**:\n\n` +
    `Thank you for asking about "${query}". As a general care guideline for a ${petAge} ${petBreed}, consistency in routine, balanced nutrition, and daily physical and mental enrichment are the foundations of health.\n\n` +
    `📌 **Recommended Services**:\n` +
    `• *Comprehensive Veterinary Consultation & Health Screening*\n` +
    `• *Professional Daily Dog Walking & Socialization*\n\n` +
    `*Disclaimer: This advice is for wellness guidance and educational purposes only. If ${petName} is showing abnormal lethargy or pain, please schedule a clinical exam with a verified veterinarian.*`;
};
