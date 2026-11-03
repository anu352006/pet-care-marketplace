// Supabase Edge Function: ai-assistant
// Handles AI-powered pet care queries, clinical safety triage, service recommendations, and chat history persistence

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// Standard CORS headers for cross-origin browser requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface AssistantRequest {
  question: string;
  pet?: {
    id?: string | number;
    name?: string;
    animal_type?: string;
    breed?: string;
    age?: number;
    gender?: string;
    weight?: string;
  };
  userId?: string;
}

// Clinical triage and safety guardrails
const checkEmergencyTriggers = (query: string, petName: string): string | null => {
  const q = query.toLowerCase();
  
  // High-severity life-threatening emergencies
  const emergencyKeywords = [
    'blood', 'bleeding', 'choking', 'poison', 'rat poison', 'chocolate', 
    'collapse', 'unconscious', 'seizure', 'pale gums', "can't breathe", 
    'difficulty breathing', 'bloat', 'hit by car', 'snake bite', 'heat stroke'
  ];

  if (emergencyKeywords.some(kw => q.includes(kw))) {
    return `⚠️ **URGENT VETERINARY ADVISORY**: The symptoms or substance you reported (${query}) indicate an acute medical emergency.\n\n` +
      `• **Immediate Action**: Please do not wait or attempt home remedies. Transport ${petName} directly to the nearest 24/7 veterinary clinic or animal trauma hospital immediately.\n` +
      `• **Critical Step**: If toxic ingestion is suspected, bring the packaging, plant, or substance sample with you.\n` +
      `• **Emergency Transit**: You can use our **Pet Taxi / Emergency Transport** service in the marketplace if you need immediate equipped vehicle assistance.`;
  }

  // Medication and human pharmaceutical toxicity guardrail
  const medKeywords = [
    'paracetamol', 'crocin', 'ibuprofen', 'aspirin', 'calpol', 
    'dose', 'dosage', 'milligram', 'mg', 'antibiotic', 'sedative'
  ];

  if (medKeywords.some(kw => q.includes(kw))) {
    return `🛑 **IMPORTANT SAFETY NOTICE**: Never administer human medications like Paracetamol, Crocin, Aspirin, or Ibuprofen to dogs or cats—they can cause fatal liver and acute kidney failure even in minute doses.\n\n` +
      `Only a licensed veterinarian can perform a clinical exam, establish a diagnosis, and safely prescribe pharmacological dosages based on ${petName}'s verified weight and vital signs.\n\n` +
      `Please schedule an appointment with one of our verified veterinarians right away.`;
  }

  return null;
};

// Recommend relevant marketplace services based on query context
const getRecommendedServices = (query: string): string[] => {
  const q = query.toLowerCase();
  const recs: string[] = [];

  if (q.includes('sick') || q.includes('fever') || q.includes('vomit') || q.includes('limp') || q.includes('vet') || q.includes('vaccin') || q.includes('deworm')) {
    recs.push('Comprehensive Veterinary Consultation & Health Screening');
  }
  if (q.includes('groom') || q.includes('bath') || q.includes('hair') || q.includes('shed') || q.includes('nail') || q.includes('coat')) {
    recs.push('Royal Spa, Deshedding Bath & Nail Care');
  }
  if (q.includes('train') || q.includes('bite') || q.includes('bark') || q.includes('potty') || q.includes('puppy') || q.includes('aggress')) {
    recs.push('1-on-1 Certified Puppy & Dog Obedience Training');
  }
  if (q.includes('walk') || q.includes('exercise') || q.includes('energy') || q.includes('bored')) {
    recs.push('Professional GPS-Tracked Daily Dog Walking');
  }
  if (q.includes('travel') || q.includes('vacation') || q.includes('board') || q.includes('leave') || q.includes('sitting')) {
    recs.push('Luxury Climate-Controlled Pet Boarding & Daycare');
  }

  if (recs.length === 0) {
    recs.push('Veterinary Consultation', 'Pet Grooming & Spa');
  }
  return recs;
};

