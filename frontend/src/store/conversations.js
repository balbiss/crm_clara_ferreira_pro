import { defineStore } from 'pinia'
import api from '../api'

// Filtro "Criada em" (pedido real da Clara: saber quantas conversas
// nasceram num período, igual o exemplo do Kommo que ela mandou,
// 2026-09-25) — compara no fuso do navegador (já é o Brasil na prática).
const matchesDateBucket = (isoString, bucket) => {
  if (!isoString) return false
  const date = new Date(isoString)
  const now = new Date()
  const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const today = startOfDay(now)

  if (bucket === 'hoje') {
    return startOfDay(date).getTime() === today.getTime()
  }
  if (bucket === 'ontem') {
    const ontem = new Date(today); ontem.setDate(ontem.getDate() - 1)
    return startOfDay(date).getTime() === ontem.getTime()
  }
  if (bucket === '7dias') {
    const seteDiasAtras = new Date(today); seteDiasAtras.setDate(seteDiasAtras.getDate() - 7)
    return date >= seteDiasAtras
  }
  if (bucket === '30dias') {
    const trintaDiasAtras = new Date(today); trintaDiasAtras.setDate(trintaDiasAtras.getDate() - 30)
    return date >= trintaDiasAtras
  }
  if (bucket === 'mes_atual') {
    return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth()
  }
  if (bucket === 'mes_passado') {
    const mesPassado = new Date(now.getFullYear(), now.getMonth() - 1, 1)
    return date.getFullYear() === mesPassado.getFullYear() && date.getMonth() === mesPassado.getMonth()
  }
  return false
}

