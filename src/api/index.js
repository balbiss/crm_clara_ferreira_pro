import axios from 'axios'

const api = axios.create({
  baseURL: window.__APP_CONFIG__?.apiUrl || import.meta.env.VITE_API_URL || 'http://localhost:3000',
  headers: {
    'Content-Type': 'application/json'
  }
})

// Optional: Add request interceptor for auth tokens
api.interceptors.request.use(config => {
  const token = localStorage.getItem('auth_token')
  if (token) {
    config.headers.Authorization = token
  }
  return config
})

api.interceptors.response.use(
  response => response,
  error => {
    if (error.response && error.response.status === 402) {
      if (error.response.data && error.response.data.error === 'subscription_required') {
        // Redireciona para a tela de conta usando window.location.href para ser à prova de falhas com o router
        if (window.location.pathname !== '/settings/account') {
          window.location.href = '/settings/account?blocked=true'
        }
      }
    }
    if (error.response && error.response.status === 401) {
      // Sessão expirada/invalida: limpa dados da sessao anterior e forca reload completo
      // para garantir que nenhum estado (Pinia) de outro login fique preso em memoria.
      localStorage.removeItem('auth_token')
      localStorage.removeItem('user')
      if (window.location.pathname !== '/login') {
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

export default api
