<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { Send, Users, Paperclip, Mic, Square, X, FileText, Download } from 'lucide-vue-next'
import Swal from 'sweetalert2'
import { useInternalChatStore } from '../store/internalChat'
import { ROLE_LABELS } from '../config/roles'

// Chat interno da equipe — consultor, gerente, financeiro e diretoria
// conversando entre si dentro do CRM. Sem relação com WhatsApp/revendedora
// (isso é a aba "Conversas"). Ver InternalMessage no backend.
const store = useInternalChatStore()

const newMessageText = ref('')
const messagesEndRef = ref(null)
const fileInputRef = ref(null)
const searchQuery = ref('')
const isSending = ref(false)

const currentUser = JSON.parse(localStorage.getItem('user') || '{}')

// Cor do avatar varia por pessoa (hash simples do nome) — antes era um rosa
// só, ficava tudo igual e monótono na lista.
const AVATAR_COLORS = [
  '#cc0066', '#6366f1', '#10b981', '#f59e0b', '#ec4899', '#3b82f6', '#8b5cf6', '#14b8a6'
]
const avatarColor = (name) => {
  const str = name || '?'
  let hash = 0
  for (let i = 0; i < str.length; i++) hash = str.charCodeAt(i) + ((hash << 5) - hash)
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length]
}

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
  isSending.value = true
  try {
    await store.sendMessage(text)
    scrollToBottom()
  } finally {
    isSending.value = false
  }
}

// Anexo (foto ou documento) — um input de arquivo genérico cobre os dois
// casos, igual ao "clipe" do WhatsApp Web.
const triggerFilePicker = () => fileInputRef.value?.click()
const onFileSelected = async (e) => {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  if (file.size > 25 * 1024 * 1024) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Arquivo muito grande (máx. 25MB).', showConfirmButton: false, timer: 3500 })
    return
  }
  isSending.value = true
  try {
    await store.sendMessage('', file)
    scrollToBottom()
  } catch (err) {
    console.error('Erro ao enviar anexo:', err)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao enviar anexo.', showConfirmButton: false, timer: 3500 })
  } finally {
    isSending.value = false
  }
}

// Gravação de áudio na hora — MediaRecorder nativo do navegador, sem lib
// externa. Clica pra começar, clica de novo (ou no X) pra parar/cancelar.
const isRecording = ref(false)
const recordingSeconds = ref(0)
let mediaRecorder = null
let audioChunks = []
let mediaStream = null
let recordingInterval = null

const startRecording = async () => {
  try {
    mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true })
  } catch (err) {
    console.error('Erro ao acessar microfone:', err)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Não foi possível acessar o microfone.', showConfirmButton: false, timer: 3500 })
    return
  }

  audioChunks = []
  mediaRecorder = new MediaRecorder(mediaStream)
  mediaRecorder.ondataavailable = (e) => { if (e.data.size > 0) audioChunks.push(e.data) }
  mediaRecorder.start()

  isRecording.value = true
  recordingSeconds.value = 0
  recordingInterval = setInterval(() => { recordingSeconds.value++ }, 1000)
}

const stopMic = () => {
  mediaStream?.getTracks().forEach(t => t.stop())
  mediaStream = null
  clearInterval(recordingInterval)
  isRecording.value = false
  recordingSeconds.value = 0
}

const cancelRecording = () => {
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.onstop = null
    mediaRecorder.stop()
  }
  stopMic()
}

const finishRecording = () => {
  if (!mediaRecorder || mediaRecorder.state === 'inactive') return
  mediaRecorder.onstop = async () => {
    const blob = new Blob(audioChunks, { type: 'audio/webm' })
    stopMic()
    if (blob.size === 0) return
    isSending.value = true
    try {
      await store.sendMessage('', blob)
      scrollToBottom()
    } catch (err) {
      console.error('Erro ao enviar áudio:', err)
      Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao enviar áudio.', showConfirmButton: false, timer: 3500 })
    } finally {
      isSending.value = false
    }
  }
  mediaRecorder.stop()
}

