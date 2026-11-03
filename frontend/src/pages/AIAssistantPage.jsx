import React, { useState, useRef, useEffect } from 'react';
import { useMarketplace } from '../context/MarketplaceContext';
import { useAuth } from '../context/AuthContext';
import { askAiAssistant } from '../services/aiService';
import { 
  Sparkles, 
  Send, 
  Bot, 
  User, 
  AlertTriangle, 
  ShieldAlert, 
  HelpCircle, 
  Heart, 
  Stethoscope, 
  RotateCcw,
  Info
} from 'lucide-react';
import './AIAssistantPage.css';

const AIAssistantPage = () => {
  const { pets } = useMarketplace();
  const { user } = useAuth();

  // Selected pet context for personalization
  const [selectedPetId, setSelectedPetId] = useState(pets.length > 0 ? pets[0].id : '');
  const activePet = pets.find(p => String(p.id) === String(selectedPetId)) || pets[0];

  // Chat message stream
  const [messages, setMessages] = useState([
    {
      id: 1,
      sender: 'bot',
      text: `Hello! I am your AI Pet Care Assistant 🐾. I am here to provide guidance on general nutrition, daily grooming, training basics, and preventive health for your pets.\n\nHow can I help you and ${activePet ? activePet.name : 'your furry companion'} today?`,
      time: 'Just now'
    }
  ]);

  const [inputQuestion, setInputQuestion] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping]);

  // Quick Starter Questions
  const starterPrompts = [
    { label: 'Nutrition & Diet', prompt: `What are safe healthy vegetables and fruits I can feed ${activePet?.name || 'my dog'}?` },
    { label: 'Grooming Routine', prompt: `How often should I brush and bathe a ${activePet?.breed || 'Golden Retriever'}?` },
    { label: 'Biting & Teething', prompt: 'My puppy is biting furniture and shoes. What positive reinforcement tricks work best?' },
    { label: 'Preventive Vaccines', prompt: 'What core annual vaccinations are essential for domestic pets in India?' },
    { label: 'Urgent Red Flags', prompt: 'What symptoms indicate a medical emergency where I should rush to an emergency clinic immediately?' }
  ];

  // Safe Intelligent Pet Care Response Engine (Academic Demo with strict Safety Guardrails)
  const generateAssistantResponse = (query, pet) => {
    const q = query.toLowerCase();
    const petName = pet ? pet.name : 'your pet';
    const petBreed = pet ? pet.breed : 'your companion';

    // Emergency Triage Trigger
    if (q.includes('blood') || q.includes('choking') || q.includes('poison') || q.includes('chocolate') || q.includes('collapse') || q.includes('unconscious') || q.includes('seizure') || q.includes('pale gums') || q.includes('can\'t breathe')) {
      return `⚠️ **URGENT VETERINARY ADVISORY**: The symptoms or ingestion you mentioned (${query}) may represent an acute emergency.\n\n• **Immediate Action**: Please do not wait or attempt home remedies. Transport ${petName} directly to the nearest 24/7 veterinary clinic or animal hospital immediately.\n• **Important**: Bring the wrapper or sample of any substance ingested if toxic.\n• Use our **Pet Taxi / Emergency Transport** in the marketplace if you need immediate stretcher vehicle dispatch.`;
    }

    // Prescription / Medication Safety Barrier
    if (q.includes('paracetamol') || q.includes('crocin') || q.includes('ibuprofen') || q.includes('dose') || q.includes('antibiotic') || q.includes('medicine')) {
      return `🛑 **IMPORTANT SAFETY NOTICE**: Never administer human medications like Paracetamol, Crocin, Aspirin, or Ibuprofen to dogs or cats—they can cause fatal liver and kidney failure even in microscopic doses.\n\nOnly a licensed veterinarian can accurately diagnose diseases and calculate pharmacological dosages based on ${petName}'s exact weight (${pet?.weight || 'monitored weight'}). Please book a clinical consultation with one of our verified veterinarians.`;
    }

    // Nutrition & Food
    if (q.includes('fruit') || q.includes('food') || q.includes('diet') || q.includes('eat') || q.includes('feed') || q.includes('vegetable')) {
      return `🥗 **Nutrition & Feeding Guide for ${petName} (${petBreed})**:\n\n• **Safe Treats to Feed**: Steamed carrots, deseeded apple slices, plain pumpkin puree, blue berries, and boiled green beans in moderation.\n• **Strictly Avoid / Toxic**: Grapes, raisins, onions, garlic, chocolate, caffeine, macadamia nuts, and any item sweetened with Xylitol.\n• **Breed Consideration**: For ${petBreed}, maintain portion-controlled meals to prevent excessive joint strain and sensitive gastric upset. Always ensure fresh filtered drinking water is available 24/7.`;
    }

    // Grooming
    if (q.includes('groom') || q.includes('bath') || q.includes('brush') || q.includes('hair') || q.includes('shed') || q.includes('coat')) {
      return `✂️ **Grooming Advice for ${petName} (${petBreed})**:\n\n• **Brushing**: For a ${petBreed}, gentle brushing 3-4 times a week with an undercoat de-shedding comb helps prevent mats and distributes healthy natural skin oils.\n• **Bathing Frequency**: Once every 3 to 4 weeks using an organic, hypoallergenic, oatmeal-based dog shampoo. Over-bathing strips protective skin lipids.\n• **Ears & Nails**: Check ears weekly for moisture or wax buildup, and keep nails trimmed so they don't click loudly on floors.\n• You can also schedule a **Royal Spa & Bath session** with our certified stylists in Mumbai, Bengaluru, or Delhi via our Services catalog!`;
    }

    // Vaccines & Health Check
    if (q.includes('vaccin') || q.includes('rabies') || q.includes('shot') || q.includes('deworm')) {
      return `💉 **Preventive Immunization Blueprint**:\n\n• **Core Canine Vaccines**: Anti-Rabies (mandatory annually) and DHPPi (protects against Distemper, Hepatitis, Parvovirus, and Parainfluenza).\n• **Core Feline Vaccines**: Tricat (Feline Rhinotracheitis, Calicivirus, Panleukopenia) + Rabies.\n• **Deworming Schedule**: Adult pets should typically receive broad-spectrum deworming every 3 months based on veterinarian guidance.\n• Check ${petName}'s health card in your **Pet Profile** to verify current validity dates!`;
    }

    // Training / Behavior
    if (q.includes('train') || q.includes('bite') || q.includes('bark') || q.includes('potty') || q.includes('behavior')) {
      return `🐾 **Positive Reinforcement Tips for ${petName}**:\n\n• **Redirect Chewing**: Whenever ${petName} mouths hands or furniture, immediately swap in a durable rubber chew toy (like a chilled KONG) and praise warmly.\n• **Short, Fun Sessions**: Keep training lessons to 5-10 minutes max with high-value treats like cooked chicken bits or freeze-dried liver.\n• **Never Punish**: Never yell or use physical force, which creates fear and anxiety. Consistency and clear reward timing create happy, confident companions.\n• Consider booking a 1-on-1 session with our certified trainers under the **Pet Behavior & Training** category!`;
    }

    // Default Friendly Response
    return `🐾 **PetCare Wellness Assistant Note for ${petName}**:\n\nThank you for asking about "${query}". As a general care guideline for a ${pet?.age || 2}-year-old ${petBreed}, consistency in routine, balanced premium nutrition, and mental enrichment through interactive play are the pillars of longevity.\n\n*Note: This advice is for wellness guidance and educational purposes. If ${petName} is showing abnormal behavior, lethargy, or discomfort, we recommend scheduling an exam with Dr. Aarav Sharma or one of our verified clinic specialists.*`;
  };

  const handleSendMessage = async (textToSend) => {
    const query = textToSend || inputQuestion;
    if (!query.trim()) return;

    // Push User message
    const userMsg = {
      id: Date.now(),
      sender: 'user',
      text: query.trim(),
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setMessages(prev => [...prev, userMsg]);
    setInputQuestion('');
    setIsTyping(true);

    try {
      const replyText = await askAiAssistant({
        question: query,
        pet: activePet,
        userId: user?.id
      });
      const botMsg = {
        id: Date.now() + 1,
        sender: 'bot',
        text: replyText,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      setMessages(prev => [...prev, botMsg]);
    } catch (err) {
      console.error('AI assistant communication error:', err);
      const botMsg = {
        id: Date.now() + 1,
        sender: 'bot',
        text: generateAssistantResponse(query, activePet),
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      setMessages(prev => [...prev, botMsg]);
    } finally {
      setIsTyping(false);
    }
  };

  const handleFormSubmit = (e) => {
    e.preventDefault();
    handleSendMessage(inputQuestion);
  };

  const handleResetChat = () => {
    setMessages([
      {
        id: Date.now(),
        sender: 'bot',
        text: `Chat cleared! How can I assist you with ${activePet ? activePet.name : 'your pet'} today?`,
        time: 'Just now'
      }
    ]);
  };

  return (
    <div className="ai-assistant-page section">
      <div className="container ai-chat-container">
        {/* Top Header Card */}
        <div className="ai-chat-header card">
          <div className="header-info-box">
            <div className="ai-avatar-badge">
              <Sparkles size={24} className="sparkle-gold" />
            </div>
            <div>
              <div className="ai-title-row">
                <h2>AI Pet Care Assistant</h2>
                <span className="demo-indicator-pill" title="Backend-Connected Safe Advisory Engine">
                  Demo & API Ready
                </span>
              </div>
              <p className="ai-subtitle">
                Guidance on nutrition, grooming, preventive vaccines, and pet wellness.
              </p>
            </div>
          </div>

          {/* Context Selector: Choose Registered Pet */}
          {pets.length > 0 && (
            <div className="pet-context-selector">
              <label className="context-label">Personalize for Pet:</label>
              <select 
                className="form-control context-select"
                value={selectedPetId}
                onChange={e => setSelectedPetId(e.target.value)}
              >
                {pets.map(p => (
                  <option key={p.id} value={p.id}>
                    {p.name} ({p.breed}, {p.age}y)
                  </option>
                ))}
              </select>
            </div>
          )}

          <button className="reset-chat-btn" onClick={handleResetChat} title="Reset Conversation">
            <RotateCcw size={16} />
            <span>Clear</span>
          </button>
        </div>

        {/* Safety Disclaimer Banner */}
        <div className="safety-alert-banner alert alert-info">
          <Info size={18} className="safety-icon" />
          <div className="safety-text">
            <strong>Veterinary Safety Notice:</strong>
            <span>
              This AI assistant provides educational wellness advice. It does not diagnose medical conditions or prescribe drugs. For medical emergencies, trauma, or toxic ingestion, contact a veterinary hospital immediately.
            </span>
          </div>
        </div>

        {/* Main Chat Stream Container */}
        <div className="chat-stream-card card">
          <div className="messages-stream">
            {messages.map(msg => (
              <div key={msg.id} className={`message-row ${msg.sender === 'user' ? 'user-row' : 'bot-row'}`}>
                {msg.sender === 'bot' && (
                  <div className="bot-msg-avatar">
                    <Bot size={20} />
                  </div>
                )}

                <div className={`message-bubble ${msg.sender === 'user' ? 'user-msg' : 'bot-msg'}`}>
                  <div className="msg-content">
                    {msg.text.split('\n').map((paragraph, idx) => (
                      <p key={idx}>{paragraph}</p>
                    ))}
                  </div>
                  <span className="msg-timestamp">{msg.time}</span>
                </div>

                {msg.sender === 'user' && (
                  <div className="user-msg-avatar">
                    <User size={18} />
                  </div>
                )}
              </div>
            ))}

            {isTyping && (
              <div className="message-row bot-row">
                <div className="bot-msg-avatar">
                  <Bot size={20} />
                </div>
                <div className="message-bubble bot-msg typing-bubble">
                  <span className="typing-dot"></span>
                  <span className="typing-dot"></span>
                  <span className="typing-dot"></span>
                </div>
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          {/* Suggested Starter Chips */}
          <div className="starter-chips-container">
            <span className="chips-title">Suggested Inquiries:</span>
            <div className="chips-scroll-strip">
              {starterPrompts.map((p, idx) => (
                <button
                  key={idx}
                  type="button"
                  className="starter-chip"
                  onClick={() => handleSendMessage(p.prompt)}
                >
                  {p.label}
                </button>
              ))}
            </div>
          </div>

          {/* Chat Input Bar */}
          <form onSubmit={handleFormSubmit} className="chat-input-bar">
            <input 
              type="text" 
              className="chat-text-input"
              placeholder={`Ask about diet, grooming, vaccines, or behavior for ${activePet ? activePet.name : 'your pet'}...`}
              value={inputQuestion}
              onChange={e => setInputQuestion(e.target.value)}
            />
            <button 
              type="submit" 
              className="btn btn-primary send-msg-btn"
              disabled={!inputQuestion.trim() || isTyping}
            >
              <Send size={18} />
              <span>Send</span>
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default AIAssistantPage;
