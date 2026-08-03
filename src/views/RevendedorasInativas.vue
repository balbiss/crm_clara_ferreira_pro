<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search, UserX } from '@lucide/vue'
import { useContactsStore } from '../store/contacts'
import { useConversationsStore } from '../store/conversations'
import { INACTIVE_STATUS_LABELS, statusLabel } from '../constants/regua'

// Tela "Revendedoras Inativas" (briefing seção 28.2) — lista/carteira, com filtro pelos
// 7 sub-status de inativa (seção 14). Sem funil/kanban, conforme diretriz do briefing.
const router = useRouter()
const contactsStore = useContactsStore()
const convStore = useConversationsStore()

const isLoading = ref(true)
const searchQuery = ref('')
const activeStatusFilter = ref('all')

const statusOptions = [
  { value: 'all', label: 'Todos os status' },
  ...Object.entries(INACTIVE_STATUS_LABELS).map(([value, label]) => ({ value, label })),
]

const inactiveStatuses = Object.keys(INACTIVE_STATUS_LABELS)

const agentsById = computed(() => {
  const map = {}
  ;(convStore.agents || []).forEach(a => { map[a.id] = `${a.first_name || ''} ${a.last_name || ''}`.trim() })
  return map
})
const responsavelNome = (contact) => agentsById.value[contact.user_id] || null

const formatDate = (iso) => {
  if (!iso) return null
  return new Date(iso).toLocaleDateString('pt-BR')
}

const inactiveContacts = computed(() => contactsStore.contacts.filter(c => inactiveStatuses.includes(c.status)))

const filteredContacts = computed(() => {
  let list = inactiveContacts.value

  if (activeStatusFilter.value !== 'all') {
    list = list.filter(c => c.status === activeStatusFilter.value)
  }

  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(c =>
      (c.name || `${c.first_name || ''} ${c.last_name || ''}`).toLowerCase().includes(q) ||
      (c.phone || '').includes(q) ||
      (c.city || '').toLowerCase().includes(q)
    )
  }

  return [...list].sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at))
})

const statusBadgeClass = (status) => `status-${status}`
const openContact = (contact) => router.push(`/contatos/${contact.id}`)

