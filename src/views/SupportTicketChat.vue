<script setup>
import { ref, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '../api'
import Swal from 'sweetalert2'

const route = useRoute()
const router = useRouter()
const ticket = ref(null)
const messages = ref([])
const newMessage = ref('')
const loading = ref(true)
const chatContainer = ref(null)

const fetchTicket = async () => {
  try {
    const response = await api.get(`/support_tickets/${route.params.id}`)
    ticket.value = response.data.ticket
    messages.value = response.data.messages
    scrollToBottom()
  } catch (error) {
    Swal.fire('Erro', 'Não foi possível carregar o chamado.', 'error')
    router.push('/suporte')
  } finally {
    loading.value = false
  }
}

const sendMessage = async () => {
  if (!newMessage.value.trim()) return

  const messageText = newMessage.value
  newMessage.value = ''

  try {
    const response = await api.post(`/support_tickets/${ticket.value.id}/support_ticket_messages`, {
      support_ticket_message: { body: messageText }
    })
    
    messages.value.push({
      ...response.data,
      user: { name: 'Você', role: 'empresa' } // optimistically add
    })
    
    // Update ticket status to open if it was resolved
    if (ticket.value.status === 2) {
      ticket.value.status = 0
    }
    
    scrollToBottom()
  } catch (error) {
    Swal.fire('Erro', 'Não foi possível enviar a mensagem.', 'error')
  }
}

const scrollToBottom = async () => {
  await nextTick()
  if (chatContainer.value) {
    chatContainer.value.scrollTop = chatContainer.value.scrollHeight
  }
}

onMounted(() => {
  fetchTicket()
})
</script>

<template>
  <div class="support-chat-page">
    <div class="header">
      <button class="back-btn" @click="router.push('/suporte')">← Voltar</button>
      <div v-if="ticket" class="title-container">
        <h1>{{ ticket.title }}</h1>
        <span class="status-badge" :class="{'status-open': ticket.status === 0, 'status-progress': ticket.status === 1, 'status-closed': ticket.status === 2}">
          {{ ticket.status === 0 ? 'Aguardando Atendimento' : (ticket.status === 1 ? 'Em Andamento' : 'Resolvido') }}
        </span>
      </div>
    </div>

    <div v-if="loading" class="loading">Carregando mensagens...</div>

    <div v-else class="chat-wrapper">
      <div class="chat-container" ref="chatContainer">
        <div v-if="messages.length === 0" class="empty-chat">
          Envie uma mensagem detalhando sua solicitação.
        </div>
        
        <div 
          v-for="msg in messages" 
          :key="msg.id" 
          class="message"
          :class="msg.user.role === 'admin' ? 'message-admin' : 'message-user'"
        >
          <div class="message-bubble">
            <div class="message-author">
              {{ msg.user.role === 'admin' ? 'SaaS Support' : msg.user.name }}
            </div>
            <div class="message-body">{{ msg.body }}</div>
            <div class="message-time">{{ new Date(msg.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) }}</div>
          </div>
        </div>
      </div>

      <form @submit.prevent="sendMessage" class="chat-input-area">
        <input 
          type="text" 
          v-model="newMessage" 
          placeholder="Digite sua mensagem aqui..." 
          required
        />
        <button type="submit" class="btn-send">
          Enviar
        </button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.support-chat-page {
  padding: 1.5rem;
  width: 100%;
  height: calc(100vh - 80px);
  display: flex;
  flex-direction: column;
}

.header {
  margin-bottom: 1.5rem;
}

.back-btn {
  background: none;
  border: none;
  color: #64748b;
  cursor: pointer;
  font-size: 0.9rem;
  padding: 0;
  margin-bottom: 0.5rem;
}

.title-container {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.title-container h1 {
  margin: 0;
  font-size: 1.1rem;
  font-weight: 600;
  color: #0f172a;
}

.status-badge {
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
  font-size: 0.7rem;
  font-weight: 600;
}
.status-open { background: #fef08a; color: #854d0e; }
.status-progress { background: #bae6fd; color: #0369a1; }
.status-closed { background: #bbf7d0; color: #166534; }

.chat-wrapper {
  flex: 1;
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.chat-container {
  flex: 1;
  padding: 1.5rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  background: #f8fafc;
}

.empty-chat {
  text-align: center;
  color: #94a3b8;
  margin-top: 2rem;
}

.message {
  display: flex;
  flex-direction: column;
  max-width: 75%;
}

.message-user {
  align-self: flex-end;
}

.message-admin {
  align-self: flex-start;
}

.message-bubble {
  padding: 0.75rem 1rem;
  border-radius: 12px;
  position: relative;
}

.message-user .message-bubble {
  background: #2563eb;
  color: white;
  border-bottom-right-radius: 2px;
}

.message-admin .message-bubble {
  background: white;
  color: #0f172a;
  border: 1px solid #e2e8f0;
  border-bottom-left-radius: 2px;
}

.message-author {
  font-size: 0.75rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
  opacity: 0.8;
}

.message-admin .message-author { color: #2563eb; }

.message-body {
  font-size: 0.95rem;
  line-height: 1.4;
  white-space: pre-wrap;
}

.message-time {
  font-size: 0.65rem;
  text-align: right;
  margin-top: 0.5rem;
  opacity: 0.8;
}

.chat-input-area {
  display: flex;
  padding: 1rem 1.5rem;
  background: white;
  border-top: 1px solid #e2e8f0;
  gap: 1rem;
}

.chat-input-area input {
  flex: 1;
  padding: 0.75rem 1rem;
  border: 1px solid #cbd5e1;
  border-radius: 9999px;
  font-size: 0.95rem;
}

.chat-input-area input:focus {
  outline: none;
  border-color: #38bdf8;
  box-shadow: 0 0 0 2px rgba(56,189,248,0.2);
}

.btn-send {
  background: #2563eb;
  color: white;
  border: none;
  padding: 0 1.5rem;
  border-radius: 9999px;
  font-weight: 600;
  cursor: pointer;
  transition: 0.2s;
}

.btn-send:hover {
  background: #1d4ed8;
}
</style>
