<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import Swal from 'sweetalert2'
import { brand } from '../config/brand'
import { Eye, EyeOff, Building2, User, Lock, Download, Share } from 'lucide-vue-next'
import { useInstallPrompt } from '../composables/useInstallPrompt'

const router = useRouter()
const { canInstall, isInstalled, isIOS, isStandalone, promptInstall } = useInstallPrompt()

const words = brand.name.split(' ')
const brandMain   = words.slice(0, -1).join(' ')
const brandAccent = words[words.length - 1]

const form = ref({
  company_name:          '',
  first_name:            '',
  last_name:             '',
  email:                 '',
  phone:                 '',
  password:              '',
  password_confirmation: ''
})

const showPassword  = ref(false)
const showConfirm   = ref(false)
const isLoading     = ref(false)
const errors        = ref({})

const handleRegister = async () => {
  errors.value = {}

  if (form.value.password !== form.value.password_confirmation) {
    errors.value.password_confirmation = 'As senhas não coincidem.'
    return
  }

  isLoading.value = true
  try {
    await axios.post(`${brand.apiUrl}/register`, { registration: form.value })

    await Swal.fire({
      icon: 'success',
      title: '🎉 Conta criada!',
      html: `Bem-vindo(a) ao ${brand.name}!<br>Verifique seu e-mail e acesse o sistema.`,
      confirmButtonColor: '#4338ca',
      confirmButtonText: 'Fazer login'
    })

    router.push('/login')
  } catch (e) {
    const msg = e.response?.data?.error || 'Erro ao criar conta. Tente novamente.'
    Swal.fire({
      icon: 'error',
      title: 'Erro no cadastro',
      text: msg,
      confirmButtonColor: '#4338ca'
    })
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="register-layout">

    <!-- Lado esquerdo: hero -->
    <div class="login-hero">
      <div class="hero-overlay"></div>
      <div class="hero-content">
        <h1 class="hero-brand">{{ brandMain }}<span>{{ brandAccent }}</span></h1>
        <p class="hero-tagline">Cadastre sua imobiliária e comece a atender leads com IA no WhatsApp em minutos.</p>
        <div class="hero-badges">
          <span class="hero-badge">IA no WhatsApp</span>
          <span class="hero-badge">Rodízio automático</span>
          <span class="hero-badge">Portais integrados</span>
          <span class="hero-badge">Sem cartão de crédito</span>
        </div>
      </div>
    </div>

    <!-- Lado direito: formulário -->
    <div class="register-panel">
      <div class="auth-card">
        <div class="auth-header">
          <h2>Cadastrar imobiliária</h2>
          <p>Crie sua conta gratuitamente e comece agora.</p>
        </div>

        <form @submit.prevent="handleRegister" class="auth-form">

          <!-- Empresa -->
          <div class="form-section-label">
            <Building2 :size="14" /> Dados da empresa
          </div>

          <div class="form-group">
            <label>Nome da imobiliária</label>
            <input v-model="form.company_name" type="text" placeholder="Ex: Imobiliária Central" required />
          </div>

          <!-- Responsável -->
          <div class="form-section-label" style="margin-top:0.25rem">
            <User :size="14" /> Responsável
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Nome</label>
              <input v-model="form.first_name" type="text" placeholder="João" required />
            </div>
            <div class="form-group">
              <label>Sobrenome</label>
              <input v-model="form.last_name" type="text" placeholder="Silva" required />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>E-mail</label>
              <input v-model="form.email" type="email" placeholder="joao@imobiliaria.com.br" required />
            </div>
            <div class="form-group">
              <label>WhatsApp <span class="optional">(opcional)</span></label>
              <input v-model="form.phone" type="tel" placeholder="(11) 99999-9999" />
            </div>
          </div>

          <!-- Senha -->
          <div class="form-section-label" style="margin-top:0.25rem">
            <Lock :size="14" /> Senha de acesso
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Senha</label>
              <div class="input-eye">
                <input
                  :type="showPassword ? 'text' : 'password'"
                  v-model="form.password"
                  placeholder="Mínimo 6 caracteres"
                  required
                  minlength="6"
                />
                <button type="button" class="eye-btn" @click="showPassword = !showPassword" tabindex="-1">
                  <EyeOff v-if="showPassword" :size="16" />
                  <Eye v-else :size="16" />
                </button>
              </div>
            </div>
            <div class="form-group">
              <label>Confirmar senha</label>
              <div class="input-eye">
                <input
                  :type="showConfirm ? 'text' : 'password'"
                  v-model="form.password_confirmation"
                  placeholder="Repita a senha"
                  required
                  minlength="6"
                />
                <button type="button" class="eye-btn" @click="showConfirm = !showConfirm" tabindex="-1">
                  <EyeOff v-if="showConfirm" :size="16" />
                  <Eye v-else :size="16" />
                </button>
              </div>
              <span v-if="errors.password_confirmation" class="field-error">
                {{ errors.password_confirmation }}
              </span>
            </div>
          </div>

          <button type="submit" class="btn-primary" :disabled="isLoading">
            {{ isLoading ? 'Criando conta...' : 'Criar conta grátis' }}
          </button>
        </form>

        <div class="auth-footer">
          <p>Já tem uma conta? <router-link to="/login">Fazer login</router-link></p>
        </div>

        <div v-if="!isInstalled && !isStandalone && canInstall" class="install-banner">
          <button class="install-btn" type="button" @click="promptInstall">
            <Download :size="16" /> Instalar aplicativo
          </button>
        </div>

        <div v-else-if="!isInstalled && !isStandalone && isIOS" class="install-banner ios-hint">
          <Share :size="14" />
          <span>Toque em <strong>Compartilhar</strong> e depois em <strong>"Adicionar à Tela de Início"</strong> pra instalar o app.</span>
        </div>
      </div>
    </div>

  </div>
</template>

<style lang="scss" scoped>
.register-layout {
  display: flex;
  min-height: 100vh;
}

.login-hero {
  flex: 1;
  position: relative;
  background: url('/login-bg.jpg') center center / cover no-repeat;
  display: flex;
  align-items: flex-end;
  padding: 3rem;

  @media (max-width: 900px) { display: none; }
}

.hero-overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(15,23,42,0.35) 0%, rgba(15,23,42,0.72) 100%);
}