// Fallback high-quality domain-specific response engine
const generateRuleBasedResponse = (query: string, pet: AssistantRequest['pet']): string => {
  const petName = pet?.name || 'your pet';
  const petBreed = pet?.breed || 'your companion';
  const petAge = pet?.age ? `${pet.age} years old` : 'pet';
  const q = query.toLowerCase();

  let body = '';

  if (q.includes('fruit') || q.includes('vegetable') || q.includes('food') || q.includes('diet') || q.includes('eat') || q.includes('feed')) {
    body = `🥗 **Nutrition & Feeding Guidance for ${petName} (${petBreed})**:\n\n` +
      `• **Safe Foods to Share**: Steamed carrots, deseeded apple slices, plain pumpkin puree, blueberries, and cooked green beans.\n` +
      `• **Strictly Prohibited & Toxic**: Grapes, raisins, onions, garlic, chocolate, macadamia nuts, avocado, and anything containing Xylitol / artificial sweeteners.\n` +
      `• **Portion Advice**: For ${petName}'s profile (${petAge}), balance high-protein meals with proper fiber to avoid digestive sensitivity. Always supply cool, filtered water in clean bowls.`;
  } else if (q.includes('groom') || q.includes('bath') || q.includes('brush') || q.includes('hair') || q.includes('shed') || q.includes('fur')) {
    body = `✂️ **Grooming Plan for ${petName} (${petBreed})**:\n\n` +
      `• **Brushing**: Brush 3 to 4 times a week using a slicker or undercoat rake to minimize shedding and avoid matting.\n` +
      `• **Bathing**: Bathe once every 3-4 weeks with an oatmeal or aloe-based pet shampoo. Over-washing strips natural skin oils and triggers dryness.\n` +
      `• **Ears & Paws**: Wipe outer ears weekly with pet-safe pads and inspect paw pads for debris after outdoor walks.`;
  } else if (q.includes('vaccin') || q.includes('shot') || q.includes('deworm') || q.includes('rabies')) {
    body = `💉 **Preventive Health & Immunization Protocol**:\n\n` +
      `• **Essential Vaccines**: Anti-Rabies (annually) and core DHPPi multi-component vaccine (Distemper, Parvo, Hepatitis, Parainfluenza).\n` +
      `• **Deworming**: Routine deworming every 3 months is recommended for adult pets, or as advised by your local vet.\n` +
      `• **Health Records**: Keep your pet's vaccination record updated in your dashboard for quick verification at boarding facilities.`;
  } else if (q.includes('train') || q.includes('bite') || q.includes('bark') || q.includes('chew') || q.includes('potty')) {
    body = `🐾 **Positive Reinforcement Training Tips for ${petName}**:\n\n` +
      `• **Redirect Unwanted Chewing**: When ${petName} bites furniture or hands, calmly redirect them to an appropriate chew toy and reward them when they engage.\n` +
      `• **Bite Inhibition**: Keep training sessions short (5-10 minutes) and use tiny, high-value treats.\n` +
      `• **Consistency**: Never use physical punishment or yelling. Consistent positive reinforcement builds trust and lasting obedience.`;
  } else {
    body = `🐾 **Pet Care Wellness Guidance for ${petName}**:\n\n` +
      `Thank you for asking about "${query}". As a general care guideline for a ${petBreed}, regular exercise, balanced nutrition tailored to their life stage, and preventive veterinary check-ups every 6 to 12 months are key to a long, happy life.`;
  }

  const recs = getRecommendedServices(query);
  const recsText = `\n\n📌 **Recommended Marketplace Services for ${petName}**:\n` +
    recs.map(r => `• ${r}`).join('\n') +
    `\n\n*Disclaimer: This assistant provides general pet care education only. It does not diagnose diseases or prescribe medications. Please consult a licensed veterinarian for medical evaluation.*`;

  return body + recsText;
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { question, pet, userId }: AssistantRequest = await req.json();

    if (!question || question.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "A valid pet-care question is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const petName = pet?.name || "your pet";
    let finalAnswer = "";

    // Step 1: Immediate Safety & Emergency Triage Check
    const emergencyAlert = checkEmergencyTriggers(question, petName);
    if (emergencyAlert) {
      finalAnswer = emergencyAlert;
    } else {
      // Step 2: Attempt External AI API if configured
      const aiApiKey = Deno.env.get("AI_API_KEY") || Deno.env.get("OPENAI_API_KEY");
      
      if (aiApiKey) {
        try {
          const systemPrompt = `You are an expert, compassionate AI Pet Care Assistant for the 'Pet Care & Services Marketplace'.
Pet Context: Name: ${petName}, Breed: ${pet?.breed || 'Unknown'}, Age: ${pet?.age || 'Unknown'}, Species: ${pet?.animal_type || 'Dog'}, Weight: ${pet?.weight || 'Unknown'}.
CRITICAL SAFETY RULES:
1. NEVER diagnose medical conditions or claim to replace a licensed veterinarian.
2. NEVER prescribe medications, pharmaceuticals, or precise drug dosages.
3. If the pet shows dangerous symptoms (severe bleeding, poisoning, choking, collapse), urgently advise immediate 24/7 veterinary care.
4. Keep answers friendly, well-structured, clear, and actionable.
5. Provide relevant pet nutrition, hygiene, training, or preventive advice.
6. At the end, recommend 1-2 relevant marketplace services (Veterinary Consultation, Grooming, Walking, Training, Boarding, or Pet Daycare).`;

          const aiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${aiApiKey}`,
            },
            body: JSON.stringify({
              model: "gpt-3.5-turbo",
              messages: [
                { role: "system", content: systemPrompt },
                { role: "user", content: question }
              ],
              temperature: 0.7,
              max_tokens: 500,
            }),
          });

          if (aiResponse.ok) {
            const data = await aiResponse.json();
            finalAnswer = data.choices[0]?.message?.content || "";
          } else {
            console.warn("External AI call returned status:", aiResponse.status);
            finalAnswer = generateRuleBasedResponse(question, pet);
          }
        } catch (apiErr) {
          console.error("External AI call failed, falling back to clinical rules:", apiErr);
          finalAnswer = generateRuleBasedResponse(question, pet);
        }
      } else {
        // No external API key in environment: execute domain rules engine
        finalAnswer = generateRuleBasedResponse(question, pet);
      }
    }

    // Step 3: Persist chat interaction in Supabase chat_history if credentials exist
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_ANON_KEY");

    if (supabaseUrl && supabaseKey) {
      try {
        const supabase = createClient(supabaseUrl, supabaseKey);
        await supabase.from("chat_history").insert({
          user_id: userId || null,
          pet_id: pet?.id && typeof pet.id === 'string' && pet.id.includes('-') ? pet.id : null,
          question: question,
          response: finalAnswer,
        });
      } catch (dbErr) {
        console.warn("Failed to log chat interaction to chat_history:", dbErr);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        answer: finalAnswer,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("Edge Function error:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
