<script setup>
import { onMounted, onUnmounted, ref, computed, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import api from '../api'
import Swal from 'sweetalert2'
import { useInboxesStore } from '../store/inboxes'
import { useContactsStore } from '../store/contacts'
import { useAgentsStore } from '../store/agents'
import { usePipelinesStore } from '../store/pipelines'
import { useInternalChatStore } from '../store/internalChat'
import {
  Search,
  Inbox,
  MessageCircle,
  Hash,
  Tag,
  BarChart2,
  Settings,
  ChevronDown,
  Users,
  Home,
  Kanban,
  Briefcase,
  User,
  Palette,
  Power,
  Sun,
  Moon,
  Monitor,
  CornerDownLeft,
  ArrowUp,
  ArrowDown,
  Bell,
  CalendarDays,
  Badge,
  Activity,
  GitBranch,
  TrendingUp,
  BookOpen,
  Menu,
  X,
  ChevronLeft,
  ChevronRight,
  UserX,
  ListChecks,
  Plus,
  MoreVertical,
  GripVertical,
  Users2,
  Package,
  FileText
} from 'lucide-vue-next'

const router = useRouter()
useRoute()
const isSettingsOpen = ref(false)
const showUserMenu = ref(false)
const autoOffline = ref(false)
const isConversasOpen = ref(true)
const isPipelinesOpen = ref(false)
const isPipelinesMenuOpen = ref(false)
const isReorderModalOpen = ref(false)
const reorderList = ref([])
const isMobileSidebarOpen = ref(false)
const isSidebarCollapsed = ref(localStorage.getItem('sidebar_collapsed') === 'true')

const toggleMobileSidebar = () => { isMobileSidebarOpen.value = !isMobileSidebarOpen.value }
const closeMobileSidebar = () => { isMobileSidebarOpen.value = false }

const toggleSidebarCollapsed = () => {
  isSidebarCollapsed.value = !isSidebarCollapsed.value
  localStorage.setItem('sidebar_collapsed', isSidebarCollapsed.value)
}

// Notification Logic
const notifications = ref([])
const unreadCount = ref(0)
const isNotificationsOpen = ref(false)
let notificationInterval = null
let isFirstFetch = true

const fetchNotifications = async () => {
  try {
    const response = await api.get('/notifications')
    const newUnreadCount = response.data.unread_count
    
    // Mostra um toast pop-up se chegou notificação nova
    if (!isFirstFetch && newUnreadCount > unreadCount.value) {
      const latestNotif = response.data.unread[0]
      if (latestNotif) {
        Swal.fire({
          toast: true,
          position: 'top-end',
          icon: 'info',
          title: latestNotif.title,
          text: latestNotif.message,
          showConfirmButton: false,
          timer: 5000,
          timerProgressBar: true
        })
      }
    }
    
    isFirstFetch = false
    notifications.value = [...response.data.unread, ...response.data.read]
    unreadCount.value = newUnreadCount
  } catch (error) {
    console.error('Erro ao buscar notificações', error)
  }
}

const toggleNotifications = () => {
  isNotificationsOpen.value = !isNotificationsOpen.value
  if (isSettingsOpen.value) isSettingsOpen.value = false
}

const markAsRead = async (notification) => {
  if (!notification.read_at) {
    try {
      await api.put(`/notifications/${notification.id}/mark_as_read`)
      unreadCount.value--
      notification.read_at = new Date().toISOString()
    } catch (error) {}
  }
  isNotificationsOpen.value = false
  router.push(notification.link)
}

const markAllAsRead = async () => {
  if (unreadCount.value === 0) return
  try {
    await api.put('/notifications/mark_all_read')
    notifications.value.forEach(n => { n.read_at = new Date().toISOString() })
    unreadCount.value = 0
  } catch (error) {
    console.error('Erro ao marcar todas como lidas', error)
  }
}

const inboxesStore = useInboxesStore()
const contactsStore = useContactsStore()
const agentsStore = useAgentsStore()
const pipelinesStore = usePipelinesStore()
const internalChatStore = useInternalChatStore()

// Dados reais do usuário logado
const currentUser = ref({ first_name: '', last_name: '', email: '', account_name: '' })
const tags = ref([])

const fetchTags = async () => {
  try {
    const response = await api.get('/tags')
    tags.value = response.data
  } catch (error) {
    console.error('Erro ao carregar tags', error)
  }
}

const loadUser = () => {
  try {
    const stored = localStorage.getItem('user')
    if (stored) {
      const parsed = JSON.parse(stored)
      currentUser.value = parsed
    }
  } catch (e) {
    console.error('Erro ao carregar dados do usuário', e)
  }
}

// Carteira inteira (Painel Gerencial) — gerente também entra aqui.
const isFullPortfolio = computed(() => isFullPortfolioRole(currentUser.value))

// Configurações críticas do sistema (briefing seção 30) — gerente NÃO entra
// aqui, só diretoria. Usado pra Agentes/Inboxes/Tags/Conta.
const isCriticalConfig = computed(() => isCriticalConfigRole(currentUser.value))

const isFinanceiro = computed(() => currentUser.value.role === 'financeiro')

// Badge de perfil na sidebar — deixa visível na hora qual nível de RBAC está
// ativo na sessão, evita chamado de suporte por botão/tela "sumida" que na
// verdade é trava de permissão (ex: consultor sem ver Configurações).
const roleLabel = computed(() => ROLE_LABELS[currentUser.value.role] || currentUser.value.role)

const userInitials = () => {
  const fn = currentUser.value.first_name || ''
  const ln = currentUser.value.last_name || ''
  return (fn[0] || '') + (ln[0] || '') || '?'
}

const userDisplayName = () => {
  const fn = currentUser.value.first_name || ''
  const ln = currentUser.value.last_name || ''
  return (fn + ' ' + ln).trim() || currentUser.value.email || 'Usuário'
}

import { brand } from '../config/brand'
import { ROLE_LABELS, isFullPortfolio as isFullPortfolioRole, isCriticalConfig as isCriticalConfigRole } from '../config/roles'
import { usePushNotifications } from '../composables/usePushNotifications'
import { useInstallPrompt } from '../composables/useInstallPrompt'

const { subscribe: subscribePush } = usePushNotifications()
const { canInstall, isInstalled, isStandalone: isAppStandalone, promptInstall } = useInstallPrompt()

const showIosInstallBanner = ref(false)
const androidInstallDismissed = ref(localStorage.getItem('android_install_banner_dismissed') === 'true')

const showAndroidInstallBanner = computed(() =>
  canInstall.value && !isInstalled.value && !isAppStandalone && !androidInstallDismissed.value
)

const dismissAndroidBanner = () => {
  androidInstallDismissed.value = true
  localStorage.setItem('android_install_banner_dismissed', 'true')
}

const checkIosInstallBanner = () => {
  const isIOS = /iPhone|iPad|iPod/.test(navigator.userAgent)
  const isStandalone = navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches
  const dismissed = localStorage.getItem('ios_install_banner_dismissed') === 'true'
  showIosInstallBanner.value = isIOS && !isStandalone && !dismissed
}

const dismissIosBanner = () => {
  showIosInstallBanner.value = false
  localStorage.setItem('ios_install_banner_dismissed', 'true')
}

// Banner de canal desconectado — some sozinho quando reconectar; o "fechar"
// só oculta pra aquela caixa até ela cair de novo (não persiste no reload,
// é um alerta operacional, não é pra ficar escondido pra sempre).
const dismissedInboxIds = ref(new Set())
const disconnectedInboxBanner = computed(() =>
  inboxesStore.disconnectedInboxes.find(i => !dismissedInboxIds.value.has(i.id))
)
const dismissDisconnectedBanner = () => {
  if (disconnectedInboxBanner.value) {
    dismissedInboxIds.value.add(disconnectedInboxBanner.value.id)
  }
}
// Se a caixa reconectar, tira do "dismissed" pra alertar de novo caso caia outra vez
watch(() => inboxesStore.disconnectedInboxes.map(i => i.id), (currentIds) => {
  dismissedInboxIds.value.forEach(id => {
    if (!currentIds.includes(id)) dismissedInboxIds.value.delete(id)
  })
})

const accountName = () => {
  return currentUser.value.account_name || brand.name
}

// Theme Command Palette State
const isThemePaletteOpen = ref(false)
const selectedThemeIndex = ref(0)
const themeSearchQuery = ref('')

const themes = [
  { id: 'light', name: 'Claro', icon: Sun },
  { id: 'dark', name: 'Escuro', icon: Moon },
  { id: 'system', name: 'Sistema', icon: Monitor }
]

const toggleSettings = () => {
  isSettingsOpen.value = !isSettingsOpen.value
}

const toggleConversas = () => {
  isConversasOpen.value = !isConversasOpen.value
}

const toggleUserMenu = () => {
  showUserMenu.value = !showUserMenu.value
}

const openThemePalette = () => {
  showUserMenu.value = false
  isThemePaletteOpen.value = true
  selectedThemeIndex.value = 0
}

// Foto de perfil — cada usuário troca a própria (ProfileController), igual
// no WhatsApp. Salva em avatar_url no localStorage 'user' pra refletir em
// todo lugar que lê currentUser (Chat da Equipe, este cartão, etc).
const isProfileModalOpen = ref(false)
const profileFileInputRef = ref(null)
const isUploadingAvatar = ref(false)

const openProfileModal = () => {
  showUserMenu.value = false
  isProfileModalOpen.value = true
}

const triggerAvatarPicker = () => profileFileInputRef.value?.click()

const persistAvatarUrl = (url) => {
  currentUser.value = { ...currentUser.value, avatar_url: url }
  localStorage.setItem('user', JSON.stringify(currentUser.value))
}

const onAvatarSelected = async (e) => {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  if (file.size > 5 * 1024 * 1024) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Imagem muito grande (máx. 5MB).', showConfirmButton: false, timer: 3500 })
    return
  }
  const formData = new FormData()
  formData.append('avatar', file)
  isUploadingAvatar.value = true
  try {
    const { data } = await api.patch('/profile/avatar', formData, { headers: { 'Content-Type': undefined } })
    persistAvatarUrl(data.avatar_url)
  } catch (err) {
    console.error('Erro ao trocar foto de perfil:', err)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao trocar a foto.', showConfirmButton: false, timer: 3500 })
  } finally {
    isUploadingAvatar.value = false
  }
}