.hero-content {
  position: relative;
  z-index: 1;
  color: white;
  max-width: 520px;
}

.hero-brand {
  font-size: 2.2rem;
  font-weight: 800;
  margin-bottom: 1rem;
  letter-spacing: -0.03em;
  span { color: #60a5fa; }
}

.hero-tagline {
  font-size: 1.05rem;
  line-height: 1.6;
  color: rgba(255,255,255,0.85);
  margin-bottom: 1.5rem;
}

.hero-badges {
  display: flex;
  gap: 0.6rem;
  flex-wrap: wrap;
}

.hero-badge {
  background: rgba(255,255,255,0.15);
  border: 1px solid rgba(255,255,255,0.25);
  backdrop-filter: blur(6px);
  color: white;
  font-size: 0.78rem;
  font-weight: 600;
  padding: 0.3rem 0.8rem;
  border-radius: 20px;
}

.register-panel {
  width: 520px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  background: var(--bg-primary, #ffffff);
  overflow-y: auto;

  @media (max-width: 900px) {
    width: 100%;
    padding: 1.5rem;
  }
}

.auth-card {
  width: 100%;
  max-width: 460px;
  padding: 1rem 0;
}

.auth-header {
  margin-bottom: 1.5rem;

  h2 {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--text-main, #111827);
    margin-bottom: 0.3rem;
  }

  p { color: var(--text-muted, #6b7280); font-size: 0.9rem; }
}

.form-section-label {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.73rem;
  font-weight: 700;
  color: var(--text-muted, #6b7280);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin-bottom: 0.5rem;
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;

  @media (max-width: 500px) { grid-template-columns: 1fr; }
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;

  label {
    font-size: 0.82rem;
    font-weight: 500;
    color: var(--text-main, #111827);
  }

  input {
    padding: 0.65rem 0.9rem;
    border: 1px solid var(--border-color, #e5e7eb);
    border-radius: 8px;
    font-size: 0.9rem;
    outline: none;
    width: 100%;
    background: var(--bg-primary, #fff);
    color: var(--text-main, #111827);
    transition: border-color 0.2s, box-shadow 0.2s;
    box-sizing: border-box;

    &:focus {
      border-color: #4338ca;
      box-shadow: 0 0 0 3px rgba(67,56,202,0.1);
    }
  }
}

.input-eye {
  position: relative;
  display: flex;
  align-items: center;

  input { padding-right: 2.5rem; }

  .eye-btn {
    position: absolute;
    right: 0.7rem;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-muted, #6b7280);
    display: flex;
    padding: 0;
    &:hover { color: #4338ca; }
  }
}

.optional {
  font-weight: 400;
  color: var(--text-muted, #9ca3af);
  font-size: 0.75rem;
}

.field-error {
  font-size: 0.78rem;
  color: #dc2626;
}

.btn-primary {
  background: #4338ca;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 0.9rem;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  margin-top: 0.5rem;
  width: 100%;
  transition: opacity 0.2s;

  &:hover:not(:disabled) { opacity: 0.9; }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
}

.auth-footer {
  text-align: center;
  margin-top: 1.5rem;
  font-size: 0.88rem;
  color: var(--text-muted, #6b7280);

  a {
    font-weight: 600;
    color: #4338ca;
    text-decoration: none;
    &:hover { text-decoration: underline; }
  }
}

.install-banner {
  margin-top: 1.25rem;
}

.install-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  background: transparent;
  color: #4338ca;
  border: 1px solid #4338ca;
  border-radius: 8px;
  padding: 0.7rem;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;

  &:hover { background: rgba(67,56,202,0.06); }
}

.ios-hint {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  background: rgba(67,56,202,0.05);
  border: 1px solid rgba(67,56,202,0.15);
  border-radius: 8px;
  padding: 0.75rem 0.9rem;
  font-size: 0.8rem;
  color: var(--text-muted, #6b7280);
  line-height: 1.4;

  svg { flex-shrink: 0; margin-top: 0.15rem; color: #4338ca; }
  strong { color: var(--text-main, #111827); }
}
</style>
