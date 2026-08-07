<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { useConversationsStore } from '../store/conversations'
import ConversationFilterPopover from '../components/ConversationFilterPopover.vue'
import ConversationSortPopover from '../components/ConversationSortPopover.vue'
import ConversationStatusDropdown from '../components/ConversationStatusDropdown.vue'
import ConversationMoreOptionsDropdown from '../components/ConversationMoreOptionsDropdown.vue'
import { 
  Filter, 
  ArrowDownUp, 
  CheckCircle,
  MoreVertical,
  Paperclip,
  Smile,
  CheckCheck,
  Send,
  Info,
  X,
  ExternalLink,
  Mail,
  Phone,
  Copy,
  Users,
  Building,
  MessageCircle,
  Edit2,
  GitMerge,
  Trash2,
  Minus,
  Plus,
  ArrowRight,
  ChevronDown,
  Sparkles,
  Loader2,
  BotOff,
  Bot
} from '@lucide/vue'

import api from '../api'
import Swal from 'sweetalert2'
import { ALL_STATUS_LABELS, ACTIVE_STATUS_LABELS, INACTIVE_STATUS_LABELS, statusLabel } from '../constants/regua'

import EmojiPicker from 'vue3-emoji-picker'
import 'vue3-emoji-picker/css'

import EditContactModal from '../components/EditContactModal.vue'
import MergeContactModal from '../components/MergeContactModal.vue'
import DeleteContactModal from '../components/DeleteContactModal.vue'
import ScheduleMessageModal from '../components/ScheduleMessageModal.vue'
import TransferModal from '../components/TransferModal.vue'

const store = useConversationsStore()
const route = useRoute()
const newMessageText = ref('')
const isPrivateMessage = ref(false)
const isEmojiPickerOpen = ref(false)
const mobileView = ref('list') // 'list' | 'chat' | 'details'

const openConversationMobile = (convId) => {
  store.setActiveConversation(convId)
  mobileView.value = 'chat'
}

const backToList = () => {
  mobileView.value = 'list'
}

const isScheduleModalOpen = ref(false)
const scheduledMessages = ref([])

const openScheduleModal = () => {
  isScheduleModalOpen.value = true
}

const closeScheduleModal = () => {
  isScheduleModalOpen.value = false
}

const fetchScheduledMessages = async () => {
  if (!store.activeConversation) return
  try {
    const response = await api.get(`/conversations/${store.activeConversation.id}/scheduled_messages`)
    scheduledMessages.value = response.data
  } catch (error) {
    console.error('Error fetching scheduled messages:', error)
  }
}

const onMessageScheduled = (newScheduledMessage) => {
  scheduledMessages.value.push(newScheduledMessage)
  // Sort them just in case
  scheduledMessages.value.sort((a, b) => new Date(a.send_at) - new Date(b.send_at))
}

const cancelScheduledMessage = async (msgId) => {
  if (!confirm('Tem certeza que deseja cancelar este agendamento?')) return
  try {
    await api.delete(`/conversations/${store.activeConversation.id}/scheduled_messages/${msgId}`)
    scheduledMessages.value = scheduledMessages.value.filter(m => m.id !== msgId)
  } catch (error) {
    console.error('Error canceling scheduled message:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao cancelar agendamento.', showConfirmButton: false, timer: 3500 })
  }
}

const DEPT_LABELS = {
  corretor:    'Consultoras',
  suporte:     'Suporte',
  financeiro:  'Financeiro',
  manutencao:  'Manutenção',
}

const agentsByDepartment = computed(() => {
  const groups = {}
  ;(store.agents || []).forEach(a => {
    const dept = a.department || 'corretor'
    if (!groups[dept]) groups[dept] = []
    groups[dept].push(a)
  })
  // ordem fixa de exibição
  return ['corretor', 'suporte', 'financeiro', 'manutencao']
    .filter(d => groups[d]?.length)
    .map(d => ({ dept: d, label: DEPT_LABELS[d] || d, agents: groups[d] }))
})

const isAssigning = ref(false)
const showTransferModal = ref(false)

const handleAssign = async (userId) => {
  if (!store.activeConversation) return
  isAssigning.value = true
  try {
    const newUserId = userId ? parseInt(userId) : null
    await store.assignConversation(store.activeConversation.id, newUserId)
  } catch (error) {
    console.error('Error assigning conversation:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao atribuir a conversa.', showConfirmButton: false, timer: 3500 })
  } finally {
    isAssigning.value = false
  }
}

const handleTransfer = async ({ userId, note }) => {
  if (!store.activeConversation) return
  isAssigning.value = true
  try {
    await store.transferConversation(store.activeConversation.id, userId, note)
    showTransferModal.value = false
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Conversa transferida!', showConfirmButton: false, timer: 3000 })
  } catch {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao transferir conversa.', showConfirmButton: false, timer: 3500 })
  } finally {
    isAssigning.value = false
  }
}

const conversationAttachments = computed(() => {
  if (!store.activeConversation?.messages) return []
  return store.activeConversation.messages.filter(m => m.attachmentUrl).reverse() // reverse to show latest first
})

const isAttachmentsOpen = ref(false)

const isAttributesOpen = ref(false)

const activeDetailsTab = ref('principal')
const detailsTabs = [
  { id: 'principal', label: 'Principal' },
  { id: 'dados', label: 'Dados' },
  { id: 'financeiro', label: 'Financeiro' },
  { id: 'estatisticas', label: 'Estatísticas' },
  { id: 'configuracoes', label: 'Configurações' },
]

const stageLabel = (status) => statusLabel(status)
const statusOptions = [
  { group: 'Ativas', options: ACTIVE_STATUS_LABELS },
  { group: 'Inativas', options: INACTIVE_STATUS_LABELS },
]
const isChangingStatus = ref(false)
const changeContactStatus = async (newStatus) => {
  const contact = store.activeConversation?.contact
  if (!contact?.id || !newStatus || newStatus === contact.status) return
  isChangingStatus.value = true
  try {
    await store.updateContact(contact.id, { status: newStatus })
  } catch (e) {
    console.error('Erro ao mudar status:', e)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao mudar etapa/status.', showConfirmButton: false, timer: 3000 })
  } finally {
    isChangingStatus.value = false
  }
}
const daysInStage = (contact) => {
  const since = contact?.status_changed_at || contact?.created_at
  if (!since) return null
  const days = Math.floor((Date.now() - new Date(since).getTime()) / 86_400_000)
  return days >= 0 ? days : null
}

// Campos do painel do lead — espelham o que a Clara Ferreira já usa no Kommo (aba Principal).
// Guardados em custom_attributes (jsonb) pra não depender de migration nova agora; editáveis
// via "Editar Contato" (já suporta atributos customizados livres).
const principalFields = [
  { key: 'venda', label: 'Venda' },
  { key: 'proximo_agendamento', label: 'Próximo agendamento' },
  { key: 'limite_inicial', label: 'Limite Inicial' },
  { key: 'dia_fechamento', label: 'Dia Fechamento' },
  { key: 'data_agendamento', label: 'Data de Agendamento' },
  { key: 'obs_fechamento', label: 'Obs Fechamento' },
  { key: 'dia_pf_fechamento', label: 'Dia p/ Fechamento' },
  { key: 'horario_fechamento', label: 'Horário de Fechamento' },
  { key: 'atraso', label: 'Atraso' },
  { key: 'observacao_mes', label: 'Observação do mês' },
  { key: 'meta', label: 'Meta' },
  { key: 'desafio_combinado', label: 'Desafio combinado para o mês' },
  { key: 'como_chegar_meta', label: 'Como chegar na Meta' },
]
const getAttr = (key) => store.activeConversation?.contact?.custom_attributes?.[key]

// Campos livres criados em "Atributos Personalizados" (EditContactModal) — qualquer
// chave que não seja um dos campos fixos acima nem uma chave de sistema (telefones,
// pedidos, dados da aba "Dados"). Mantém a lista de chaves reservadas espelhando
// RESERVED_KEYS do EditContactModal.vue pra não exibir campo duplicado nem os
// internos (telefones_adicionais, pedidos) aqui no painel Principal.
const RESERVED_ATTR_KEYS = [
  ...principalFields.map(f => f.key),
  'instagram', 'id_jueri', 'origem',
  'gerente_jueri_nome', 'gerente_jueri_id', 'supervisor_nome',
  'rg', 'profissao', 'razao_social', 'nome_fantasia', 'cnpj',
  'observacao_jueri', 'observacao_interna_jueri', 'data_inativacao_jueri',
  'pedidos', 'telefones_adicionais',
]
const humanizeKey = (key) => key
  .replace(/_/g, ' ')
  .replace(/\b\w/g, (c) => c.toUpperCase())
const extraAttributes = computed(() => {
  const custom = store.activeConversation?.contact?.custom_attributes || {}
  return Object.keys(custom)
    .filter(k => !RESERVED_ATTR_KEYS.includes(k) && custom[k])
    .map(k => ({ key: k, label: humanizeKey(k), value: custom[k] }))
})

