<script setup>
import { ref, onMounted } from 'vue'
import api from '../../api'
import Swal from 'sweetalert2'

const settings = ref({
  openai_api_key: '',
  openai_model: 'gpt-4o-mini', // default
  resend_api_key: '',
  stripe_secret_key: '',
  stripe_webhook_secret: ''
})

const loading = ref(true)
const showOpenAiKey = ref(false)
const showResendKey = ref(false)
const showStripeSecret = ref(false)
const showStripeWebhook = ref(false)

const fetchSettings = async () => {
  try {
    const response = await api.get('/admin/settings')
    if (response.data) {
      if (response.data.openai_api_key) settings.value.openai_api_key = response.data.openai_api_key
      if (response.data.openai_model) settings.value.openai_model = response.data.openai_model
      if (response.data.resend_api_key) settings.value.resend_api_key = response.data.resend_api_key
      if (response.data.stripe_secret_key) settings.value.stripe_secret_key = response.data.stripe_secret_key
      if (response.data.stripe_webhook_secret) settings.value.stripe_webhook_secret = response.data.stripe_webhook_secret
    }
  } catch (error) {
    console.error("Erro ao carregar configurações:", error)
  } finally {
    loading.value = false
  }
}

const saveSettings = async () => {
  try {
    await api.post('/admin/settings', { settings: settings.value })
    Swal.fire('Salvo!', 'Configurações de integração atualizadas.', 'success')
  } catch (error) {
    Swal.fire('Erro', 'Não foi possível salvar as configurações.', 'error')
  }
}

onMounted(() => {
  fetchSettings()
})
</script>

<template>
  <div class="admin-integrations">
    <div class="header-row">
      <h2 class="page-title">Integrações Globais</h2>
      <p class="subtitle">Gerencie as chaves de API e serviços centrais que alimentam todas as imobiliárias do SaaS.</p>
    </div>
    
    <div v-if="loading" class="loading">Carregando integrações...</div>
    
    <div v-else class="integrations-grid">
      <!-- OpenAI Card -->
      <div class="integration-card">
        <div class="card-header">
          <div class="header-icon open-ai-icon">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
          </div>
          <div>
            <h3>Inteligência Artificial (OpenAI)</h3>
            <p>Usado para resumir conversas, classificar leads e automações de chatbot.</p>
          </div>
        </div>
        
        <form @submit.prevent="saveSettings" class="settings-form">
          <div class="form-group">
            <label>OpenAI API Key <span class="required">*</span></label>
            <div class="input-with-icon">
              <input 
                :type="showOpenAiKey ? 'text' : 'password'" 
                v-model="settings.openai_api_key" 
                placeholder="sk-..." 
                required 
              />
              <button type="button" class="toggle-visibility" @click="showOpenAiKey = !showOpenAiKey">
                {{ showOpenAiKey ? 'Ocultar' : 'Mostrar' }}
              </button>
            </div>
          </div>

          <div class="form-group">
            <label>Modelo Padrão <span class="required">*</span></label>
            <select v-model="settings.openai_model" required>
              <option value="gpt-4o-mini">GPT-4o Mini (Recomendado - Rápido e Barato)</option>
              <option value="gpt-4o">GPT-4o (Avançado - Multimodal)</option>
              <option value="o1-preview">o1-preview (Raciocínio Avançado)</option>
              <option value="o1-mini">o1-mini / 4o1-mini (Raciocínio Rápido)</option>
              <option value="gpt-4-turbo">GPT-4 Turbo</option>
              <option value="gpt-4">GPT-4 (Legado)</option>
              <option value="gpt-3.5-turbo">GPT-3.5 Turbo (Legado)</option>
            </select>
          </div>

          <div class="form-actions">
            <button type="submit" class="btn btn-primary">Salvar Chaves</button>
          </div>
        </form>
      </div>

      <!-- Resend Card -->
      <div class="integration-card">
        <div class="card-header">
          <div class="header-icon resend-icon">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
          </div>
          <div>
            <h3>Envio de E-mails (Resend)</h3>
            <p>Sistema global de disparo de e-mails (Recuperação de Senha, Boas-vindas, Faturas).</p>
          </div>
        </div>
        
        <form @submit.prevent="saveSettings" class="settings-form">
          <div class="form-group">
            <label>Resend API Key <span class="required">*</span></label>
            <div class="input-with-icon">
              <input 
                :type="showResendKey ? 'text' : 'password'" 
                v-model="settings.resend_api_key" 
                placeholder="re_..." 
              />
              <button type="button" class="toggle-visibility" @click="showResendKey = !showResendKey">
                {{ showResendKey ? 'Ocultar' : 'Mostrar' }}
              </button>
            </div>
            <small class="help-text">Ao preencher, o sistema passará a usar esta chave oficial para os e-mails.</small>
          </div>

          <div class="form-actions">
            <button type="submit" class="btn btn-primary">Salvar Chaves</button>
          </div>
        </form>
      </div>

      <!-- Stripe Card -->
      <div class="integration-card">
        <div class="card-header">
          <div class="header-icon stripe-icon">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm.31-8.86c-1.77-.45-2.34-.94-2.34-1.67 0-.84.79-1.43 2.1-1.43 1.38 0 1.9.66 1.94 1.64h1.71c-.05-1.97-1.3-3.15-3.61-3.15-2.22 0-3.8 1.14-3.8 3.12 0 1.98 1.54 2.7 3.93 3.3 1.91.48 2.37 1.05 2.37 1.84 0 .9-.85 1.55-2.22 1.55-1.6 0-2.33-.82-2.4-1.92h-1.71c.08 2.05 1.39 3.25 4.09 3.25 2.39 0 3.95-1.12 3.95-3.23 0-2.12-1.64-2.73-3.93-3.3z"/></svg>
          </div>
          <div>
            <h3>Pagamentos (Stripe)</h3>
            <p>Gerenciamento de assinaturas e bloqueio automático de inadimplentes.</p>
          </div>
        </div>
        
        <form @submit.prevent="saveSettings" class="settings-form">
          <div class="form-group">
            <label>Stripe Secret Key <span class="required">*</span></label>
            <div class="input-with-icon">
              <input 
                :type="showStripeSecret ? 'text' : 'password'" 
                v-model="settings.stripe_secret_key" 
                placeholder="sk_live_..." 
              />
              <button type="button" class="toggle-visibility" @click="showStripeSecret = !showStripeSecret">
                {{ showStripeSecret ? 'Ocultar' : 'Mostrar' }}
              </button>
            </div>
          </div>

          <div class="form-group">
            <label>Webhook Secret</label>
            <div class="input-with-icon">
              <input 
                :type="showStripeWebhook ? 'text' : 'password'" 
                v-model="settings.stripe_webhook_secret" 
                placeholder="whsec_..." 
              />
              <button type="button" class="toggle-visibility" @click="showStripeWebhook = !showStripeWebhook">
                {{ showStripeWebhook ? 'Ocultar' : 'Mostrar' }}
              </button>
            </div>
            <small class="help-text">Necessário para avisar o seu SaaS quando um cliente cancelar ou atrasar a fatura.</small>
          </div>

          <div class="form-actions">
            <button type="submit" class="btn btn-primary stripe-btn">Salvar Chaves</button>
          </div>
        </form>
      </div>

    </div>
  </div>
