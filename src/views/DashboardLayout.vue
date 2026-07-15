<script setup>
import { onMounted, onUnmounted, ref, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import api from '../api'
import Swal from 'sweetalert2'
import { useInboxesStore } from '../store/inboxes'
import { useContactsStore } from '../store/contacts'
import { usePropertiesStore } from '../store/properties'
import { useCondominiumsStore } from '../store/condominiums'
import { useAppointmentsStore } from '../store/appointments'
import { useAgentsStore } from '../store/agents'
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
  Building,
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
  HelpCircle,
  CalendarDays,
  Badge,
  TrendingUp,
  CreditCard,
  BookOpen,
  Menu,
  X
} from 'lucide-vue-next'

const router = useRouter()
useRoute()
const isSettingsOpen = ref(false)
const showUserMenu = ref(false)
const autoOffline = ref(false)
const isConversasOpen = ref(true)
const isMobileSidebarOpen = ref(false)

const toggleMobileSidebar = () => { isMobileSidebarOpen.value = !isMobileSidebarOpen.value }
const closeMobileSidebar = () => { isMobileSidebarOpen.value = false }

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
const propertiesStore = usePropertiesStore()
const condominiumsStore = useCondominiumsStore()
const appointmentsStore = useAppointmentsStore()
const agentsStore = useAgentsStore()

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

const isAdminOrEmpresa = computed(() => {
  return ['admin', 'empresa'].includes(currentUser.value.role) || !!currentUser.value.permissions?.admin
})

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
  if (!propertiesStore.isLoadedOnce) propertiesStore.fetchProperties()
  if (!condominiumsStore.isLoadedOnce) condominiumsStore.fetchCondominiums()
  if (!appointmentsStore.isLoadedOnce) appointmentsStore.fetchAppointments()
  if (!agentsStore.isLoadedOnce) agentsStore.fetchAgents()

  window.addEventListener('keydown', handlePaletteKeydown)
  const savedTheme = localStorage.getItem('theme') || 'system'
  applyTheme(savedTheme)

  fetchNotifications()
  notificationInterval = setInterval(fetchNotifications, 10000)
  document.addEventListener('visibilitychange', handleVisibilityChange)

  fetchTags()
  window.addEventListener('tags-updated', fetchTags)
  window.addEventListener('lead-atribuido', handleLeadAtribuido)
  window.addEventListener('property-match-found', handlePropertyMatchFound)
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
    confirmButtonColor: '#4338ca',
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

const handlePropertyMatchFound = (e) => {
  const { property_title, match_count } = e.detail
  Swal.fire({
    toast: true,
    position: 'top-end',
    icon: 'success',
    title: '🏠 Match de Leads Encontrado!',
    html: `<strong>${property_title}</strong><br><small style="color:#6b7280">${match_count} lead(s) compatível(is) foram notificados no WhatsApp</small>`,
    showConfirmButton: true,
    confirmButtonText: 'Ver Imóveis',
    confirmButtonColor: '#10b981',
    showCloseButton: true,
    timer: 15000,
    timerProgressBar: true
  }).then((result) => {
    if (result.isConfirmed) router.push('/imoveis')
  })
}