const removeAvatar = async () => {
  isUploadingAvatar.value = true
  try {
    await api.delete('/profile/avatar')
    persistAvatarUrl(null)
  } catch (err) {
    console.error('Erro ao remover foto de perfil:', err)
  } finally {
    isUploadingAvatar.value = false
  }
}

const applyTheme = (themeId) => {
  if (themeId === 'dark') {
    document.body.classList.add('dark-theme')
  } else if (themeId === 'light') {
    document.body.classList.remove('dark-theme')
  } else {
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      document.body.classList.add('dark-theme')
    } else {
      document.body.classList.remove('dark-theme')
    }
  }
  localStorage.setItem('theme', themeId)
  isThemePaletteOpen.value = false
}

const handlePaletteKeydown = (e) => {
  if (!isThemePaletteOpen.value) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault()
      openThemePalette()
    }
    return
  }

  if (e.key === 'Escape') {
    isThemePaletteOpen.value = false
  } else if (e.key === 'ArrowDown') {
    e.preventDefault()
    selectedThemeIndex.value = (selectedThemeIndex.value + 1) % themes.length
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    selectedThemeIndex.value = (selectedThemeIndex.value - 1 + themes.length) % themes.length
  } else if (e.key === 'Enter') {
    e.preventDefault()
    applyTheme(themes[selectedThemeIndex.value].id)
  }
}

const handleVisibilityChange = () => {
  if (document.visibilityState === 'visible') {
    fetchNotifications()
    if (!notificationInterval) {
      notificationInterval = setInterval(fetchNotifications, 10000)
    }
  } else if (document.visibilityState === 'hidden') {
    if (notificationInterval) {
      clearInterval(notificationInterval)
      notificationInterval = null
    }
  }
}

onMounted(() => {
  loadUser()
  checkIosInstallBanner()

  // Push notifications — pede permissão após login (silencioso se negado)
  subscribePush()

  // Navegação disparada pelo toque na push notification (quando app estava fechado)
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', (event) => {
      if (event.data?.type === 'NAVIGATE') {
        router.push(event.data.url)
      }
    })
  }

  // Only fetch stores if not already loaded
  if (!inboxesStore.isLoadedOnce) inboxesStore.fetchInboxes()
  if (!contactsStore.isLoadedOnce) contactsStore.fetchContacts()
  if (!agentsStore.isLoadedOnce) agentsStore.fetchAgents()
  if (!pipelinesStore.isLoadedOnce) pipelinesStore.fetchPipelines()
  inboxesStore.startStatusPolling()

  // Chat interno da equipe: ativo em qualquer tela do sistema (não só na
  // tela do próprio chat), pra badge de não lidas e toast tipo WhatsApp
  // funcionarem mesmo quando o usuário está trabalhando em outra parte do CRM.
  internalChatStore.fetchThreads()
  internalChatStore.setupWebSocket()

  window.addEventListener('keydown', handlePaletteKeydown)
  const savedTheme = localStorage.getItem('theme') || 'system'
  applyTheme(savedTheme)

  fetchNotifications()
  notificationInterval = setInterval(fetchNotifications, 10000)
  document.addEventListener('visibilitychange', handleVisibilityChange)

  fetchTags()
  window.addEventListener('tags-updated', fetchTags)
  window.addEventListener('lead-atribuido', handleLeadAtribuido)
  window.addEventListener('snooze-expired', handleSnoozeExpired)
})

