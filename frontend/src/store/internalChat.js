import { defineStore } from 'pinia'
import Swal from 'sweetalert2'
import api from '../api'

const previewFor = (msg) => {
  if (msg.text) return msg.text
  if (msg.attachment_type?.startsWith('image/')) return '📷 Foto'
  if (msg.attachment_type?.startsWith('audio/')) return '🎤 Áudio'
  if (msg.attachment_type) return `📎 ${msg.attachment_name || 'Documento'}`
  return ''
}

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

    // file opcional — foto, documento ou áudio gravado na hora (Blob).
    async sendMessage(text, file = null) {
      const trimmed = (text || '').trim()
      if (!this.activeUserId || (!trimmed && !file)) return

      const formData = new FormData()
      formData.append('recipient_id', this.activeUserId)
      if (trimmed) formData.append('text', trimmed)
      if (file) formData.append('attachment', file, file.name || 'audio.webm')

      // A instância `api` tem Content-Type: application/json fixo por padrão
      // (src/api/index.js) — isso vazava pra esse POST mesmo mandando
      // FormData, e o servidor recebia multipart sem o "boundary" que só o
      // navegador sabe gerar. undefined aqui faz o axios deixar o navegador
      // decidir sozinho (era a causa real do "Erro ao enviar áudio": 500).
      const { data } = await api.post('/internal_messages', formData, {
        headers: { 'Content-Type': undefined }
      })

      if (!this.messagesByUser[this.activeUserId]) this.messagesByUser[this.activeUserId] = []
      if (!this.messagesByUser[this.activeUserId].some(m => m.id === data.id)) {
        this.messagesByUser[this.activeUserId].push(data)
      }
      const t = this.threads.find(t => t.id === this.activeUserId)
      if (t) {
        t.last_message = previewFor(data)
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
          const isIncoming = msg.recipient_id === me
          const isViewingThread = this.activeUserId === otherId

          if (!this.messagesByUser[otherId]) this.messagesByUser[otherId] = []
          if (!this.messagesByUser[otherId].some(m => m.id === msg.id)) {
            this.messagesByUser[otherId].push(msg)
          }

          const t = this.threads.find(t => t.id === otherId)
          if (t) {
            t.last_message = previewFor(msg)
            t.last_message_at = msg.created_at
            if (isIncoming && !isViewingThread) {
              t.unread_count = (t.unread_count || 0) + 1
              this.notifyNewMessage(t, msg)
            } else if (isIncoming && isViewingThread) {
              // Já está com a conversa aberta — marca como lida no servidor
              // sem precisar reabrir a thread inteira.
              api.get('/internal_messages', { params: { with: otherId } }).catch(() => {})
            }
          } else {
            this.fetchThreads().then(() => {
              if (isIncoming) {
                const newT = this.threads.find(t => t.id === otherId)
                if (newT) this.notifyNewMessage(newT, msg)
              }
            })
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
    },

    // Toast estilo WhatsApp quando chega mensagem de um colega que não é a
    // conversa aberta no momento — igual ao badge de não lidas na sidebar.
    notifyNewMessage(thread, msg) {
      const name = `${thread.first_name || ''} ${thread.last_name || ''}`.trim() || 'Colega'
      Swal.fire({
        toast: true,
        position: 'top-end',
        icon: 'info',
        title: name,
        text: previewFor(msg),
        showConfirmButton: false,
        timer: 4500,
        timerProgressBar: true
      })
    }
  }
})
