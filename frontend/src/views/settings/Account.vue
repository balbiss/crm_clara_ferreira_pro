<template>
  <div class="account-settings-container">
    <div class="header-section">
      <h1 class="page-title">Configurações da Conta</h1>
      <p class="page-subtitle">Gerencie as preferências gerais do seu workspace.</p>
    </div>

    <div class="settings-grid">
      <div class="settings-column">
        <div class="settings-card">
          <h2 class="section-title">Configurações gerais</h2>
          <p class="section-description">Informações básicas da sua conta e do administrador.</p>
          
          <div class="form-group">
            <label>Nome da Conta</label>
            <input type="text" v-model="accountName" class="form-control" placeholder="Ex: Clara Ferreira Acessórios" />
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
        <!-- Seção de Integração com o Jueri -->
        <div class="settings-card">
          <h2 class="section-title">Integração ERP Jueri</h2>
          <p class="section-description">Cole essa URL em Jueri → Configurações → API → Webhooks, pra receber eventos de pedido/venda em tempo real (o CRM sincroniza a carteira automaticamente quando isso dispara).</p>
          <div class="form-group">
            <label>URL do Webhook</label>
            <div class="webhook-url-row">
              <input type="text" :value="jueriWebhookUrl" class="form-control" readonly />
              <button class="btn btn-secondary" @click="copyWebhookUrl">{{ copied ? 'Copiado!' : 'Copiar' }}</button>
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

const loadingPassword = ref(false)
const passwordForm = ref({
  current_password: '',
  password: '',
  password_confirmation: ''
})

const facebookPageName = ref('')
const loadingFacebookLeads = ref(false)
const jueriWebhookUrl = ref('')
const copied = ref(false)

const fetchAccountData = async () => {
  try {
    const response = await api.get('/account')
    accountName.value = response.data.account_name
    userEmail.value = response.data.email
    facebookPageName.value = response.data.facebook_page_name || ''
    jueriWebhookUrl.value = response.data.jueri_webhook_url || ''
  } catch (error) {
    console.error('Erro ao buscar dados da conta:', error)
  }
}

const copyWebhookUrl = async () => {
  try {
    await navigator.clipboard.writeText(jueriWebhookUrl.value)
    copied.value = true
    setTimeout(() => { copied.value = false }, 2000)
  } catch (error) {
    console.error('Erro ao copiar:', error)
  }
}

onMounted(() => {
  fetchAccountData()

  const params = new URLSearchParams(window.location.search)
  if (params.get('facebook_leads_connected')) {
    Swal.fire({ icon: 'success', title: 'Facebook conectado!', text: 'Os leads das suas campanhas já vão cair aqui no CRM.', confirmButtonColor: '#ff007f' })
  } else if (params.get('facebook_leads_error')) {
    Swal.fire({ icon: 'error', title: 'Erro ao conectar', text: params.get('facebook_leads_error'), confirmButtonColor: '#ff007f' })
  }
})

const connectFacebookLeads = async () => {
  loadingFacebookLeads.value = true
  try {
    const response = await api.get('/facebook_leads_oauth/authorize_url')
    window.location.href = response.data.url
  } catch (error) {
    loadingFacebookLeads.value = false
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível iniciar a conexão com o Facebook.', confirmButtonColor: '#ff007f' })
  }
}

const disconnectFacebookLeads = async () => {
  loadingFacebookLeads.value = true
  try {
    await api.post('/facebook_leads_oauth/disconnect')
    facebookPageName.value = ''
  } catch (error) {
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível desconectar.', confirmButtonColor: '#ff007f' })
  } finally {
    loadingFacebookLeads.value = false
  }
}

const updatePassword = async () => {
  if (!passwordForm.value.current_password || !passwordForm.value.password) {
    Swal.fire({
      icon: 'warning',
      title: 'Atenção',
      text: 'Preencha a senha atual e a nova senha.',
      confirmButtonColor: '#ff007f'
    })
    return
  }
  if (passwordForm.value.password !== passwordForm.value.password_confirmation) {
    Swal.fire({
      icon: 'warning',
      title: 'Atenção',
      text: 'A nova senha e a confirmação não batem.',
      confirmButtonColor: '#ff007f'
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
      confirmButtonColor: '#ff007f',
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
      confirmButtonColor: '#ff007f'
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
      confirmButtonColor: '#ff007f',
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
      confirmButtonColor: '#ff007f'
    })
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
    box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);

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
        background: #ff007f; 
        color: white;
        
        &:hover { 
          background: #cc0066; 
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

  .webhook-url-row {
    display: flex;
    gap: 0.5rem;

    .form-control { flex: 1; font-family: monospace; font-size: 0.78rem; }
    .btn { flex-shrink: 0; }
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
  }
}
</style>
