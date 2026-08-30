<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '../api'
import { useContactsStore } from '../store/contacts'
import { useConversationsStore } from '../store/conversations'
import { ACTIVE_STATUS_LABELS, INACTIVE_STATUS_LABELS, statusLabel } from '../constants/regua'

// Tela Gerencial (briefing seção 28.5) — visão consolidada pra gerência/diretoria.
// Contagens derivadas dos mesmos dados das outras telas, sem model novo.
const contactsStore = useContactsStore()
const convStore = useConversationsStore()
const isLoading = ref(true)
const tarefas = ref([])

const agentsById = computed(() => {
  const map = {}
  ;(convStore.agents || []).forEach(a => { map[a.id] = `${a.first_name || ''} ${a.last_name || ''}`.trim() })
  return map
})

const ativas = computed(() => contactsStore.contacts.filter(c => Object.keys(ACTIVE_STATUS_LABELS).includes(c.status || 'revendedor_ativo')))
const inativas = computed(() => contactsStore.contacts.filter(c => Object.keys(INACTIVE_STATUS_LABELS).includes(c.status)))

const countByStatus = (list, status) => list.filter(c => (c.status || 'revendedor_ativo') === status).length

const summaryCards = computed(() => [
  { label: 'Revendedoras Ativas', value: ativas.value.length, tone: 'primary' },
  { label: 'Revendedoras Inativas', value: inativas.value.length, tone: 'muted' },
  { label: 'Atrasadas', value: countByStatus(ativas.value, 'atrasada'), tone: 'danger' },
  { label: 'Agendadas', value: countByStatus(ativas.value, 'agendado'), tone: 'success' },
  { label: 'Reagendar', value: countByStatus(ativas.value, 'reagendar'), tone: 'warn' },
  { label: 'Em Resgate', value: countByStatus(inativas.value, 'resgate'), tone: 'danger' },
  { label: 'Em Reativação', value: countByStatus(inativas.value, 'reativacao'), tone: 'success' },
])

const ativasPorConsultor = computed(() => {
  const groups = {}
  ativas.value.forEach(c => {
    const key = c.user_id || 'sem_responsavel'
    if (!groups[key]) groups[key] = { id: key, nome: c.user_id ? (agentsById.value[c.user_id] || `Usuário #${c.user_id}`) : 'Não atribuído', total: 0 }
    groups[key].total += 1
  })
  return Object.values(groups).sort((a, b) => b.total - a.total)
})

const inativasPorStatus = computed(() => {
  return Object.entries(INACTIVE_STATUS_LABELS).map(([status, label]) => ({
    status, label, total: countByStatus(inativas.value, status),
  }))
})

// Tarefas atrasadas por consultor (briefing seção 24/28.5) — pra gerência
// cobrar time. "Atrasada" aqui é vencimento_em no passado, mesmo critério de
// TarefasView.vue (grupo "Atrasadas"), não o status de régua "atrasada".
const tarefasAtrasadasPorConsultor = computed(() => {
  const agora = Date.now()
  const groups = {}
  tarefas.value.forEach(t => {
    if (!t.vencimento_em || new Date(t.vencimento_em).getTime() >= agora) return
    const key = t.user_id || 'sem_responsavel'
    if (!groups[key]) groups[key] = { id: key, nome: t.user_id ? (agentsById.value[t.user_id] || `Usuário #${t.user_id}`) : 'Não atribuído', total: 0 }
    groups[key].total += 1
  })
  return Object.values(groups).sort((a, b) => b.total - a.total)
})

const maxAtivasPorConsultor = computed(() => Math.max(1, ...ativasPorConsultor.value.map(g => g.total)))
const maxInativasPorStatus = computed(() => Math.max(1, ...inativasPorStatus.value.map(g => g.total)))
const maxTarefasAtrasadas = computed(() => Math.max(1, ...tarefasAtrasadasPorConsultor.value.map(g => g.total)))

const fetchTarefas = async () => {
  try {
    const { data } = await api.get('/tarefas', { params: { status: 'pendente' } })
    tarefas.value = data
  } catch (e) {
    console.error('Erro ao buscar tarefas:', e)
  }
}