const formatRecordingTime = (secs) => {
  const m = Math.floor(secs / 60).toString().padStart(2, '0')
  const s = (secs % 60).toString().padStart(2, '0')
  return `${m}:${s}`
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
  stopMic()
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
          <img v-if="t.avatar_url" :src="t.avatar_url" class="thread-avatar thread-avatar-photo" />
          <div v-else class="thread-avatar" :style="{ background: avatarColor(`${t.first_name || ''} ${t.last_name || ''}`) }">
            {{ getInitials(`${t.first_name || ''} ${t.last_name || ''}`) }}
          </div>
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
        <img v-if="store.activeThread?.avatar_url" :src="store.activeThread.avatar_url" class="thread-avatar thread-avatar-photo" />
        <div v-else class="thread-avatar" :style="{ background: avatarColor(`${store.activeThread?.first_name || ''} ${store.activeThread?.last_name || ''}`) }">
          {{ getInitials(`${store.activeThread?.first_name || ''} ${store.activeThread?.last_name || ''}`) }}
        </div>
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
            :class="{ 'from-me': m.sender_id === currentUser.id, 'has-attachment': !!m.attachment_url }"
          >
            <div v-if="m.attachment_url" class="bubble-attachment">
              <a v-if="m.attachment_type?.startsWith('image/')" :href="m.attachment_url" target="_blank" title="Clique para ampliar">
                <img :src="m.attachment_url" class="attachment-image" @load="scrollToBottom" />
              </a>
              <audio v-else-if="m.attachment_type?.startsWith('audio/')" :src="m.attachment_url" controls class="attachment-audio" />
              <a v-else :href="m.attachment_url" target="_blank" download class="attachment-doc">
                <FileText class="icon-xs" />
                <span>{{ m.attachment_name || 'Documento' }}</span>
                <Download class="icon-xs" />
              </a>
            </div>
            <div class="bubble-text" v-if="m.text">{{ m.text }}</div>
            <div class="bubble-time">{{ formatTime(m.created_at) }}</div>
          </div>
          <p v-if="store.activeMessages.length === 0" class="empty-thread-text">
            Nenhuma mensagem ainda. Diga oi!
          </p>
        </template>
        <div ref="messagesEndRef"></div>
      </div>

      <div class="composer">
        <template v-if="isRecording">
          <button class="cancel-recording-btn" @click="cancelRecording" title="Cancelar gravação">
            <X class="icon-sm" />
          </button>
          <div class="recording-indicator">
            <span class="recording-dot"></span>
            Gravando... {{ formatRecordingTime(recordingSeconds) }}
          </div>
          <button class="send-btn" @click="finishRecording" title="Enviar áudio">
            <Send class="icon-sm" />
          </button>
        </template>
        <template v-else>
          <input type="file" ref="fileInputRef" class="hidden-file-input" @change="onFileSelected" />
          <button class="composer-icon-btn" @click="triggerFilePicker" title="Anexar imagem ou documento" :disabled="isSending">
            <Paperclip class="icon-sm" />
          </button>
          <input
            v-model="newMessageText"
            type="text"
            placeholder="Digite uma mensagem..."
            :disabled="isSending"
            @keyup.enter="sendMessage"
          />
          <button v-if="!newMessageText.trim()" class="composer-icon-btn" @click="startRecording" title="Gravar áudio" :disabled="isSending">
            <Mic class="icon-sm" />
          </button>
          <button v-else class="send-btn" :disabled="isSending" @click="sendMessage" title="Enviar">
            <Send class="icon-sm" />
          </button>
        </template>
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
  border-radius: 8px;
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
  transition: background 0.15s;

  &:hover { background: var(--bg-tertiary); }
  &.active { background: var(--bg-tertiary); border-left: 3px solid var(--primary); }
}

.thread-avatar {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.85rem;
  font-weight: 700;
  flex-shrink: 0;
  box-shadow: 0 2px 5px rgba(0, 0, 0, 0.15);
}

.thread-avatar-photo {
  object-fit: cover;
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
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
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

    .icon-lg { width: 48px; height: 48px; opacity: 0.35; }
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
  box-shadow: 0 1px 2px rgba(43, 0, 22, 0.05);

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
  background:
    linear-gradient(var(--bg-primary), var(--bg-primary));
}

.message-bubble {
  max-width: 60%;
  align-self: flex-start;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 14px 14px 14px 3px;
  padding: 0.6rem 0.9rem;
  box-shadow: 0 1px 2px rgba(43, 0, 22, 0.06);

  &.from-me {
    align-self: flex-end;
    background: var(--primary);
    color: white;
    border-color: var(--primary);
    border-radius: 14px 14px 3px 14px;

    .bubble-time { color: rgba(255, 255, 255, 0.75); }
    .attachment-doc { background: rgba(255, 255, 255, 0.15); color: white; }
  }

  &.has-attachment { padding: 0.5rem; }
  &.has-attachment.from-me .bubble-text,
  &.has-attachment .bubble-text { padding: 0.3rem 0.4rem 0; }
}

.bubble-attachment {
  display: flex;
  flex-direction: column;
}

.attachment-image {
  max-width: 260px;
  max-height: 260px;
  border-radius: 10px;
  display: block;
  cursor: zoom-in;
  object-fit: cover;
}

.attachment-audio {
  max-width: 260px;
  height: 40px;
}

.attachment-doc {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.7rem;
  border-radius: 8px;
  background: var(--bg-tertiary);
  color: var(--text-main);
  text-decoration: none;
  font-size: 0.82rem;

  span { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  &:hover { opacity: 0.85; }
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
  align-items: center;
  gap: 0.5rem;
  padding: 0.9rem 1.5rem;
  border-top: 1px solid var(--border-color);
  background: var(--bg-secondary);

  input[type="text"] {
    flex: 1;
    padding: 0.65rem 0.95rem;
    border: 1px solid var(--border-color);
    border-radius: 20px;
    background: var(--bg-primary);
    color: var(--text-main);
    font-size: 0.9rem;
    outline: none;

    &:focus { border-color: var(--primary); }
    &:disabled { opacity: 0.6; }
  }
}

.hidden-file-input { display: none; }

.composer-icon-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.15s, color 0.15s;

  &:hover:not(:disabled) { background: var(--bg-tertiary); color: var(--primary); }
  &:disabled { opacity: 0.5; cursor: not-allowed; }
}

.send-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: none;
  background: var(--primary);
  color: white;
  cursor: pointer;
  flex-shrink: 0;
  box-shadow: 0 2px 6px rgba(204, 0, 102, 0.4);

  &:hover:not(:disabled) { opacity: 0.9; }
  &:disabled { opacity: 0.5; cursor: not-allowed; }
}

.recording-indicator {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.88rem;
  color: var(--text-main);
  font-weight: 500;
}

.recording-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #ef4444;
  animation: pulse-dot 1.2s infinite;
}

@keyframes pulse-dot {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.3; }
}

.cancel-recording-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: #ef4444;
  cursor: pointer;
  flex-shrink: 0;

  &:hover { background: rgba(239, 68, 68, 0.1); }
}

.empty-state {
  padding: 2rem 1.25rem;
  text-align: center;
  color: var(--text-muted);
  font-size: 0.85rem;
}

.icon-sm { width: 18px; height: 18px; }
.icon-xs { width: 14px; height: 14px; }

@media (max-width: 900px) {
  .team-chat-container { flex-direction: column; }
  .threads-pane { width: 100%; max-height: 40vh; }
}
</style>
