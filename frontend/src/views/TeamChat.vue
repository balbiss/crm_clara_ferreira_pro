<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { Send, Users } from 'lucide-vue-next'
import { useInternalChatStore } from '../store/internalChat'
import { ROLE_LABELS } from '../config/roles'

// Chat interno da equipe — consultor, gerente, financeiro e diretoria
// conversando entre si dentro do CRM. Sem relação com WhatsApp/revendedora
// (isso é a aba "Conversas"). Ver InternalMessage no backend.
const store = useInternalChatStore()

const newMessageText = ref('')
const messagesEndRef = ref(null)
const searchQuery = ref('')

const currentUser = JSON.parse(localStorage.getItem('user') || '{}')

const filteredThreads = computed(() => {
  if (!searchQuery.value.trim()) return store.threads
  const q = searchQuery.value.toLowerCase()
  return store.threads.filter(t => `${t.first_name || ''} ${t.last_name || ''}`.toLowerCase().includes(q))
})

const scrollToBottom = () => {
  nextTick(() => {
    messagesEndRef.value?.scrollIntoView({ behavior: 'smooth' })
  })
}

const selectThread = async (userId) => {
  await store.openThread(userId)
  scrollToBottom()
}

const sendMessage = async () => {
  const text = newMessageText.value
  newMessageText.value = ''
  await store.sendMessage(text)
  scrollToBottom()
}

const formatTime = (iso) => {
  if (!iso) return ''
  return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
}

const formatPreviewTime = (iso) => {
  if (!iso) return ''
  const d = new Date(iso)
  const today = new Date()
  if (d.toDateString() === today.toDateString()) {
    return d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
  }
  return d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })
}

const getInitials = (name) => (name || '?').substring(0, 2).toUpperCase()

watch(() => store.activeMessages.length, scrollToBottom)

onMounted(() => {
  store.fetchThreads()
  store.setupWebSocket()
})

onUnmounted(() => {
  if (store.ws) {
    store.ws.close()
    store.ws = null
  }
})
</script>

<template>
  <div class="team-chat-container">
    <div class="threads-pane">
      <div class="threads-header">
        <h2><Users class="icon-sm" /> Chat da Equipe</h2>
        <input v-model="searchQuery" type="text" placeholder="Buscar colega..." class="search-input" />
      </div>

      <div class="threads-list" v-if="!store.isLoadingThreads && filteredThreads.length > 0">
        <div
          v-for="t in filteredThreads"
          :key="t.id"
          class="thread-item"
          :class="{ active: store.activeUserId === t.id }"
          @click="selectThread(t.id)"
        >
          <div class="thread-avatar">{{ getInitials(`${t.first_name || ''} ${t.last_name || ''}`) }}</div>
          <div class="thread-info">
            <div class="thread-top">
              <span class="thread-name">{{ t.first_name }} {{ t.last_name }}</span>
              <span class="thread-time" v-if="t.last_message_at">{{ formatPreviewTime(t.last_message_at) }}</span>
            </div>
            <div class="thread-bottom">
              <span class="thread-preview">{{ t.last_message || ROLE_LABELS[t.role] || t.role }}</span>
              <span v-if="t.unread_count > 0" class="unread-badge">{{ t.unread_count }}</span>
            </div>
          </div>
        </div>
      </div>
      <div v-else-if="store.isLoadingThreads" class="empty-state"><p>Carregando equipe...</p></div>
      <div v-else class="empty-state">
        <p>Nenhum outro membro na equipe ainda.</p>
      </div>
    </div>

    <div class="thread-detail-pane" v-if="store.activeUserId">
      <div class="detail-header">
        <div class="thread-avatar">{{ getInitials(`${store.activeThread?.first_name || ''} ${store.activeThread?.last_name || ''}`) }}</div>
        <div>
          <div class="detail-name">{{ store.activeThread?.first_name }} {{ store.activeThread?.last_name }}</div>
          <div class="detail-role">{{ ROLE_LABELS[store.activeThread?.role] || store.activeThread?.role }}</div>
        </div>
      </div>

      <div class="messages-area">
        <div v-if="store.isLoadingMessages" class="empty-state"><p>Carregando conversa...</p></div>
        <template v-else>
          <div
            v-for="m in store.activeMessages"
            :key="m.id"
            class="message-bubble"
            :class="{ 'from-me': m.sender_id === currentUser.id }"
          >
            <div class="bubble-text">{{ m.text }}</div>
            <div class="bubble-time">{{ formatTime(m.created_at) }}</div>
          </div>
          <p v-if="store.activeMessages.length === 0" class="empty-thread-text">
            Nenhuma mensagem ainda. Diga oi!
          </p>
        </template>
        <div ref="messagesEndRef"></div>
      </div>

      <div class="composer">
        <input
          v-model="newMessageText"
          type="text"
          placeholder="Digite uma mensagem..."
          @keyup.enter="sendMessage"
        />
        <button class="send-btn" :disabled="!newMessageText.trim()" @click="sendMessage">
          <Send class="icon-sm" />
        </button>
      </div>
    </div>

    <div class="thread-detail-pane empty-selection" v-else>
      <Users class="icon-lg" />
      <p>Escolha um colega na lista pra começar a conversar.</p>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.team-chat-container {
  display: flex;
  height: 100%;
  background: var(--bg-primary);
}

