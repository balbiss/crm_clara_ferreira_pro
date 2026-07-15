<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import axios from 'axios'
import Swal from 'sweetalert2'
import { brand } from '../config/brand'

const router = useRouter()
const route = useRoute()

const password = ref('')
const passwordConfirmation = ref('')
const resetToken = ref('')
const isLoading = ref(false)

onMounted(() => {
  if (route.query.reset_password_token) {
    resetToken.value = route.query.reset_password_token
  } else {
    Swal.fire({
      icon: 'error',
      title: 'Link Inválido',
      text: 'O link de recuperação parece estar quebrado ou incompleto.',
      confirmButtonColor: '#2563eb'
    }).then(() => {
      router.push('/login')
    })
  }
})

const handleResetPassword = async () => {
  if (password.value !== passwordConfirmation.value) {
    Swal.fire({
      icon: 'warning',
      title: 'Atenção',
      text: 'As senhas não coincidem. Digite novamente.',
      confirmButtonColor: '#2563eb'
    })
    return
  }

  isLoading.value = true
  
  try {
    const response = await axios.put(`${brand.apiUrl}/users/password`, {
      user: {
        reset_password_token: resetToken.value,
        password: password.value,
        password_confirmation: passwordConfirmation.value
      }
    })
    
    await Swal.fire({
      icon: 'success',
      title: 'Senha Redefinida!',
      text: response.data.message || 'Sua senha foi redefinida com sucesso. Você já pode fazer login.',
      confirmButtonColor: '#2563eb',
      timer: 2500,
      showConfirmButton: false
    })
    
    router.push('/login')
  } catch (error) {
    console.error("Reset password error", error)
    let errorMsg = 'Houve um erro ao redefinir sua senha. O link pode ter expirado.'
    if (error.response && error.response.data && error.response.data.errors) {
      errorMsg = error.response.data.errors.join(', ')
    }

    Swal.fire({
      icon: 'error',
      title: 'Ops...',
      text: errorMsg,
      confirmButtonColor: '#2563eb',
      customClass: { icon: 'swal-icon-pulse-slow' }
    })
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="auth-container">
    <div class="auth-card">
      <div class="auth-header">
        <h1 class="logo">Innova<span>web</span></h1>
        <h2>Criar Nova Senha</h2>
        <p>Digite sua nova senha abaixo para recuperar o acesso.</p>
      </div>

      <form @submit.prevent="handleResetPassword" class="auth-form" v-if="resetToken">
        <div class="form-group">
          <label for="password">Nova Senha</label>
          <input 
            type="password" 
            id="password" 
            v-model="password" 
            placeholder="Mínimo 6 caracteres" 
            required 
            minlength="6"
          />
        </div>

        <div class="form-group">
          <label for="password_confirmation">Confirmar Nova Senha</label>
          <input 
            type="password" 
            id="password_confirmation" 
            v-model="passwordConfirmation" 
            placeholder="Repita a nova senha" 
            required 
            minlength="6"
          />
        </div>

        <button type="submit" class="btn-primary" :disabled="isLoading">
          {{ isLoading ? 'Salvando...' : 'Salvar Nova Senha' }}
        </button>
      </form>

      <div class="auth-footer">
        <p>Lembrou da senha? <router-link to="/login">Voltar ao Login</router-link></p>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.auth-container {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 1rem;
}

.auth-card {
  background: var(--card-bg);
  width: 100%;
  max-width: 420px;
  border-radius: 12px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.05);
  padding: 2.5rem;
}

.auth-header {
  text-align: center;
  margin-bottom: 2rem;

  .logo {
    font-size: 1.8rem;
    font-weight: 700;
    color: var(--text-main);
    margin-bottom: 1.5rem;
    
    span {
      color: var(--primary);
    }
  }

  h2 {
    font-size: 1.5rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
  }

  p {
    color: var(--text-muted);
    font-size: 0.95rem;
    line-height: 1.4;
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
    font-size: 0.9rem;
    font-weight: 500;
    color: var(--text-main);
  }

  input {
    width: 100%;
    box-sizing: border-box;
    padding: 0.75rem 1rem;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    font-size: 0.95rem;
    outline: none;
    transition: all 0.2s;

    &:focus {
      border-color: var(--primary);
      box-shadow: 0 0 0 3px var(--input-focus);
    }
  }
}

.btn-primary {
  background: var(--primary);
  color: white;
  border: none;
  border-radius: 8px;
  padding: 0.8rem;
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  margin-top: 0.5rem;
  transition: background 0.2s;

  &:hover {
    background: var(--primary-hover);
  }
  
  &:disabled {
    background: #94a3b8;
    cursor: not-allowed;
  }
}

.auth-footer {
  text-align: center;
  margin-top: 2rem;
  font-size: 0.9rem;
  color: var(--text-muted);

  a {
    font-weight: 500;
    color: var(--primary);
    text-decoration: none;
    &:hover {
      text-decoration: underline;
    }
  }
}
</style>