const formatDate = (iso) => {
  if (!iso) return null
  return new Date(iso).toLocaleDateString('pt-BR')
}
const formatDateTime = (iso) => {
  if (!iso) return null
  return new Date(iso).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
const brl = (v) => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(v || 0)

// Aba Dados — cadastro/pessoal da revendedora
const enderecoCompleto = computed(() => {
  const c = store.activeConversation?.contact
  if (!c) return null
  const linha1 = [c.street, c.address_number].filter(Boolean).join(', ')
  const linha2 = [c.neighborhood, c.city, c.state].filter(Boolean).join(' - ')
  const full = [linha1, linha2, c.cep].filter(Boolean).join(' · ')
  return full || null
})
const dadosFields = [
  { key: 'cpf', label: 'CPF', source: 'contact' },
  { key: 'birth_date', label: 'Data de Nascimento', source: 'contact', format: 'date' },
  { key: 'nivel', label: 'Nível', source: 'contact' },
  { key: 'instagram', label: 'Instagram', source: 'attr' },
  { key: 'id_jueri', label: 'ID Jueri (ERP)', source: 'attr' },
  { key: 'origem', label: 'Origem do lead', source: 'attr' },
  { key: 'gerente_jueri_nome', label: 'Gerente no Jueri', source: 'attr' },
  { key: 'gerente_jueri_id', label: 'ID do Gerente no Jueri', source: 'attr' },
  { key: 'supervisor_nome', label: 'Supervisor no Jueri', source: 'attr' },
  { key: 'rg', label: 'RG', source: 'attr' },
  { key: 'profissao', label: 'Profissão', source: 'attr' },
  { key: 'razao_social', label: 'Razão Social', source: 'attr' },
  { key: 'nome_fantasia', label: 'Nome Fantasia', source: 'attr' },
  { key: 'cnpj', label: 'CNPJ', source: 'attr' },
  { key: 'observacao_jueri', label: 'Observação (Jueri)', source: 'attr' },
  { key: 'observacao_interna_jueri', label: 'Observação Interna (Jueri)', source: 'attr' },
  { key: 'data_inativacao_jueri', label: 'Data de Inativação (Jueri)', source: 'attr', format: 'date' },
]
const getDadoValue = (f) => {
  const c = store.activeConversation?.contact
  if (!c) return null
  const raw = f.source === 'attr' ? c.custom_attributes?.[f.key] : c[f.key]
  if (!raw) return null
  return f.format === 'date' ? formatDate(raw) : raw
}

// Aba Financeiro — pedidos sincronizados da tabela `pedidos` (Jueri é a fonte
// da verdade; baixa/cancelamento de pedido é feito na tela do Jueri, não aqui
// — por isso não existe mais "adicionar pedido manual", só leitura).
const STATUS_LABELS = { 1: 'Aberto', 2: 'Baixado', 3: 'Cancelado', 4: 'Perdido' }
const STATUS_CLASSES = { 1: 'aberto', 2: 'baixado', 3: 'cancelado', 4: 'perdido' }
const pedidoStatusLabel = (statusId) => STATUS_LABELS[statusId] || 'Desconhecido'
const pedidoStatusClass = (statusId) => STATUS_CLASSES[statusId] || 'desconhecido'
const pedidos = computed(() => {
  const list = store.activeConversation?.contact?.pedidos
  return Array.isArray(list) ? [...list].sort((a, b) => new Date(b.data_criacao) - new Date(a.data_criacao)) : []
})
const totalVendido = computed(() => pedidos.value.filter(p => p.status_id === 2).reduce((s, p) => s + (parseFloat(p.valor_total) || 0), 0))
const totalEmAberto = computed(() => pedidos.value.filter(p => p.status_id === 1).reduce((s, p) => s + (parseFloat(p.valor_total) || 0), 0))

// Aba Estatísticas — métricas reais derivadas da conversa/contato ativos
const totalMessagesCount = computed(() => store.activeConversation?.messages?.length || 0)
const daysAsClient = computed(() => {
  const created = store.activeConversation?.contact?.created_at
  if (!created) return null
  const days = Math.floor((Date.now() - new Date(created).getTime()) / 86_400_000)
  return days >= 0 ? days : null
})
const lastMessageAt = computed(() => {
  const msgs = store.activeConversation?.messages
  if (!msgs?.length) return null
  return msgs[msgs.length - 1].timestamp
})
const activeTagsCount = computed(() => store.activeConversation?.tags?.length || 0)

// Linha do tempo de marcos de ciclo de vida (lifecycle_events) — Iniciada,
// Churn e Reativação, na ordem em que aconteceram de verdade (histórico,
// diferente do status atual que é sobrescrito a cada transição).
const LIFECYCLE_EVENT_LABELS = { iniciada: 'Iniciada', churn: 'Churn', reativacao: 'Reativação' }
const lifecycleEvents = computed(() => store.activeConversation?.contact?.lifecycle_events || [])
const pedidosFechadosCount = computed(() => pedidos.value.filter(p => p.status_id === 2).length)

const isNotesOpen = ref(false)
const newNoteText = ref('')
const isSavingNote = ref(false)

const saveNote = async () => {
  if (!store.activeConversation?.contact?.id || !newNoteText.value.trim()) return
  isSavingNote.value = true
  try {
    await store.addNote(store.activeConversation.contact.id, newNoteText.value.trim())
    newNoteText.value = ''
  } catch (error) {
    console.error('Error saving note:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao salvar nota.', showConfirmButton: false, timer: 3500 })
  } finally {
    isSavingNote.value = false
  }
}

watch(() => store.activeConversation, (newVal) => {
  if (newVal) {
    fetchScheduledMessages()
  } else {
    scheduledMessages.value = []
  }
}, { immediate: true })

const toggleEmojiPicker = () => {
  isEmojiPickerOpen.value = !isEmojiPickerOpen.value
}

const onSelectEmoji = (emoji) => {
  newMessageText.value += emoji.i
}

const closeEmojiPicker = () => {
  isEmojiPickerOpen.value = false
}

const isGeneratingSummary = ref(false)

const generateSummary = async () => {
  if (!store.activeConversation) return
  isGeneratingSummary.value = true
  try {
    const response = await api.post(`/conversations/${store.activeConversation.id}/generate_summary`)
    isPrivateMessage.value = true
    newMessageText.value = response.data.summary
  } catch (error) {
    console.error('Error generating summary:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao gerar resumo da conversa.', showConfirmButton: false, timer: 3500 })
  } finally {
    isGeneratingSummary.value = false
  }
}

const formatMessageTime = (isoString) => {
  if (!isoString || !isoString.includes('T')) return isoString
  const date = new Date(isoString)
  const timeStr = date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
  const dayStr = date.toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' }).replace('.', '')
  return `${dayStr}, ${timeStr}`
}

const isEditModalOpen = ref(false)
const isMergeModalOpen = ref(false)
const isDeleteModalOpen = ref(false)

const currentUser = JSON.parse(localStorage.getItem('user') || '{}')
const isFilterPopoverOpen = ref(false)
const isSortPopoverOpen = ref(false)

const toggleFilterPopover = () => {
  isFilterPopoverOpen.value = !isFilterPopoverOpen.value
  isSortPopoverOpen.value = false
}

const toggleSortPopover = () => {
  isSortPopoverOpen.value = !isSortPopoverOpen.value
  isFilterPopoverOpen.value = false
}

const applyAdvancedFilters = (filters) => {
  store.setAdvancedFilters(filters)
}

const openEditModal = () => {
  if (store.activeConversation?.contact) {
    isEditModalOpen.value = true
  }
}

const openMergeModal = () => {
  if (store.activeConversation?.contact) {
    isMergeModalOpen.value = true
  }
}

const openDeleteModal = () => {
  if (store.activeConversation?.contact) {
    isDeleteModalOpen.value = true
  }
}

const handleContactDeleted = () => {
  // Conversas store will automatically set activeConversationId to null
  // No extra action needed here unless we want to show a toast
}

const focusMessageInput = () => {
  const input = document.querySelector('.chat-input-area textarea')
  if (input) {
    input.focus()
  }
}

const messagesContainerRef = ref(null)

const scrollToBottom = async () => {
  await nextTick()
  requestAnimationFrame(() => {
    const el = messagesContainerRef.value || document.querySelector('.chat-messages')
    if (el) el.scrollTop = el.scrollHeight
  })
}

watch(() => store.activeConversationId, (newVal) => {
  if (newVal) {
    scrollToBottom()
  }
})

watch(() => store.activeConversation?.messages?.length, (newVal, oldVal) => {
  if (newVal !== oldVal) {
    scrollToBottom()
  }
})

const handleNewMessage = (e) => {
  if (e.detail && e.detail.conversationId === store.activeConversationId) {
    scrollToBottom()
  }
}

const closeFilterPopover = () => {
  isFilterPopoverOpen.value = false
  isSortPopoverOpen.value = false
  isDetailsMenuOpen.value = false
}

const isDetailsMenuOpen = ref(false)
const toggleDetailsMenu = () => {
  isDetailsMenuOpen.value = !isDetailsMenuOpen.value
}

onMounted(() => {
  if (store.conversations.length === 0) store.fetchConversations()
  if (store.agents.length === 0) store.fetchAgents()
  if (route.params.inboxId) {
    store.setSidebarInboxId(route.params.inboxId)
  } else {
    store.setSidebarFilter(route.params.filter || 'all')
  }
  window.addEventListener('new-message', handleNewMessage)
  document.addEventListener('click', closeEmojiPicker)
  document.addEventListener('click', closeFilterPopover)
  store.setupWebSocket()
  scrollToBottom()
})

onUnmounted(() => {
  window.removeEventListener('new-message', handleNewMessage)
  document.removeEventListener('click', closeEmojiPicker)
  document.removeEventListener('click', closeFilterPopover)
  clearInterval(aiStatusInterval.value)
})

watch(() => route.params.filter, (newFilter) => {
  if (newFilter) {
    store.setSidebarFilter(newFilter)
  } else if (!route.params.inboxId) {
    store.setSidebarFilter('all')
  }
})

watch(() => route.params.inboxId, (newInboxId) => {
  if (newInboxId) {
    store.setSidebarInboxId(newInboxId)
  }
})

const fileInput = ref(null)
const selectedFile = ref(null)
const selectedFilePreview = ref(null)

const triggerFileInput = () => {
  if (fileInput.value) {
    fileInput.value.click()
  }
}

const handleFileChange = (event) => {
  const file = event.target.files[0]
  if (file) {
    selectedFile.value = file
    if (file.type.startsWith('image/')) {
      selectedFilePreview.value = URL.createObjectURL(file)
    } else {
      selectedFilePreview.value = null
    }
  }
}

const clearSelectedFile = () => {
  if (selectedFilePreview.value) {
    URL.revokeObjectURL(selectedFilePreview.value)
    selectedFilePreview.value = null
  }
  selectedFile.value = null
  if (fileInput.value) {
    fileInput.value.value = ''
  }
}

const handleSendMessage = () => {
  if (newMessageText.value.trim() || selectedFile.value) {
    store.sendMessage(newMessageText.value, isPrivateMessage.value, selectedFile.value)
    newMessageText.value = ''
    clearSelectedFile()
    scrollToBottom()
  }
}

// IA pause status
const aiPauseStatus = ref({ paused: false, remaining_seconds: 0 })
const aiStatusInterval = ref(null)

const fetchAiStatus = async () => {
  const convId = store.activeConversationId
  if (!convId) return
  try {
    const res = await api.get(`/conversations/${convId}/ai_status`)
    aiPauseStatus.value = res.data
  } catch (e) {
    aiPauseStatus.value = { paused: false, remaining_seconds: 0 }
  }
}

const resumeAi = async () => {
  const convId = store.activeConversationId
  if (!convId) return
  try {
    await api.post(`/conversations/${convId}/resume_ai`)
    aiPauseStatus.value = { paused: false, remaining_seconds: 0 }
  } catch (e) {
    console.error('Erro ao reativar IA:', e)
  }
}

const newTagName = ref('')
const TAG_COLORS = ['#6b7280', '#ef4444', '#f59e0b', '#10b981', '#3b82f6', '#8b5cf6', '#ec4899']
const newTagColor = ref(TAG_COLORS[0])

const removeTag = async (tagId) => {
  const convId = store.activeConversationId
  if (!convId) return
  try {
    await api.delete(`/conversations/${convId}/tags/${tagId}`)
  } catch (e) {
    console.error('Erro ao remover etiqueta:', e)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao remover etiqueta.', showConfirmButton: false, timer: 3000 })
  }
}

const addTag = async () => {
  const convId = store.activeConversationId
  const name = newTagName.value.trim()
  if (!convId || !name) return
  try {
    await api.post(`/conversations/${convId}/tags`, { name, color: newTagColor.value })
    newTagName.value = ''
    newTagColor.value = TAG_COLORS[0]
  } catch (e) {
    console.error('Erro ao adicionar etiqueta:', e)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao adicionar etiqueta.', showConfirmButton: false, timer: 3000 })
  }
}

const formatAiRemaining = (seconds) => {
  if (!seconds || seconds <= 0) return '0 min'
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return m > 0 ? `${m} min${s > 0 ? ` ${s}s` : ''}` : `${s}s`
}

watch(() => store.activeConversationId, (newId) => {
  clearInterval(aiStatusInterval.value)
  aiPauseStatus.value = { paused: false, remaining_seconds: 0 }
  if (newId) {
    fetchAiStatus()
    aiStatusInterval.value = setInterval(fetchAiStatus, 15000)
  }
}, { immediate: true })

onUnmounted(() => {
  clearInterval(aiStatusInterval.value)
  window.removeEventListener('new-message', handleNewMessage)
  document.removeEventListener('click', closeEmojiPicker)
  document.removeEventListener('click', closeFilterPopover)
})
</script>