</template>

<style scoped lang="scss">
.header-row {
  margin-bottom: 1.5rem;
  
  .page-title {
    font-size: 1.1rem;
    font-weight: 600;
    color: #1e293b;
    margin: 0 0 0.25rem 0;
  }
  
  .subtitle {
    font-size: 0.8rem;
    color: #64748b;
    margin: 0;
  }
}

.integrations-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
  width: 100%;
}

.integration-card {
  background: white;
  border-radius: 10px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  border: 1px solid #e2e8f0;
  padding: 1.25rem;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.25rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #f1f5f9;
  
  .header-icon {
    width: 40px;
    height: 40px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    
    svg {
      width: 20px;
      height: 20px;
    }
    
    &.open-ai-icon { background: #38bdf8; }
    &.resend-icon { background: #0f172a; }
    &.stripe-icon { background: #6366f1; }
  }
  
  h3 {
    margin: 0 0 0.15rem 0;
    font-size: 0.95rem;
    color: #0f172a;
  }
  
  p {
    margin: 0;
    font-size: 0.75rem;
    color: #64748b;
  }
}

.settings-form {
  .form-group {
    margin-bottom: 1.25rem;
    
    label {
      display: block;
      font-size: 0.8rem;
      font-weight: 600;
      color: #334155;
      margin-bottom: 0.4rem;
      
      .required { color: #ef4444; }
    }
    
    input, select {
      width: 100%;
      padding: 0.5rem 0.75rem;
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      font-size: 0.85rem;
      box-sizing: border-box;
      
      &:focus {
        outline: none;
        border-color: #38bdf8;
        box-shadow: 0 0 0 2px rgba(56, 189, 248, 0.2);
      }
    }
    
    .input-with-icon {
      position: relative;
      display: flex;
      
      input {
        padding-right: 70px;
      }
      
      .toggle-visibility {
        position: absolute;
        right: 8px;
        top: 50%;
        transform: translateY(-50%);
        background: none;
        border: none;
        color: #38bdf8;
        font-size: 0.75rem;
        cursor: pointer;
        font-weight: 500;
        
        &:hover { color: #0ea5e9; }
      }
    }
    
    .help-text {
      display: block;
      margin-top: 0.3rem;
      font-size: 0.7rem;
      color: #94a3b8;
    }
  }
  
  .form-actions {
    display: flex;
    justify-content: flex-end;
    margin-top: 1rem;
  }
}

.btn-primary {
  background: #38bdf8;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.8rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  
  &:hover {
    background: #0ea5e9;
  }
  
  &.stripe-btn {
    background: #6366f1;
    &:hover { background: #4f46e5; }
  }
}
</style>