const handleSnoozeExpired = (e) => {
  const { contact_name } = e.detail
  Swal.fire({
    toast:           true,
    position:        'top-end',
    icon:            'info',
    title:           '⏰ Conversa reativada!',
    html:            `<strong>${contact_name || 'Lead'}</strong><br><small style="color:#6b7280">O tempo de adiamento expirou — conversa reaberta.</small>`,
    showConfirmButton: true,
    confirmButtonText: 'Ver conversa',
    confirmButtonColor: '#4338ca',
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
  window.removeEventListener('property-match-found', handlePropertyMatchFound)
  window.removeEventListener('snooze-expired', handleSnoozeExpired)
})

const handleLogout = () => {
  localStorage.removeItem('auth_token')
  localStorage.removeItem('user')
  window.location.href = '/login'
}
</script>

<template>
  <div class="chatwoot-layout">
    <!-- Mobile overlay -->
    <div v-if="isMobileSidebarOpen" class="mobile-overlay" @click="closeMobileSidebar"></div>

    <!-- Primary Sidebar -->
    <aside class="sidebar" :class="{ 'mobile-open': isMobileSidebarOpen }">
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
          <BarChart2 class="icon" />
          <span>Dashboard</span>
        </router-link>

        <div class="settings-section">
          <div class="settings-header" @click="toggleConversas">
            <div class="left">
              <MessageCircle class="icon-sm" />
              <span>Conversas</span>
            </div>
            <ChevronDown class="icon-xs chevron-icon" :class="{ 'rotate': isConversasOpen }" />
          </div>
          <div class="settings-menu" v-show="isConversasOpen">
            <router-link to="/conversas" class="nav-item sub-item" exact-active-class="active">Todas as conversas</router-link>
            <router-link to="/conversas/mencoes" class="nav-item sub-item" exact-active-class="active">Menções</router-link>
            <router-link to="/conversas/participantes" class="nav-item sub-item" exact-active-class="active">Participantes</router-link>
            <router-link to="/conversas/nao-atendidas" class="nav-item sub-item" exact-active-class="active">Não atendidas</router-link>
          </div>
        </div>

        <router-link to="/contatos" class="nav-item">
          <Users class="icon" />
          <span>Contatos</span>
        </router-link>

        <router-link to="/imoveis" class="nav-item">
          <Home class="icon" />
          <span>Imóveis</span>
        </router-link>

        <router-link to="/condominios" class="nav-item">
          <Building class="icon" />
          <span>Condomínios</span>
        </router-link>

        <router-link to="/agendamentos" class="nav-item" active-class="active">
          <CalendarDays class="icon" />
          <span>Agendamentos</span>
        </router-link>

        <router-link v-if="isAdminOrEmpresa" to="/agentes" class="nav-item" active-class="active">
          <Badge class="icon" />
          <span>Agentes</span>
        </router-link>

        <router-link to="/funil" class="nav-item">
          <Kanban class="icon" />
          <span>Funil de Vendas</span>
        </router-link>

        <router-link to="/relatorios" class="nav-item" active-class="active">
          <TrendingUp class="icon" />
          <span>Relatórios</span>
        </router-link>

        <router-link to="/manual" class="nav-item" active-class="active">
          <BookOpen class="icon" />
          <span>Manual do Sistema</span>
        </router-link>

        <div class="nav-section">
          <h3 class="section-title">Canais</h3>
          <router-link 
            v-for="inbox in inboxesStore.inboxes" 
            :key="inbox.id"
            :to="'/conversas/inbox/' + inbox.id"
            class="nav-item sub-item"
            exact-active-class="active"
          >
            <img v-if="inbox.provider === 'baileys'" src="https://upload.wikimedia.org/wikipedia/commons/6/6b/WhatsApp.svg" alt="WA" class="icon-img" />
            <img v-else-if="inbox.provider === 'instagram'" src="https://upload.wikimedia.org/wikipedia/commons/a/a5/Instagram_icon.png" alt="IG" class="icon-img" />
            <Hash v-else class="icon" />
            <span>{{ inbox.name }}</span>
          </router-link>
        </div>

        <div class="nav-section" v-if="tags.length > 0">
          <h3 class="section-title">Etiquetas</h3>
          <a href="#" class="nav-item sub-item" v-for="tag in tags" :key="tag.id">
            <span class="tag-color" :style="{ background: tag.color }"></span>
            <span>{{ tag.name }}</span>
          </a>
        </div>

        <div class="nav-section settings-section" v-if="isAdminOrEmpresa">
          <div class="settings-header" @click="toggleSettings">
            <div class="left">
              <Settings class="icon-sm" />
              <span>Configurações</span>
            </div>
            <ChevronDown class="icon-xs chevron-icon" :class="{ 'rotate': isSettingsOpen }" />
          </div>
          <div class="settings-menu" v-show="isSettingsOpen">
            <router-link to="/settings/account" class="nav-item sub-item" active-class="active"><Briefcase class="icon-sm" /> Conta</router-link>
            <router-link to="/suporte" class="nav-item sub-item"><HelpCircle class="icon-sm" /> Central de Suporte</router-link>
            <router-link to="/settings/inboxes" class="nav-item sub-item"><Inbox class="icon-sm" /> Caixas de Entrada</router-link>
            <router-link to="/settings/tags" class="nav-item sub-item" active-class="active"><Tag class="icon-sm" /> Etiquetas</router-link>
            <router-link v-if="isAdminOrEmpresa" to="/settings/portals" class="nav-item sub-item" active-class="active"><TrendingUp class="icon-sm" /> Portais Imobiliários</router-link>
            <router-link v-if="isAdminOrEmpresa" to="/settings/asaas" class="nav-item sub-item" active-class="active"><CreditCard class="icon-sm" /> Cobrança (Asaas)</router-link>
          </div>
        </div>
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
          
          <a href="#" class="menu-item"><User class="icon-sm" /> Configurações do Perfil</a>
          <a href="#" class="menu-item" @click.prevent="openThemePalette"><Palette class="icon-sm" /> Alterar Tema</a>
          <a href="#" class="menu-item logout" @click="handleLogout"><Power class="icon-sm" /> Encerrar sessão</a>
        </div>

        <div class="user-profile" @click="toggleUserMenu" :class="{ 'active': showUserMenu }">
          <div class="avatar-wrapper">
            <div class="avatar">{{ userInitials() }}</div>
            <div class="status-indicator online"></div>
          </div>
          <div class="user-info">
            <span class="name">{{ userDisplayName() }}</span>
            <span class="email">{{ currentUser.email }}</span>
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
        <span>📲 Adicione o VisitaIA à Tela de Início pra receber notificações e usar em tela cheia.</span>
        <button class="ios-install-banner-close" @click="dismissIosBanner">
          <X class="icon-sm" />
        </button>
      </div>

      <div v-if="showAndroidInstallBanner" class="ios-install-banner">
        <span>📲 Instale o VisitaIA no seu celular pra acesso rápido e notificações.</span>
        <button class="install-cta-btn" @click="promptInstall">Instalar</button>
        <button class="ios-install-banner-close" @click="dismissAndroidBanner">
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
  background-color: var(--bg-secondary);
  border-right: 1px solid var(--border-color);
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
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
  color: #0ea5e9;
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  padding: 0;
  &:hover { text-decoration: underline; color: #0284c7; }
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
  width: 6px; height: 6px; background: #3b82f6; border-radius: 50%;
}

.icon-sm { width: 16px; height: 16px; color: #6b7280; }
.icon-xs { width: 14px; height: 14px; color: #6b7280; }

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

.nav-section {
  margin-top: 1.5rem;

  .section-title {
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #9ca3af;
    font-weight: 600;
    padding: 0 0.75rem;
    margin-bottom: 0.5rem;
  }

  .sub-item {
    font-weight: 400;
    font-size: 0.85rem;
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
    &:checked + .slider { background-color: #1f93ff; }
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
</style>