// Última mensagem foi do cliente = ninguém da equipe/IA respondeu ainda.
// Diferente de "não lida" (unread), que é só sobre o agente ter aberto a
// conversa ou não. Compartilhado entre o filtro avançado, a aba rápida da
// sidebar e o contador — não duplica a mesma checagem em 3 lugares.
export const isSemResposta = (conv) => {
  const msgs = conv.messages || []
  const last = msgs[msgs.length - 1]
  return !!(last && last.senderType === 'contact')
}

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
    lastFetchedAt: null,
    // Paginação da lista (2026-10-16): antes só vinha a 1ª página (100 mais
    // recentes da CONTA toda) e a caixa era filtrada no navegador — numa caixa
    // quieta (Gerência-Expansão, 161 conversas) só apareciam 2.
    conversationsPage: 1,
    conversationsHasMore: false,
    isLoadingMore: false,
    isLoadingAll: false, // carregando o restante da lista em segundo plano
    inboxLoaded: {},   // { [inboxId]: true } — todas as conversas da caixa já vieram
    inboxLoading: {},  // { [inboxId]: true } — carregando agora
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

      // Sort Status filter — se o filtro avançado (funil) já escolhe um
      // status, ele manda: antes os dois somavam, e com o ⇅ no padrão
      // "Abertas" escolher "Resolvidas" no funil dava lista vazia (Clara,
      // 2026-10).
      const advancedStatus = state.advancedFilters?.some(f => f.attribute === 'status' && f.operator && f.value)
      if (!advancedStatus && state.sortStatus !== 'all') {
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
      } else if (state.currentFilter === 'sem-resposta') {
        filtered = filtered.filter(isSemResposta)
      }
      
      // Apply advanced filters
      if (state.advancedFilters && state.advancedFilters.length > 0) {
        state.advancedFilters.forEach(filter => {
          if (!filter.attribute || !filter.operator || !filter.value) return;
          
          filtered = filtered.filter(c => {
            let actualValue;
            
            if (filter.attribute === 'status') {
              if (filter.value === 'all') return filter.operator !== 'not_equal_to'
              actualValue = c.status;
            } else if (filter.attribute === 'assignee') {
              // Antes comparava c.assignee (NOME do responsável — dois
              // agentes com o mesmo primeiro nome colidiam) contra um ID
              // fixo fake ("João") que nunca existiu de verdade. Corrigido
              // pra comparar por ID real (c.assignee_id).
              actualValue = c.assignee_id ? String(c.assignee_id) : 'unassigned';
            } else if (filter.attribute === 'carteira') {
              actualValue = c.contact?.custom_attributes?.gerente_jueri_nome || '';
            } else if (filter.attribute === 'sem_resposta') {
              actualValue = isSemResposta(c) ? 'sim' : 'nao'
            } else if (filter.attribute === 'criada_em') {
              const matches = matchesDateBucket(c.created_at_iso, filter.value)
              // "criada_em" não é igualdade simples (é uma janela de tempo) —
              // trata equal_to/not_equal_to como "está dentro"/"está fora".
              return filter.operator === 'not_equal_to' ? !matches : matches
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
    // ---- Lista de conversas (modo "lista": só a última mensagem; o chat
    // completo vem de GET /conversations/:id quando a conversa é aberta) ----

    // messagesLoaded === false só pro item de lista; conversa vinda de
    // POST/GET /conversations/:id (completa) conta como carregada.
    _normalizar(conv) {
      return { ...conv, messagesLoaded: conv.messages_loaded !== false }
    },

    // Item novo da lista sem derrubar o que já está carregado: se a conversa já
    // tem o chat completo na memória (aberta/visitada), mantém as mensagens e os
    // detalhes do contato — o item de lista só traz a última mensagem.
    _preservarCarregado(antigo, novo) {
      if (!antigo || antigo.messagesLoaded === false || novo.messagesLoaded !== false) return novo
      const ids = new Set((antigo.messages || []).map(m => m.id))
      return {
        ...novo,
        messages: [...(antigo.messages || []), ...(novo.messages || []).filter(m => !ids.has(m.id))],
        messagesLoaded: true,
        _paged: antigo._paged,
        contact: {
          ...novo.contact,
          pedidos: antigo.contact?.pedidos || [],
          reseller_phones: antigo.contact?.reseller_phones || [],
          lifecycle_events: antigo.contact?.lifecycle_events || [],
          notes: antigo.contact?.notes || []
        }
      }
    },

    // Adiciona conversas de páginas extras / de uma caixa SEM rebaixar o que já
    // existe na memória (WebSocket mantém as existentes atualizadas).
    _adicionarPaginadas(lista) {
      const existentes = new Set(this.conversations.map(c => c.id))
      lista.forEach(c => {
        if (!existentes.has(c.id)) this.conversations.push({ ...c, _paged: true })
      })
    },

    async fetchConversations() {
      const POR_PAGINA = 100
      try {
        const response = await api.get('/conversations', { params: { light: true, per_page: POR_PAGINA } })
        const recebidas = response.data.map(c => this._normalizar(c))

        // Recarga da 1ª página (WebSocket reconectando, aba voltando do sono...):
        // não pode apagar o que o usuário já abriu nem as páginas/caixas que ele
        // carregou — senão o chat aberto ficava em branco (Ana, 2026-10-15).
        const anteriores = new Map(this.conversations.map(c => [c.id, c]))
        const ids = new Set(recebidas.map(c => c.id))
        const mescladas = recebidas.map(c => this._preservarCarregado(anteriores.get(c.id), c))
        this.conversations.forEach(c => {
          if (!ids.has(c.id) && (c.id === this.activeConversationId || c._paged)) mescladas.push(c)
        })
        this.conversations = mescladas

        if (this.conversationsPage === 1) this.conversationsHasMore = recebidas.length === POR_PAGINA
        this.lastFetchedAt = Date.now()
        if (!this.activeConversationId) {
          this.activeConversationId = this.sidebarFilteredConversations[0]?.id || null
        }
        this.setupWebSocket()
        // Sem limite: o resto da lista (todas as caixas) vem sozinho, em segundo
        // plano, depois da 1ª página (que já aparece na hora).
        if (this.conversationsPage === 1 && this.conversationsHasMore) this.carregarTudoEmSegundoPlano()
      } catch (error) {
        console.error('Error fetching conversations:', error)
      }
    },

    // Próxima página da lista geral. Devolve true se deu certo.
    async loadMoreConversations() {
      const POR_PAGINA = 100 // mesmo tamanho da 1ª página (a paginação é por deslocamento)
      if (this.isLoadingMore || !this.conversationsHasMore) return false
      this.isLoadingMore = true
      try {
        const pagina = this.conversationsPage + 1
        const { data } = await api.get('/conversations', { params: { light: true, per_page: POR_PAGINA, page: pagina } })
        this._adicionarPaginadas(data.map(c => this._normalizar(c)))
        this.conversationsPage = pagina
        this.conversationsHasMore = data.length === POR_PAGINA
        return true
      } catch (error) {
        console.error('Error loading more conversations:', error)
        return false
      } finally {
        this.isLoadingMore = false
      }
    },

    // Traz TODAS as conversas, página por página. Se uma página falhar, para —
    // o botão "Carregar mais conversas" continua disponível como plano B.
    async carregarTudoEmSegundoPlano() {
      if (this.isLoadingAll) return
      this.isLoadingAll = true
      try {
        for (let i = 0; i < 500 && this.conversationsHasMore; i++) {
          const ok = await this.loadMoreConversations()
          if (!ok) break
        }
      } finally {
        this.isLoadingAll = false
      }
    },

    // Ao escolher uma caixa no menu: busca TODAS as conversas dela no servidor
    // (antes só aparecia o que estava entre as 100 mais recentes da conta).
    async fetchInboxConversations(inboxId) {
      if (!inboxId) return
      const chave = String(inboxId)
      if (this.inboxLoading[chave]) return
      this.inboxLoading[chave] = true
      const POR_PAGINA = 200
      try {
        for (let pagina = 1; pagina <= 200; pagina++) {
          const { data } = await api.get('/conversations', { params: { light: true, inbox_id: inboxId, per_page: POR_PAGINA, page: pagina } })
          this._adicionarPaginadas(data.map(c => this._normalizar(c)))
          if (data.length < POR_PAGINA) break
        }
        this.inboxLoaded[chave] = true
        this.reconcileActiveConversation()
      } catch (error) {
        console.error('Error fetching inbox conversations:', error)
      } finally {
        this.inboxLoading[chave] = false
      }
    },

    // Chat completo da conversa aberta (a lista só traz a última mensagem).
    async ensureMessagesLoaded(id) {
      const conv = this.conversations.find(c => c.id === id)
      if (!conv || conv.messagesLoaded !== false) return
      this._carregandoCompleta = this._carregandoCompleta || {}
      if (this._carregandoCompleta[id]) return
      this._carregandoCompleta[id] = true
      try {
        const { data } = await api.get(`/conversations/${id}`)
        const idx = this.conversations.findIndex(c => c.id === id)
        if (idx === -1) return
        const antigo = this.conversations[idx]
        // Mensagem que chegou pelo WebSocket durante o carregamento e ainda não
        // estava na resposta não pode se perder.
        const ids = new Set(data.messages.map(m => m.id))
        const extras = (antigo.messages || []).filter(m => !ids.has(m.id) && m.id)
        this.conversations[idx] = {
          ...data,
          messages: [...data.messages, ...extras],
          unread: antigo.unread, // "lida" local vale (mark_as_read pode ainda estar a caminho)
          messagesLoaded: true,
          _paged: antigo._paged
        }
      } catch (error) {
        console.error('Error loading full conversation:', error)
      } finally {
        this._carregandoCompleta[id] = false
      }
    },

    // Mensagem/atualização de conversa que não está na memória (fora das páginas
    // carregadas): busca só ela — antes recarregava a lista inteira a cada
    // mensagem. Conversa que o usuário não pode ver (404) é lembrada por 10 min.
    async _buscarConversaDesconhecida(id, avisarNovaMensagem = false) {
      const numero = Number(id)
      this._naoVisiveis = this._naoVisiveis || {}
      this._buscandoDesconhecida = this._buscandoDesconhecida || {}
      if (this._naoVisiveis[numero] && Date.now() - this._naoVisiveis[numero] < 10 * 60 * 1000) return
      if (this._buscandoDesconhecida[numero]) return
      this._buscandoDesconhecida[numero] = true
      try {
        const { data } = await api.get(`/conversations/${numero}`)
        if (!this.conversations.some(c => c.id === data.id)) {
          this.conversations.push({ ...this._normalizar(data), _paged: true })
        }
        if (avisarNovaMensagem) {
          window.dispatchEvent(new CustomEvent('new-message', { detail: { conversationId: numero } }))
        }
      } catch (error) {
        if (error.response?.status === 404) this._naoVisiveis[numero] = Date.now()
      } finally {
        this._buscandoDesconhecida[numero] = false
      }
    },

    // Inicia (ou reabre) a conversa de uma revendedora que ainda não trocou
    // mensagem nenhuma — sem isso não tinha como mandar a "mensagem de
    // incentivo" do 3º/10º/20º dia da régua manualmente.
    async startConversation(contactId, inboxId = null) {
      return this._createConversation({ contact_id: contactId }, inboxId)
    },

    // Número ainda não cadastrado — o backend reaproveita o contato se o
    // telefone já existir, ou cria um novo na carteira de quem abriu.
    async startConversationWithPhone(phone, inboxId = null) {
      return this._createConversation({ phone }, inboxId)
    },

    async _createConversation(payload, inboxId) {
      if (inboxId) payload.inbox_id = inboxId
      const { data } = await api.post('/conversations', payload)
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
        const hadUnread = conv.unread > 0
        conv.unread = 0
        // Persiste no banco (unread_count) — sem isso o zerado ficava só na
        // memória do navegador e voltava a contar errado no próximo refetch
        // (reconexão do WebSocket, troca de aba etc).
        if (hadUnread) {
          api.post(`/conversations/${id}/mark_as_read`).catch(() => {})
        }
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

    async sendMessage(text, isPrivate = false, file = null, clientMsgId = null) {
      // Lança erro em vez de retornar/engolir calado -- antes, se a conversa
      // ativa não estivesse pronta (troca rápida de conversa) ou a API
      // falhasse, a mensagem sumia sem aviso nenhum (Bel, 2026-10-01: o log
      // do servidor confirmou que a requisição nunca chegou no backend).
      if (!this.activeConversationId || (!text.trim() && !file)) {
        throw new Error('Nenhuma conversa ativa ou mensagem vazia')
      }

      let response;
      if (file) {
        const formData = new FormData()
        formData.append('text', text)
        formData.append('is_private', isPrivate)
        formData.append('attachment', file, file.name || 'audio.webm')
        if (clientMsgId) formData.append('client_msg_id', clientMsgId)
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
          is_private: isPrivate,
          client_msg_id: clientMsgId
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
              this._buscarConversaDesconhecida(conversation_id, true)
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
            } else if (payload.conversation?.id) {
              this._buscarConversaDesconhecida(payload.conversation.id)
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

