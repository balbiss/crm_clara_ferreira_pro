<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search, ListChecks, Check, MessageCircle } from '@lucide/vue'
import api from '../api'
import Swal from 'sweetalert2'
import { useConversationsStore } from '../store/conversations'

// Tela de Tarefas (briefing seção 28.4). Antes as tarefas eram DERIVADAS em
// tempo real (status + dias no ciclo, sem persistir nada) — não dava pra
// marcar "concluída" de verdade nem auditar quem fez o quê. Agora consome o
// motor de tarefas real (model Tarefa, criado automaticamente pelo
// ReguaAutoAdvanceJob na transição de status).
const PRIORITY_LABELS = { urgente: 'Urgente', alta: 'Alta', normal: 'Normal' }

const router = useRouter()
const convStore = useConversationsStore()

const isLoading = ref(true)
const isCompleting = ref(null)
const searchQuery = ref('')
const responsavelFilter = ref('all')
const priorityFilter = ref('all')
const groupFilter = ref('all')
const tarefas = ref([])

const priorityOptions = [
  { value: 'all', label: 'Todas as prioridades' },
  { value: 'urgente', label: 'Urgente' },
  { value: 'alta', label: 'Alta' },
  { value: 'normal', label: 'Normal' },
]

const groupOptions = [
  { value: 'all', label: 'Todas' },
  { value: 'atrasadas', label: 'Atrasadas' },
  { value: 'hoje', label: 'Hoje' },
  { value: 'amanha', label: 'Amanhã' },
  { value: 'depois', label: 'Mais adiante' },
]

const agentsById = computed(() => {
  const map = {}
  ;(convStore.agents || []).forEach(a => { map[a.id] = `${a.first_name || ''} ${a.last_name || ''}`.trim() })
  return map
})

const daysInCycle = (t) => {
  if (!t.created_at) return null
  const days = Math.floor((Date.now() - new Date(t.created_at).getTime()) / 86_400_000)
  return days >= 0 ? days : null
}

// Antes só listava responsáveis que já tinham alguma tarefa (quase ninguém,
// já que a maioria das tarefas nasce "Não atribuído" — mesmo achado da
// atribuição de carteira: quase nenhum Contact#user_id preenchido ainda).
// Lista todos os agentes de verdade + opção "Não atribuído", mesmo padrão já
// usado no filtro de responsável de RevendedorasAtivas.vue.
const responsavelOptions = computed(() => [
  { value: 'all', label: 'Todos os responsáveis' },
  { value: 'none', label: 'Não atribuído' },
  ...(convStore.agents || []).map(a => ({ value: a.id, label: `${a.first_name || ''} ${a.last_name || ''}`.trim() })),
])

const filteredTasks = computed(() => {
  let list = tarefas.value

  if (responsavelFilter.value === 'none') {
    list = list.filter(t => !t.user_id)
  } else if (responsavelFilter.value !== 'all') {
    list = list.filter(t => t.user_id === responsavelFilter.value)
  }

  if (priorityFilter.value !== 'all') {
    list = list.filter(t => t.prioridade === priorityFilter.value)
  }

  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(t => {
      const c = t.contact || {}
      return (c.name || '').toLowerCase().includes(q) || (c.phone || '').includes(q)
    })
  }

  return list
})

