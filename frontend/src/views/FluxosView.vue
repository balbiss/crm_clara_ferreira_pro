<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search, GitBranch, MoreVertical, Copy, Pencil, Trash2, Edit2 } from '@lucide/vue'
import Swal from 'sweetalert2'
import api from '../api'

// Tela "Fluxos" — construtor visual de automação de conversa (MVP). Mesmo
// visual de listagem já usado em SettingsInboxes.vue/RevendedorasAtivas.vue
// (cards em var(--bg-secondary), badge de status, menu de ações).
const router = useRouter()

const flows = ref([])
const isLoading = ref(true)
const searchQuery = ref('')
const openMenuId = ref(null)

const filteredFlows = computed(() => {
  if (!searchQuery.value.trim()) return flows.value
  const q = searchQuery.value.toLowerCase()
  return flows.value.filter(f => (f.name || '').toLowerCase().includes(q) || (f.description || '').toLowerCase().includes(q))
})

const formatDate = (iso) => {
  if (!iso) return '...'
  return new Date(iso).toLocaleDateString('pt-BR')
}

const fetchFlows = async () => {
  isLoading.value = true
  try {
    const { data } = await api.get('/flows')
    flows.value = data
  } catch (e) {
    console.error('Erro ao buscar fluxos:', e)
  } finally {
    isLoading.value = false
  }
}

const openFlow = (flow) => router.push(`/fluxos/${flow.id}`)
const toggleMenu = (id) => { openMenuId.value = openMenuId.value === id ? null : id }

const toggleActive = async (flow) => {
  try {
    const { data } = await api.patch(`/flows/${flow.id}`, { flow: { active: !flow.active } })
    const idx = flows.value.findIndex(f => f.id === flow.id)
    if (idx !== -1) flows.value[idx] = { ...flows.value[idx], active: data.active }
  } catch (e) {
    console.error('Erro ao ativar/desativar fluxo:', e)
  }
}

const duplicateFlow = async (flow) => {
  openMenuId.value = null
  try {
    await api.post(`/flows/${flow.id}/duplicate`)
    await fetchFlows()
  } catch (e) {
    console.error('Erro ao duplicar fluxo:', e)
  }
}

const renameFlow = async (flow) => {
  openMenuId.value = null
  const { value: novoNome } = await Swal.fire({
    title: 'Renomear fluxo',
    input: 'text',
    inputValue: flow.name,
    showCancelButton: true,
    confirmButtonText: 'Salvar',
    cancelButtonText: 'Cancelar'
  })
  if (!novoNome || !novoNome.trim()) return
  try {
    await api.patch(`/flows/${flow.id}`, { flow: { name: novoNome.trim() } })
    await fetchFlows()
  } catch (e) {
    console.error('Erro ao renomear fluxo:', e)
  }
}

const deleteFlow = async (flow) => {
  openMenuId.value = null
  const result = await Swal.fire({
    title: 'Excluir fluxo?',
    text: `"${flow.name}" será removido permanentemente.`,
    icon: 'warning',
    showCancelButton: true,
    confirmButtonText: 'Sim, excluir',
    cancelButtonText: 'Cancelar'
  })
  if (!result.isConfirmed) return
  try {
    await api.delete(`/flows/${flow.id}`)
    flows.value = flows.value.filter(f => f.id !== flow.id)
  } catch (e) {
    console.error('Erro ao excluir fluxo:', e)
    Swal.fire('Erro', 'Não foi possível excluir o fluxo.', 'error')
  }
}

onMounted(fetchFlows)
</script>

<template>
  <div class="page-container">
    <div class="page-content">
      <div class="header">
        <h1>Fluxos</h1>
        <p class="description">Crie e gerencie automações de conversa visualmente.</p>
      </div>

      <div class="actions-bar">
        <div class="search-wrapper">
          <Search class="icon-sm search-icon" />
          <input v-model="searchQuery" type="text" placeholder="Buscar fluxos..." />
        </div>
        <router-link to="/fluxos/novo" class="btn-primary">+ Criar fluxo</router-link>
      </div>

      <div v-if="isLoading" class="empty-state"><p>Carregando fluxos...</p></div>

      <div v-else-if="filteredFlows.length > 0" class="flows-grid">
        <div v-for="flow in filteredFlows" :key="flow.id" class="flow-card" @click="openFlow(flow)">
          <div class="flow-card-header">
            <div class="flow-icon"><GitBranch class="icon-sm" /></div>
            <span class="status-badge" :class="{ connected: flow.active, disconnected: !flow.active }">
              <span class="dot"></span>{{ flow.active ? 'Ativo' : 'Inativo' }}
            </span>
          </div>

          <h3 class="flow-name">{{ flow.name }}</h3>
          <p class="flow-description">{{ flow.description || 'Sem descrição.' }}</p>

          <div class="flow-meta">
            <span class="step-pill">{{ flow.flow_nodes_count }} etapa{{ flow.flow_nodes_count === 1 ? '' : 's' }}</span>
            <span class="meta-sep">·</span>
            <span :class="{ 'no-inbox': !flow.inbox_name }">{{ flow.inbox_name || 'Sem caixa (não dispara)' }}</span>
            <span class="meta-sep">·</span>
            <span>Criado em {{ formatDate(flow.created_at) }}</span>
            <span class="meta-sep">·</span>
            <span>Atualizado em {{ formatDate(flow.updated_at) }}</span>
          </div>

          <div class="flow-actions" @click.stop>
            <button class="icon-btn" title="Editar" @click="openFlow(flow)"><Edit2 class="icon-sm" /></button>
            <button class="icon-btn" title="Duplicar" @click="duplicateFlow(flow)"><Copy class="icon-sm" /></button>
            <button
              class="switch"
              :class="{ on: flow.active }"
              :title="flow.active ? 'Desativar' : 'Ativar'"
              role="switch"
              :aria-checked="flow.active"
              @click="toggleActive(flow)"
            >
              <span class="switch-knob"></span>
            </button>
            <div class="menu-wrapper">
              <button class="icon-btn" title="Mais ações" @click="toggleMenu(flow.id)"><MoreVertical class="icon-sm" /></button>
              <div v-if="openMenuId === flow.id" class="dropdown-menu" @click.self="openMenuId = null">
                <button @click="openFlow(flow)"><Pencil class="icon-xs" /> Editar</button>
                <button @click="duplicateFlow(flow)"><Copy class="icon-xs" /> Duplicar</button>
                <button @click="renameFlow(flow)"><Pencil class="icon-xs" /> Renomear</button>
                <button class="danger" @click="deleteFlow(flow)"><Trash2 class="icon-xs" /> Excluir</button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-else class="empty-state">
        <div class="empty-icon"><GitBranch :size="28" /></div>
        <h3>Você ainda não possui fluxos.</h3>
        <p>Crie seu primeiro fluxo para começar a automatizar suas conversas.</p>
        <router-link to="/fluxos/novo" class="btn-primary">Criar primeiro fluxo</router-link>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 2.5rem 3rem;
  background: var(--bg-primary);
  overflow-y: auto;
}