const handleLeadAtribuido = (e) => {
  const { contact_name, conversation_id, assigned_by } = e.detail
  const origem = assigned_by === 'rodizio' ? 'via rodízio automático' : 'pelo gestor'

  // Toast de alerta visual
  Swal.fire({
    toast: true,
    position: 'top-end',
    icon: 'info',
    title: '📋 Novo lead atribuído a você!',
    html: `<strong>${contact_name}</strong><br><small style="color:#6b7280">${origem}</small>`,
    showConfirmButton: true,
    confirmButtonText: 'Ver conversa',
    confirmButtonColor: '#ff007f',
    showCloseButton: true,
    timer: 12000,
    timerProgressBar: true,
    didOpen: () => {
      // Som de notificação
      try {
        const AudioCtx = window.AudioContext || window['webkitAudioContext']
        const ctx = new AudioCtx()
        const osc = ctx.createOscillator()
        const gain = ctx.createGain()
        osc.connect(gain)
        gain.connect(ctx.destination)
        osc.frequency.setValueAtTime(880, ctx.currentTime)
        osc.frequency.setValueAtTime(660, ctx.currentTime + 0.1)
        gain.gain.setValueAtTime(0.3, ctx.currentTime)
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.4)
        osc.start(ctx.currentTime)
        osc.stop(ctx.currentTime + 0.4)
      } catch {}
    }
  }).then((result) => {
    if (result.isConfirmed && conversation_id) {
      router.push(`/conversas`)
    }
  })
}

const handleSnoozeExpired = (e) => {
  const { contact_name } = e.detail
  Swal.fire({
    toast:           true,
    position:        'top-end',
    icon:            'info',
    title:           '⏰ Conversa reativada!',
    html:            `<strong>${contact_name || 'Revendedora'}</strong><br><small style="color:#6b7280">O tempo de adiamento expirou — conversa reaberta.</small>`,
    showConfirmButton: true,
    confirmButtonText: 'Ver conversa',
    confirmButtonColor: '#ff007f',
    showCloseButton: true,
    timer:           12000,
    timerProgressBar: true
  }).then((result) => {
    if (result.isConfirmed) router.push('/conversas')
  })
}

onUnmounted(() => {
  window.removeEventListener('keydown', handlePaletteKeydown)
  if (notificationInterval) clearInterval(notificationInterval)
  document.removeEventListener('visibilitychange', handleVisibilityChange)
  window.removeEventListener('tags-updated', fetchTags)
  window.removeEventListener('lead-atribuido', handleLeadAtribuido)
  window.removeEventListener('snooze-expired', handleSnoozeExpired)
  inboxesStore.stopStatusPolling()
})

const handleLogout = () => {
  localStorage.removeItem('auth_token')
  localStorage.removeItem('user')
  window.location.href = '/login'
}

const createPipeline = async () => {
  isPipelinesMenuOpen.value = false
  const { value: name } = await Swal.fire({
    title: 'Novo pipeline', input: 'text', inputPlaceholder: 'Ex: Atacado, Prospecção...',
    showCancelButton: true, confirmButtonColor: '#ff007f', confirmButtonText: 'Criar', cancelButtonText: 'Cancelar'
  })
  if (!name || !name.trim()) return
  const pipeline = await pipelinesStore.createPipeline(name.trim())
  router.push(`/pipelines/${pipeline.slug}`)
}

const openReorderModal = () => {
  isPipelinesMenuOpen.value = false
  reorderList.value = [...pipelinesStore.pipelines].sort((a, b) => a.position - b.position)
  isReorderModalOpen.value = true
}

const moveReorderItem = (index, direction) => {
  const target = index + direction
  if (target < 0 || target >= reorderList.value.length) return
  const list = reorderList.value
  ;[list[index], list[target]] = [list[target], list[index]]
}

const saveReorder = async () => {
  await pipelinesStore.reorderPipelines(reorderList.value)
  isReorderModalOpen.value = false
}
</script>