// Lista/checklist tipo agenda, agrupada por vencimento_em (pedido explícito
// do cliente: "saber quais são as tarefas de hoje, atrasadas, e de amanhã").
// Tarefa criada pelo ReguaAutoAdvanceJob sempre nasce com vencimento_em =
// agora (já vencida no instante em que aparece — é uma régua reativa, não
// agendada com antecedência), por isso a maioria cai em "Atrasadas"/"Hoje".
// "Amanhã" existe pra tarefas manuais criadas com prazo futuro
// (TarefasController#create, gerente/diretoria) e pro dia seguinte virar
// "Hoje" sozinho sem precisar recarregar a tela numa data errada.
const startOfDay = (d) => { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
const todayStart = computed(() => startOfDay(new Date()))
const tomorrowStart = computed(() => { const d = new Date(todayStart.value); d.setDate(d.getDate() + 1); return d })
const dayAfterTomorrowStart = computed(() => { const d = new Date(tomorrowStart.value); d.setDate(d.getDate() + 1); return d })

const taskGroups = computed(() => {
  const groups = { atrasadas: [], hoje: [], amanha: [], depois: [] }
  filteredTasks.value.forEach(t => {
    const venc = t.vencimento_em ? new Date(t.vencimento_em) : null
    if (!venc || venc < todayStart.value) groups.atrasadas.push(t)
    else if (venc < tomorrowStart.value) groups.hoje.push(t)
    else if (venc < dayAfterTomorrowStart.value) groups.amanha.push(t)
    else groups.depois.push(t)
  })
  return [
    { key: 'atrasadas', label: 'Atrasadas', items: groups.atrasadas },
    { key: 'hoje', label: 'Hoje', items: groups.hoje },
    { key: 'amanha', label: 'Amanhã', items: groups.amanha },
    { key: 'depois', label: 'Mais adiante', items: groups.depois }
  ]
    .filter(g => groupFilter.value === 'all' || g.key === groupFilter.value)
    .filter(g => g.items.length > 0)
})

const visibleTasksCount = computed(() => taskGroups.value.reduce((s, g) => s + g.items.length, 0))

const openContact = (contact) => contact && router.push(`/contatos/${contact.id}`)

const isStartingConversation = ref(null)
const startConversation = async (contact) => {
  if (!contact) return
  isStartingConversation.value = contact.id
  try {
    const conv = await convStore.startConversation(contact.id)
    router.push(`/conversas?abrir=${conv.id}`)
  } catch (e) {
    console.error('Erro ao iniciar conversa:', e)
    const msg = e.response?.data?.message || 'Erro ao iniciar conversa.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 3500 })
  } finally {
    isStartingConversation.value = null
  }
}

const fetchTarefas = async () => {
  isLoading.value = true
  try {
    const { data } = await api.get('/tarefas', { params: { status: 'pendente' } })
    tarefas.value = data
  } catch (e) {
    console.error('Erro ao buscar tarefas:', e)
  } finally {
    isLoading.value = false
  }
}

const completeTask = async (t) => {
  isCompleting.value = t.id
  try {
    await api.patch(`/tarefas/${t.id}/complete`)
    tarefas.value = tarefas.value.filter(x => x.id !== t.id)
  } catch (e) {
    console.error('Erro ao concluir tarefa:', e)
  } finally {
    isCompleting.value = null
  }
}

onMounted(async () => {
  await fetchTarefas()
  if (!convStore.agents.length) await convStore.fetchAgents()
})
</script>

<template>
  <div class="tarefas-page">
    <div class="page-header">
      <div class="title-block">
        <h1>Tarefas</h1>
        <p>{{ visibleTasksCount }} tarefa{{ visibleTasksCount === 1 ? '' : 's' }} pendente{{ visibleTasksCount === 1 ? '' : 's' }}, geradas automaticamente pela régua do ciclo</p>
      </div>
    </div>

    <div class="toolbar">
      <div class="search-box">
        <Search class="icon-sm" />
        <input v-model="searchQuery" type="text" placeholder="Buscar por nome ou telefone..." />
      </div>
      <select v-model="responsavelFilter" class="responsavel-select">
        <option v-for="opt in responsavelOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <select v-model="priorityFilter" class="responsavel-select">
        <option v-for="opt in priorityOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <div class="stage-chips">
        <button
          v-for="opt in groupOptions"
          :key="opt.value"
          class="stage-chip"
          :class="{ active: groupFilter === opt.value }"
          @click="groupFilter = opt.value"
        >
          {{ opt.label }}
        </button>
      </div>
    </div>

    <div v-if="!isLoading && filteredTasks.length > 0" class="agenda">
      <div v-for="group in taskGroups" :key="group.key" class="agenda-group">
        <h2 class="agenda-group-title" :class="'group-' + group.key">
          {{ group.label }}
          <span class="agenda-group-count">{{ group.items.length }}</span>
        </h2>
        <div class="tasks-list">
          <div v-for="t in group.items" :key="t.id" class="task-row" :class="'priority-' + t.prioridade">
            <div class="task-header" @click="openContact(t.contact)">
              <div class="row-avatar">{{ (t.contact?.name || '?').charAt(0).toUpperCase() }}</div>
              <div class="task-info">
                <span class="task-name">{{ t.contact?.name || 'Sem nome' }}</span>
                <span class="task-title">{{ t.titulo }}</span>
              </div>
              <span class="priority-badge">{{ PRIORITY_LABELS[t.prioridade] }}</span>
            </div>
            <ul class="task-checklist">
              <li v-for="(item, idx) in (t.descricao || '').split('\n')" :key="idx">{{ item }}</li>
            </ul>
            <div class="task-footer">
              <span>{{ agentsById[t.user_id] || 'Não atribuído' }}</span>
              <span v-if="daysInCycle(t) !== null">{{ daysInCycle(t) }} dias em aberto</span>
              <button class="whatsapp-btn" :disabled="isStartingConversation === t.contact?.id" @click="startConversation(t.contact)" title="Iniciar conversa no WhatsApp">
                <MessageCircle class="icon-xs" />
              </button>
              <button class="complete-btn" :disabled="isCompleting === t.id" @click="completeTask(t)">
                <Check class="icon-xs" /> {{ isCompleting === t.id ? 'Concluindo...' : 'Concluir' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-else-if="isLoading" class="empty-state">
      <p>Carregando tarefas...</p>
    </div>

    <div v-else class="empty-state">
      <div class="empty-icon"><ListChecks :size="28" /></div>
      <h3>Nenhuma tarefa pendente</h3>
      <p>Todas as revendedoras ativas estão em dia com a régua.</p>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.tarefas-page {
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

.responsavel-select {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-secondary);
  color: var(--text-main);
  font-size: 0.82rem;
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

.agenda-group {
  margin-bottom: 1.75rem;

  &:last-child { margin-bottom: 0; }
}

.agenda-group-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.85rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-muted);
  margin: 0 0 0.6rem;
  padding-bottom: 0.4rem;
  border-bottom: 1px solid var(--border-color);

  &.group-atrasadas { color: #ef4444; }
  &.group-hoje { color: var(--primary); }
}

.agenda-group-count {
  background: var(--bg-tertiary);
  color: var(--text-muted);
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.1rem 0.5rem;
  border-radius: 20px;

  .group-atrasadas & { background: #fee2e2; color: #991b1b; }
  .group-hoje & { background: var(--input-focus, #fce7ea); color: var(--primary); }
}

.tasks-list {
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.task-row {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-left: 4px solid var(--border-color);
  border-radius: 10px;
  padding: 0.85rem 1rem;

  &.priority-alta { border-left-color: #f59e0b; }
  &.priority-urgente { border-left-color: #ef4444; }
}

.task-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
  margin-bottom: 0.6rem;
}

.row-avatar {
  width: 34px;
  height: 34px;
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

.task-info {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;

  .task-name { font-size: 0.9rem; font-weight: 700; color: var(--text-main); }
  .task-title { font-size: 0.78rem; color: var(--text-muted); }
}

.priority-badge {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  padding: 0.2rem 0.55rem;
  border-radius: 20px;
  background: var(--bg-tertiary);
  color: var(--text-muted);
  flex-shrink: 0;

  .priority-alta & { background: #fef3c7; color: #92400e; }
  .priority-urgente & { background: #fee2e2; color: #991b1b; }
}

.task-checklist {
  list-style: none;
  padding: 0;
  margin: 0 0 0.7rem 3.1rem;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;

  li {
    font-size: 0.8rem;
    color: var(--text-main);
    position: relative;
    padding-left: 1rem;

    &::before {
      content: '';
      position: absolute;
      left: 0;
      top: 0.45rem;
      width: 5px;
      height: 5px;
      border-radius: 50%;
      background: var(--primary);
    }
  }
}

.task-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-left: 3.1rem;
  font-size: 0.75rem;
  color: var(--text-muted);
}

.whatsapp-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  margin-left: auto;
  width: 30px;
  height: 30px;
  border-radius: 6px;
  border: 1px solid var(--primary);
  background: transparent;
  color: var(--primary);
  cursor: pointer;
  transition: background 0.15s, color 0.15s;

  &:hover:not(:disabled) { background: var(--primary); color: white; }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
}

.complete-btn {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.35rem 0.7rem;
  border-radius: 6px;
  border: 1px solid var(--primary);
  background: transparent;
  color: var(--primary);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s, color 0.15s;

  &:hover:not(:disabled) { background: var(--primary); color: white; }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
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