<template>
  <div class="conversations-container">
    <!-- Middle Pane: Conversation List -->
    <div class="conv-list-pane" :class="{ 'mobile-hidden': mobileView !== 'list' }">
      <div class="list-header">
        <div class="header-top">
          <h2 style="text-transform: capitalize;">{{ route.params.filter ? route.params.filter.replace('-', ' ') : 'Todas as conversas' }} <span class="badge">Abertas</span></h2>
          <div class="actions" style="position: relative; display: flex; gap: 0.5rem;">
            <div style="position: relative;">
              <button class="icon-btn" @click.stop="toggleFilterPopover"><Filter class="icon" /></button>
              <ConversationFilterPopover 
                :is-open="isFilterPopoverOpen" 
                :initial-filters="store.advancedFilters"
                @close="isFilterPopoverOpen = false" 
                @apply="applyAdvancedFilters" 
              />
            </div>
            
            <div style="position: relative;">
              <button class="icon-btn" @click.stop="toggleSortPopover"><ArrowDownUp class="icon" /></button>
              <ConversationSortPopover
                :is-open="isSortPopoverOpen"
                @close="isSortPopoverOpen = false"
              />
            </div>
          </div>
        </div>
        
        <div class="tabs">
          <button 
            :class="['tab', { active: store.currentFilter === 'minhas' }]"
            @click="store.setFilter('minhas')"
          >
            Minhas <span class="count">{{ store.sidebarFilteredConversations.filter(c => c.assignee_id === store.currentUser.id).length }}</span>
          </button>
          <button 
            :class="['tab', { active: store.currentFilter === 'nao-atribuidos' }]"
            @click="store.setFilter('nao-atribuidos')"
          >
            Não atribuídas <span class="count">{{ store.sidebarFilteredConversations.filter(c => !c.assignee).length }}</span>
          </button>
          <button 
            :class="['tab', { active: store.currentFilter === 'all' }]"
            @click="store.setFilter('all')"
          >
            Todos <span class="count">{{ store.sidebarFilteredConversations.length }}</span>
          </button>
        </div>
      </div>

      <div class="conv-list">
        <div 
          v-for="conv in store.filteredConversations" 
          :key="conv.id" 
          :class="['conv-item', { unread: conv.unread > 0, active: conv.id === store.activeConversationId }]"
          @click="openConversationMobile(conv.id)"
        >
          <div class="conv-avatar" :style="{ backgroundColor: conv.contact.avatarBg, color: 'white', overflow: 'hidden' }">
            <img v-if="conv.contact.avatar_url" :src="conv.contact.avatar_url" alt="avatar" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%;" />
            <span v-else class="avatar-text">{{ conv.contact.avatarInitials }}</span>
          </div>
          <div class="conv-info">
            <div class="conv-title-row">
              <span class="conv-name">
                {{ conv.contact.name }}
                <span class="channel-icon" :class="conv.source" :title="conv.source === 'instagram' ? 'Instagram' : 'WhatsApp'">
                  <svg v-if="conv.source === 'instagram'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="url(#ig-grad-list)"><defs><linearGradient id="ig-grad-list" x1="0" x2="1" y1="1" y2="0"><stop offset="0%" stop-color="#f09433"/><stop offset="50%" stop-color="#dc2743"/><stop offset="100%" stop-color="#bc1888"/></linearGradient></defs><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm6.406-11.845a1.44 1.44 0 1 0 0 2.881 1.44 1.44 0 0 0 0-2.881z"/></svg>
                  <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
                    <circle cx="12" cy="12" r="12" fill="#25D366"/>
                    <path fill="#fff" d="M12.04 4.6c-4.07 0-7.38 3.31-7.38 7.38 0 1.3.34 2.57.99 3.69l-1.05 3.83 3.92-1.03a7.35 7.35 0 0 0 3.52.9h.01c4.07 0 7.38-3.31 7.38-7.38a7.34 7.34 0 0 0-2.16-5.22 7.34 7.34 0 0 0-5.23-2.17zm4.32 10.55c-.18.51-.9.94-1.47 1.06-.4.08-.91.15-2.65-.57-2.23-.92-3.66-3.18-3.77-3.33-.11-.15-.9-1.2-.9-2.29 0-1.09.57-1.63.77-1.85.18-.2.45-.32.7-.32.09 0 .16 0 .23.01.2.01.3.02.44.33.16.38.54 1.3.59 1.4.05.1.08.22.02.35-.06.13-.09.2-.18.31-.09.11-.19.25-.27.34-.09.1-.19.2-.08.4.11.2.5.82 1.07 1.32.75.65 1.38.86 1.57.96.15.07.32.06.43-.06.14-.15.33-.4.51-.65.13-.18.3-.21.51-.13.21.08 1.32.62 1.55.74.22.11.37.17.42.26.05.1.05.56-.13 1.08z"/>
                  </svg>
                </span>
              </span>
              <span class="conv-time">{{ formatMessageTime(conv.timestamp) }}</span>
            </div>
            <div class="conv-preview">
              <span v-if="conv.unread > 0" class="unread-badge"></span>
              <span>{{ conv.preview }}</span>
            </div>
            <div class="conv-tags" v-if="(conv.tags && conv.tags.length > 0) || conv.assignee">
              <span v-for="tag in conv.tags" :key="tag.id" class="conv-tag" :style="{ background: tag.color, color: '#fff' }">
                {{ tag.name }}
              </span>
              <span v-if="conv.assignee" class="conv-tag conv-tag-agent" :title="'Atendente: ' + conv.assignee">
                👤 {{ conv.assignee }}
              </span>
            </div>
          </div>
        </div>
        
        <div class="all-loaded" v-if="store.filteredConversations.length > 0">
          Todas as conversas carregadas 🎉
        </div>
        
        <div class="all-loaded" v-else style="margin-top: 2rem;">
          Não há conversas ativas neste grupo.
        </div>
      </div>
    </div>

    <!-- Main Chat Pane -->
    <div class="chat-pane" :class="{ 'mobile-hidden': mobileView === 'list' }">
      <div class="chat-header" v-if="store.activeConversation">
        <div class="chat-title">
          <button class="btn-back-mobile" @click="backToList" title="Voltar">
            ←
          </button>
          <div class="conv-avatar" :style="{ backgroundColor: store.activeConversation.contact.avatarBg, color: 'white', overflow: 'hidden' }">
            <img v-if="store.activeConversation.contact.avatar_url" :src="store.activeConversation.contact.avatar_url" alt="avatar" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%;" />
            <span v-else>{{ store.activeConversation.contact.avatarInitials }}</span>
          </div>
          <div class="title-info">
            <h3>{{ store.activeConversation.contact.name }}</h3>
            <span class="ticket-id">#{{ store.activeConversation.id }}</span>
          </div>
        </div>
        <div class="chat-actions">
          <button class="btn-details-mobile" @click="mobileView = 'details'" title="Detalhes do contato">
            <Info class="icon-sm" />
          </button>
          <ConversationStatusDropdown
            :conversation-id="store.activeConversation.id"
            :current-status="store.activeConversation.status"
          />
          <ConversationMoreOptionsDropdown
            :conversation-id="store.activeConversation.id"
            :contact-id="store.activeConversation.contact?.id"
            :contact-status="store.activeConversation.contact?.status"
            @contact-blocked="store.activeConversation.contact.status = 'blocked'"
            @contact-unblocked="store.activeConversation.contact.status = 'active'"
          />
        </div>
      </div>

      <div class="chat-messages" ref="messagesContainerRef" v-if="store.activeConversation">
        
        <div class="message-wrapper" v-for="msg in store.activeConversation.messages" :key="msg.id" :class="msg.senderType">
          
          <div class="msg-avatar" v-if="msg.senderType === 'contact'">
            <img v-if="store.activeConversation.contact.avatar_url" :src="store.activeConversation.contact.avatar_url" />
            <span v-else>{{ store.activeConversation.contact.avatarInitials }}</span>
          </div>

          <div class="message-content">
            <div class="bubble" :class="{ private: msg.isPrivate }">
              <div v-if="msg.attachmentUrl" class="attachment-preview">
                <a v-if="msg.attachmentType && msg.attachmentType.startsWith('image/')" :href="msg.attachmentUrl" target="_blank" title="Clique para ampliar" class="image-link">
                  <img :src="msg.attachmentUrl" class="msg-image" @load="scrollToBottom" />
                </a>
                <audio v-else-if="msg.attachmentType && msg.attachmentType.startsWith('audio/')" :src="msg.attachmentUrl" controls class="msg-audio"></audio>
                <div v-else-if="msg.attachmentType && msg.attachmentType.startsWith('video/')" class="video-wrapper">
                  <video :src="msg.attachmentUrl" controls class="msg-video" @loadeddata="scrollToBottom"></video>
                  <a :href="msg.attachmentUrl" target="_blank" download class="media-download-link">Baixar Vídeo</a>
                </div>
                <a v-else :href="msg.attachmentUrl" target="_blank" class="msg-doc">📎 Ver Anexo</a>
              </div>
              <div v-if="msg.text" class="msg-text">{{ msg.text }}</div>
              
              <div class="bubble-meta">
                <span class="time">{{ formatMessageTime(msg.timestamp) }}</span>
                <CheckCheck v-if="msg.senderType === 'agent'" class="icon-xxs" />
              </div>
            </div>
          </div>

          <div class="msg-avatar agent-avatar" v-if="msg.senderType === 'agent'">
            <span v-if="msg.agentName">{{ msg.agentName.charAt(0).toUpperCase() }}</span>
            <span v-else>A</span>
          </div>

        </div>

        <div class="empty-state" v-if="store.activeConversation.messages.length === 0">
          <div class="icon-circle">
            <MessageCircle class="icon-lg" />
          </div>
          <p>Não há mensagens nesta conversa ainda.</p>
        </div>
      </div>

      <!-- Banner IA pausada -->
      <div v-if="store.activeConversation && aiPauseStatus.paused" class="ai-paused-banner">
        <BotOff class="banner-icon" />
        <span>IA pausada — <strong>{{ formatAiRemaining(aiPauseStatus.remaining_seconds) }}</strong> para voltar automaticamente</span>
        <button class="btn-resume-ai" @click="resumeAi">
          <Bot class="icon-xs" />
          Reativar agora
        </button>
      </div>

      <div class="chat-input-area" v-if="store.activeConversation">
        <div class="input-tabs">
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <button :class="['input-tab', { active: !isPrivateMessage }]" @click="isPrivateMessage = false">Responder</button>
            <button :class="['input-tab', { active: isPrivateMessage }]" @click="isPrivateMessage = true">Mensagem Privada</button>
          </div>
          <button class="btn-magic-sm" @click="generateSummary" :disabled="isGeneratingSummary">
            <Loader2 v-if="isGeneratingSummary" class="icon-sm spin" />
            <Sparkles v-else class="icon-sm" />
            <span class="btn-magic-label">{{ isGeneratingSummary ? 'Resumindo...' : 'Gerar Resumo' }}</span>
          </button>
        </div>
        <div class="input-box">
          <div v-if="selectedFile" class="file-preview-area">
            <div class="file-preview-content">
              <img v-if="selectedFilePreview" :src="selectedFilePreview" class="preview-img" />
              <div v-else class="file-icon">📄</div>
              <span class="file-name">{{ selectedFile.name }}</span>
            </div>
            <button class="clear-file-btn" @click="clearSelectedFile">&times;</button>
          </div>
          <textarea 
            v-model="newMessageText" 
            @keydown.enter.prevent="handleSendMessage"
            :placeholder="isPrivateMessage ? 'Digite uma nota privada...' : 'Digite sua mensagem aqui...'"
          ></textarea>
          <div class="input-actions">
            <div class="left-actions">
              <input type="file" ref="fileInput" @change="handleFileChange" hidden />
              <button class="icon-btn" @click="triggerFileInput" title="Anexar arquivo"><Paperclip class="icon-sm" /></button>
              <div class="emoji-wrapper">
                <button class="icon-btn" @click.stop="toggleEmojiPicker"><Smile class="icon-sm" /></button>
                <div v-if="isEmojiPickerOpen" class="emoji-picker-container" @click.stop>
                  <EmojiPicker :native="true" @select="onSelectEmoji" />
                </div>
              </div>
              <!-- Indicador IA pausada -->
              <div v-if="aiPauseStatus.paused" class="ai-paused-pill">
                <BotOff class="pill-icon" />
                <span>IA pausada · {{ formatAiRemaining(aiPauseStatus.remaining_seconds) }}</span>
                <button class="pill-resume" @click="resumeAi" title="Reativar IA agora">
                  <Bot class="pill-icon" />
                </button>
              </div>
            </div>
            <button class="btn-send" @click="handleSendMessage">Enviar (↵)</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Right Sidebar Pane (Contact Details) -->
    <div class="details-pane" :class="{ 'mobile-hidden': mobileView !== 'details' }" v-if="store.activeConversation">
      <div class="details-header-top">
        <h3>Contatos</h3>
        <div class="details-header-actions">
          <div class="details-menu-wrapper">
            <button class="icon-btn" @click.stop="toggleDetailsMenu" title="Mais opções"><MoreVertical class="icon-sm" /></button>
            <div v-if="isDetailsMenuOpen" class="details-menu" @click.stop>
              <button class="details-menu-item" @click="openEditModal(); isDetailsMenuOpen = false"><Edit2 class="icon-xs" /> Editar contato</button>
              <button class="details-menu-item" @click="openMergeModal(); isDetailsMenuOpen = false"><GitMerge class="icon-xs" /> Mesclar contato</button>
              <button class="details-menu-item danger" @click="openDeleteModal(); isDetailsMenuOpen = false"><Trash2 class="icon-xs" /> Apagar contato</button>
            </div>
          </div>
          <button class="icon-btn" @click="mobileView = 'chat'"><X class="icon-sm" /></button>
        </div>
      </div>

      <div class="contact-profile">
        <div class="contact-avatar" :style="{ backgroundColor: store.activeConversation.contact.avatarBg, color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.5rem', fontWeight: 'bold', overflow: 'hidden' }">
          <img v-if="store.activeConversation.contact.avatar_url" :src="store.activeConversation.contact.avatar_url" alt="avatar" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%;" />
          <span v-else>{{ store.activeConversation.contact.avatarInitials }}</span>
        </div>
        <div class="contact-name-row">
          <h4>{{ store.activeConversation.contact.name }}</h4>
          <Info class="icon-xs" />
          <ExternalLink class="icon-xs" />
        </div>

        <div class="lead-badges" v-if="store.activeConversation.contact.id">
          <span class="lead-id-badge">#{{ store.activeConversation.contact.id }}</span>
          <template v-if="store.activeConversation.contact.id_jueri">
            <span class="lead-tag lead-tag-revendedora">REVENDEDORA</span>
            <span class="lead-tag lead-tag-consignado">CONSIGNADO</span>
          </template>
          <span v-else class="lead-tag lead-tag-novo">NOVO CONTATO</span>
        </div>

        <div class="lead-stage-row" v-if="store.activeConversation.contact.id_jueri">
          <span class="stage-pipeline">Consignado</span>
          <span class="stage-badge">{{ stageLabel(store.activeConversation.contact.status) }}</span>
          <span v-if="daysInStage(store.activeConversation.contact)" class="stage-days">({{ daysInStage(store.activeConversation.contact) }} dias)</span>
          <ChevronDown class="icon-xs" style="margin-left: auto;" />
        </div>

        <div class="contact-attributes">
          <div class="attr-row">
            <Mail class="icon-xs" />
            <span>{{ store.activeConversation.contact.email || 'Indisponível' }}</span>
          </div>
          <div class="attr-row">
            <Phone class="icon-xs" />
            <span>{{ store.activeConversation.contact.phone || 'Indisponível' }}</span>
            <Copy class="icon-xs action-icon" v-if="store.activeConversation.contact.phone" />
          </div>
          <div class="attr-row">
            <Users class="icon-xs" />
            <span>{{ store.activeConversation.contact.jid || store.activeConversation.contact.socialProfile || 'Indisponível' }}</span>
          </div>
          <div class="attr-row">
            <Building class="icon-xs" />
            <span>{{ store.activeConversation.contact.location || 'Indisponível' }}</span>
          </div>
        </div>

        <div class="contact-actions-row">
          <button class="action-btn" title="Focar Mensagem" @click="focusMessageInput"><MessageCircle class="icon-sm" /></button>
          <button class="action-btn" title="Editar Contato" @click="openEditModal"><Edit2 class="icon-sm" /></button>
          <button class="action-btn" title="Mesclar Contato" @click="openMergeModal"><GitMerge class="icon-sm" /></button>
          <button class="action-btn danger" title="Apagar Contato" @click="openDeleteModal"><Trash2 class="icon-sm" /></button>
        </div>
      </div>

      <div class="details-tabs">
        <button
          v-for="tab in detailsTabs"
          :key="tab.id"
          class="details-tab"
          :class="{ active: activeDetailsTab === tab.id }"
          @click="activeDetailsTab = tab.id"
        >
          {{ tab.label }}
        </button>
      </div>

      <template v-if="activeDetailsTab === 'principal'">
      <div class="lead-fields">
        <div class="lead-field">
          <span class="lf-label">Usuário responsável</span>
          <span class="lf-value">{{ store.activeConversation.assignee || 'Não atribuído' }}</span>
        </div>
        <div class="lead-field" v-for="f in principalFields" :key="f.key">
          <span class="lf-label">{{ f.label }}</span>
          <span class="lf-value" :class="{ empty: !getAttr(f.key) }">{{ getAttr(f.key) || '...' }}</span>
        </div>
        <div class="lead-field" v-for="attr in extraAttributes" :key="'extra-' + attr.key">
          <span class="lf-label">{{ attr.label }}</span>
          <span class="lf-value">{{ attr.value }}</span>
        </div>
        <button class="lead-fields-edit" @click="openEditModal"><Edit2 class="icon-xs" /> Editar campos</button>
      </div>

      <div class="accordion-card">
        <div class="card-header">
          <h3>Mensagens agendadas</h3>
          <Minus class="icon-sm" />
        </div>
        <div class="card-body">
          <button class="btn-text-blue" @click="openScheduleModal"><Plus class="icon-xs" /> Agendar mensagem</button>
          
          <div v-if="scheduledMessages.length > 0" class="scheduled-list-ui">
            <div v-for="msg in scheduledMessages" :key="msg.id" class="scheduled-item-ui">
              <div class="sch-header">
                <span class="sch-time">{{ new Date(msg.send_at).toLocaleString('pt-BR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) }}</span>
                <button class="icon-btn-cancel" @click="cancelScheduledMessage(msg.id)" title="Cancelar envio"><X class="icon-xxs" /></button>
              </div>
              <div class="sch-content">
                <p v-if="msg.text">{{ msg.text.length > 50 ? msg.text.substring(0, 50) + '...' : msg.text }}</p>
                <div v-if="msg.attachmentUrl" class="sch-attachment">📎 {{ msg.attachmentName || 'Anexo' }}</div>
              </div>
            </div>
          </div>
          <p v-else class="empty-text">Ainda não há mensagens agendadas.</p>
        </div>
      </div>
      
      <div class="accordion-card">
        <div class="card-header">
          <h3>Atendente</h3>
        </div>
        <div class="card-body" style="padding-top: 0.5rem; padding-bottom: 1rem;">
          <select
            class="assign-select"
            :value="store.activeConversation?.assignee_id || ''"
            @change="handleAssign($event.target.value)"
            :disabled="isAssigning"
          >
            <option value="">Nenhum (Não atribuído)</option>
            <optgroup v-for="group in agentsByDepartment" :key="group.dept" :label="'— ' + group.label">
              <option v-for="agent in group.agents" :key="agent.id" :value="agent.id">
                {{ agent.first_name }} {{ agent.last_name }}
              </option>
            </optgroup>
          </select>
          <button
            class="btn-transfer"
            :disabled="!store.activeConversation?.assignee_id || isAssigning"
            @click="showTransferModal = true"
          >
            Transferir com nota
          </button>
        </div>
      </div>
      <div class="accordion-card">
        <div class="card-header">
          <h3>Etiquetas</h3>
        </div>
        <div class="card-body" style="padding-top: 0.5rem; padding-bottom: 1rem;">
          <div class="tag-chips">
            <span
              v-for="tag in store.activeConversation?.tags || []"
              :key="tag.id"
              class="tag-chip"
              :style="{ background: tag.color }"
            >
              {{ tag.name }}
              <button class="tag-remove" @click="removeTag(tag.id)" title="Remover etiqueta (reativa a IA se for 'agente_off')">×</button>
            </span>
            <span v-if="!store.activeConversation?.tags?.length" class="empty-text">Nenhuma etiqueta</span>
          </div>
          <div class="tag-add-row">
            <input
              v-model="newTagName"
              @keyup.enter="addTag"
              placeholder="Nova etiqueta..."
              class="tag-input"
            />
            <button class="btn-add-tag" @click="addTag" :disabled="!newTagName.trim()">
              <Plus class="icon-xs" /> Adicionar
            </button>
          </div>
          <div class="tag-color-picker">
            <button
              v-for="c in TAG_COLORS"
              :key="c"
              class="tag-color-dot"
              :class="{ active: newTagColor === c }"
              :style="{ background: c }"
              @click="newTagColor = c"
              :title="c"
            ></button>
          </div>
        </div>
      </div>
      </template>

      <template v-if="activeDetailsTab === 'dados'">
      <div class="lead-fields">
        <div class="lead-field" v-for="f in dadosFields" :key="f.key">
          <span class="lf-label">{{ f.label }}</span>
          <span class="lf-value" :class="{ empty: !getDadoValue(f) }">{{ getDadoValue(f) || '...' }}</span>
        </div>
        <div class="lead-field">
          <span class="lf-label">E-mail</span>
          <span class="lf-value" :class="{ empty: !store.activeConversation.contact.email }">{{ store.activeConversation.contact.email || '...' }}</span>
        </div>
        <div class="lead-field">
          <span class="lf-label">Endereço</span>
          <span class="lf-value" :class="{ empty: !enderecoCompleto }">{{ enderecoCompleto || '...' }}</span>
        </div>
        <div class="lead-field">
          <span class="lf-label">Empresa vinculada</span>
          <span class="lf-value" :class="{ empty: !store.activeConversation.contact.company_name }">{{ store.activeConversation.contact.company_name || '...' }}</span>
        </div>
        <div class="lead-field" v-for="tel in (store.activeConversation.contact.reseller_phones || [])" :key="'tel-' + tel.id">
          <span class="lf-label">{{ tel.label || 'Telefone adicional' }}</span>
          <span class="lf-value">{{ tel.phone }}</span>
        </div>
        <div class="lead-field">
          <span class="lf-label">Data de cadastro</span>
          <span class="lf-value" :class="{ empty: !store.activeConversation.contact.created_at }">{{ formatDate(store.activeConversation.contact.created_at) || '...' }}</span>
        </div>
        <button class="lead-fields-edit" @click="openEditModal"><Edit2 class="icon-xs" /> Editar campos</button>
      </div>

      <div class="accordion-card" v-if="store.activeConversation?.contact?.bio">
        <div class="card-header"><h3>Descrição</h3></div>
        <div class="card-body" style="padding-top: 0.5rem;">
          <p style="font-size: 0.85rem; color: var(--text-main); line-height: 1.5;">{{ store.activeConversation.contact.bio }}</p>
        </div>
      </div>
      </template>

      <template v-if="activeDetailsTab === 'financeiro'">
      <div class="fin-summary">
        <div class="fin-card">
          <span class="fin-label">Total vendido</span>
          <span class="fin-value positive">{{ brl(totalVendido) }}</span>
        </div>
        <div class="fin-card">
          <span class="fin-label">Em aberto</span>
          <span class="fin-value" :class="{ warn: totalEmAberto > 0 }">{{ brl(totalEmAberto) }}</span>
        </div>
      </div>

      <div class="accordion-card">
        <div class="card-header"><h3>Pedidos / Acertos</h3></div>
        <div class="card-body" style="padding-top: 0.5rem; display: flex; flex-direction: column; gap: 0.75rem;">
          <p class="empty-text" style="margin: 0;">Sincronizado automaticamente do Jueri — baixa/cancelamento de pedido é feito lá, não aqui.</p>

          <div v-if="pedidos.length > 0" class="pedido-list">
            <div class="pedido-item" v-for="p in pedidos" :key="p.id">
              <span class="pedido-status" :class="'status-' + pedidoStatusClass(p.status_id)">{{ pedidoStatusLabel(p.status_id) }}</span>
              <span class="pedido-date">{{ formatDate(p.data_criacao) }}</span>
              <span class="pedido-valor">{{ brl(p.valor_total) }}</span>
            </div>
          </div>
          <p v-else class="empty-text">Nenhum pedido sincronizado ainda.</p>
        </div>
      </div>
      </template>

      <template v-if="activeDetailsTab === 'estatisticas'">
      <div class="stat-grid">
        <div class="stat-card">
          <span class="stat-value">{{ daysAsClient !== null ? daysAsClient : '...' }}</span>
          <span class="stat-label">Dias como revendedora</span>
        </div>
        <div class="stat-card">
          <span class="stat-value">{{ daysInStage(store.activeConversation.contact) ?? '...' }}</span>
          <span class="stat-label">Dias na etapa atual</span>
        </div>
        <div class="stat-card">
          <span class="stat-value">{{ totalMessagesCount }}</span>
          <span class="stat-label">Mensagens trocadas</span>
        </div>
        <div class="stat-card">
          <span class="stat-value">{{ pedidosFechadosCount }}</span>
          <span class="stat-label">Pedidos baixados</span>
        </div>
        <div class="stat-card">
          <span class="stat-value">{{ activeTagsCount }}</span>
          <span class="stat-label">Etiquetas ativas</span>
        </div>
        <div class="stat-card">
          <span class="stat-value stat-value-sm">{{ formatDateTime(lastMessageAt) || '...' }}</span>
          <span class="stat-label">Última interação</span>
        </div>
      </div>

      <div class="accordion-card">
        <div class="card-header"><h3>Linha do tempo do ciclo de vida</h3></div>
        <div class="card-body" style="padding-top: 0.5rem;">
          <div v-if="lifecycleEvents.length > 0" class="lifecycle-timeline">
            <div class="lifecycle-item" v-for="ev in lifecycleEvents" :key="ev.id" :class="'event-' + ev.event_type">
              <span class="lifecycle-dot"></span>
              <div class="lifecycle-body">
                <span class="lifecycle-label">{{ LIFECYCLE_EVENT_LABELS[ev.event_type] || ev.event_type }}</span>
                <span class="lifecycle-date">{{ formatDateTime(ev.occurred_at) }}</span>
                <span v-if="ev.metadata?.pecas_abertas != null" class="lifecycle-meta">{{ ev.metadata.pecas_abertas }} peças abertas</span>
              </div>
            </div>
          </div>
          <p v-else class="empty-text">Nenhum marco registrado ainda pra essa revendedora.</p>
        </div>
      </div>
      </template>

      <template v-if="activeDetailsTab === 'configuracoes'">
      <div class="accordion-card">
        <div class="card-header"><h3>Funil</h3></div>
        <div class="card-body" style="padding-top: 0.5rem; display: flex; flex-direction: column; gap: 0.5rem;">
          <div class="lead-field">
            <span class="lf-label">Pipeline</span>
            <span class="lf-value">Consignado</span>
          </div>
          <div class="lead-field">
            <span class="lf-label">Etapa atual</span>
            <select
              class="status-select"
              :value="store.activeConversation.contact.status || 'revendedor_ativo'"
              :disabled="isChangingStatus"
              @change="changeContactStatus($event.target.value)"
            >
              <optgroup v-for="grp in statusOptions" :key="grp.group" :label="grp.group">
                <option v-for="(label, key) in grp.options" :key="key" :value="key">{{ label }}</option>
              </optgroup>
            </select>
          </div>
          <div class="lead-field">
            <span class="lf-label">Responsável</span>
            <span class="lf-value" :class="{ empty: !store.activeConversation.assignee }">{{ store.activeConversation.assignee || 'Não atribuído' }}</span>
          </div>
        </div>
      </div>

      <div class="accordion-card">
        <div class="card-header"><h3>Datas</h3></div>
        <div class="card-body" style="padding-top: 0.5rem; display: flex; flex-direction: column; gap: 0.5rem;">
          <div class="lead-field">
            <span class="lf-label">Criado em</span>
            <span class="lf-value" :class="{ empty: !store.activeConversation.contact.created_at }">{{ formatDateTime(store.activeConversation.contact.created_at) || '...' }}</span>
          </div>
          <div class="lead-field">
            <span class="lf-label">Última mudança de etapa</span>
            <span class="lf-value" :class="{ empty: !store.activeConversation.contact.status_changed_at }">{{ formatDateTime(store.activeConversation.contact.status_changed_at) || '...' }}</span>
          </div>
        </div>
      </div>

      <div class="accordion-card">
        <div class="card-header"><h3>Ações</h3></div>
        <div class="card-body" style="padding-top: 0.5rem; display: flex; flex-direction: column; gap: 0.5rem;">
          <button class="btn-text-blue" @click="openMergeModal"><GitMerge class="icon-xs" /> Mesclar com outro contato</button>
          <button class="btn-text-blue danger-text" @click="openDeleteModal"><Trash2 class="icon-xs" /> Apagar este contato</button>
        </div>
      </div>
      </template>

      <template v-if="activeDetailsTab === 'principal'">
      <div class="accordion-card">
        <div class="card-header" @click="isNotesOpen = !isNotesOpen" style="cursor: pointer;">
          <h3>Notas do contato</h3>
          <Minus v-if="isNotesOpen" class="icon-sm" />
          <Plus v-else class="icon-sm" />
        </div>
        <div class="card-body" v-if="isNotesOpen" style="padding-top: 0.5rem; display: flex; flex-direction: column; gap: 0.5rem;">
          <div class="notes-list" v-if="store.activeConversation?.contact?.notes?.length > 0">
            <div class="note-item" v-for="note in store.activeConversation.contact.notes" :key="note.id">
              <div class="note-header">
                <span class="note-author">{{ note.author }}</span>
                <span class="note-time">{{ new Date(note.created_at).toLocaleDateString('pt-BR') }}</span>
              </div>
              <div class="note-content">{{ note.content }}</div>
            </div>
          </div>
          <p v-else class="empty-text">Nenhuma nota adicionada.</p>
          
          <div class="add-note-box" style="margin-top: 0.5rem; display: flex; flex-direction: column; gap: 0.5rem;">
            <textarea v-model="newNoteText" placeholder="Adicionar nova nota..." rows="2" class="note-textarea"></textarea>
            <button class="btn-primary" style="padding: 0.4rem; font-size: 0.85rem;" @click="saveNote" :disabled="isSavingNote || !newNoteText.trim()">
              {{ isSavingNote ? 'Salvando...' : 'Salvar Nota' }}
            </button>
          </div>
        </div>
      </div>

      <div class="accordion-card">
        <div class="card-header" @click="isAttachmentsOpen = !isAttachmentsOpen" style="cursor: pointer;">
          <h3>Anexos</h3>
          <Minus v-if="isAttachmentsOpen" class="icon-sm" />
          <Plus v-else class="icon-sm" />
        </div>
        <div class="card-body" v-if="isAttachmentsOpen" style="padding-top: 0.5rem;">
          <div v-if="conversationAttachments.length > 0" class="attachments-gallery">
            <a v-for="att in conversationAttachments" :key="att.id" :href="att.attachmentUrl" target="_blank" class="attachment-thumb">
              <img v-if="att.attachmentType && att.attachmentType.startsWith('image/')" :src="att.attachmentUrl" alt="Anexo" />
              <div v-else class="attachment-doc">
                <span>📎</span>
                <small>Documento</small>
              </div>
            </a>
          </div>
          <p v-else class="empty-text">Nenhum anexo nesta conversa.</p>
        </div>
      </div>
      </template>

    </div>

    <!-- Modals -->
    <EditContactModal :isOpen="isEditModalOpen" :contact="store.activeConversation?.contact" @close="isEditModalOpen = false" />
    <MergeContactModal :isOpen="isMergeModalOpen" :contact="store.activeConversation?.contact" @close="isMergeModalOpen = false" />
    <DeleteContactModal :isOpen="isDeleteModalOpen" :contact="store.activeConversation?.contact" @close="isDeleteModalOpen = false" @deleted="handleContactDeleted" />
    <TransferModal v-if="showTransferModal" :agents="store.agents" :currentAssigneeId="store.activeConversation?.assignee_id" @close="showTransferModal = false" @confirm="handleTransfer" />
    
    <ScheduleMessageModal 
      :isOpen="isScheduleModalOpen" 
      :conversationId="store.activeConversation?.id" 
      @close="closeScheduleModal" 
      @scheduled="onMessageScheduled"
    />
  </div>
</template>

<style lang="scss" scoped>
.conversations-container {
  display: flex;
  flex: 1;
  min-height: 0;
  width: 100%;
  background: var(--bg-primary);
  overflow: hidden;
}

/* Common */
.icon { width: 18px; height: 18px; color: var(--text-muted); }
.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 14px; height: 14px; }
.icon-lg { width: 32px; height: 32px; color: var(--text-muted); }
.icon-btn {
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  
  &:hover { background: var(--bg-hover); color: var(--text-main); }
}
.mr-1 { margin-right: 0.25rem; }

/* Left Pane: Conversation List */
.conv-list-pane {
  order: 1;
  width: 360px;
  border-right: 1px solid var(--border-color);
  background: var(--bg-secondary);
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
}

.list-header {
  padding: 1rem 1rem 0;
  border-bottom: 1px solid var(--border-color);
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;

  h2 {
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--text-main);
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .badge {
    background: var(--bg-tertiary);
    color: var(--text-muted);
    font-size: 0.7rem;
    padding: 2px 6px;
    border-radius: 10px;
    font-weight: 500;
  }

  .actions {
    display: flex;
    gap: 0.25rem;
  }
}

.tabs {
  display: flex;
  gap: 1rem;

  .tab {
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    padding: 0.5rem 0;
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text-muted);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.4rem;

    &.active {
      color: var(--primary);
      border-bottom-color: var(--primary);
      
      .count {
        background: var(--input-focus);
        color: var(--primary);
      }
    }

    .count {
      background: var(--bg-tertiary);
      padding: 1px 6px;
      border-radius: 10px;
      font-size: 0.7rem;
      color: var(--text-muted);
    }
  }
}

.conv-list {
  flex: 1;
  overflow-y: auto;
}

.conv-item {
  display: flex;
  padding: 1rem;
  border-bottom: 1px solid var(--border-color);
  gap: 0.75rem;
  cursor: pointer;
  transition: background-color 0.1s;

  &:hover { background: var(--bg-hover); }
  &.active { background: var(--input-focus); }

  .conv-avatar {
    width: 36px;
    height: 36px;
    background: var(--bg-tertiary);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--text-main);
    flex-shrink: 0;
  }

  .conv-info {
    flex: 1;
    min-width: 0;
  }

  .conv-title-row {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0.25rem;
  }

  .conv-name {
    font-weight: 600;
    font-size: 0.9rem;
    color: var(--text-main);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;

    .channel-icon {
      display: inline-flex;
      flex-shrink: 0;

      svg {
        width: 17px;
        height: 17px;
      }
    }
  }

  .conv-time {
    font-size: 0.75rem;
    color: var(--text-muted);
  }


  .conv-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 3px;
    margin-top: 3px;
  }

  .conv-tag {
    font-size: 0.68rem;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 10px;
    border: none;
    white-space: nowrap;
    letter-spacing: 0.01em;
    text-shadow: 0 1px 2px rgba(0,0,0,0.18);
  }

  .conv-tag-agent {
    background: linear-gradient(135deg, #d49ba7, #a80050) !important;
    color: #fff !important;
    text-shadow: 0 1px 3px rgba(0,0,0,0.3) !important;
    font-weight: 700;
    letter-spacing: 0.01em;
    box-shadow: 0 2px 6px rgba(212, 155, 167,0.4);
  }

  .tag-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 0.9rem;

    &:empty { display: none; }
  }

  .tag-chip {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    font-size: 0.75rem;
    font-weight: 700;
    padding: 5px 6px 5px 12px;
    border-radius: 999px;
    color: #fff;
    text-shadow: 0 1px 2px rgba(0,0,0,0.18);
    box-shadow: 0 1px 3px rgba(0,0,0,0.15);
    line-height: 1.3;
  }

  .tag-remove {
    background: rgba(255,255,255,0.22);
    border: none;
    color: #fff;
    border-radius: 50%;
    width: 18px;
    height: 18px;
    line-height: 1;
    cursor: pointer;
    font-size: 0.9rem;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0;
    flex-shrink: 0;
    transition: background 0.15s;
    &:hover { background: rgba(255,255,255,0.4); }
  }

  .tag-add-row {
    display: flex;
    gap: 0.5rem;
    align-items: stretch;
  }

  .tag-color-picker {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    margin-top: 0.5rem;
  }

  .tag-color-dot {
    width: 18px;
    height: 18px;
    border-radius: 50%;
    border: 2px solid transparent;
    cursor: pointer;
    padding: 0;

    &.active { border-color: var(--text-main); }
    &:hover { opacity: 0.85; }
  }

  .tag-input {
    flex: 1;
    min-width: 0;
    height: 36px;
    box-sizing: border-box;
    padding: 0 0.75rem;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    background: var(--bg-secondary);
    color: var(--text-main);
    font-size: 0.85rem;
    transition: border-color 0.15s, box-shadow 0.15s;

    &:focus {
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(212, 155, 167,0.12);
    }
  }

  .btn-add-tag {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.3rem;
    flex-shrink: 0;
    height: 36px;
    box-sizing: border-box;
    padding: 0 0.85rem;
    font-size: 0.8rem;
    font-weight: 600;
    border-radius: 8px;
    cursor: pointer;
    white-space: nowrap;
    transition: background 0.15s;

    color: white;
    background: var(--primary);
    border: none;

    &:hover:not(:disabled) { background: var(--primary-hover); }
    &:disabled { cursor: not-allowed; }

    .icon-xs { width: 14px; height: 14px; }
  }

  .conv-preview {
    font-size: 0.8rem;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  &.unread .conv-preview {
    color: var(--primary-color, #20B2AA);
    font-weight: 500;
  }

  .unread-badge {
    display: inline-block;
    width: 8px;
    height: 8px;
    background-color: var(--primary-color, #20B2AA);
    border-radius: 50%;
    margin-right: 6px;
    box-shadow: 0 0 5px var(--primary-color, #20B2AA);
    animation: unread-pulse 2s infinite ease-in-out;
  }
}

@keyframes unread-pulse {
  0% {
    transform: scale(0.9);
    opacity: 0.6;
    box-shadow: 0 0 0 0 rgba(32, 178, 170, 0.4);
  }
  50% {
    transform: scale(1.1);
    opacity: 1;
    box-shadow: 0 0 0 4px rgba(32, 178, 170, 0);
  }
  100% {
    transform: scale(0.9);
    opacity: 0.6;
    box-shadow: 0 0 0 0 rgba(32, 178, 170, 0);
  }
}

.all-loaded {
  text-align: center;
  padding: 2rem;
  font-size: 0.8rem;
  color: var(--text-muted);
}

/* Middle Pane: Chat Area */
.chat-pane {
  order: 3;
  flex: 1;
  display: flex;
  flex-direction: column;
  background: var(--bg-primary);
  min-width: 300px;
  overflow: hidden;
  border-left: 1px solid var(--border-color);
}

.chat-header {
  height: 64px;
  background: var(--bg-secondary);
  border-bottom: 1px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 1.5rem;
  flex-shrink: 0;
  min-width: 0;

  .chat-title {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    
    .conv-avatar {
      width: 28px;
      height: 28px;
      background: var(--bg-tertiary);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.75rem;
      font-weight: bold;
      color: var(--text-main);
    }

    .title-info {
      min-width: 0;
      flex: 1;
    }

    h3 {
      font-size: 0.95rem;
      font-weight: 600;
      color: var(--text-main);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .ticket-id {
      font-size: 0.75rem;
      color: var(--text-muted);
    }
  }

  .chat-actions {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .btn-details-mobile {
    display: none;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    width: 32px;
    height: 32px;
    color: var(--text-muted);
    cursor: pointer;
    &:hover { background: var(--bg-hover); color: var(--text-main); }
  }

  .btn-resolve {
    display: flex;
    align-items: center;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    padding: 0.4rem 0.75rem;
    border-radius: 6px;
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text-main);
    cursor: pointer;

    &:hover { background: var(--bg-hover); }
  }
}

.chat-messages {
  flex: 1;
  padding: 1.5rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  background-color: #f4f6f8; /* Slightly darker background like Chatwoot */
}

.message-wrapper {
  display: flex;
  flex-direction: row;
  max-width: 85%;
  gap: 0.5rem;

  &.contact {
    align-self: flex-start;
    
    .bubble {
      background: #e5e7eb;
      color: #1f2937;
      border: none;
      border-radius: 0 8px 8px 8px;
    }
  }

  &.agent {
    align-self: flex-end;
    justify-content: flex-end;
    
    .message-content {
      display: flex;
      justify-content: flex-end;
    }

    .bubble {
      background: #e3f2fd; /* light blue */
      color: #1f2937; /* dark text */
      border: none;
      border-radius: 8px 0 8px 8px;

      &.private {
        background: #fef08a; /* yellow note */
        color: #854d0e;
      }
    }
  }

  .msg-avatar {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
    font-weight: 600;
    color: #4b5563;
    flex-shrink: 0;
    overflow: hidden;
    margin-top: auto; /* align to bottom like chatwoot */

    &.agent-avatar {
      background: #ede9fe; /* light purple */
      color: #5b21b6;
    }

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  .message-content {
    display: flex;
    flex-direction: column;
    max-width: calc(100% - 36px);
  }

  .bubble {
    padding: 0.5rem 0.75rem 0.25rem 0.75rem;
    font-size: 0.95rem;
    line-height: 1.4;
    word-break: break-word;
    display: flex;
    flex-direction: column;
    box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
    
    .attachment-preview {
      margin-bottom: 0.5rem;
      max-width: 100%;
      border-radius: 6px;
      overflow: hidden;
      
      .image-link {
        display: block;
        cursor: zoom-in;
      }

      .msg-image, .msg-video {
        width: 100%;
        max-height: 300px;
        object-fit: cover;
        display: block;
      }
      
      .msg-audio {
        width: 100%;
        max-width: 250px;
      }

      .video-wrapper {
        display: flex;
        flex-direction: column;
      }

      .media-download-link {
        display: block;
        font-size: 0.75rem;
        text-align: center;
        padding: 0.4rem;
        background: rgba(0,0,0,0.05);
        color: inherit;
        text-decoration: none;
        font-weight: 500;
        transition: background 0.2s;
      }
      .media-download-link:hover {
        background: rgba(0,0,0,0.1);
      }
    }

    .msg-doc {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.5rem 0.75rem;
      background: rgba(128, 128, 128, 0.2);
      border-radius: 6px;
      color: inherit;
      text-decoration: none;
      font-weight: 600;
      font-size: 0.85rem;
      transition: background 0.2s;
      
      &:hover {
        background: rgba(128, 128, 128, 0.3);
      }
    }

    .bubble-meta {
      display: flex;
      justify-content: flex-end;
      align-items: center;
      gap: 0.25rem;
      margin-top: 0.25rem;
      font-size: 0.65rem;
      color: rgba(0,0,0,0.4);

      .icon-xxs {
        width: 14px;
        height: 14px;
      }
    }
  }
}

.system-message {
  padding: 1rem;
  border-radius: 8px;
  font-size: 0.85rem;
  
  &.warning {
    background: #451a25; /* Dark mode adaptation */
    color: #fca5a5;
    border: 1px solid #7f1d1d;
    display: flex;
    justify-content: space-between;
    align-items: center;

    .btn-text {
      background: none;
      border: none;
      color: #fca5a5;
      font-weight: 600;
      cursor: pointer;
      text-decoration: underline;
    }
  }

  &.info-box {
    background: #3b2f15; /* Dark mode adaptation */
    border: 1px solid #854d0e;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;

    .info-content {
      min-width: 0;
      flex: 1;
    }

    h4 { color: #fde047; margin-bottom: 0.25rem; }
    p { color: #fef08a; margin-bottom: 0.25rem; }
    .subtext { color: #fef08a; font-size: 0.75rem; font-style: italic; opacity: 0.8; }
    
    .learn-more {
      color: #fde047;
      font-weight: 500;
      white-space: nowrap;
      flex-shrink: 0;
    }
  }
}

/* Fix light mode for system messages if not in dark-theme */
:global(body:not(.dark-theme)) .system-message.warning {
  background: #fef2f2;
  color: #b91c1c;
  border: none;
  .btn-text { color: #b91c1c; }
}
:global(body:not(.dark-theme)) .system-message.info-box {
  background: #fefce8;
  border: 1px solid #fef08a;
  h4 { color: #854d0e; }
  p { color: #a16207; }
  .subtext { color: #ca8a04; opacity: 1; }
  .learn-more { color: #854d0e; }
}


.empty-state {
  margin: auto;
  text-align: center;
  color: var(--text-muted);
  
  .icon-circle {
    width: 64px;
    height: 64px;
    background: var(--bg-tertiary);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1rem;
  }
}

.ai-paused-banner {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.6rem 1.5rem;
  background: #4d0026;
  border-top: 1px solid #ba5e72;
  color: #ffd9ec;
  font-size: 0.82rem;

  .banner-icon {
    width: 16px;
    height: 16px;
    flex-shrink: 0;
    color: #ff8fc7;
  }

  span {
    flex: 1;
    strong { color: #ffe0f0; }
  }

  .btn-resume-ai {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.3rem 0.75rem;
    background: #ba5e72;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.78rem;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    transition: background 0.15s;

    &:hover { background: #a80050; }

    .icon-xs {
      width: 13px;
      height: 13px;
    }
  }
}

.ai-paused-pill {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.2rem 0.5rem 0.2rem 0.4rem;
  background: #4d0026;
  border: 1px solid #ba5e72;
  border-radius: 20px;
  color: #ffd9ec;
  font-size: 0.72rem;
  white-space: nowrap;

  .pill-icon {
    width: 12px;
    height: 12px;
    flex-shrink: 0;
  }

  span { font-weight: 500; }

  .pill-resume {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    background: #ba5e72;
    border: none;
    border-radius: 50%;
    color: white;
    cursor: pointer;
    padding: 0;
    transition: background 0.15s;
    &:hover { background: #a80050; }
    .pill-icon { color: white; }
  }
}

.chat-input-area {
  padding: 1rem 1.5rem;
  background: var(--bg-secondary);
}

.btn-magic-sm {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.8rem;
  background: var(--primary);
  border: none;
  border-radius: 6px;
  color: white;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.85rem;
  transition: opacity 0.2s;
  margin-left: auto;
  white-space: nowrap;

  &:disabled { opacity: 0.65; cursor: not-allowed; }
  &:hover:not(:disabled) { opacity: 0.88; }
}

.input-tabs {
  display: flex;
  flex-wrap: wrap;
  row-gap: 0.4rem;
  gap: 0.5rem;
  margin-bottom: -1px;
  padding-left: 1rem;

  .input-tab {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-bottom: none;
    padding: 0.5rem 1rem;
    border-radius: 8px 8px 0 0;
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text-muted);
    cursor: pointer;

    &.active {
      color: var(--text-main);
      border-bottom: 2px solid var(--bg-secondary);
      z-index: 1;
    }
  }
}

.input-box {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  box-shadow: 0 1px 2px var(--shadow-sm);
  
  textarea {
    width: 100%;
    border: none;
    padding: 1rem;
    min-height: 100px;
    resize: none;
    outline: none;
    font-size: 0.9rem;
    background: var(--bg-secondary);
    color: var(--text-main);
    &::placeholder {
      color: var(--text-muted);
    }
  }

  .input-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.5rem 1rem;
    background: var(--bg-secondary);
    border-top: 1px solid var(--border-color);
    border-radius: 0 0 8px 8px;

    .left-actions { display: flex; gap: 0.5rem; }
    
    .btn-send {
      background: var(--primary);
      color: white;
      border: none;
      padding: 0.5rem 1rem;
      border-radius: 6px;
      font-size: 0.85rem;
      font-weight: 500;
      cursor: pointer;

      &:hover { background: var(--primary-hover); }
    }
    
    .emoji-wrapper {
      position: relative;
    }
    
    .emoji-picker-container {
      position: absolute;
      bottom: 40px;
      left: 0;
      z-index: 50;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
      border-radius: 8px;
    }
  }
}

/* Right Pane: Contact Details */
.details-pane {
  order: 2;
  width: 400px;
  background: var(--bg-secondary); /* White in light mode */
  flex-shrink: 0;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
}

.details-header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;

  .details-header-actions {
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  .details-menu-wrapper {
    position: relative;
  }

  .details-menu {
    position: absolute;
    top: calc(100% + 4px);
    right: 0;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    box-shadow: 0 4px 16px rgba(43,0,22,0.14);
    min-width: 190px;
    padding: 0.35rem;
    z-index: 20;
    display: flex;
    flex-direction: column;
  }

  .details-menu-item {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    background: none;
    border: none;
    text-align: left;
    padding: 0.5rem 0.6rem;
    font-size: 0.82rem;
    color: var(--text-main);
    border-radius: 6px;
    cursor: pointer;

    &:hover { background: var(--bg-hover); }
    &.danger { color: #ef4444; }
  }

  h3 {
    font-size: 1rem;
    font-weight: 600;
    color: var(--text-main);
  }
}

.details-tabs {
  display: flex;
  gap: 0;
  padding: 0 0.75rem;
  border-bottom: 1px solid var(--border-color);
  overflow-x: auto;
  scrollbar-width: none;
  &::-webkit-scrollbar { display: none; }
}

.details-tab {
  background: none;
  border: none;
  padding: 0.65rem 0.5rem;
  font-size: 0.74rem;
  font-weight: 600;
  color: var(--text-muted);
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
  white-space: nowrap;
  flex-shrink: 0;
  transition: color 0.15s, border-color 0.15s;

  &:hover { color: var(--text-main); }

  &.active {
    color: var(--primary);
    border-bottom-color: var(--primary);
  }
}

.contact-profile {
  display: flex;
  flex-direction: column;
  padding: 0 1.25rem 1.25rem;
  border-bottom: 1px solid var(--border-color);

  .contact-avatar {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    overflow: hidden;
    margin-bottom: 0.75rem;
    
    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  .contact-name-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: var(--text-main);
    margin-bottom: 0.75rem;

    h4 {
      font-size: 1rem;
      font-weight: 600;
    }
    
    .icon-xs { color: var(--text-muted); cursor: pointer; }
  }

  .lead-badges {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 0.35rem;
    margin-bottom: 0.6rem;

    .lead-id-badge {
      font-size: 0.7rem;
      color: var(--text-muted);
      font-weight: 600;
    }

    .lead-tag {
      font-size: 0.62rem;
      font-weight: 700;
      padding: 0.15rem 0.5rem;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 0.02em;
    }
    .lead-tag-revendedora { background: #d1fae5; color: #065f46; }
    .lead-tag-consignado { background: #ffd9ec; color: #a80050; }
    .lead-tag-novo { background: var(--bg-tertiary); color: var(--text-muted); }
  }

  .lead-stage-row {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.5rem 0.6rem;
    background: var(--bg-tertiary);
    border-radius: 8px;
    margin-bottom: 0.75rem;
    font-size: 0.78rem;
    color: var(--text-main);

    .stage-pipeline { color: var(--text-muted); }
    .stage-badge { font-weight: 700; color: var(--primary); }
    .stage-days { color: var(--text-muted); }
    .icon-xs { color: var(--text-muted); }
  }

  .contact-attributes {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;

    .attr-row {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      color: var(--text-muted);
      font-size: 0.85rem;

      span {
        flex: 1;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      .action-icon {
        cursor: pointer;
        opacity: 0;
        transition: opacity 0.2s;
      }

      &:hover .action-icon {
        opacity: 1;
        color: var(--text-main);
      }
    }
  }

  .contact-actions-row {
    display: flex;
    gap: 0.5rem;
    margin-top: 1.25rem;

    .action-btn {
      width: 36px;
      height: 36px;
      border-radius: 8px;
      background: var(--bg-primary); /* Slightly different from bg-secondary */
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      color: var(--text-muted);
      transition: background 0.2s, color 0.2s;

      &:hover {
        background: var(--bg-hover);
        color: var(--text-main);
      }

      &.danger {
        color: #ef4444;
        background: rgba(239, 68, 68, 0.1);
        &:hover { background: rgba(239, 68, 68, 0.2); }
      }

      &.charge {
        color: #059669;
        background: rgba(5, 150, 105, 0.1);
        &:hover { background: rgba(5, 150, 105, 0.2); }
      }
    }
  }
}

.lead-fields {
  padding: 0.75rem 1.25rem 1rem;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
}

.status-select {
  padding: 0.3rem 0.5rem;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-secondary);
  color: var(--text-main);
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
  max-width: 100%;

  &:focus { outline: none; border-color: var(--primary); }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
}

.lead-field {
  display: grid;
  grid-template-columns: 150px 1fr;
  gap: 0.5rem;
  font-size: 0.78rem;
  align-items: baseline;

  .lf-label { color: var(--text-muted); }
  .lf-value {
    color: var(--text-main);
    font-weight: 500;
    overflow-wrap: break-word;
    &.empty { color: var(--text-muted); font-weight: 400; }
  }
}

.lead-fields-edit {
  align-self: flex-start;
  margin-top: 0.3rem;
  display: flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.5rem 0.75rem;
  font-size: 0.8rem;
  font-weight: 600;
  color: #d49ba7;
  background: rgba(212, 155, 167,0.07);
  border: 1px solid rgba(212, 155, 167,0.2);
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.15s;

  &:hover { background: rgba(212, 155, 167,0.14); }
}

.fin-summary {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
  padding: 0.9rem 1.25rem;
  border-bottom: 1px solid var(--border-color);
}

.fin-card {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  background: var(--bg-tertiary);
  border-radius: 8px;
  padding: 0.65rem 0.75rem;

  .fin-label { font-size: 0.72rem; color: var(--text-muted); }
  .fin-value {
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--text-main);
    &.positive { color: #059669; }
    &.warn { color: #d97706; }
  }
}

.pedido-add-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;

  .pedido-input {
    flex: 1;
    min-width: 90px;
    padding: 0.4rem 0.5rem;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    background: var(--bg-primary);
    color: var(--text-main);
    font-size: 0.8rem;
  }
}

.pedido-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.pedido-item {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.4rem 0.6rem;
  background: var(--bg-tertiary);
  border-radius: 6px;
  font-size: 0.8rem;

  .pedido-date { color: var(--text-muted); }
  .pedido-valor { margin-left: auto; font-weight: 600; color: var(--text-main); }

  .pedido-status {
    font-size: 0.65rem;
    font-weight: 700;
    text-transform: uppercase;
    padding: 0.15rem 0.45rem;
    border-radius: 20px;
    &.status-aberto { background: #dbeafe; color: #1e40af; }
    &.status-baixado { background: #d1fae5; color: #065f46; }
    &.status-cancelado { background: #e5e7eb; color: #4b5563; }
    &.status-perdido { background: #fee2e2; color: #b91c1c; }
  }
}

.lifecycle-timeline {
  display: flex;
  flex-direction: column;
  gap: 0;
  position: relative;
  padding-left: 1.1rem;

  &::before {
    content: '';
    position: absolute;
    left: 4px;
    top: 6px;
    bottom: 6px;
    width: 2px;
    background: var(--border-color);
  }
}

.lifecycle-item {
  display: flex;
  gap: 0.75rem;
  padding: 0.55rem 0;
  position: relative;

  .lifecycle-dot {
    position: absolute;
    left: -1.1rem;
    top: 0.7rem;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: var(--text-muted);
    border: 2px solid var(--bg-secondary);
  }

  &.event-iniciada .lifecycle-dot { background: #22c55e; }
  &.event-churn .lifecycle-dot { background: #ef4444; }
  &.event-reativacao .lifecycle-dot { background: #3b82f6; }
}

.lifecycle-body {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.lifecycle-label { font-size: 0.85rem; font-weight: 700; color: var(--text-main); }
.lifecycle-date { font-size: 0.75rem; color: var(--text-muted); }
.lifecycle-meta { font-size: 0.72rem; color: var(--text-muted); }

.stat-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
  padding: 0.9rem 1.25rem;
}

.stat-card {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  background: var(--bg-tertiary);
  border-radius: 8px;
  padding: 0.7rem 0.75rem;

  .stat-value {
    font-size: 1.3rem;
    font-weight: 700;
    color: var(--primary);
    &.stat-value-sm { font-size: 0.85rem; color: var(--text-main); }
  }
  .stat-label { font-size: 0.72rem; color: var(--text-muted); }
}

.danger-text { color: #ef4444 !important; }

.accordion-card {
  background: transparent;
  border-bottom: 1px solid var(--border-color);

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.25rem;
    cursor: pointer;
    transition: background 0.2s;

    &:hover {
      background: var(--bg-hover);
    }

    h3 {
      font-size: 0.9rem;
      font-weight: 600;
      color: var(--text-main);
    }
    
    .icon-sm {
      color: var(--primary); /* In Chatwoot, these icons are blueish */
      opacity: 0.8;
    }
  }

  .card-body {
    padding: 0 1.25rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;

    .btn-text-blue {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      background: none;
      border: none;
      color: var(--primary);
      font-size: 0.85rem;
      font-weight: 500;
      cursor: pointer;
      padding: 0;

      &:hover {
        text-decoration: underline;
      }
    }

    .empty-text {
      text-align: center;
      color: var(--text-muted);
      font-size: 0.85rem;
      padding: 1rem 0;
    }

    .action-label-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      
      .label {
        font-size: 0.85rem;
        font-weight: 600;
        color: var(--text-main);
      }
    }

    .select-wrapper {
      position: relative;
      
      select {
        width: 100%;
        appearance: none;
        background: var(--bg-primary);
        border: 1px solid var(--border-color);
        border-radius: 6px;
        padding: 0.6rem 2rem 0.6rem 0.75rem;
        color: var(--text-main);
        font-size: 0.9rem;
        outline: none;
        cursor: pointer;
        
        &:focus {
          border-color: var(--primary);
        }
      }

      .select-icon {
        position: absolute;
        right: 0.75rem;
        top: 50%;
        transform: translateY(-50%);
        pointer-events: none;
      }
    }
  }
}

/* File Preview before send */
.file-preview-area {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  background: #f9fafb;
  padding: 12px;
  border-radius: 8px 8px 0 0;
  border-bottom: 1px solid #e5e7eb;
}

.file-preview-content {
  display: flex;
  align-items: center;
  gap: 12px;
}

.preview-img {
  width: 60px;
  height: 60px;
  object-fit: cover;
  border-radius: 6px;
  border: 1px solid #e5e7eb;
}

.file-icon {
  font-size: 2rem;
  width: 60px;
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #e5e7eb;
  border-radius: 6px;
}

.file-name {
  font-size: 0.9rem;
  color: #374151;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 250px;
}

.clear-file-btn {
  background: #f3f4f6;
  border: none;
  font-size: 1.2rem;
  color: #4b5563;
  cursor: pointer;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.clear-file-btn:hover {
  background: #e5e7eb;
  color: #1f2937;
}

.notes-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  max-height: 200px;
  overflow-y: auto;
}
.note-item {
  background: var(--bg-secondary);
  border-radius: 6px;
  padding: 0.5rem;
  border: 1px solid var(--border-color);
}
.note-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.3rem;
  font-size: 0.75rem;
  color: #64748b;
}
.note-author {
  font-weight: 600;
  color: var(--primary);
}
.note-content {
  font-size: 0.85rem;
  color: var(--text-color);
  white-space: pre-wrap;
}
.note-textarea {
  width: 100%;
  padding: 0.5rem;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-color);
  color: var(--text-color);
  font-size: 0.85rem;
  resize: vertical;
}

.attr-row {
  display: flex;
  justify-content: space-between;
  font-size: 0.85rem;
  padding: 0.2rem 0;
  border-bottom: 1px solid var(--border-color);
}
.attr-row:last-child {
  border-bottom: none;
}
.attr-label {
  color: #64748b;
  font-weight: 500;
}
.attr-val {
  color: var(--text-color);
  font-weight: 600;
  text-align: right;
  max-width: 60%;
  word-break: break-word;
}

.assign-select {
  width: 100%;
  padding: 0.55rem 2.1rem 0.55rem 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background-color: var(--bg-secondary);
  color: var(--text-main);
  font-size: 0.88rem;
  font-family: inherit;
  cursor: pointer;
  outline: none;
  appearance: none;
  -webkit-appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='%23ff007f' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.7rem center;
  background-size: 13px;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.assign-select:hover:not(:disabled) {
  border-color: var(--primary);
}
.assign-select:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(212, 155, 167, 0.12);
}
.assign-select:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.assign-select optgroup {
  font-weight: 600;
  font-style: normal;
  color: var(--text-muted);
  background: var(--bg-secondary);
}
.assign-select option {
  font-weight: 400;
  color: var(--text-main);
  background: var(--bg-secondary);
  padding: 6px;
}

.btn-transfer {
  margin-top: 0.5rem;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  padding: 0.45rem 0;
  font-size: 0.8rem;
  font-weight: 600;
  color: #d49ba7;
  background: rgba(212, 155, 167,0.07);
  border: 1px solid rgba(212, 155, 167,0.2);
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.15s;
  &:hover:not(:disabled) { background: rgba(212, 155, 167,0.14); }
  &:disabled { opacity: 0.4; cursor: not-allowed; }
}

.attachments-gallery {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
  max-height: 200px;
  overflow-y: auto;
}
.attachment-thumb {
  display: block;
  width: 100%;
  aspect-ratio: 1;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  overflow: hidden;
  text-decoration: none;
  transition: transform 0.2s;
}
.attachment-thumb:hover {
  transform: scale(1.05);
}
.attachment-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.attachment-doc {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--text-color);
}
.attachment-doc span {
  font-size: 1.5rem;
  margin-bottom: 0.2rem;
}
.attachment-doc small {
  font-size: 0.65rem;
  font-weight: 500;
  text-align: center;
  word-break: break-all;
  padding: 0 0.2rem;
}

.scheduled-list-ui {
  margin-top: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}
.scheduled-item-ui {
  background: var(--bg-color);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.75rem;
  font-size: 0.85rem;
}
.sch-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}
.sch-time {
  font-weight: 600;
  color: var(--primary);
}
.icon-btn-cancel {
  background: transparent;
  border: none;
  color: #ef4444;
  cursor: pointer;
  padding: 2px;
  border-radius: 4px;
}
.icon-btn-cancel:hover {
  background: #fef2f2;
}
.sch-content p {
  margin: 0;
  color: var(--text-color);
  line-height: 1.4;
}
.sch-attachment {
  margin-top: 0.25rem;
  color: #64748b;
  font-size: 0.8rem;
}

/* Botão voltar mobile — oculto em desktop */
.btn-back-mobile {
  display: none;
}

/* ===== RESPONSIVO MOBILE ===== */
@media (max-width: 768px) {
  .conversations-container {
    position: relative;
    overflow: hidden;
    height: 100%;
  }

  /* Lista de conversas: full width no mobile */
  .conv-list-pane {
    width: 100%;
    flex-shrink: 0;
  }

  /* Painel de chat: flex column ocupando toda a tela */
  .chat-pane {
    position: absolute;
    inset: 0;
    z-index: 10;
    background: var(--bg-primary);
    width: 100%;
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Painel de detalhes: vira tela cheia no mobile, controlado pelo mobileView */
  .details-pane {
    position: absolute;
    inset: 0;
    z-index: 11;
    background: var(--bg-primary);
    width: 100%;
    height: 100%;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }

  .chat-header .btn-details-mobile {
    display: flex;
  }

  /* Controla visibilidade pelo mobileView */
  .mobile-hidden {
    display: none !important;
  }

  /* Botão voltar: visível no mobile */
  .btn-back-mobile {
    display: flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    font-size: 1.3rem;
    color: var(--text-main);
    cursor: pointer;
    padding: 0.25rem 0.5rem;
    margin-right: 0.25rem;
    border-radius: 6px;
    &:hover { background: var(--bg-hover); }
  }

  /* Header do chat mais compacto */
  .chat-header {
    padding: 0.6rem 0.75rem;
    flex-shrink: 0;
  }

  /* Mensagens: cresce e rola, min-height:0 permite shrink no flex */
  .chat-messages {
    padding: 0.5rem;
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }

  /* Banner IA pausada: compacto e fixo antes do input */
  .ai-pause-banner {
    flex-shrink: 0;
    padding: 0.4rem 0.75rem;
    font-size: 0.78rem;
    gap: 0.4rem;
  }

  /* Área de input: cola no fundo, nunca sai da tela */
  .chat-input-area {
    flex-shrink: 0;
    padding: 0.5rem 0.6rem;
    padding-bottom: max(0.5rem, env(safe-area-inset-bottom));
  }

  /* Tabs de input mais compactas */
  .input-tabs {
    padding-left: 0;
    gap: 0.35rem;
    margin-bottom: 0.3rem;
    flex-wrap: nowrap;

    .input-tab {
      font-size: 0.78rem;
      padding: 0.35rem 0.6rem;
    }

    /* Botão Gerar Resumo: só ícone no mobile */
    .btn-magic-sm {
      display: flex;
      align-items: center;
      gap: 0.3rem;
      padding: 0.35rem 0.6rem;
      background: var(--primary);
      border: none;
      border-radius: 6px;
      color: white;
      cursor: pointer;
      font-weight: 600;
      font-size: 0.8rem;
      margin-left: auto;
      flex-shrink: 0;

      .btn-magic-label { display: none; }
    }
  }

  /* Textarea menor no mobile */
  .input-box {
    textarea {
      min-height: 52px;
      max-height: 120px;
      padding: 0.6rem 0.75rem;
      font-size: 0.875rem;
    }

    .input-actions {
      padding: 0.35rem 0.6rem;

      .btn-send {
        padding: 0.45rem 0.9rem;
        font-size: 0.82rem;
        white-space: nowrap;
      }

      .left-actions {
        gap: 0.25rem;
      }

      /* Pill IA pausada: compacto no mobile */
      .ai-paused-pill {
        font-size: 0.7rem;
        padding: 0.2rem 0.4rem;
        gap: 0.25rem;
        max-width: 130px;

        span {
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
      }
    }
  }

  /* Tabs de status mais compactas */
  .tabs {
    gap: 0.5rem;
    padding: 0 0.5rem;
  }

  .tab {
    font-size: 0.78rem;
    padding: 0.4rem 0.5rem;
  }

  /* Lista mais compacta */
  .list-header {
    padding: 0.75rem;
  }

  .header-top h2 {
    font-size: 1rem;
  }

  .conv-item {
    padding: 0.75rem;
  }
}
</style>
