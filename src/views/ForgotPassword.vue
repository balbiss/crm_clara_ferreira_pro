<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import Swal from 'sweetalert2'
import { brand } from '../config/brand'

const router = useRouter()
const email = ref('')
const isLoading = ref(false)

const handleForgotPassword = async () => {
  if (!email.value) return
  
  isLoading.value = true
  
  try {
    await axios.post(`${brand.apiUrl}/users/password`, {
      user: {
        email: email.value
      }
    })
    
    await Swal.fire({
      icon: 'success',
      title: 'E-mail enviado!',
      text: 'Se este e-mail estiver cadastrado, você receberá um link para redefinir sua senha.',
      confirmButtonColor: '#2563eb'
    })
    
    router.push('/login')
  } catch (error) {
    console.error("Forgot password error", error)
    // Para segurança, a maioria dos sistemas diz "E-mail enviado" mesmo se falhar, mas 
    // como estamos no desenvolvimento do nosso SaaS, vamos mostrar o erro se houver
    Swal.fire({
      icon: 'error',
      title: 'Ops...',
      text: 'Houve um problema ao processar sua solicitação. Verifique o e-mail e tente novamente.',
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
        <h2>Recuperar Senha</h2>
        <p>Digite seu e-mail para receber um link de redefinição de senha.</p>
      </div>

      <form @submit.prevent="handleForgotPassword" class="auth-form">
        <div class="form-group">
          <label for="email">E-mail Corporativo</label>
          <input 
            type="email" 
            id="email" 
            v-model="email" 
            placeholder="seu@email.com" 
            required 
          />
        </div>

        <button type="submit" class="btn-primary" :disabled="isLoading">
          {{ isLoading ? 'Enviando...' : 'Enviar Link de Recuperação' }}
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
  }
}
</style>