onMounted(async () => {
  isLoading.value = true
  try {
    if (!contactsStore.isLoadedOnce) await contactsStore.fetchContacts()
    if (!convStore.agents.length) await convStore.fetchAgents()
    await fetchTarefas()
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <div class="gerencial-page">
    <div class="page-header">
      <h1>Visão Gerencial</h1>
      <p>Panorama consolidado da carteira de revendedoras</p>
    </div>

    <div v-if="!isLoading" class="summary-grid">
      <div v-for="card in summaryCards" :key="card.label" class="summary-card" :class="'tone-' + card.tone">
        <span class="summary-value">{{ card.value }}</span>
        <span class="summary-label">{{ card.label }}</span>
      </div>
    </div>

    <div v-if="!isLoading" class="panels-grid">
      <div class="panel">
        <h2>Ativas por consultor</h2>
        <div v-if="ativasPorConsultor.length" class="bar-list">
          <div v-for="g in ativasPorConsultor" :key="g.id" class="bar-row">
            <span class="bar-label">{{ g.nome }}</span>
            <div class="bar-track">
              <div class="bar-fill" :style="{ width: (g.total / maxAtivasPorConsultor * 100) + '%' }"></div>
            </div>
            <span class="bar-value">{{ g.total }}</span>
          </div>
        </div>
        <p v-else class="empty-text">Nenhuma revendedora ativa ainda.</p>
      </div>

      <div class="panel">
        <h2>Inativas por status</h2>
        <div class="bar-list">
          <div v-for="g in inativasPorStatus" :key="g.status" class="bar-row">
            <span class="bar-label">{{ g.label }}</span>
            <div class="bar-track">
              <div class="bar-fill muted" :style="{ width: (g.total / maxInativasPorStatus * 100) + '%' }"></div>
            </div>
            <span class="bar-value">{{ g.total }}</span>
          </div>
        </div>
      </div>

      <div class="panel">
        <h2>Tarefas atrasadas por consultor</h2>
        <div v-if="tarefasAtrasadasPorConsultor.length" class="bar-list">
          <div v-for="g in tarefasAtrasadasPorConsultor" :key="g.id" class="bar-row">
            <span class="bar-label">{{ g.nome }}</span>
            <div class="bar-track">
              <div class="bar-fill danger" :style="{ width: (g.total / maxTarefasAtrasadas * 100) + '%' }"></div>
            </div>
            <span class="bar-value">{{ g.total }}</span>
          </div>
        </div>
        <p v-else class="empty-text">Nenhuma tarefa atrasada.</p>
      </div>
    </div>

    <div v-else class="empty-state"><p>Carregando dados gerenciais...</p></div>
  </div>
</template>

<style lang="scss" scoped>
.gerencial-page {
  padding: 1.5rem 2rem;
  height: 100%;
  overflow-y: auto;
}

.page-header {
  margin-bottom: 1.25rem;

  h1 { font-size: 1.35rem; font-weight: 700; color: var(--text-main); }
  p { font-size: 0.85rem; color: var(--text-muted); margin-top: 0.25rem; }
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}

.summary-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;

  .summary-value { font-size: 1.6rem; font-weight: 800; color: var(--text-main); }
  .summary-label { font-size: 0.78rem; color: var(--text-muted); }

  &.tone-primary .summary-value { color: var(--primary); }
  &.tone-danger .summary-value { color: #dc2626; }
  &.tone-success .summary-value { color: #059669; }
  &.tone-warn .summary-value { color: #d97706; }
}

.panels-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 1rem;
}

.panel {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  padding: 1.25rem;

  h2 { font-size: 0.95rem; font-weight: 700; color: var(--text-main); margin-bottom: 1rem; }
}

.bar-list {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.bar-row {
  display: grid;
  grid-template-columns: 130px 1fr 30px;
  align-items: center;
  gap: 0.6rem;
  font-size: 0.8rem;
}

.bar-label {
  color: var(--text-main);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.bar-track {
  height: 8px;
  background: var(--bg-tertiary);
  border-radius: 4px;
  overflow: hidden;
}

.bar-fill {
  height: 100%;
  background: var(--primary);
  border-radius: 4px;
  transition: width 0.3s;

  &.muted { background: #9ca3af; }
  &.danger { background: #dc2626; }
}

.bar-value {
  text-align: right;
  font-weight: 700;
  color: var(--text-main);
}

.empty-text {
  font-size: 0.85rem;
  color: var(--text-muted);
}

.empty-state {
  padding: 3rem 1.5rem;
  text-align: center;
  color: var(--text-muted);
}
</style>
