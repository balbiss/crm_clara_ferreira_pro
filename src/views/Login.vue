<script setup>
import { ref, onMounted } from 'vue'
import axios from 'axios'
import Swal from 'sweetalert2'
import { brand } from '../config/brand'
import { Eye, EyeOff, Download, Share } from 'lucide-vue-next'
import { useInstallPrompt } from '../composables/useInstallPrompt'

const { canInstall, isInstalled, isIOS, isStandalone, promptInstall } = useInstallPrompt()

const words = brand.name.split(' ')
const brandMain = words.slice(0, -1).join(' ')
const brandAccent = words[words.length - 1]
const email = ref('')
const password = ref('')
const showPassword = ref(false)
const rememberMe = ref(false)
const isLoading = ref(false)

onMounted(() => {
  const saved = localStorage.getItem('remembered_email')
  if (saved) {
    email.value = saved
    rememberMe.value = true
  }
})

const handleLogin = async () => {
  isLoading.value = true

  if (rememberMe.value) {
    localStorage.setItem('remembered_email', email.value)
  } else {
    localStorage.removeItem('remembered_email')
  }

  try {
    const response = await axios.post(`${brand.apiUrl}/users/sign_in`, {
      user: {
        email: email.value,
        password: password.value
      }
    })

    const token = response.headers.authorization
    if (token) {
      localStorage.setItem('auth_token', token)
    }

    if (response.data && response.data.user) {
      localStorage.setItem('user', JSON.stringify(response.data.user))
    }

    await Swal.fire({
      icon: 'success',
      title: 'Login realizado!',
      text: `Bem-vindo de volta ao ${brand.name}.`,
      confirmButtonColor: '#2563eb',
      timer: 1500,
      showConfirmButton: false
    })

    if (response.data && response.data.user && response.data.user.role === 'admin') {
      window.location.href = '/admin'
    } else {
      window.location.href = '/dashboard'
    }
  } catch (error) {
    console.error("Login error", error)
    Swal.fire({
      icon: 'error',
      title: 'Acesso Negado',
      text: 'E-mail ou senha incorretos. Verifique e tente novamente.',
      confirmButtonColor: '#2563eb',
      customClass: { icon: 'swal-icon-pulse-slow' }
    })
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="login-layout">

    <!-- Lado esquerdo: imagem + branding -->
    <div class="login-hero">
      <div class="hero-overlay"></div>
      <div class="hero-content">
        <h1 class="hero-brand">{{ brandMain }}<span>{{ brandAccent }}</span></h1>
        <p class="hero-tagline">Gerencie seus leads, imóveis e equipe em um só lugar — com IA trabalhando 24h para você.</p>
        <div class="hero-badges">
          <span class="hero-badge">IA no WhatsApp</span>
          <span class="hero-badge">Rodízio automático</span>
          <span class="hero-badge">Portais integrados</span>
        </div>
      </div>
    </div>

    <!-- Lado direito: formulário -->
    <div class="login-panel">
      <div class="auth-card">
        <div class="auth-header">
          <h2>Bem-vindo de volta</h2>
          <p>Acesse sua conta para gerenciar seus imóveis e leads.</p>
        </div>

        <form @submit.prevent="handleLogin" class="auth-form">
          <div class="form-group">
            <label for="email">E-mail</label>
            <input
              type="email"
              id="email"
              v-model="email"
              placeholder="seu@email.com"
              required
            />
          </div>

          <div class="form-group">
            <label for="password">Senha</label>
            <div class="input-eye">
              <input
                :type="showPassword ? 'text' : 'password'"
                id="password"
                v-model="password"
                placeholder="••••••••"
                required
              />
              <button type="button" class="eye-btn" @click="showPassword = !showPassword" tabindex="-1">
                <EyeOff v-if="showPassword" :size="18" />
                <Eye v-else :size="18" />
              </button>
            </div>
          </div>

          <div class="form-actions">
            <label class="remember-me">
              <input type="checkbox" v-model="rememberMe" />
              Lembrar de mim
            </label>
            <router-link to="/forgot-password" class="forgot-password">Esqueceu a senha?</router-link>
          </div>

          <button type="submit" class="btn-primary" :disabled="isLoading">
            {{ isLoading ? 'Entrando...' : 'Entrar' }}
          </button>
        </form>

        <div class="auth-footer">
          <p>Ainda não tem uma conta? <router-link to="/register">Crie uma agora</router-link></p>
        </div>

        <div v-if="!isInstalled && !isStandalone && canInstall" class="install-banner">
          <button class="install-btn" @click="promptInstall">
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
/* ── Layout principal ── */
.login-layout {
  display: flex;
  min-height: 100vh;
}

/* ── Lado esquerdo: hero com imagem ── */
.login-hero {
  flex: 1;
  position: relative;
  background: url('/login-bg.jpg') center center / cover no-repeat;
  display: flex;
  align-items: flex-end;
  padding: 3rem;

  @media (max-width: 768px) { display: none; }
}

.hero-overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    to bottom,
    rgba(15, 23, 42, 0.35) 0%,
    rgba(15, 23, 42, 0.72) 100%
  );
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
  letter-spacing: 0.02em;
}

