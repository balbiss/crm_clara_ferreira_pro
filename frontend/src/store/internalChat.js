import { defineStore } from 'pinia'
import api from '../api'

// Chat interno da equipe (consultor <-> gerente <-> financeiro <-> diretoria)
// — sem relação nenhuma com WhatsApp/revendedora, ver InternalMessage no
// backend. Mesmo protocolo de WebSocket cru falando ActionCable que
// store/conversations.js já usa, só que num canal separado.
export const useInternalChatStore = defineStore('internalChat', {
  state: () => ({
    threads: [],
    activeUserId: null,
    messagesByUser: {},
    ws: null,
    isLoadingThreads: false,
    isLoadingMessages: false,
    currentUser: (() => {
      try {
        return JSON.parse(localStorage.getItem('user')) || {}
      } catch {
        return {}
      }
    })()
  }),

  getters: {
    activeMessages(state) {
      return state.messagesByUser[state.activeUserId] || []
    },
    activeThread(state) {
      return state.threads.find(t => t.id === state.activeUserId) || null
    },
    totalUnread(state) {
      return state.threads.reduce((sum, t) => sum + (t.unread_count || 0), 0)
    }
  },

  actions: {
    async fetchThreads() {
      this.isLoadingThreads = true
      try {
        const { data } = await api.get('/internal_messages/threads')
        this.threads = data
      } catch (error) {
        console.error('Erro ao buscar conversas internas:', error)
      } finally {
        this.isLoadingThreads = false
      }
    },

    async openThread(userId) {
      this.activeUserId = userId
      this.isLoadingMessages = true
      try {
        const { data } = await api.get('/internal_messages', { params: { with: userId } })
        this.messagesByUser[userId] = data
        const t = this.threads.find(t => t.id === userId)
        if (t) t.unread_count = 0
      } catch (error) {
        console.error('Erro ao abrir conversa interna:', error)
      } finally {
        this.isLoadingMessages = false
      }
    },

    async sendMessage(text) {
      const trimmed = (text || '').trim()
      if (!this.activeUserId || !trimmed) return
      const { data } = await api.post('/internal_messages', { recipient_id: this.activeUserId, text: trimmed })
      if (!this.messagesByUser[this.activeUserId]) this.messagesByUser[this.activeUserId] = []
      if (!this.messagesByUser[this.activeUserId].some(m => m.id === data.id)) {
        this.messagesByUser[this.activeUserId].push(data)
      }
      const t = this.threads.find(t => t.id === this.activeUserId)
      if (t) {
        t.last_message = data.text
        t.last_message_at = data.created_at
      }
      return data
    },

    setupWebSocket() {
      if (this.ws) return

      let baseURL = api.defaults.baseURL
      if (!baseURL) {
        baseURL = window.location.origin.replace(':5173', ':3000')
      }

      const rawToken = (localStorage.getItem('auth_token') || '').replace(/^Bearer\s+/i, '')
      const wsURL = baseURL.replace(/^http/, 'ws') + '/cable?token=' + rawToken
      const ws = new WebSocket(wsURL)
      this.ws = ws

      ws.onopen = () => {
        ws.send(JSON.stringify({
          command: 'subscribe',
          identifier: JSON.stringify({ channel: 'InternalChatChannel' })
        }))
      }

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          if (data.type === 'ping' || data.type === 'welcome' || data.type === 'confirm_subscription') return

          const payload = data.message
          if (!payload || payload.event !== 'internal_message_created') return

          const msg = payload.message
          const me = this.currentUser.id
          if (msg.sender_id !== me && msg.recipient_id !== me) return

          const otherId = msg.sender_id === me ? msg.recipient_id : msg.sender_id
          if (!this.messagesByUser[otherId]) this.messagesByUser[otherId] = []
          if (!this.messagesByUser[otherId].some(m => m.id === msg.id)) {
            this.messagesByUser[otherId].push(msg)
          }

          let t = this.threads.find(t => t.id === otherId)
          if (t) {
            t.last_message = msg.text
            t.last_message_at = msg.created_at
            if (msg.recipient_id === me && this.activeUserId !== otherId) {
              t.unread_count = (t.unread_count || 0) + 1
            } else if (msg.recipient_id === me && this.activeUserId === otherId) {
              // Já está com a conversa aberta — marca como lida no servidor
              // sem precisar reabrir a thread inteira.
              api.get('/internal_messages', { params: { with: otherId } }).catch(() => {})
            }
          } else {
            this.fetchThreads()
          }
        } catch (e) {
          console.error('Erro processando mensagem do chat interno:', e)
        }
      }

      ws.onclose = () => {
        this.ws = null
        setTimeout(() => this.setupWebSocket(), 2000)
      }

      ws.onerror = () => {
        ws.close()
      }
    }
  }
})