<template>
  <div class="chatwoot-layout">
    <!-- Mobile overlay -->
    <div v-if="isMobileSidebarOpen" class="mobile-overlay" @click="closeMobileSidebar"></div>

    <!-- Primary Sidebar -->
    <aside class="sidebar" :class="{ 'mobile-open': isMobileSidebarOpen, 'collapsed': isSidebarCollapsed }">
      <button class="sidebar-collapse-btn" @click="toggleSidebarCollapsed" :title="isSidebarCollapsed ? 'Expandir menu' : 'Recolher menu'">
        <ChevronRight v-if="isSidebarCollapsed" class="icon-xs" />
        <ChevronLeft v-else class="icon-xs" />
      </button>

      <!-- Workspace Header -->
      <div class="workspace-header">
        <div class="workspace-info">
          <div class="workspace-avatar">{{ (accountName()[0] || 'I').toUpperCase() }}</div>
          <span class="workspace-name">{{ accountName() }}</span>
        </div>
        <ChevronDown class="icon-sm" />
      </div>

      <!-- Header Actions -->
      <div class="header-actions">
        <div class="search-bar">
          <Search class="icon-sm" />
          <input type="text" placeholder="Pesquisar contatos..." />
        </div>

        <div class="notifications-wrapper">
          <button class="icon-btn" @click="toggleNotifications">
            <Bell class="icon" />
            <span v-if="unreadCount > 0" class="notification-badge">{{ unreadCount }}</span>
          </button>
          
          <div v-if="isNotificationsOpen" class="notifications-dropdown">
            <div class="notifications-header">
              <h3>Notificações</h3>
              <button class="btn-mark-all" v-if="unreadCount > 0" @click="markAllAsRead">
                Marcar todas como lidas
              </button>
            </div>
            <div class="notifications-list">
              <div v-if="notifications.length === 0" class="no-notifications">
                Nenhuma notificação nova.
              </div>
              <div 
                v-for="notif in notifications" 
                :key="notif.id" 
                class="notification-item"
                :class="{ 'unread': !notif.read_at }"
                @click="markAsRead(notif)"
              >
                <div class="notif-content">
                  <h4>{{ notif.title }}</h4>
                  <p>{{ notif.message }}</p>
                  <span class="notif-time">{{ new Date(notif.created_at).toLocaleString([], {day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit'}) }}</span>
                </div>
                <div v-if="!notif.read_at" class="unread-dot"></div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Navigation -->
      <nav class="nav-menu">
        <router-link to="/dashboard" class="nav-item">
          <Home class="icon" />
          <span>Início</span>
        </router-link>

        <router-link v-if="!isFinanceiro" to="/carteira" class="nav-item">
          <Users class="icon" />
          <span>Minhas Revendedoras</span>
        </router-link>

        <router-link to="/inativas" class="nav-item">
          <UserX class="icon" />
          <span>Inativas</span>
        </router-link>

        <router-link to="/atacado" class="nav-item">
          <Package class="icon" />
          <span>Atacado</span>
        </router-link>

        <router-link v-if="!isFinanceiro" to="/tarefas" class="nav-item">
          <ListChecks class="icon" />
          <span>Tarefas</span>
        </router-link>

        <router-link v-if="isFullPortfolio" to="/gerencial" class="nav-item">
          <BarChart2 class="icon" />
          <span>Gerencial</span>
        </router-link>

        <router-link v-if="isFullPortfolio" to="/relatorios" class="nav-item">
          <TrendingUp class="icon" />
          <span>Relatórios</span>
        </router-link>

        <router-link v-if="isFullPortfolio" to="/settings/times-de-vendas" class="nav-item">
          <Users2 class="icon" />
          <span>Times de Vendas</span>
        </router-link>

        <div class="settings-section">
          <div class="settings-header" @click="toggleConversas">
            <div class="left">
              <MessageCircle class="icon-sm" />
              <span>Comunicações</span>
            </div>
            <ChevronDown class="icon-xs chevron-icon" :class="{ 'rotate': isConversasOpen }" />
          </div>
          <div class="settings-menu" v-show="isConversasOpen">
            <router-link to="/conversas" class="nav-item sub-item" exact-active-class="active"><MessageCircle class="icon-sm" /> Inbox de chat</router-link>
            <router-link
              v-for="inbox in inboxesStore.inboxes"
              :key="inbox.id"
              :to="`/conversas/inbox/${inbox.id}`"
              class="nav-item sub-item inbox-sub-item"
              exact-active-class="active"
            >
              <span
                class="inbox-status-dot"
                :class="{ connected: inbox.connected === true, disconnected: inbox.connected === false }"
              ></span>
              {{ inbox.name }}
            </router-link>
            <router-link to="/chat-equipe" class="nav-item sub-item" exact-active-class="active">
              <Users class="icon-sm" /> Chat da Equipe
              <span v-if="internalChatStore.totalUnread > 0" class="nav-unread-badge">{{ internalChatStore.totalUnread }}</span>
            </router-link>
          </div>
        </div>

        <div class="settings-section">
          <div class="settings-header pipelines-header">
            <div class="left" @click="isPipelinesOpen = !isPipelinesOpen">
              <Kanban class="icon-sm" />
              <span>Pipelines</span>
            </div>
            <div class="pipelines-header-actions">
              <button
                v-if="isFullPortfolio"
                class="icon-btn-inline"
                title="Mais opções"
                @click.stop="isPipelinesMenuOpen = !isPipelinesMenuOpen"
              ><MoreVertical class="icon-xs" /></button>
              <ChevronDown class="icon-xs chevron-icon" :class="{ 'rotate': isPipelinesOpen }" @click="isPipelinesOpen = !isPipelinesOpen" />
            </div>
            <div v-if="isPipelinesMenuOpen" class="pipelines-menu-overlay" @click="isPipelinesMenuOpen = false"></div>
            <div v-if="isPipelinesMenuOpen" class="pipelines-dropdown">
              <button class="pipelines-dropdown-item" @click.stop="createPipeline"><Plus class="icon-xs" /> Adicionar funil de vendas</button>
              <button class="pipelines-dropdown-item" @click.stop="openReorderModal"><GripVertical class="icon-xs" /> Reordenar pipelines</button>
            </div>
          </div>
          <div class="settings-menu" v-show="isPipelinesOpen">
            <router-link to="/funil" class="nav-item sub-item" exact-active-class="active"><Badge class="icon-sm" /> Consignado</router-link>
            <template v-if="isFullPortfolio">
              <router-link
                v-for="p in pipelinesStore.pipelines"
                :key="p.id"
                :to="`/pipelines/${p.slug}`"
                class="nav-item sub-item"
                exact-active-class="active"
              ><Hash class="icon-sm" /> {{ p.name }}</router-link>
              <router-link to="/pipelines/todos-leads" class="nav-item sub-item" exact-active-class="active"><ListChecks class="icon-sm" /> Todos os leads</router-link>
            </template>
          </div>
        </div>

        <div v-if="isReorderModalOpen" class="modal-overlay" @click.self="isReorderModalOpen = false">
          <div class="reorder-modal">
            <div class="reorder-modal-header">
              <h3>Reordenar pipelines</h3>
              <button class="close-btn" @click="isReorderModalOpen = false">&times;</button>
            </div>
            <div class="reorder-modal-body">
              <div v-for="(p, index) in reorderList" :key="p.id" class="reorder-item">
                <GripVertical class="icon-sm reorder-grip" />
                <span class="reorder-name">{{ p.name }}</span>
                <div class="reorder-arrows">
                  <button :disabled="index === 0" @click="moveReorderItem(index, -1)" title="Mover pra cima"><ArrowUp class="icon-xs" /></button>
                  <button :disabled="index === reorderList.length - 1" @click="moveReorderItem(index, 1)" title="Mover pra baixo"><ArrowDown class="icon-xs" /></button>
                </div>
              </div>
            </div>
            <div class="reorder-modal-footer">
              <button class="btn-cancel" @click="isReorderModalOpen = false">Cancelar</button>
              <button class="btn-primary" @click="saveReorder">Salvar ordem</button>
            </div>
          </div>
        </div>

        <router-link to="/calendario" class="nav-item">
          <CalendarDays class="icon" />
          <span>Calendário</span>
        </router-link>

        <router-link to="/manual" class="nav-item">
          <BookOpen class="icon" />
          <span>Manual do Sistema</span>
        </router-link>

        <router-link v-if="isCriticalConfig" to="/fluxos" class="nav-item">
          <GitBranch class="icon" />
          <span>Fluxos</span>
        </router-link>

        <div class="nav-section settings-section" v-if="isCriticalConfig">
          <div class="settings-header" @click="toggleSettings">
            <div class="left">
              <Settings class="icon-sm" />
              <span>Configurações</span>
            </div>
            <ChevronDown class="icon-xs chevron-icon" :class="{ 'rotate': isSettingsOpen }" />
          </div>
          <div class="settings-menu" v-show="isSettingsOpen">
            <router-link to="/settings/account" class="nav-item sub-item" active-class="active"><Briefcase class="icon-sm" /> Conta</router-link>
            <router-link to="/settings/inboxes" class="nav-item sub-item"><Inbox class="icon-sm" /> Caixas de Entrada</router-link>
            <router-link to="/settings/tags" class="nav-item sub-item" active-class="active"><Tag class="icon-sm" /> Etiquetas</router-link>
            <router-link to="/agentes" class="nav-item sub-item" active-class="active"><Badge class="icon-sm" /> Agentes</router-link>
            <router-link to="/atividades" class="nav-item sub-item" active-class="active"><Activity class="icon-sm" /> Atividades</router-link>
          </div>
        </div>

        <button type="button" class="nav-item nav-item-btn" @click="toggleNotifications">
          <Bell class="icon" />
          <span>Central de Notificação</span>
          <span v-if="unreadCount > 0" class="nav-badge">{{ unreadCount > 99 ? '99+' : unreadCount }}</span>
        </button>
      </nav>

      <!-- Bottom Profile -->
      <div class="sidebar-bottom">
        
        <!-- User Popup Menu -->
        <div class="user-popup-menu" v-if="showUserMenu">
          <div class="menu-row">
            <span>Disponibilidade</span>
            <div class="status-selector">
              <div class="status-dot online"></div>
              <span>Online</span>
              <ChevronDown class="icon-xs" />
            </div>
          </div>
          
          <div class="menu-row">
            <span>Marcar offline automaticamente</span>
            <label class="toggle-switch">
              <input type="checkbox" v-model="autoOffline" />
              <span class="slider"></span>
            </label>
          </div>
          
          <div class="menu-divider"></div>
          
          <a href="#" class="menu-item" @click.prevent="openProfileModal"><User class="icon-sm" /> Configurações do Perfil</a>
          <a href="#" class="menu-item" @click.prevent="openThemePalette"><Palette class="icon-sm" /> Alterar Tema</a>
          <a href="#" class="menu-item logout" @click="handleLogout"><Power class="icon-sm" /> Encerrar sessão</a>
        </div>

        <div class="user-profile" @click="toggleUserMenu" :class="{ 'active': showUserMenu }">
          <div class="avatar-wrapper">
            <img v-if="currentUser.avatar_url" :src="currentUser.avatar_url" class="avatar avatar-photo" />
            <div v-else class="avatar">{{ userInitials() }}</div>
            <div class="status-indicator online"></div>
          </div>
          <div class="user-info">
            <span class="name">{{ userDisplayName() }}</span>
            <span class="email">{{ currentUser.email }}</span>
            <span class="role-badge" :class="'role-' + currentUser.role">{{ roleLabel }}</span>
          </div>
        </div>
      </div>
    </aside>

    <!-- Main Content Area -->
    <main class="main-content">
      <div class="mobile-topbar">
        <button class="mobile-menu-btn" @click="toggleMobileSidebar">
          <X v-if="isMobileSidebarOpen" class="icon" />
          <Menu v-else class="icon" />
        </button>
        <span class="mobile-brand">{{ accountName() }}</span>
      </div>
      <div v-if="showIosInstallBanner" class="ios-install-banner">
        <span>Adicione o {{ brand.name }} à Tela de Início pra receber notificações e usar em tela cheia.</span>
        <button class="ios-install-banner-close" @click="dismissIosBanner">
          <X class="icon-sm" />
        </button>
      </div>

      <div v-if="showAndroidInstallBanner" class="ios-install-banner">
        <span>Instale o {{ brand.name }} no seu celular pra acesso rápido e notificações.</span>
        <button class="install-cta-btn" @click="promptInstall">Instalar</button>
        <button class="ios-install-banner-close" @click="dismissAndroidBanner">
          <X class="icon-sm" />
        </button>
      </div>

      <div v-if="disconnectedInboxBanner" class="disconnected-banner">
        <span>⚠️ O WhatsApp "{{ disconnectedInboxBanner.name }}" está desconectado. As mensagens não estão sendo enviadas nem recebidas.</span>
        <router-link to="/settings/inboxes" class="install-cta-btn">Reconectar</router-link>
        <button class="ios-install-banner-close" @click="dismissDisconnectedBanner">
          <X class="icon-sm" />
        </button>
      </div>
      <router-view @click="closeMobileSidebar"></router-view>
    </main>

    <!-- Theme Command Palette -->
    <div class="palette-overlay" v-if="isThemePaletteOpen" @click.self="isThemePaletteOpen = false">
      <div class="palette-modal">
        <div class="palette-header">
          <input type="text" v-model="themeSearchQuery" placeholder="Pesquisar ou pular para" autofocus>
        </div>
        <div class="palette-body">
          <div class="palette-group">Tema</div>
          <div 
            class="palette-item" 
            v-for="(theme, index) in themes" 
            :key="theme.id"
            :class="{ 'active': index === selectedThemeIndex }"
            @click="applyTheme(theme.id)"
            @mouseover="selectedThemeIndex = index"
          >
            <component :is="theme.icon" class="icon-sm" />
            <span>{{ theme.name }}</span>
          </div>
        </div>
        <div class="palette-footer">
          <div class="shortcut-group">
            <kbd><CornerDownLeft class="icon-xs" /></kbd>
            <span>to select</span>
          </div>
          <div class="shortcut-group">
            <kbd><ArrowDown class="icon-xs" /></kbd>
            <kbd><ArrowUp class="icon-xs" /></kbd>
            <span>to navigate</span>
          </div>
          <div class="shortcut-group">
            <kbd>esc</kbd>
            <span>to close</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de perfil: cada usuário troca a própria foto, igual no WhatsApp -->
    <div class="profile-overlay" v-if="isProfileModalOpen" @click.self="isProfileModalOpen = false">
      <div class="profile-modal">
        <div class="profile-modal-header">
          <h3>Configurações do Perfil</h3>
          <button class="profile-modal-close" @click="isProfileModalOpen = false"><X class="icon-sm" /></button>
        </div>
        <div class="profile-modal-body">
          <div class="profile-avatar-block">
            <div class="profile-avatar-preview">
              <img v-if="currentUser.avatar_url" :src="currentUser.avatar_url" />
              <div v-else class="profile-avatar-fallback">{{ userInitials() }}</div>
            </div>
            <input type="file" ref="profileFileInputRef" accept="image/*" class="hidden-file-input" @change="onAvatarSelected" />
            <div class="profile-avatar-actions">
              <button class="btn-change-photo" :disabled="isUploadingAvatar" @click="triggerAvatarPicker">
                {{ isUploadingAvatar ? 'Enviando...' : 'Alterar foto' }}
              </button>
              <button v-if="currentUser.avatar_url" class="btn-remove-photo" :disabled="isUploadingAvatar" @click="removeAvatar">
                Remover
              </button>
            </div>
          </div>
          <div class="profile-info-block">
            <div class="profile-info-row">
              <span class="label">Nome</span>
              <span class="value">{{ userDisplayName() }}</span>
            </div>
            <div class="profile-info-row">
              <span class="label">E-mail</span>
              <span class="value">{{ currentUser.email }}</span>
            </div>
            <div class="profile-info-row">
              <span class="label">Perfil</span>
              <span class="value">{{ roleLabel }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.chatwoot-layout {
  display: flex;
  height: 100vh;
  width: 100%;
  overflow: hidden;
  background-color: var(--bg-primary);
}

.sidebar {
  width: 256px;
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  position: relative;
  transition: width 0.18s ease;

  /* Sobrescreve as variáveis de tema só dentro do menu lateral — o resto do app continua claro */
  --bg-secondary: #2b0016;
  --bg-tertiary: rgba(255, 255, 255, 0.08);
  --bg-hover: rgba(255, 255, 255, 0.08);
  --text-main: #ffffff;
  --text-muted: rgba(255, 255, 255, 0.65);
  --border-color: rgba(255, 255, 255, 0.12);
  --input-focus: rgba(255, 255, 255, 0.14);

  background-color: var(--bg-secondary);
  border-right: 1px solid var(--border-color);

  &.collapsed {
    width: 72px;

    .workspace-name,
    .search-bar input,
    .nav-item span:not(.notification-badge),
    .section-title,
    .settings-header .left span,
    .settings-header .chevron-icon,
    .user-info {
      display: none;
    }

    .workspace-header { justify-content: center; }
    .workspace-header > svg { display: none; }
    .header-actions { padding: 0 0.5rem 1rem; flex-direction: column; }
    .search-bar { justify-content: center; padding: 0.4rem; }
    .nav-item { justify-content: center; }
    .settings-header { justify-content: center; }

    /* Submenus viram flyout ao lado em vez de empurrar o conteúdo */
    .settings-menu {
      position: absolute;
      left: calc(100% + 6px);
      top: 0;
      width: 210px;
      margin-left: 0;
      padding: 0.5rem;
      border-radius: 10px;
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      box-shadow: 0 8px 24px rgba(0,0,0,0.35);
      z-index: 60;

      .sub-item { display: flex; }
    }

    .nav-section { padding: 0 0.25rem; }
  }
}

.sidebar-collapse-btn {
  position: absolute;
  top: 22px;
  right: -11px;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: var(--primary);
  color: white;
  border: 2px solid var(--bg-primary, #fff);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  z-index: 70;
  padding: 0;
  box-shadow: 0 2px 6px rgba(0,0,0,0.25);

  &:hover { opacity: 0.9; }
}

.workspace-header {
  padding: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  cursor: pointer;
  
  &:hover {
    background-color: var(--bg-hover);
  }

  .workspace-info {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .workspace-avatar {
    width: 24px;
    height: 24px;
    background: var(--primary);
    color: var(--text-inverse);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.7rem;
    font-weight: bold;
  }

  .workspace-name {
    font-weight: 600;
    font-size: 0.95rem;
    color: var(--text-main);
  }
}

.header-actions {
  padding: 0 1rem 1rem 1rem;
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.search-bar {
  flex: 1;
  display: flex;
  align-items: center;
  background: var(--bg-tertiary);
  padding: 0.4rem 0.6rem;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  input {
    background: transparent;
    border: none;
    margin-left: 0.5rem;
    outline: none;
    font-size: 0.8rem;
    width: 100%;
    color: var(--text-main);
  }
}

.icon-btn {
  background: transparent;
  border: 1px solid var(--border-color);
  padding: 0.4rem;
  border-radius: 6px;
  cursor: pointer;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  &:hover { background: var(--bg-hover); }
  .icon { width: 16px; height: 16px; color: var(--text-muted); }
}

.notification-badge {
  position: absolute;
  top: -4px;
  right: -4px;
  background: #ef4444;
  color: white;
  font-size: 0.6rem;
  font-weight: bold;
  height: 14px;
  width: 14px;
  border-radius: 7px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.notifications-wrapper {
  position: relative;
}

.notifications-dropdown {
  position: absolute;
  top: calc(100% + 0.5rem);
  left: 0;
  width: 280px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  box-shadow: 0 10px 15px rgba(0,0,0,0.1);
  z-index: 100;
  overflow: hidden;
}

.notifications-header {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  justify-content: space-between;
  align-items: center;
  h3 { font-size: 0.85rem; margin: 0; color: var(--text-main); font-weight: 600; }
}

.btn-mark-all {
  background: transparent;
  border: none;
  color: #ff007f;
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  padding: 0;
  &:hover { text-decoration: underline; color: #cc0066; }
}

.notifications-list { max-height: 250px; overflow-y: auto; }

.no-notifications {
  padding: 1.5rem 1rem;
  text-align: center;
  color: var(--text-muted);
  font-size: 0.8rem;
}

.notification-item {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--border-color);
  cursor: pointer;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  transition: background 0.2s;
  &:hover { background: var(--bg-hover); }
  &.unread { background: var(--input-focus); }
}

.notif-content {
  h4 { margin: 0; font-size: 0.85rem; }
  p { margin: 0.2rem 0; font-size: 0.75rem; color: var(--text-muted); }
  .notif-time { font-size: 0.65rem; }
}

.unread-dot {
  width: 6px; height: 6px; background: #ff007f; border-radius: 50%;
}

.icon-sm { width: 16px; height: 16px; color: rgba(255,255,255,0.7); }
.icon-xs { width: 14px; height: 14px; color: rgba(255,255,255,0.7); }

.nav-menu {
  flex: 1;
  overflow-y: auto;
  padding: 0 0.5rem;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0.75rem;
  border-radius: 6px;
  color: var(--text-main);
  font-size: 0.9rem;
  font-weight: 500;
  margin-bottom: 2px;
  text-decoration: none;
  transition: background-color 0.1s;

  .icon { width: 18px; height: 18px; color: var(--text-muted); }
  .icon-img { width: 18px; height: 18px; }

  &:hover { background-color: var(--bg-hover); }

  &.router-link-active {
    background-color: var(--input-focus);
    color: var(--primary);
    .icon { color: var(--primary); }
  }
}

.nav-item-btn {
  width: 100%;
  background: none;
  border: none;
  font-family: inherit;
  cursor: pointer;
  position: relative;
}

.nav-badge {
  margin-left: auto;
  background: var(--primary);
  color: white;
  font-size: 0.68rem;
  font-weight: 700;
  padding: 1px 6px;
  border-radius: 10px;
  line-height: 1.4;
}

.sidebar.collapsed .nav-badge {
  position: absolute;
  top: 4px;
  right: 4px;
  margin-left: 0;
}

.nav-section {
  margin-top: 1.5rem;

  .section-title {
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: rgba(255, 255, 255, 0.5);
    font-weight: 600;
    padding: 0 0.75rem;
    margin-bottom: 0.5rem;
  }

  .sub-item {
    font-weight: 400;
    font-size: 0.85rem;
  }

  .nav-unread-badge {
    margin-left: auto;
    background: #ef4444;
    color: white;
    font-size: 0.68rem;
    font-weight: 700;
    border-radius: 10px;
    padding: 0.1rem 0.4rem;
    min-width: 18px;
    text-align: center;
  }

  .tag-color {
    width: 10px;
    height: 10px;
    border-radius: 3px;
    display: inline-block;
  }
}

.settings-section {
  .settings-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.5rem 0.75rem;
    color: var(--text-main);
    font-size: 0.9rem;
    font-weight: 500;
    cursor: pointer;
    
    .left { display: flex; align-items: center; gap: 0.5rem; }

    .chevron-icon {
      transition: transform 0.2s ease;
      &.rotate { transform: rotate(180deg); }
    }
  }

  .settings-menu {
    margin-top: 0.25rem;
    padding-left: 0.5rem;
    border-left: 1px solid var(--border-color);
    margin-left: 1rem;
    display: flex;
    flex-direction: column;
    gap: 2px;
    
    .sub-item {
      padding: 0.4rem 0.75rem;
      font-size: 0.85rem;
      color: var(--text-main);
      opacity: 0.8;

      &.active {
        background-color: var(--bg-hover);
        color: var(--text-main);
        opacity: 1;
        font-weight: 500;
      }
    }

    .inbox-sub-item {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .inbox-status-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      flex-shrink: 0;
      background: #9ca3af;

      &.connected { background: #10b981; }
      &.disconnected { background: #ef4444; }
    }
  }

  .pipelines-header {
    position: relative;

    .left { cursor: pointer; }

    .pipelines-header-actions {
      display: flex;
      align-items: center;
      gap: 0.15rem;
    }

    .icon-btn-inline {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 22px;
      height: 22px;
      border-radius: 5px;
      background: none;
      border: none;
      padding: 0;
      color: var(--text-muted);
      cursor: pointer;
      transition: background 0.15s, color 0.15s;

      &:hover { background: var(--bg-hover); color: var(--text-main); }
    }

    .pipelines-menu-overlay {
      position: fixed;
      inset: 0;
      z-index: 40;
    }

    .pipelines-dropdown {
      position: absolute;
      top: calc(100% + 2px);
      right: 0.5rem;
      min-width: 220px;
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      box-shadow: 0 10px 15px -3px var(--shadow-color), 0 4px 6px -2px var(--shadow-sm);
      padding: 0.35rem;
      z-index: 41;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }

    .pipelines-dropdown-item {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.5rem 0.6rem;
      font-size: 0.85rem;
      color: var(--text-main);
      background: none;
      border: none;
      border-radius: 6px;
      cursor: pointer;
      text-align: left;
      width: 100%;

      &:hover { background: var(--bg-hover); }
    }
  }
}

.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 200;
}

.reorder-modal {
  width: 380px;
  max-width: 90vw;
  max-height: 80vh;
  background: var(--bg-secondary);
  border-radius: 10px;
  box-shadow: 0 10px 15px -3px var(--shadow-color), 0 4px 6px -2px var(--shadow-sm);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.reorder-modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-color);

  h3 { margin: 0; font-size: 1rem; color: var(--text-main); }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.3rem;
    line-height: 1;
    color: var(--text-muted);
    cursor: pointer;
  }
}

.reorder-modal-body {
  padding: 0.75rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.reorder-item {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.5rem 0.6rem;
  border-radius: 8px;
  background: var(--bg-tertiary);

  .reorder-grip { color: var(--text-muted); flex-shrink: 0; }

  .reorder-name {
    flex: 1;
    font-size: 0.9rem;
    color: var(--text-main);
  }

  .reorder-arrows {
    display: flex;
    gap: 2px;

    button {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 26px;
      height: 26px;
      border-radius: 5px;
      border: 1px solid var(--border-color);
      background: var(--bg-secondary);
      color: var(--text-main);
      cursor: pointer;

      &:hover:not(:disabled) { background: var(--bg-hover); }
      &:disabled { opacity: 0.35; cursor: not-allowed; }
    }
  }
}

.reorder-modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.6rem;
  padding: 0.9rem 1.25rem;
  border-top: 1px solid var(--border-color);

  .btn-cancel {
    background: transparent;
    border: 1px solid var(--border-color);
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    color: var(--text-main);
    font-weight: 500;
    font-size: 0.85rem;

    &:hover { background: var(--bg-hover); }
  }

  .btn-primary {
    background: var(--primary, #ff007f);
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 500;
    font-size: 0.85rem;

    &:hover { background: var(--primary-hover, #cc0066); }
  }
}

.sidebar-bottom {
  margin-top: auto;
  position: relative;
}

.user-popup-menu {
  position: absolute;
  bottom: calc(100% + 0.5rem);
  left: 0.5rem;
  right: 0.5rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  box-shadow: 0 10px 15px -3px var(--shadow-color), 0 4px 6px -2px var(--shadow-sm);
  padding: 0.5rem 0;
  z-index: 50;
}

.menu-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  font-size: 0.85rem;
  color: var(--text-main);

  .status-selector {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background: var(--bg-tertiary);
    padding: 0.25rem 0.5rem;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 500;

    .status-dot {
      width: 8px; height: 8px; border-radius: 50%;
      &.online { background: #10b981; }
    }
  }
}

.toggle-switch {
  position: relative;
  display: inline-block;
  width: 36px; height: 20px;

  input {
    opacity: 0; width: 0; height: 0;
    &:checked + .slider { background-color: #ff007f; }
    &:checked + .slider:before { transform: translateX(16px); }
  }

  .slider {
    position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0;
    background-color: #ccc; transition: .4s; border-radius: 34px;
    &:before {
      position: absolute; content: ""; height: 16px; width: 16px; left: 2px; bottom: 2px;
      background-color: white; transition: .4s; border-radius: 50%;
    }
  }
}

.menu-divider { height: 1px; background: var(--border-color); margin: 0.5rem 0; }

.menu-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 1rem;
  color: var(--text-main);
  text-decoration: none;
  font-size: 0.85rem;
  transition: background 0.2s;

  &:hover {
    background: var(--bg-hover);
  }

  .icon-sm {
    color: var(--text-main);
    opacity: 0.8;
  }

  &.logout {
    margin-top: 0.5rem;
    color: #ef4444;
  }
}

.user-profile {
  display: flex;
  align-items: center;
  padding: 1rem;
  border-top: 1px solid var(--border-color);
  cursor: pointer;
  transition: background 0.2s;
  gap: 0.75rem;

  &:hover, &.active {
    background: var(--bg-hover);
  }

  .avatar-wrapper {
    position: relative;
  }

  .avatar {
    width: 32px;
    height: 32px;
    background: var(--input-focus);
    color: var(--primary);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.9rem;
    font-weight: 500;
  }

  .avatar-photo {
    object-fit: cover;
  }

  .status-indicator {
    position: absolute;
    bottom: 0;
    right: 0;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    border: 2px solid var(--bg-secondary);
    &.online { background: #10b981; }
  }

  .user-info {
    display: flex;
    flex-direction: column;
    overflow: hidden;

    .name {
      font-size: 0.85rem;
      font-weight: 500;
      color: var(--text-main);
    }

    .email {
      font-size: 0.75rem;
      color: var(--text-muted);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .role-badge {
      align-self: flex-start;
      margin-top: 0.25rem;
      font-size: 0.65rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.03em;
      padding: 0.1rem 0.45rem;
      border-radius: 20px;
      background: var(--bg-tertiary);
      color: var(--text-muted);

      &.role-gerente, &.role-diretoria { background: rgba(255, 0, 127, 0.15); color: var(--primary-hover); }
      &.role-financeiro { background: #dcfce7; color: #166534; }
    }
  }
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  overflow-x: hidden;
  min-width: 0;
  height: 100%;

  // O CSS scoped do Vue aplica regra do pai no elemento-raiz do filho — isso
  // alcança a página que o <router-view> renderiza. Sem min-width:0 aqui,
  // uma página com tabela larga (ex: Minhas Revendedoras) crescia mais que
  // o .main-content em vez de deixar a rolagem própria da tabela agir, e o
  // overflow-x:hidden acima cortava o resto (reclamação real: "a tabela
  // corta com zoom 100%, só aparece tudo reduzindo o zoom").
  > * {
    min-width: 0;
  }
}

.mobile-topbar {
  display: none;
}

.mobile-overlay {
  display: none;
}

.ios-install-banner {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.6rem 1rem;
  background: var(--input-focus);
  border-bottom: 1px solid var(--border-color);
  color: var(--text-main);
  font-size: 0.82rem;
  line-height: 1.35;

  span { flex: 1; }

  .install-cta-btn {
    flex-shrink: 0;
    background: var(--primary);
    color: white;
    border: none;
    border-radius: 6px;
    padding: 0.35rem 0.8rem;
    font-size: 0.78rem;
    font-weight: 600;
    cursor: pointer;
    &:hover { opacity: 0.9; }
  }

  .ios-install-banner-close {
    flex-shrink: 0;
    background: transparent;
    border: none;
    color: var(--text-muted);
    cursor: pointer;
    display: flex;
    padding: 0.2rem;
    &:hover { color: var(--text-main); }
  }
}

.disconnected-banner {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.6rem 1rem;
  background: #fee2e2;
  border-bottom: 1px solid #fca5a5;
  color: #991b1b;
  font-size: 0.82rem;
  line-height: 1.35;

  span { flex: 1; }

  .install-cta-btn {
    flex-shrink: 0;
    background: #dc2626;
    color: white;
    border: none;
    border-radius: 6px;
    padding: 0.35rem 0.8rem;
    font-size: 0.78rem;
    font-weight: 600;
    cursor: pointer;
    text-decoration: none;
    &:hover { opacity: 0.9; }
  }

  .ios-install-banner-close {
    flex-shrink: 0;
    background: transparent;
    border: none;
    color: #991b1b;
    cursor: pointer;
    display: flex;
    padding: 0.2rem;
    &:hover { color: #7f1d1d; }
  }
}

@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    left: -260px;
    top: 0;
    bottom: 0;
    z-index: 300;
    transition: left 0.25s ease;
    width: 260px;

    &.mobile-open {
      left: 0;
    }
  }

  .mobile-overlay {
    display: block;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 299;
  }

  .mobile-topbar {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 1rem;
    background: var(--bg-secondary);
    border-bottom: 1px solid var(--border-color);
    flex-shrink: 0;
    position: sticky;
    top: 0;
    z-index: 10;

    .mobile-menu-btn {
      background: transparent;
      border: none;
      cursor: pointer;
      padding: 0.25rem;
      display: flex;
      align-items: center;
      color: var(--text-main);
      .icon { width: 22px; height: 22px; }
    }

    .mobile-brand {
      font-weight: 600;
      font-size: 0.95rem;
      color: var(--text-main);
    }
  }
}

.content-area {
  flex: 1;
  background: var(--bg-primary);
  position: relative;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  overflow-x: hidden;
}

.palette-overlay {
  position: fixed;
  inset: 0;
  background-color: rgba(0, 0, 0, 0.4);
  z-index: 9999;
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding-top: 10vh;
}

.palette-modal {
  width: 100%;
  max-width: 600px;
  background: var(--bg-secondary);
  border-radius: 8px;
  box-shadow: 0 20px 25px -5px var(--shadow-color), 0 10px 10px -5px var(--shadow-sm);
  overflow: hidden;
  display: flex;
  flex-direction: column;

  .palette-header {
    padding: 1rem;
    border-bottom: 1px solid var(--border-color);

    input {
      width: 100%;
      background: transparent;
      border: none;
      outline: none;
      font-size: 1.1rem;
      color: var(--text-main);
      &::placeholder {
        color: var(--text-muted);
      }
    }
  }

  .palette-body {
    padding: 0.5rem 0;

    .palette-group {
      padding: 0.5rem 1rem;
      font-size: 0.75rem;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .palette-item {
      display: flex;
      align-items: center;
      gap: 1rem;
      padding: 0.75rem 1rem;
      cursor: pointer;
      color: var(--text-main);
      font-size: 0.9rem;

      &.active {
        background: var(--primary);
        color: var(--text-inverse);
        
        .icon-sm {
          color: var(--text-inverse);
        }
      }

      .icon-sm {
        color: var(--text-muted);
      }
    }
  }

  .palette-footer {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.75rem 1rem;
    border-top: 1px solid var(--border-color);
    background: var(--bg-tertiary);
    font-size: 0.75rem;
    color: var(--text-muted);

    .shortcut-group {
      display: flex;
      align-items: center;
      gap: 0.5rem;

      kbd {
        background: var(--bg-secondary);
        border: 1px solid var(--border-color);
        padding: 0.1rem 0.4rem;
        border-radius: 4px;
        box-shadow: 0 1px 0 var(--border-color);
        font-family: inherit;
        display: flex;
        align-items: center;
      }
    }
  }
}

.profile-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.profile-modal {
  width: 90%;
  max-width: 380px;
  background: var(--bg-secondary);
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
  overflow: hidden;
}

.profile-modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.1rem 1.4rem;
  border-bottom: 1px solid var(--border-color);

  h3 { margin: 0; font-size: 1rem; color: var(--text-main); }
}

.profile-modal-close {
  background: transparent;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  display: flex;
  padding: 0.25rem;
  border-radius: 4px;

  &:hover { background: var(--bg-tertiary); }
}

.profile-modal-body {
  padding: 1.5rem;
}

.profile-avatar-block {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.85rem;
  margin-bottom: 1.5rem;
  padding-bottom: 1.5rem;
  border-bottom: 1px solid var(--border-color);
}

.profile-avatar-preview {
  width: 88px;
  height: 88px;
  border-radius: 50%;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);

  img { width: 100%; height: 100%; object-fit: cover; }
}

.profile-avatar-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--input-focus);
  color: var(--primary);
  font-size: 1.7rem;
  font-weight: 600;
}

.hidden-file-input { display: none; }

.profile-avatar-actions {
  display: flex;
  gap: 0.6rem;
}

.btn-change-photo {
  background: var(--primary);
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;

  &:hover:not(:disabled) { opacity: 0.9; }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
}

.btn-remove-photo {
  background: transparent;
  color: #ef4444;
  border: 1px solid #ef4444;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;

  &:hover:not(:disabled) { background: rgba(239, 68, 68, 0.08); }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
}

.profile-info-block {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}

.profile-info-row {
  display: flex;
  justify-content: space-between;
  font-size: 0.85rem;

  .label { color: var(--text-muted); }
  .value { color: var(--text-main); font-weight: 500; }
}
</style>