.page-content {
  max-width: 1200px;
  width: 100%;
  margin: 0;
}

.header {
  margin-bottom: 2rem;

  h1 {
    font-size: 1.5rem;
    font-weight: 700;
    letter-spacing: -0.01em;
    color: var(--text-main);
    margin-bottom: 0.4rem;
  }
  .description { color: var(--text-muted); font-size: 0.92rem; }
}

.icon-xs { width: 14px; height: 14px; }
.icon-sm { width: 16px; height: 16px; }

.actions-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
  gap: 1rem;
}

.search-wrapper {
  position: relative;
  width: 280px;

  .search-icon { position: absolute; left: 1rem; top: 50%; transform: translateY(-50%); color: var(--text-muted); }

  input {
    width: 100%;
    padding: 0.55rem 1rem 0.55rem 2.5rem;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    background: var(--bg-tertiary);
    font-size: 0.85rem;
    color: var(--text-main);
    outline: none;

    &:focus { border-color: var(--primary); }
  }
}

.btn-primary {
  background: var(--primary, #ff007f);
  color: white;
  padding: 0.55rem 1.1rem;
  border-radius: 6px;
  text-decoration: none;
  font-size: 0.85rem;
  font-weight: 600;
  border: none;
  cursor: pointer;
  white-space: nowrap;
}

.flows-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.1rem;
}

.flow-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 1.35rem;
  cursor: pointer;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
  transition: border-color 0.15s, box-shadow 0.15s, transform 0.15s;

  &:hover {
    border-color: var(--primary, #ff007f);
    box-shadow: 0 10px 24px -8px rgba(255, 0, 127, 0.35);
    transform: translateY(-2px);
  }
}

.flow-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
}

.flow-icon {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  background: linear-gradient(135deg, rgba(255, 0, 127, 0.28), rgba(255, 0, 127, 0.12));
  color: var(--primary, #ff007f);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.status-badge {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.72rem;
  font-weight: 600;
  padding: 0.15rem 0.55rem;
  border-radius: 12px;

  .dot { width: 6px; height: 6px; border-radius: 50%; }

  &.connected { background: #d1fae5; color: #059669; .dot { background: #10b981; } }
  &.disconnected { background: #f3f4f6; color: #6b7280; .dot { background: #9ca3af; } }
}

.flow-name {
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: -0.005em;
  color: var(--text-main);
  margin-bottom: 0.35rem;
}

.flow-description {
  font-size: 0.84rem;
  line-height: 1.5;
  color: var(--text-muted);
  margin-bottom: 1rem;
  min-height: 2.5rem;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.flow-meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem 0.6rem;
  font-size: 0.73rem;
  color: var(--text-muted);
  margin-bottom: 1.1rem;
  padding-bottom: 1.1rem;
  border-bottom: 1px solid var(--border-color);

  .step-pill {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.2rem 0.55rem;
    border-radius: 20px;
    background: var(--bg-tertiary);
    color: var(--text-main);
    font-weight: 600;
  }

  .meta-sep { color: var(--border-color); }
  .no-inbox { color: #dc2626; }
}

.flow-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.icon-btn {
  width: 32px;
  height: 32px;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
  color: var(--text-muted);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;

  &:hover { background: var(--bg-hover); color: var(--text-main); }
}

.toggle-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #d1d5db;

  &.on { background: #10b981; }
}

.menu-wrapper {
  position: relative;
  margin-left: auto;
}

.dropdown-menu {
  position: absolute;
  right: 0;
  top: calc(100% + 4px);
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  box-shadow: 0 8px 20px rgba(0,0,0,0.12);
  min-width: 160px;
  z-index: 20;
  overflow: hidden;

  button {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    padding: 0.6rem 0.85rem;
    background: none;
    border: none;
    text-align: left;
    font-size: 0.82rem;
    color: var(--text-main);
    cursor: pointer;

    &:hover { background: var(--bg-hover); }
    &.danger { color: #ef4444; }
  }
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
  p { font-size: 0.85rem; margin-bottom: 1rem; }
}
</style>