onMounted(async () => {
  isLoading.value = true
  try {
    if (!contactsStore.isLoadedOnce) await contactsStore.fetchContacts()
    if (!convStore.agents.length) await convStore.fetchAgents()
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <div class="revendedoras-page">
    <div class="page-header">
      <div class="title-block">
        <h1>Revendedoras Inativas</h1>
        <p>{{ filteredContacts.length }} revendedora{{ filteredContacts.length === 1 ? '' : 's' }} fora do ciclo ativo</p>
      </div>
    </div>

    <div class="toolbar">
      <div class="search-box">
        <Search class="icon-sm" />
        <input v-model="searchQuery" type="text" placeholder="Buscar por nome, telefone ou cidade..." />
      </div>
      <div class="stage-chips">
        <button
          v-for="opt in statusOptions"
          :key="opt.value"
          class="stage-chip"
          :class="{ active: activeStatusFilter === opt.value }"
          @click="activeStatusFilter = opt.value"
        >
          {{ opt.label }}
        </button>
      </div>
    </div>

    <div class="table-wrapper">
      <table v-if="!isLoading && filteredContacts.length > 0" class="revendedoras-table">
        <thead>
          <tr>
            <th>Revendedora</th>
            <th>Status</th>
            <th>Telefone</th>
            <th>Cidade</th>
            <th>Responsável anterior</th>
            <th>Motivo</th>
            <th>Atualizado em</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in filteredContacts" :key="c.id" @click="openContact(c)">
            <td class="cell-name">
              <div class="row-avatar">{{ (c.name || c.first_name || '?').charAt(0).toUpperCase() }}</div>
              <span>{{ c.name || `${c.first_name || ''} ${c.last_name || ''}`.trim() || 'Sem nome' }}</span>
            </td>
            <td><span class="status-badge" :class="statusBadgeClass(c.status)">{{ statusLabel(c.status) }}</span></td>
            <td>{{ c.phone || '...' }}</td>
            <td>{{ c.city || '...' }}</td>
            <td>{{ responsavelNome(c) || 'Não atribuído' }}</td>
            <td>{{ c.custom_attributes?.motivo_inativacao || '...' }}</td>
            <td>{{ formatDate(c.updated_at) || '...' }}</td>
          </tr>
        </tbody>
      </table>

      <div v-else-if="isLoading" class="empty-state">
        <p>Carregando...</p>
      </div>

      <div v-else class="empty-state">
        <div class="empty-icon"><UserX :size="28" /></div>
        <h3>Nenhuma revendedora inativa encontrada</h3>
        <p>Ajuste os filtros, ou nenhuma revendedora está fora do ciclo ativo hoje.</p>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.revendedoras-page {
  padding: 1.5rem 2rem;
  height: 100%;
  overflow-y: auto;
}

.page-header {
  margin-bottom: 1.25rem;

  h1 { font-size: 1.35rem; font-weight: 700; color: var(--text-main); }
  p { font-size: 0.85rem; color: var(--text-muted); margin-top: 0.25rem; }
}

.toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.search-box {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.5rem 0.75rem;
  min-width: 260px;

  .icon-sm { width: 16px; height: 16px; color: var(--text-muted); }

  input {
    border: none;
    outline: none;
    background: transparent;
    color: var(--text-main);
    font-size: 0.85rem;
    flex: 1;
  }
}

.stage-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.stage-chip {
  padding: 0.4rem 0.75rem;
  border-radius: 20px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
  color: var(--text-muted);
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s, color 0.15s, border-color 0.15s;

  &:hover { background: var(--bg-hover); }
  &.active { background: var(--primary-hover); border-color: var(--primary-hover); color: white; }
}

.table-wrapper {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  overflow: hidden;
}

.revendedoras-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;

  thead th {
    text-align: left;
    padding: 0.75rem 1rem;
    font-size: 0.72rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--text-muted);
    background: var(--bg-tertiary);
    border-bottom: 1px solid var(--border-color);
  }

  tbody tr {
    cursor: pointer;
    transition: background 0.15s;
    border-bottom: 1px solid var(--border-color);

    &:hover { background: var(--bg-hover); }
    &:last-child { border-bottom: none; }
  }

  td {
    padding: 0.7rem 1rem;
    color: var(--text-main);
    white-space: nowrap;
  }

  .cell-name {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    font-weight: 600;
  }

  .row-avatar {
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: #6b7280;
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.8rem;
    font-weight: 700;
    flex-shrink: 0;
  }
}

.status-badge {
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.25rem 0.6rem;
  border-radius: 20px;
  white-space: nowrap;

  &.status-sem_maleta { background: #e0e7ff; color: #3730a3; }
  &.status-inativa_pendencia { background: #fef3c7; color: #92400e; }
  &.status-suspensa_atraso { background: #fee2e2; color: #991b1b; }
  &.status-negativado_juridico { background: #1f2937; color: #f9fafb; }
  &.status-resgate { background: #fecaca; color: #7f1d1d; }
  &.status-reativacao { background: #d1fae5; color: #065f46; }
  &.status-descadastrada { background: #e5e7eb; color: #4b5563; }
}

.empty-state {
  padding: 3rem 1.5rem;
  text-align: center;
  color: var(--text-muted);

  .empty-icon {
    width: 56px;
    height: 56px;
    border-radius: 16px;
    background: var(--bg-tertiary);
    color: var(--primary);
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1rem;
  }

  h3 { font-size: 1rem; font-weight: 700; color: var(--text-main); margin-bottom: 0.4rem; }
  p { font-size: 0.85rem; }
}
</style>