.threads-pane {
  width: 320px;
  flex-shrink: 0;
  border-right: 1px solid var(--border-color);
  display: flex;
  flex-direction: column;
  background: var(--bg-secondary);
}

.threads-header {
  padding: 1.25rem;
  border-bottom: 1px solid var(--border-color);

  h2 {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--text-main);
    margin: 0 0 0.75rem;
  }
}

.search-input {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-primary);
  color: var(--text-main);
  font-size: 0.85rem;
  outline: none;

  &:focus { border-color: var(--primary); }
}

.threads-list {
  flex: 1;
  overflow-y: auto;
}

.thread-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.85rem 1.25rem;
  cursor: pointer;
  border-bottom: 1px solid var(--border-color);

  &:hover { background: var(--bg-tertiary); }
  &.active { background: var(--bg-tertiary); border-left: 3px solid var(--primary); }
}

.thread-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--primary);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.85rem;
  font-weight: 700;
  flex-shrink: 0;
}

.thread-info {
  flex: 1;
  min-width: 0;
}

.thread-top {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 0.5rem;
}

.thread-name {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--text-main);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.thread-time {
  font-size: 0.72rem;
  color: var(--text-muted);
  flex-shrink: 0;
}

.thread-bottom {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.15rem;
}

.thread-preview {
  font-size: 0.8rem;
  color: var(--text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.unread-badge {
  background: var(--primary);
  color: white;
  font-size: 0.68rem;
  font-weight: 700;
  border-radius: 10px;
  padding: 0.1rem 0.45rem;
  flex-shrink: 0;
}

.thread-detail-pane {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;

  &.empty-selection {
    align-items: center;
    justify-content: center;
    gap: 0.75rem;
    color: var(--text-muted);

    .icon-lg { width: 48px; height: 48px; opacity: 0.4; }
    p { font-size: 0.9rem; }
  }
}

.detail-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid var(--border-color);
  background: var(--bg-secondary);

  .detail-name { font-size: 0.95rem; font-weight: 700; color: var(--text-main); }
  .detail-role { font-size: 0.78rem; color: var(--text-muted); }
}

.messages-area {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.message-bubble {
  max-width: 60%;
  align-self: flex-start;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 12px 12px 12px 2px;
  padding: 0.55rem 0.85rem;

  &.from-me {
    align-self: flex-end;
    background: var(--primary);
    color: white;
    border-color: var(--primary);
    border-radius: 12px 12px 2px 12px;

    .bubble-time { color: rgba(255, 255, 255, 0.75); }
  }
}

.bubble-text {
  font-size: 0.9rem;
  white-space: pre-wrap;
  word-break: break-word;
}

.bubble-time {
  font-size: 0.68rem;
  color: var(--text-muted);
  margin-top: 0.25rem;
  text-align: right;
}

.empty-thread-text {
  text-align: center;
  color: var(--text-muted);
  font-size: 0.85rem;
  margin-top: 2rem;
}

.composer {
  display: flex;
  gap: 0.6rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--border-color);
  background: var(--bg-secondary);

  input {
    flex: 1;
    padding: 0.6rem 0.9rem;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    background: var(--bg-primary);
    color: var(--text-main);
    font-size: 0.9rem;
    outline: none;

    &:focus { border-color: var(--primary); }
  }
}

.send-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 8px;
  border: none;
  background: var(--primary);
  color: white;
  cursor: pointer;

  &:hover:not(:disabled) { opacity: 0.9; }
  &:disabled { opacity: 0.5; cursor: not-allowed; }
}

.empty-state {
  padding: 2rem 1.25rem;
  text-align: center;
  color: var(--text-muted);
  font-size: 0.85rem;
}

.icon-sm { width: 18px; height: 18px; }

@media (max-width: 900px) {
  .team-chat-container { flex-direction: column; }
  .threads-pane { width: 100%; max-height: 40vh; }
}
</style>
