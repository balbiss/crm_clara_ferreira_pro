<script setup>
import { ref, onMounted, nextTick } from 'vue'
import api from '../../api'
import Swal from 'sweetalert2'

const tickets = ref([])
const loading = ref(true)

const selectedTicket = ref(null)
const messages = ref([])
const newMessage = ref('')
const chatContainer = ref(null)
const chatLoading = ref(false)

const fetchTickets = async () => {
  try {
    const response = await api.get('/admin/support_tickets')
    tickets.value = response.data
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const openTicket = async (ticket) => {
  chatLoading.value = true
  selectedTicket.value = ticket
  try {
    const response = await api.get(`/admin/support_tickets/${ticket.id}`)
    messages.value = response.data.messages
    
    // Atualiza status local se necessário
    const tIndex = tickets.value.findIndex(t => t.id === ticket.id)
    if (tIndex !== -1) {
      tickets.value[tIndex].status = response.data.ticket.status
      selectedTicket.value.status = response.data.ticket.status
    }

    scrollToBottom()
  } catch (error) {
    Swal.fire('Erro', 'Não foi possível carregar as mensagens.', 'error')
    selectedTicket.value = null
  } finally {
    chatLoading.value = false
  }
}

const sendMessage = async () => {
  if (!newMessage.value.trim()) return

  const messageText = newMessage.value
  newMessage.value = ''

  try {
    const response = await api.post(`/admin/support_tickets/${selectedTicket.value.id}/reply`, {
      message: messageText
    })
    
    messages.value.push({
      ...response.data,
      user: { name: 'Suporte Master', role: 'admin' }
    })
    
    // Admin replying changes status to In Progress (1)
    if (selectedTicket.value.status === 0 || selectedTicket.value.status === 2) {
      selectedTicket.value.status = 1
      const tIndex = tickets.value.findIndex(t => t.id === selectedTicket.value.id)
      if (tIndex !== -1) tickets.value[tIndex].status = 1
    }

    scrollToBottom()
  } catch (error) {
    Swal.fire('Erro', 'Não foi possível enviar a resposta.', 'error')
  }
}

const closeTicket = async () => {
  try {
    await api.put(`/admin/support_tickets/${selectedTicket.value.id}/close`)
    selectedTicket.value.status = 2
    const tIndex = tickets.value.findIndex(t => t.id === selectedTicket.value.id)
    if (tIndex !== -1) tickets.value[tIndex].status = 2
    Swal.fire('Resolvido', 'Ticket encerrado com sucesso.', 'success')
  } catch (error) {
    Swal.fire('Erro', 'Não foi possível fechar o ticket.', 'error')
  }
}

const scrollToBottom = async () => {
  await nextTick()
  if (chatContainer.value) {
    chatContainer.value.scrollTop = chatContainer.value.scrollHeight
  }
}

onMounted(() => {
  fetchTickets()
})
</script>

<template>
  <div class="admin-support-page">
    <div class="header-row">
      <h2 class="page-title">Central de Atendimento (Tickets)</h2>
      <p class="subtitle">Responda às solicitações de suporte de todas as empresas do SaaS.</p>
    </div>
    
    <div v-if="loading" class="loading">Carregando chamados globais...</div>
    
    <div v-else class="layout-container">
      
      <!-- Lista de Tickets Esquerda -->
      <div class="tickets-sidebar">
        <div v-if="tickets.length === 0" class="empty-list">Nenhum chamado aberto.</div>
        
        <div 
          v-for="ticket in tickets" 
          :key="ticket.id" 
          class="ticket-item"
          :class="{ 'active': selectedTicket && selectedTicket.id === ticket.id }"
          @click="openTicket(ticket)"
        >
          <div class="t-header">
            <h4>{{ ticket.title }}</h4>
          </div>
          <div class="t-body">
            <span class="t-account">{{ ticket.account_name }}</span>
            <span class="status-indicator" :class="'s-' + ticket.status"></span>
          </div>
          <div class="t-footer">
            <span>{{ ticket.messages_count }} mensagens</span>
            <span>{{ new Date(ticket.updated_at).toLocaleString([], {day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit'}) }}</span>
          </div>
        </div>
      </div>

      <!-- Chat Direito -->
      <div class="chat-area" v-if="selectedTicket">
        <div class="chat-header">
          <div>
            <h3>{{ selectedTicket.title }}</h3>
            <span class="company-badge">{{ selectedTicket.account_name }}</span>
          </div>
          <div class="actions">
            <span class="status-badge" :class="'badge-' + selectedTicket.status">
              {{ selectedTicket.status === 0 ? 'Aberto' : (selectedTicket.status === 1 ? 'Em Andamento' : 'Resolvido') }}
            </span>
            <button 
              v-if="selectedTicket.status !== 2" 
              class="btn-close-ticket" 
              @click="closeTicket"
            >
              ✔ Marcar Resolvido
            </button>
          </div>
        </div>

        <div v-if="chatLoading" class="chat-loading">Carregando histórico...</div>
        
        <div v-else class="chat-messages" ref="chatContainer">
          <div 
            v-for="msg in messages" 
            :key="msg.id" 
            class="msg-bubble-wrapper"
            :class="msg.user.role === 'admin' ? 'is-admin' : 'is-user'"
          >
            <div class="msg-bubble">
              <div class="msg-author">{{ msg.user.name }}</div>
              <div class="msg-text">{{ msg.body }}</div>
              <div class="msg-time">{{ new Date(msg.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) }}</div>
            </div>
          </div>
        </div>

        <form @submit.prevent="sendMessage" class="chat-input" v-if="!chatLoading">
          <input 
            type="text" 
            v-model="newMessage" 
            placeholder="Digite sua resposta oficial..." 
            required
          />
          <button type="submit" class="btn-reply">Responder</button>
        </form>
      </div>
      
      <div v-else class="no-selection">
        Selecione um chamado na lista ao lado para iniciar o atendimento.
      </div>

    </div>
  </div>
</template>

<style scoped>
.header-row {
  margin-bottom: 1.5rem;
}

.page-title {
  font-size: 1.1rem;
  font-weight: 600;
  color: #1e293b;
  margin: 0 0 0.25rem 0;
}

.subtitle {
  font-size: 0.8rem;
  color: #64748b;
  margin: 0;
}

.layout-container {
  display: flex;
  height: calc(100vh - 180px);
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  overflow: hidden;
}

.tickets-sidebar {
  width: 320px;
  border-right: 1px solid #e2e8f0;
  overflow-y: auto;
  background: #f8fafc;
}

.empty-list {
  padding: 2rem;
  text-align: center;
  color: #94a3b8;
  font-size: 0.9rem;
}

.ticket-item {
  padding: 1rem;
  border-bottom: 1px solid #e2e8f0;
  cursor: pointer;
  transition: background 0.2s;
}

.ticket-item:hover {
  background: #f1f5f9;
}

.ticket-item.active {
  background: #e0f2fe;
  border-left: 3px solid #0ea5e9;
}

.t-header h4 {
  margin: 0 0 0.25rem 0;
  font-size: 0.95rem;
  color: #0f172a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.t-body {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.t-account {
  font-size: 0.8rem;
  font-weight: 600;
  color: #64748b;
}

.status-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.s-0 { background: #eab308; }
.s-1 { background: #0ea5e9; }
.s-2 { background: #22c55e; }

.t-footer {
  display: flex;
  justify-content: space-between;
  font-size: 0.7rem;
  color: #94a3b8;
}

.chat-area {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.no-selection {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #94a3b8;
  background: #f1f5f9;
}

.chat-header {
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e2e8f0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.chat-header h3 {
  margin: 0 0 0.25rem 0;
  font-size: 1.1rem;
}

.company-badge {
  font-size: 0.75rem;
  background: #e2e8f0;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  color: #475569;
}

.actions {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.status-badge {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
}
.badge-0 { background: #fef08a; color: #854d0e; }
.badge-1 { background: #bae6fd; color: #0369a1; }
.badge-2 { background: #bbf7d0; color: #166534; }

.btn-close-ticket {
  background: #22c55e;
  color: white;
  border: none;
  padding: 0.4rem 0.8rem;
  border-radius: 6px;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
}

.btn-close-ticket:hover { background: #16a34a; }

.chat-messages {
  flex: 1;
  padding: 1.5rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  background: #fafafa;
}

.msg-bubble-wrapper {
  display: flex;
  flex-direction: column;
  max-width: 80%;
}

.is-user { align-self: flex-start; }
.is-admin { align-self: flex-end; }

.msg-bubble {
  padding: 0.75rem 1rem;
  border-radius: 10px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}

.is-user .msg-bubble {
  background: white;
  border: 1px solid #e2e8f0;
  border-bottom-left-radius: 2px;
}

.is-admin .msg-bubble {
  background: #0ea5e9;
  color: white;
  border-bottom-right-radius: 2px;
}

.msg-author {
  font-size: 0.7rem;
  font-weight: 600;
  margin-bottom: 0.2rem;
  opacity: 0.8;
}

.is-user .msg-author { color: #0f172a; }

.msg-text {
  font-size: 0.9rem;
  line-height: 1.4;
  white-space: pre-wrap;
}

.msg-time {
  font-size: 0.65rem;
  text-align: right;
  margin-top: 0.4rem;
  opacity: 0.7;
}

.chat-input {
  display: flex;
  padding: 1rem;
  border-top: 1px solid #e2e8f0;
  background: white;
}

.chat-input input {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  margin-right: 0.5rem;
  font-size: 0.9rem;
}

.chat-input input:focus {
  outline: none;
  border-color: #0ea5e9;
}

.btn-reply {
  background: #0f172a;
  color: white;
  border: none;
  padding: 0 1.5rem;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
}

.btn-reply:hover { background: #1e293b; }
</style>
