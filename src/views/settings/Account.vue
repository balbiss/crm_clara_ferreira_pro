<template>
  <div class="account-settings-container">
    <div v-if="showTrialWarning" class="trial-warning-banner">
      <strong>Atenção:</strong> Seu período de teste de 7 dias acabou ou sua assinatura está inativa. Assine agora para continuar usando o CRM.
    </div>

    <div class="header-section">
      <h1 class="page-title">Configurações da Conta</h1>
      <p class="page-subtitle">Gerencie as preferências gerais e a assinatura do seu workspace.</p>
    </div>

    <div class="settings-grid">
      <div class="settings-column">
        <div class="settings-card">
          <h2 class="section-title">Configurações gerais</h2>
          <p class="section-description">Informações básicas da sua conta e do administrador.</p>
          
          <div class="form-group">
            <label>Nome da Conta</label>
            <input type="text" v-model="accountName" class="form-control" placeholder="Ex: Minha Imobiliária" />
          </div>

          <div class="form-group">
            <label>Email do Proprietário</label>
            <input type="email" :value="userEmail" class="form-control" readonly style="background-color: var(--bg-hover); color: var(--text-muted);" />
          </div>

          <div class="form-group">
            <label>Idioma do site</label>
            <select v-model="siteLanguage" class="form-control">
              <option value="pt-BR">Português Brasileiro (pt-BR)</option>
              <option value="en">English (en)</option>
            </select>
          </div>

          <button class="btn btn-primary" @click="updateSettings">Atualizar configurações</button>
        </div>

        <!-- Seção de Segurança -->
        <div class="settings-card">
          <h2 class="section-title">Segurança</h2>
          <p class="section-description">Altere sua senha de acesso ao CRM.</p>
          
          <div class="form-group">
            <label>Senha Atual</label>
            <input type="password" v-model="passwordForm.current_password" class="form-control" placeholder="Sua senha atual" />
          </div>
          <div class="form-group">
            <label>Nova Senha</label>
            <input type="password" v-model="passwordForm.password" class="form-control" placeholder="Nova senha" />
          </div>
          <div class="form-group">
            <label>Confirmar Nova Senha</label>
            <input type="password" v-model="passwordForm.password_confirmation" class="form-control" placeholder="Repita a nova senha" />
          </div>

          <button class="btn btn-primary" :disabled="loadingPassword" @click="updatePassword">
            {{ loadingPassword ? 'Alterando...' : 'Alterar Senha' }}
          </button>
        </div>
      </div>

      <div class="settings-column">
        <!-- Seção de Assinatura (SaaS) -->
    <div class="settings-card subscription-card">
      <h2 class="section-title">Assinatura do Sistema</h2>
      <p class="section-description">Gerencie seu plano e pagamentos do CRM.</p>
      
      <div v-if="loadingSubscription" class="loading-text">Carregando...</div>
      <div v-else>
        <div class="status-active" v-if="subscriptionStatus === 'active'">
          <p><strong>Plano Atual:</strong> {{ planName }} <span class="badge success">Ativo</span></p>
          <p>Sua assinatura está ativa e sendo cobrada normalmente.</p>
          <button class="btn btn-secondary" :disabled="loadingPortal" @click="openPortal">
            {{ loadingPortal ? 'Carregando...' : 'Gerenciar Assinatura' }}
          </button>
        </div>

        <div class="status-inactive" v-else>
          <p><strong>Plano Atual:</strong> {{ planName }} <span class="badge warning">{{ subscriptionStatus === 'trialing' ? 'Em Teste' : 'Pendente' }}</span></p>
          <p v-if="trialEndsAt">Seu período de teste grátis termina em: <strong>{{ formatDate(trialEndsAt) }}</strong>.</p>
          <p v-else>Você não possui uma assinatura ativa no momento.</p>
          
          <button class="btn btn-primary" :disabled="loadingCheckout" @click="startCheckout">
            {{ loadingCheckout ? 'Gerando Link...' : 'Assinar Agora' }}
          </button>
        </div>
      </div>
    </div>

        <!-- Seção de Meta Ads (Lead Ads) -->
        <div class="settings-card">
          <h2 class="section-title">Meta Ads (Geração de Cadastros)</h2>
          <p class="section-description">Conecte a Página do Facebook usada nas suas campanhas de anúncio com formulário — os leads caem automaticamente aqui no CRM.</p>

          <div v-if="facebookPageName" class="status-active">
            <p><strong>Conectado:</strong> {{ facebookPageName }} <span class="badge success">Ativo</span></p>
            <button class="btn btn-secondary" :disabled="loadingFacebookLeads" @click="disconnectFacebookLeads">
              {{ loadingFacebookLeads ? 'Desconectando...' : 'Desconectar' }}
            </button>
          </div>
          <div v-else class="status-inactive">
            <p>Nenhuma Página conectada ainda.</p>
            <button class="btn btn-primary" :disabled="loadingFacebookLeads" @click="connectFacebookLeads">
              {{ loadingFacebookLeads ? 'Redirecionando...' : 'Conectar Facebook' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../../api'
import Swal from 'sweetalert2'

const accountName = ref('')
const userEmail = ref('')
const siteLanguage = ref('pt-BR')

const subscriptionStatus = ref('pending')
const planName = ref('Plano Premium')
const trialEndsAt = ref(null)

const loadingSubscription = ref(false)
const loadingCheckout = ref(false)
const loadingPortal = ref(false)
const showTrialWarning = ref(false)

const loadingPassword = ref(false)
const passwordForm = ref({
  current_password: '',
  password: '',
  password_confirmation: ''
})

const facebookPageName = ref('')
const loadingFacebookLeads = ref(false)

const fetchAccountData = async () => {
  try {
    const response = await api.get('/account')
    accountName.value = response.data.account_name
    userEmail.value = response.data.email
    subscriptionStatus.value = response.data.subscription_status
    trialEndsAt.value = response.data.trial_ends_at
    planName.value = response.data.plan_name
    facebookPageName.value = response.data.facebook_page_name || ''
    
    // Se o trial_ends_at for no futuro e não for active, mostramos como trialing no visual
    if (subscriptionStatus.value !== 'active' && trialEndsAt.value && new Date(trialEndsAt.value) > new Date()) {
      subscriptionStatus.value = 'trialing'
    }
  } catch (error) {
    console.error('Erro ao buscar dados da conta:', error)
  }
}

onMounted(() => {
  fetchAccountData()

  // Verifica se a URL indica bloqueio por assinatura
  if (window.location.search.includes('blocked=true')) {
    showTrialWarning.value = true
  }

  const params = new URLSearchParams(window.location.search)
  if (params.get('facebook_leads_connected')) {
    Swal.fire({ icon: 'success', title: 'Facebook conectado!', text: 'Os leads das suas campanhas já vão cair aqui no CRM.', confirmButtonColor: '#1f73ff' })
  } else if (params.get('facebook_leads_error')) {
    Swal.fire({ icon: 'error', title: 'Erro ao conectar', text: params.get('facebook_leads_error'), confirmButtonColor: '#1f73ff' })
  }
})

const connectFacebookLeads = async () => {
  loadingFacebookLeads.value = true
  try {
    const response = await api.get('/facebook_leads_oauth/authorize_url')
    window.location.href = response.data.url
  } catch (error) {
    loadingFacebookLeads.value = false
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível iniciar a conexão com o Facebook.', confirmButtonColor: '#1f73ff' })
  }
}

const disconnectFacebookLeads = async () => {
  loadingFacebookLeads.value = true
  try {
    await api.post('/facebook_leads_oauth/disconnect')
    facebookPageName.value = ''
  } catch (error) {
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível desconectar.', confirmButtonColor: '#1f73ff' })
  } finally {
    loadingFacebookLeads.value = false
  }
}

const formatDate = (dateString) => {
  if (!dateString) return ''
  const options = { day: '2-digit', month: '2-digit', year: 'numeric' }
  return new Date(dateString).toLocaleDateString('pt-BR', options)
}

const updatePassword = async () => {
  if (!passwordForm.value.current_password || !passwordForm.value.password) {
    Swal.fire({
      icon: 'warning',
      title: 'Atenção',
      text: 'Preencha a senha atual e a nova senha.',
      confirmButtonColor: '#1f73ff'
    })
    return
  }
  if (passwordForm.value.password !== passwordForm.value.password_confirmation) {
    Swal.fire({
      icon: 'warning',
      title: 'Atenção',
      text: 'A nova senha e a confirmação não batem.',
      confirmButtonColor: '#1f73ff'
    })
    return
  }
  
  loadingPassword.value = true
  try {
    const response = await api.put('/account/update_password', { user: passwordForm.value })
    Swal.fire({
      icon: 'success',
      title: 'Sucesso!',
      text: response.data.message || 'Senha alterada com sucesso!',
      confirmButtonColor: '#1f73ff',
      timer: 2000,
      showConfirmButton: false
    })
    passwordForm.value = { current_password: '', password: '', password_confirmation: '' }
  } catch (error) {
    let errorMsg = 'Erro ao alterar senha. Tente novamente.'
    if (error.response && error.response.data && error.response.data.error) {
      errorMsg = error.response.data.error
    }
    Swal.fire({
      icon: 'error',
      title: 'Oops...',
      text: errorMsg,
      confirmButtonColor: '#1f73ff'
    })
  } finally {
    loadingPassword.value = false
  }
}

const updateSettings = async () => {
  try {
    const response = await api.put('/account', { account: { name: accountName.value } })
    Swal.fire({
      icon: 'success',
      title: 'Configurações Salvas!',
      text: response.data.message || 'Configurações atualizadas com sucesso!',
      confirmButtonColor: '#1f73ff',
      timer: 2000,
      showConfirmButton: false
    })
    // Update local storage so the sidebar name updates too (if it reads from there)
    const storedUser = localStorage.getItem('user')
    if (storedUser) {
      const user = JSON.parse(storedUser)
      user.account_name = accountName.value
      localStorage.setItem('user', JSON.stringify(user))
      window.dispatchEvent(new Event('storage')) // trigger reactive updates if any
    }
  } catch (error) {
    Swal.fire({
      icon: 'error',
      title: 'Falha ao salvar',
      text: 'Ocorreu um erro ao atualizar as configurações.',
      confirmButtonColor: '#1f73ff'
    })
  }
}

const startCheckout = async () => {
  loadingCheckout.value = true
  try {
    const response = await api.post('/billing/checkout')
    if (response.data && response.data.url) {
      window.location.href = response.data.url
    }
  } catch (error) {
    console.error('Erro ao gerar checkout:', error)
    Swal.fire({
      icon: 'error',
      title: 'Erro de Pagamento',
      text: 'Não foi possível gerar o link de pagamento. Tente novamente mais tarde.',
      confirmButtonColor: '#1f73ff'
    })
  } finally {
    loadingCheckout.value = false
  }
}

const manageSubscription = async () => {
  loadingPortal.value = true
  try {
    const response = await api.post('/billing/portal')
    if (response.data && response.data.url) {
      window.location.href = response.data.url
    }
  } catch (error) {
    console.error('Erro ao abrir portal:', error)
    Swal.fire({
      icon: 'error',
      title: 'Erro',
      text: 'Não foi possível acessar o portal do cliente.',
      confirmButtonColor: '#1f73ff'
    })
  } finally {
    loadingPortal.value = false
  }
}
</script>

<style scoped lang="scss">
.account-settings-container {
  padding: 1.5rem 2rem;
  max-width: 1200px;
  margin: 0;

  .header-section {
    margin-bottom: 1.5rem;
    
    .page-title {
      font-size: 1.25rem;
      font-weight: 600;
      color: var(--text-color);
      margin-bottom: 0.25rem;
      letter-spacing: -0.01em;
    }
    
    .page-subtitle {
      font-size: 0.85rem;
      color: var(--text-muted);
    }
  }

  .settings-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
    align-items: start;

    @media (max-width: 900px) {
      grid-template-columns: 1fr;
    }
  }

  .settings-card {
    background: var(--surface-color);
    border: 1px solid rgba(0,0,0,0.06);
    border-radius: 8px;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);

    .section-title {
      font-size: 1rem;
      font-weight: 600;
      margin-bottom: 0.25rem;
      color: var(--text-color);
    }

    .section-description {
      font-size: 0.85rem;
      color: var(--text-muted);
      margin-top: 0;
      margin-bottom: 1.5rem;
      line-height: 1.4;
    }

    .form-group {
      margin-bottom: 1.25rem;
      max-width: 500px;

      label {
        display: block;
        font-size: 0.85rem;
        font-weight: 600;
        margin-bottom: 0.4rem;
        color: var(--text-color);
      }

      .form-control {
        width: 100%;
        padding: 0.5rem 0.75rem;
        border: 1px solid var(--border-color);
        border-radius: 6px;
        background: var(--bg-color);
        color: var(--text-color);
        font-size: 0.85rem;
        transition: all 0.2s ease;

        &:focus {
          outline: none;
          border-color: var(--primary-color);
          box-shadow: 0 0 0 2px rgba(var(--primary-color-rgb), 0.15);
        }
      }
    }

    .btn {
      padding: 0.5rem 1rem;
      border-radius: 6px;
      font-weight: 500;
      font-size: 0.85rem;
      cursor: pointer;
      border: none;
      transition: all 0.2s ease;
      display: inline-flex;
      align-items: center;
      justify-content: center;

      &-primary {
        background: #1f73ff; 
        color: white;
        
        &:hover { 
          background: #155bd5; 
        }
      }

      &-secondary {
        background: var(--bg-color);
        color: var(--text-color);
        border: 1px solid var(--border-color);
        
        &:hover { 
          background: var(--border-color); 
        }
      }

      &:disabled {
        opacity: 0.7;
        cursor: not-allowed;
      }
    }
  }

  .subscription-card {
    border-top: 3px solid var(--primary-color);
    background: linear-gradient(to bottom right, var(--surface-color), rgba(var(--primary-color-rgb), 0.02));
    
    .badge {
      padding: 0.2rem 0.6rem;
      border-radius: 12px;
      font-size: 0.75rem;
      font-weight: 600;
      letter-spacing: 0.02em;
      display: inline-block;
      margin-left: 0.5rem;
      
      &.success { 
        background: #dcfce7; 
        color: #166534; 
        border: 1px solid #bbf7d0;
      }
      &.warning { 
        background: #fef9c3; 
        color: #854d0e; 
        border: 1px solid #fef08a;
      }
    }

    .status-active, .status-inactive {
      margin-top: 1rem;
      background: var(--bg-color);
      padding: 1rem;
      border-radius: 6px;
      border: 1px solid var(--border-color);
      
      strong {
        font-size: 0.9rem;
        color: var(--text-color);
      }
      
      p { 
        margin-top: 0.5rem; 
        margin-bottom: 1rem;
        color: var(--text-muted); 
        font-size: 0.85rem;
        line-height: 1.4;
      }
    }
  }

  .trial-warning-banner {
    background: #fef2f2;
    color: #991b1b;
    border: 1px solid #fecaca;
    padding: 0.75rem 1rem;
    border-radius: 6px;
    margin-bottom: 1.5rem;
    font-size: 0.85rem;
    
    strong {
      font-weight: 600;
    }
  }
}
</style>
