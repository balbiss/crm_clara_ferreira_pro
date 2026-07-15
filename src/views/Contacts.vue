<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Search, Filter, ChevronDown, ArrowDownUp, MoreVertical, X, MessageCircle, Download, Check } from '@lucide/vue'
import api from '../api'
import { useContactsStore } from '../store/contacts'
import { storeToRefs } from 'pinia'

const router = useRouter()
const contactsStore = useContactsStore()
const { contacts, isLoading } = storeToRefs(contactsStore)

// ── Search / Filter / Sort state ─────────────────────────────
const searchQuery      = ref('')
const showFilter       = ref(false)
const showSort         = ref(false)
const showMore         = ref(false)
const showSendModal    = ref(false)
const sendSearch       = ref('')
const activeTemps      = ref([])          // temperature filter
const sortBy           = ref('newest')    // newest | oldest | name_asc | name_desc

const SORT_OPTIONS = [
  { value: 'newest',    label: 'Mais recentes' },
  { value: 'oldest',   label: 'Mais antigos' },
  { value: 'name_asc', label: 'Nome A → Z' },
  { value: 'name_desc',label: 'Nome Z → A' },
]

const TEMP_OPTIONS = [
  { value: 'hot',  label: 'Quente', color: '#ef4444' },
  { value: 'warm', label: 'Morno',  color: '#f59e0b' },
  { value: 'cold', label: 'Frio',   color: '#6b7280' },
]

// ── Computed ─────────────────────────────────────────────────
const contactName = (c) => ((c.first_name || c.name || '') + ' ' + (c.last_name || '')).trim()

const filteredContacts = computed(() => {
  let list = contacts.value

  // text search
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(c =>
      contactName(c).toLowerCase().includes(q) ||
      (c.phone  || '').includes(q) ||
      (c.email  || '').toLowerCase().includes(q)
    )
  }

  // temperature filter
  if (activeTemps.value.length > 0) {
    list = list.filter(c => activeTemps.value.includes(c.temperature))
  }

  // sort
  list = [...list].sort((a, b) => {
    if (sortBy.value === 'name_asc')  return contactName(a).localeCompare(contactName(b))
    if (sortBy.value === 'name_desc') return contactName(b).localeCompare(contactName(a))
    if (sortBy.value === 'oldest')    return new Date(a.created_at) - new Date(b.created_at)
    return new Date(b.created_at) - new Date(a.created_at) // newest
  })

  return list
})

const activeFilterCount = computed(() => activeTemps.value.length)
const currentSortLabel  = computed(() => SORT_OPTIONS.find(o => o.value === sortBy.value)?.label || '')

// ── Send-message modal ────────────────────────────────────────
const sendModalContacts = computed(() => {
  const q = sendSearch.value.toLowerCase()
  const list = q
    ? contacts.value.filter(c =>
        contactName(c).toLowerCase().includes(q) || (c.phone || '').includes(q)
      )
    : contacts.value
  return list.slice(0, 12)
})

const goToConversation = (contact) => {
  showSendModal.value = false
  router.push('/conversas')
}