/* ── Lado direito: painel do formulário ── */
.login-panel {
  width: 440px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  background: var(--bg-primary, #ffffff);

  @media (max-width: 768px) {
    width: 100%;
    padding: 1.5rem;
  }
}

.auth-card {
  width: 100%;
  max-width: 380px;
}

.auth-header {
  margin-bottom: 2rem;

  h2 {
    font-size: 1.6rem;
    font-weight: 700;
    color: var(--text-main, #111827);
    margin-bottom: 0.4rem;
  }

  p {
    color: var(--text-muted, #6b7280);
    font-size: 0.9rem;
    line-height: 1.5;
  }
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: 1.2rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;

  label {
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--text-main, #111827);
  }

  input {
    padding: 0.75rem 1rem;
    border: 1px solid var(--border-color, #e5e7eb);
    border-radius: 8px;
    font-size: 0.95rem;
    outline: none;
    width: 100%;
    transition: border-color 0.2s, box-shadow 0.2s;
    background: var(--bg-primary, #fff);
    color: var(--text-main, #111827);

    &:focus {
      border-color: var(--primary, #4338ca);
      box-shadow: 0 0 0 3px rgba(67,56,202,0.12);
    }
  }
}

.input-eye {
  position: relative;
  display: flex;
  align-items: center;

  input { padding-right: 2.75rem; }

  .eye-btn {
    position: absolute;
    right: 0.75rem;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-muted, #6b7280);
    display: flex;
    align-items: center;
    padding: 0;
    &:hover { color: var(--primary, #4338ca); }
  }
}

.form-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 0.85rem;

  .remember-me {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    cursor: pointer;
    color: var(--text-muted, #6b7280);
  }

  .forgot-password {
    font-weight: 500;
    color: var(--primary, #4338ca);
    text-decoration: none;
    &:hover { text-decoration: underline; }
  }
}

.btn-primary {
  background: var(--primary, #4338ca);
  color: white;
  border: none;
  border-radius: 8px;
  padding: 0.85rem;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  margin-top: 0.25rem;
  transition: opacity 0.2s;
  width: 100%;

  &:hover:not(:disabled) { opacity: 0.9; }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
}

.auth-footer {
  text-align: center;
  margin-top: 2rem;
  font-size: 0.88rem;
  color: var(--text-muted, #6b7280);

  a {
    font-weight: 600;
    color: var(--primary, #4338ca);
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
  color: var(--primary, #4338ca);
  border: 1px solid var(--primary, #4338ca);
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

  svg { flex-shrink: 0; margin-top: 0.15rem; color: var(--primary, #4338ca); }
  strong { color: var(--text-main, #111827); }
}
</style>
