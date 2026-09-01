import { defineStore } from 'pinia'
import api from '../api'

export const useConversationsStore = defineStore('conversations', {
  state: () => ({
    conversations: [],
    agents: [],
    activeConversationId: null,
    currentFilter: 'todos', // todos, minhas, nao-atribuidos
    sidebarFilter: 'all',
    sidebarInboxId: null,
    sortStatus: 'open',
    sortBy: 'latest',
    sortType: 'all',
    advancedFilters: [],
    ws: null,
    currentUser: (() => {
      try {
        return JSON.parse(localStorage.getItem('user')) || { first_name: 'Usuário', email: '' }
      } catch {
        return { first_name: 'Usuário', email: '' }
      }
    })()
  }),

  getters: {
    activeConversation(state) {
      return state.conversations.find(c => c.id === state.activeConversationId) || null
    },
    sidebarFilteredConversations(state) {
      // "Iniciar conversa" (Minhas Revendedoras/Tarefas) cria a Conversation
      // na hora pra permitir mensagem proativa (régua), mas isso não deveria
      // virar item permanente na lista só por ter sido aberta — só entra na
      // lista quem já trocou mensagem de verdade. A conversa que está aberta
      // agora continua visível mesmo vazia (senão ela "some" da tela embaixo
      // dela mesma enquanto o usuário ainda está digitando a primeira msg).
      let filtered = state.conversations.filter(c =>
        (c.messages && c.messages.length > 0) || c.id === state.activeConversationId
      )

      // Sort Status filter
      if (state.sortStatus !== 'all') {
        filtered = filtered.filter(c => c.status === state.sortStatus)
      }

      // Sort Type filter
      if (state.sortType === 'unread') {
        filtered = filtered.filter(c => c.unread > 0)
      } else if (state.sortType === 'mentions') {
        filtered = filtered.filter(() => false) // Mock mentions
      }

      // Sidebar route param filter overrides
      if (state.sidebarFilter === 'mencoes') {
        filtered = filtered.filter(() => false) // Mock
      } else if (state.sidebarFilter === 'participantes') {
        // "Chats da equipe" = conversas atribuídas a OUTRO membro da equipe
        // (não as minhas, não as sem responsável — essas já têm filtro próprio).
        filtered = filtered.filter(c => c.assignee_id && c.assignee_id !== state.currentUser.id)
      } else if (state.sidebarFilter === 'nao-atendidas') {
        filtered = filtered.filter(c => c.status === 'open' && c.unread > 0)
      }

      // Inbox Filter
      if (state.sidebarInboxId) {
        filtered = filtered.filter(c => String(c.inbox_id) === String(state.sidebarInboxId))
      }

      return filtered
    },
    filteredConversations(state) {
      let filtered = this.sidebarFilteredConversations
      
      if (state.currentFilter === 'minhas') {
        filtered = filtered.filter(c => c.assignee_id === state.currentUser.id)
      } else if (state.currentFilter === 'nao-atribuidos') {
        filtered = filtered.filter(c => !c.assignee)
      }
      
      // Apply advanced filters
      if (state.advancedFilters && state.advancedFilters.length > 0) {
        state.advancedFilters.forEach(filter => {
          if (!filter.attribute || !filter.operator || !filter.value) return;
          
          filtered = filtered.filter(c => {
            let actualValue;
            
            if (filter.attribute === 'status') {
              actualValue = c.status;
            } else if (filter.attribute === 'assignee') {
              actualValue = c.assignee || 'unassigned';
            } else if (filter.attribute === 'sem_resposta') {
              // Última mensagem foi do cliente = ninguém da equipe/IA
              // respondeu ainda. Diferente de "não lida" (unread), que é
              // só sobre o agente ter aberto a conversa ou não.
              const msgs = c.messages || []
              const last = msgs[msgs.length - 1]
              actualValue = last && last.senderType === 'contact' ? 'sim' : 'nao'
            }
            
            if (filter.operator === 'equal_to') {
              return actualValue === filter.value;
            } else if (filter.operator === 'not_equal_to') {
              return actualValue !== filter.value;
            }
            return true;
          });
        });
      }

      // Apply Sort By — spread to avoid mutating state.conversations in place.
      // `timestamp` é só "HH:MM" (exibição) — sem data, new Date() dava
      // Invalid Date pra tudo e o sort não reordenava nada na prática
      // (reclamação real: "Ordenar não está ordenando"). last_activity_iso
      // é o valor de verdade (data completa) que o backend manda pra isso.
      const sortValue = (c) => new Date(c.last_activity_iso || c.timestamp).getTime() || 0
      if (state.sortBy === 'oldest') {
        filtered = [...filtered].sort((a, b) => sortValue(a) - sortValue(b))
      } else {
        filtered = [...filtered].sort((a, b) => sortValue(b) - sortValue(a))
      }

      return filtered
    }
  },

  actions: {
    async fetchConversations() {
      try {
        const response = await api.get('/conversations')
        this.conversations = response.data
        if (!this.activeConversationId) {
          this.activeConversationId = this.sidebarFilteredConversations[0]?.id || null
        }
        this.setupWebSocket()
      } catch (error) {
        console.error('Error fetching conversations:', error)
      }
    },

    // Inicia (ou reabre) a conversa de uma revendedora que ainda não trocou
    // mensagem nenhuma — sem isso não tinha como mandar a "mensagem de
    // incentivo" do 3º/10º/20º dia da régua manualmente.
    async startConversation(contactId) {
      const { data } = await api.post('/conversations', { contact_id: contactId })
      const existing = this.conversations.findIndex(c => c.id === data.id)
      if (existing !== -1) {
        this.conversations[existing] = data
      } else {
        this.conversations.unshift(data)
      }
      return data
    },

    async fetchAgents() {
      try {
        const response = await api.get('/agents')
        this.agents = response.data
      } catch (error) {
        console.error('Error fetching agents:', error)
      }
    },

    async assignConversation(conversationId, userId) {
      try {
        const response = await api.put(`/conversations/${conversationId}`, {
          conversation: { user_id: userId }
        })

        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          // Update the local conversation state
          this.conversations[convIndex].assignee_id = response.data.assignee_id
          this.conversations[convIndex].assignee = response.data.assignee
        }
      } catch (error) {
        console.error('Error assigning conversation:', error)
        throw error
      }
    },

    async transferConversation(conversationId, userId, note) {
      try {
        const response = await api.put(`/conversations/${conversationId}`, {
          conversation: { user_id: userId },
          transfer_note: note
        })
        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          this.conversations[convIndex].assignee_id = response.data.assignee_id
          this.conversations[convIndex].assignee = response.data.assignee
        }
        return response.data
      } catch (error) {
        console.error('Error transferring conversation:', error)
        throw error
      }
    },

    setActiveConversation(id) {
      this.activeConversationId = id
      const conv = this.conversations.find(c => c.id === id)
      if (conv) {
        conv.unread = 0
      }
    },

    setFilter(filterType) {
      this.currentFilter = filterType
    },

    setSidebarFilter(filterType) {
      this.sidebarFilter = filterType
      this.sidebarInboxId = null
      this.reconcileActiveConversation()
    },

    setSidebarInboxId(inboxId) {
      this.sidebarInboxId = inboxId
      this.sidebarFilter = null
      this.reconcileActiveConversation()
    },

    // Sem isso, ao trocar de filtro/caixa (ex: clicar numa caixa específica
    // no menu) o painel da direita continuava mostrando a conversa que tinha
    // sido selecionada automaticamente antes (a mais recente da conta
    // inteira, escolhida em fetchConversations) mesmo que ela não pertença
    // ao filtro atual — dava a impressão de "sempre cai na conversa errada"
    // ao recarregar a página numa rota filtrada.
    reconcileActiveConversation() {
      const stillVisible = this.sidebarFilteredConversations.some(c => c.id === this.activeConversationId)
      if (!stillVisible) {
        this.activeConversationId = this.sidebarFilteredConversations[0]?.id || null
      }
    },

    setSortFilters({ status, sortBy, type }) {
      this.sortStatus = status
      this.sortBy = sortBy
      this.sortType = type
    },

    setAdvancedFilters(filters) {
      this.advancedFilters = filters
    },

    async sendMessage(text, isPrivate = false, file = null) {
      if (!this.activeConversationId || (!text.trim() && !file)) return

      try {
        let response;
        if (file) {
          const formData = new FormData()
          formData.append('text', text)
          formData.append('is_private', isPrivate)
          formData.append('attachment', file, file.name || 'audio.webm')
          response = await api.post(`/conversations/${this.activeConversationId}/messages`, formData, {
            headers: {
              // undefined (não 'multipart/form-data') deixa o navegador gerar o
              // boundary certo — com o header fixo o parser multipart do
              // backend não conseguia ler o anexo (mesmo bug já visto no
              // envio de áudio do chat interno).
              'Content-Type': undefined
            }
          })
        } else {
          response = await api.post(`/conversations/${this.activeConversationId}/messages`, {
            text,
            is_private: isPrivate
          })
        }
        const newMsg = response.data.message
        const conv = this.conversations.find(c => c.id === this.activeConversationId)
        if (conv) {
          if (!conv.messages) conv.messages = []
          const exists = conv.messages.some(m => m.id === newMsg.id)
          if (!exists) {
            conv.messages.push(newMsg)
          }
          conv.preview = newMsg.text
          conv.timestamp = newMsg.timestamp
        }
      } catch (error) {
        console.error('Error sending message:', error)
      }
    },

    async updateContact(contactId, data) {
      try {
        const response = await api.put(`/contacts/${contactId}`, { contact: data })
        // Update contact in all conversations that match
        this.conversations.forEach(c => {
          if (c.contact && c.contact.id === contactId) {
            Object.assign(c.contact, response.data)
          }
        })
      } catch (error) {
        console.error('Error updating contact:', error)
        throw error
      }
    },

    async deleteContact(contactId) {
      try {
        await api.delete(`/contacts/${contactId}`)
        // Remove conversations belonging to this contact
        this.conversations = this.conversations.filter(c => !c.contact || c.contact.id !== contactId)
        if (this.activeConversation && this.activeConversation.contact.id === contactId) {
          this.activeConversationId = null
        }
      } catch (error) {
        console.error('Error deleting contact:', error)
        throw error
      }
    },

    async deleteConversation(conversationId) {
      try {
        await api.delete(`/conversations/${conversationId}`)
        this.conversations = this.conversations.filter(c => c.id !== conversationId)
        if (this.activeConversationId === conversationId) {
          this.activeConversationId = null
        }
      } catch (error) {
        console.error('Error deleting conversation:', error)
        throw error
      }
    },

    async addNote(contactId, content) {
      try {
        const response = await api.post(`/contacts/${contactId}/add_note`, { content })
        
        // Update contact notes in all conversations that match
        this.conversations.forEach(c => {
          if (c.contact && c.contact.id === contactId) {
            if (!c.contact.notes) c.contact.notes = []
            c.contact.notes.unshift({
              id: response.data.id,
              content: response.data.content,
              created_at: response.data.created_at,
              author: response.data.user?.first_name || 'Sistema'
            })
          }
        })
      } catch (error) {
        console.error('Error adding note:', error)
        throw error
      }
    },

    async mergeContact(contactId, targetContactId) {
      try {
        await api.post(`/contacts/${contactId}/merge`, { target_contact_id: targetContactId })
        // Re-fetch everything because conversations were moved
        await this.fetchConversations()
      } catch (error) {
        console.error('Error merging contact:', error)
        throw error
      }
    },

    async updateConversationStatus(conversationId, status) {
      try {
        const response = await api.put(`/conversations/${conversationId}`, {
          conversation: { status }
        })
        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          this.conversations[convIndex].status = response.data.status
          this.conversations[convIndex].snoozed_until = response.data.snoozed_until || null
        }
      } catch (error) {
        console.error('Error updating conversation status:', error)
      }
    },

    async snoozeConversation(conversationId, snoozedUntil) {
      try {
        const response = await api.put(`/conversations/${conversationId}`, {
          conversation: { status: 'snoozed', snoozed_until: snoozedUntil }
        })
        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          this.conversations[convIndex].status = 'snoozed'
          this.conversations[convIndex].snoozed_until = response.data.snoozed_until
        }
      } catch (error) {
        console.error('Error snoozing conversation:', error)
        throw error
      }
    },

    async resolveConversation(conversationId, { kanbanStage, sendClosingMessage, closingMessageText }) {
      try {
        await api.put(`/conversations/${conversationId}`, {
          conversation: { status: 'resolved' },
          kanban_stage:          kanbanStage || '',
          send_closing_message:  sendClosingMessage,
          closing_message_text:  closingMessageText || ''
        })
        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          this.conversations[convIndex].status = 'resolved'
          this.conversations[convIndex].snoozed_until = null
        }
      } catch (error) {
        console.error('Error resolving conversation:', error)
        throw error
      }
    },

    setupWebSocket() {
      if (this.ws) return

      if (!this._wsHealthCheckInterval) {
        this._wsHealthCheckInterval = setInterval(() => {
          if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
            this.fetchConversations()
          }
        }, 12000)
      }

      let baseURL = api.defaults.baseURL
      if (!baseURL) {
        baseURL = window.location.origin.replace(':5173', ':3000')
      }

      const rawToken = (localStorage.getItem('auth_token') || '').replace(/^Bearer\s+/i, '')
      const wsURL = baseURL.replace(/^http/, 'ws') + '/cable?token=' + rawToken
      const ws = new WebSocket(wsURL)
      this.ws = ws
      this._wsReconnectDelay = this._wsReconnectDelay || 1500

      ws.onopen = () => {
        this._wsReconnectDelay = 1500
        ws.send(JSON.stringify({
          command: 'subscribe',
          identifier: JSON.stringify({ channel: 'ConversationsChannel' })
        }))
      }

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          if (data.type === 'ping' || data.type === 'welcome' || data.type === 'confirm_subscription') return

          const payload = data.message
          if (!payload) return

          if (payload.event === 'message_created') {
            const { conversation_id, message: newMsg } = payload
            const conv = this.conversations.find(c => Number(c.id) === Number(conversation_id))
            if (conv) {
              if (!conv.messages) conv.messages = []
              const existingIdx = conv.messages.findIndex(m => m.id === newMsg.id)
              if (existingIdx === -1) {
                conv.messages.push(newMsg)
                conv.preview = newMsg.text
                conv.timestamp = newMsg.timestamp
                if (Number(conversation_id) !== Number(this.activeConversationId)) {
                  conv.unread = (conv.unread || 0) + 1
                }
                window.dispatchEvent(new CustomEvent('new-message', {
                  detail: { conversationId: conversation_id }
                }))
              } else {
                // Reenvio da mesma mensagem (ex: webhook do Baileys manda de
                // novo depois que o anexo termina de baixar) — atualiza em
                // vez de ignorar, senão imagem/áudio só aparece com reload.
                conv.messages[existingIdx] = { ...conv.messages[existingIdx], ...newMsg }
                conv.preview = newMsg.text
              }
            } else {
              this.fetchConversations()
            }
          } else if (payload.event === 'inbox_updated') {
            window.dispatchEvent(new CustomEvent('inbox-updated', { detail: payload }))
          } else if (payload.event === 'contact_updated') {
            window.dispatchEvent(new CustomEvent('contact-updated', { detail: payload }))
          } else if (payload.event === 'conversation_tags_updated') {
            const conv = this.conversations.find(c => c.id === payload.conversation_id)
            if (conv) conv.tags = payload.tags
          } else if (payload.event === 'conversation_updated') {
            const idx = this.conversations.findIndex(c => Number(c.id) === Number(payload.conversation?.id))
            if (idx !== -1) {
              Object.assign(this.conversations[idx], payload.conversation)
            } else {
              this.fetchConversations()
            }
          } else if (payload.event === 'snooze_expired') {
            const conv = this.conversations.find(c => Number(c.id) === Number(payload.conversation_id))
            if (conv) {
              conv.status = 'open'
              conv.snoozed_until = null
            }
            window.dispatchEvent(new CustomEvent('snooze-expired', { detail: payload }))
          } else if (payload.event === 'lead_atribuido') {
            const me = this.currentUser
            if (Number(payload.assigned_to_user_id) === Number(me?.id)) {
              window.dispatchEvent(new CustomEvent('lead-atribuido', { detail: payload }))
            }
          }
        } catch (error) {
          console.error('WS message error:', error)
        }
      }

      ws.onclose = () => {
        this.ws = null
        const delay = Math.min(this._wsReconnectDelay || 1500, 8000)
        this._wsReconnectDelay = delay * 2
        setTimeout(() => this.fetchConversations(), delay)
      }

      ws.onerror = () => {
        ws.close()
      }
    }
  }
})