// ── Export CSV ────────────────────────────────────────────────
const exportCsv = () => {
  const header = ['Nome', 'Telefone', 'Email', 'Temperatura', 'Intenção', 'Origem']
  const rows = filteredContacts.value.map(c => [
    contactName(c),
    c.phone  || '',
    c.email  || '',
    c.temperature || '',
    c.intention   || '',
    c.source      || '',
  ])
  const csv = [header, ...rows].map(r => r.map(v => `"${String(v).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
  const url  = URL.createObjectURL(blob)
  const a    = Object.assign(document.createElement('a'), { href: url, download: 'contatos.csv' })
  a.click()
  URL.revokeObjectURL(url)
  showMore.value = false
}

// ── Toggle helpers ────────────────────────────────────────────
const toggleTemp = (v) => {
  const i = activeTemps.value.indexOf(v)
  i === -1 ? activeTemps.value.push(v) : activeTemps.value.splice(i, 1)
}

const clearFilters = () => { activeTemps.value = []; showFilter.value = false }

// ── Close popovers on outside click ──────────────────────────
const closeAll = (e) => {
  if (!e.target.closest('.popover-anchor')) {
    showFilter.value = false
    showSort.value   = false
    showMore.value   = false
  }
}

onMounted(() => {
  contactsStore.fetchContacts()
  document.addEventListener('click', closeAll)
})
onUnmounted(() => document.removeEventListener('click', closeAll))

// ── Avatar helpers ────────────────────────────────────────────
const getInitials = (name) => (name || '?').substring(0, 2).toUpperCase()
const PALETTE = [
  { bg: '#dbeafe', color: '#1e40af' },
  { bg: '#d1fae5', color: '#065f46' },
  { bg: '#fee2e2', color: '#991b1b' },
  { bg: '#fef3c7', color: '#92400e' },
  { bg: '#f3e8ff', color: '#6b21a8' },
]
const getAvatarStyle = (name) => {
  if (!name) return { backgroundColor: '#e5e7eb', color: '#4b5563' }
  const p = PALETTE[name.charCodeAt(0) % PALETTE.length]
  return { backgroundColor: p.bg, color: p.color }
}

const tempColor = (t) => ({ hot: '#ef4444', warm: '#f59e0b', cold: '#6b7280' }[t] || '#e5e7eb')
const tempLabel = (t) => ({ hot: 'Quente', warm: 'Morno', cold: 'Frio' }[t] || '')
</script>

<template>
  <div class="page-container">

    <!-- Header -->
    <div class="page-header">
      <h1>Contatos</h1>

      <div class="header-actions">
        <!-- Search -->
        <div class="search-box">
          <Search class="search-icon" :size="14" />
          <input v-model="searchQuery" type="text" placeholder="Pesquisar nome, telefone ou email..." />
          <button v-if="searchQuery" class="clear-search" @click="searchQuery = ''"><X :size="12" /></button>
        </div>

        <!-- Filter -->
        <div class="popover-anchor">
          <button
            class="icon-btn"
            :class="{ active: activeFilterCount > 0 }"
            @click.stop="showFilter = !showFilter; showSort = false; showMore = false"
            title="Filtrar"
          >
            <Filter :size="16" />
            <span v-if="activeFilterCount > 0" class="badge-dot">{{ activeFilterCount }}</span>
          </button>

          <div v-if="showFilter" class="popover" @click.stop>
            <div class="popover-header">
              <span>Filtrar por</span>
              <button v-if="activeFilterCount > 0" class="btn-link" @click="clearFilters">Limpar</button>
            </div>
            <div class="popover-section-label">Temperatura</div>
            <label v-for="t in TEMP_OPTIONS" :key="t.value" class="popover-check">
              <div class="check-box" :class="{ checked: activeTemps.includes(t.value) }" @click="toggleTemp(t.value)">
                <Check v-if="activeTemps.includes(t.value)" :size="10" />
              </div>
              <span class="temp-dot" :style="{ background: t.color }"></span>
              {{ t.label }}
            </label>
            <div class="popover-footer">
              <button class="btn-apply" @click="showFilter = false">Aplicar</button>
            </div>
          </div>
        </div>

        <!-- Sort -->
        <div class="popover-anchor">
          <button
            class="icon-btn"
            :class="{ active: sortBy !== 'newest' }"
            @click.stop="showSort = !showSort; showFilter = false; showMore = false"
            title="Ordenar"
          >
            <ArrowDownUp :size="16" />
          </button>

          <div v-if="showSort" class="popover" @click.stop>
            <div class="popover-header"><span>Ordenar por</span></div>
            <button
              v-for="opt in SORT_OPTIONS"
              :key="opt.value"
              class="sort-option"
              :class="{ active: sortBy === opt.value }"
              @click="sortBy = opt.value; showSort = false"
            >
              <Check v-if="sortBy === opt.value" :size="12" />
              {{ opt.label }}
            </button>
          </div>
        </div>

        <!-- More -->
        <div class="popover-anchor">
          <button
            class="icon-btn"
            @click.stop="showMore = !showMore; showFilter = false; showSort = false"
            title="Mais opções"
          >
            <MoreVertical :size="16" />
          </button>

          <div v-if="showMore" class="popover popover-sm" @click.stop>
            <button class="more-option" @click="exportCsv">
              <Download :size="14" /> Exportar CSV ({{ filteredContacts.length }} contatos)
            </button>
          </div>
        </div>

        <!-- Send message -->
        <button class="btn-primary" @click="showSendModal = true">
          <MessageCircle :size="14" /> Enviar Mensagem
        </button>
      </div>
    </div>

    <!-- Count bar -->
    <div class="count-bar" v-if="!isLoading">
      <span>{{ filteredContacts.length }} contato{{ filteredContacts.length !== 1 ? 's' : '' }}</span>
      <span v-if="activeFilterCount > 0 || searchQuery" class="filter-active-tag">
        Filtros ativos
        <button @click="searchQuery = ''; activeTemps = []"><X :size="10" /></button>
      </span>
      <span v-if="sortBy !== 'newest'" class="sort-tag">{{ currentSortLabel }}</span>
    </div>

    <!-- List -->
    <div class="contacts-list">
      <div v-if="isLoading" class="skeleton-list">
        <div class="skeleton-card" v-for="i in 5" :key="i">
          <div class="skeleton-avatar"></div>
          <div class="skeleton-text">
            <div class="skeleton-line title"></div>
            <div class="skeleton-line subtitle"></div>
          </div>
          <div class="skeleton-action"></div>
        </div>
      </div>

      <template v-else>
        <div
          class="contact-card"
          v-for="contact in filteredContacts"
          :key="contact.id"
          @click="router.push(`/contatos/${contact.id}`)"
        >
          <div class="avatar" :style="getAvatarStyle(contact.first_name || contact.name)">
            {{ getInitials(contact.first_name || contact.name) }}
          </div>

          <div class="contact-info">
            <span class="contact-name">{{ contactName(contact) }}</span>
            <span class="contact-sub">{{ contact.phone || 'Sem telefone' }}<template v-if="contact.email"> · {{ contact.email }}</template></span>
          </div>

          <div class="contact-meta">
            <span v-if="contact.temperature" class="temp-chip" :style="{ background: tempColor(contact.temperature) + '22', color: tempColor(contact.temperature) }">
              {{ tempLabel(contact.temperature) }}
            </span>
            <span v-if="contact.source" class="source-chip">{{ contact.source }}</span>
          </div>

          <ChevronDown :size="16" class="chevron" />
        </div>

        <div v-if="filteredContacts.length === 0 && !isLoading" class="empty-state">
          <span v-if="searchQuery || activeFilterCount > 0">Nenhum contato encontrado para os filtros aplicados.</span>
          <span v-else>Nenhum contato cadastrado.</span>
        </div>

        <div class="pagination" v-if="filteredContacts.length > 0">
          Exibindo {{ filteredContacts.length }} de {{ contacts.length }} contatos
        </div>
      </template>
    </div>

    <!-- Send Message Modal -->
    <div v-if="showSendModal" class="modal-overlay" @click.self="showSendModal = false">
      <div class="modal-box">
        <div class="modal-head">
          <span>Enviar Mensagem</span>
          <button @click="showSendModal = false"><X :size="16" /></button>
        </div>
        <div class="modal-body">
          <p class="modal-hint">Selecione o contato para abrir a conversa no WhatsApp:</p>
          <div class="modal-search">
            <Search :size="14" />
            <input v-model="sendSearch" placeholder="Buscar contato..." autofocus />
          </div>
          <div class="modal-contact-list">
            <button
              v-for="c in sendModalContacts"
              :key="c.id"
              class="modal-contact-item"
              @click="goToConversation(c)"
            >
              <div class="mc-avatar" :style="getAvatarStyle(c.first_name || c.name)">
                {{ getInitials(c.first_name || c.name) }}
              </div>
              <div class="mc-info">
                <span class="mc-name">{{ contactName(c) }}</span>
                <span class="mc-phone">{{ c.phone || 'Sem telefone' }}</span>
              </div>
              <MessageCircle :size="14" class="mc-icon" />
            </button>
            <div v-if="sendModalContacts.length === 0" class="empty-modal">Nenhum contato encontrado.</div>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<style lang="scss" scoped>
.page-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 1.5rem 2rem;
  background: var(--bg-primary);
  overflow-y: auto;
  gap: 0;
}

// ── Header ──────────────────────────────────────────────────
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;

  h1 { font-size: 1.25rem; font-weight: 700; color: var(--text-main); margin: 0; }
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.search-box {
  position: relative;
  display: flex;
  align-items: center;

  .search-icon {
    position: absolute;
    left: 0.6rem;
    color: var(--text-muted);
    pointer-events: none;
  }

  input {
    padding: 0.45rem 2rem 0.45rem 2rem;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    outline: none;
    font-size: 0.82rem;
    color: var(--text-main);
    width: 240px;
    &::placeholder { color: var(--text-muted); }
    &:focus { border-color: #4338ca; }
  }

  .clear-search {
    position: absolute;
    right: 0.5rem;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    &:hover { color: var(--text-main); }
  }
}

// ── Icon buttons ─────────────────────────────────────────────
.icon-btn {
  position: relative;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.45rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  transition: border-color 0.12s, color 0.12s;

  &:hover { border-color: #4338ca; color: #4338ca; }
  &.active { border-color: #4338ca; color: #4338ca; background: rgba(67,56,202,0.06); }

  .badge-dot {
    position: absolute;
    top: -5px; right: -5px;
    background: #4338ca;
    color: white;
    font-size: 0.6rem;
    font-weight: 700;
    width: 14px; height: 14px;
    border-radius: 7px;
    display: flex; align-items: center; justify-content: center;
  }
}

.btn-primary {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: #4338ca;
  color: white;
  padding: 0.45rem 0.9rem;
  border-radius: 6px;
  border: none;
  font-weight: 600;
  font-size: 0.82rem;
  cursor: pointer;
  &:hover { background: #3730a3; }
}

// ── Popovers ─────────────────────────────────────────────────
.popover-anchor { position: relative; }

.popover {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  box-shadow: 0 8px 20px rgba(0,0,0,0.12);
  z-index: 200;
  min-width: 200px;
  padding: 0.5rem 0;

  &.popover-sm { min-width: 220px; }
}

.popover-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 0.9rem;
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  border-bottom: 1px solid var(--border-color);
  margin-bottom: 0.4rem;
}

.btn-link {
  background: none;
  border: none;
  color: #4338ca;
  font-size: 0.78rem;
  cursor: pointer;
  font-weight: 600;
  &:hover { text-decoration: underline; }
}

.popover-section-label {
  padding: 0.3rem 0.9rem 0.2rem;
  font-size: 0.72rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
}

.popover-check {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.45rem 0.9rem;
  cursor: pointer;
  font-size: 0.85rem;
  color: var(--text-main);
  user-select: none;
  &:hover { background: var(--bg-hover); }

  .check-box {
    width: 16px; height: 16px;
    border: 1.5px solid var(--border-color);
    border-radius: 4px;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0;
    &.checked { background: #4338ca; border-color: #4338ca; color: white; }
  }

  .temp-dot {
    width: 8px; height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
}

.sort-option {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.5rem 0.9rem;
  background: none;
  border: none;
  font-size: 0.85rem;
  color: var(--text-muted);
  cursor: pointer;
  text-align: left;
  &:hover { background: var(--bg-hover); color: var(--text-main); }
  &.active { color: #4338ca; font-weight: 600; }
}

.more-option {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  width: 100%;
  padding: 0.55rem 0.9rem;
  background: none;
  border: none;
  font-size: 0.85rem;
  color: var(--text-muted);
  cursor: pointer;
  text-align: left;
  &:hover { background: var(--bg-hover); color: var(--text-main); }
}

.popover-footer {
  padding: 0.5rem 0.9rem;
  border-top: 1px solid var(--border-color);
  margin-top: 0.4rem;
  display: flex;
  justify-content: flex-end;
}

.btn-apply {
  background: #4338ca;
  color: white;
  border: none;
  border-radius: 5px;
  padding: 0.35rem 0.9rem;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  &:hover { background: #3730a3; }
}

// ── Count bar ─────────────────────────────────────────────────
.count-bar {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.8rem;
  color: var(--text-muted);
  margin-bottom: 0.75rem;
}

.filter-active-tag, .sort-tag {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  background: rgba(67,56,202,0.08);
  color: #4338ca;
  border-radius: 4px;
  padding: 0.1rem 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;

  button {
    background: none; border: none; cursor: pointer;
    color: #4338ca; display: flex; align-items: center;
    padding: 0;
  }
}

// ── Contact list ──────────────────────────────────────────────
.contacts-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  flex: 1;
}

.contact-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.85rem 1.25rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  cursor: pointer;
  transition: border-color 0.12s, box-shadow 0.12s;

  &:hover {
    border-color: #4338ca;
    box-shadow: 0 1px 6px rgba(67,56,202,0.1);
  }
}

.avatar {
  width: 40px; height: 40px;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.9rem; font-weight: 600;
  flex-shrink: 0;
}

.contact-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.contact-name {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--text-main);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.contact-sub {
  font-size: 0.78rem;
  color: var(--text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.contact-meta {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
}

.temp-chip {
  font-size: 0.72rem;
  font-weight: 700;
  padding: 0.15rem 0.5rem;
  border-radius: 4px;
}

.source-chip {
  font-size: 0.72rem;
  color: var(--text-muted);
  background: var(--bg-tertiary);
  border: 1px solid var(--border-color);
  padding: 0.12rem 0.45rem;
  border-radius: 4px;
}

.chevron { color: var(--text-muted); flex-shrink: 0; }

// ── Skeleton ──────────────────────────────────────────────────
.skeleton-list { display: flex; flex-direction: column; gap: 0.4rem; }
.skeleton-card {
  display: flex; align-items: center; gap: 1rem;
  padding: 0.85rem 1.25rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  animation: pulse-sk 1.5s infinite;

  .skeleton-avatar { width: 40px; height: 40px; border-radius: 50%; background: var(--border-color); flex-shrink: 0; }
  .skeleton-text { flex: 1; display: flex; flex-direction: column; gap: 0.4rem; }
  .skeleton-line { height: 10px; background: var(--border-color); border-radius: 4px; &.title { width: 140px; height: 13px; } &.subtitle { width: 200px; } }
  .skeleton-action { width: 20px; height: 20px; background: var(--border-color); border-radius: 4px; }
}
@keyframes pulse-sk { 0%,100% { opacity: 0.6; } 50% { opacity: 1; } }

.empty-state {
  padding: 3rem;
  text-align: center;
  color: var(--text-muted);
  font-size: 0.88rem;
  background: var(--bg-secondary);
  border-radius: 8px;
  border: 1px solid var(--border-color);
}

.pagination {
  margin-top: 0.5rem;
  font-size: 0.8rem;
  color: var(--text-muted);
  padding: 0.5rem 0;
}

// ── Send modal ────────────────────────────────────────────────
.modal-overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,0.4);
  z-index: 9999;
  display: flex; align-items: center; justify-content: center;
  padding: 1rem;
}

.modal-box {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  width: 100%; max-width: 420px;
  box-shadow: 0 20px 40px rgba(0,0,0,0.2);
  overflow: hidden;
}

.modal-head {
  display: flex; justify-content: space-between; align-items: center;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-color);
  font-size: 0.92rem; font-weight: 700; color: var(--text-main);

  button { background: none; border: none; cursor: pointer; color: var(--text-muted); display: flex; align-items: center; &:hover { color: var(--text-main); } }
}

.modal-body { padding: 1rem 1.25rem; }

.modal-hint {
  font-size: 0.83rem;
  color: var(--text-muted);
  margin: 0 0 0.75rem;
}

.modal-search {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  margin-bottom: 0.75rem;
  &:focus-within { border-color: #4338ca; }
  svg { color: var(--text-muted); flex-shrink: 0; }
  input { flex: 1; border: none; background: none; outline: none; font-size: 0.85rem; color: var(--text-main); &::placeholder { color: var(--text-muted); } }
}

.modal-contact-list { display: flex; flex-direction: column; gap: 2px; max-height: 300px; overflow-y: auto; }

.modal-contact-item {
  display: flex; align-items: center; gap: 0.75rem;
  padding: 0.6rem 0.75rem;
  border-radius: 6px;
  background: none; border: none; cursor: pointer; text-align: left; width: 100%;
  &:hover { background: var(--bg-hover); }

  .mc-avatar { width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 0.78rem; font-weight: 600; flex-shrink: 0; }
  .mc-info { flex: 1; min-width: 0; display: flex; flex-direction: column; }
  .mc-name { font-size: 0.85rem; font-weight: 600; color: var(--text-main); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .mc-phone { font-size: 0.75rem; color: var(--text-muted); }
  .mc-icon { color: #4338ca; flex-shrink: 0; }
}

.empty-modal { padding: 1.5rem; text-align: center; font-size: 0.83rem; color: var(--text-muted); }

@media (max-width: 768px) {
  .page-container {
    padding: 1rem;
  }

  .page-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }

  .header-actions {
    width: 100%;
    flex-wrap: wrap;
    gap: 0.4rem;
  }

  .search-box input {
    width: 100%;
  }

  .search-box {
    width: 100%;
  }

  .contact-card {
    padding: 0.75rem;
    gap: 0.75rem;
  }

  .card-actions {
    flex-wrap: wrap;
    gap: 0.4rem;
  }

  .filter-popover,
  .sort-popover,
  .more-popover {
    right: auto;
    left: 0;
    width: 90vw;
    max-width: 320px;
  }

  .send-modal-box {
    width: 95vw;
    max-height: 90vh;
  }
}
</style>
