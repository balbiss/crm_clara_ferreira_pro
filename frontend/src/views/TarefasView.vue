<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Search, ListChecks, Check, MessageCircle, ArrowUpDown, CheckCheck, Plus, X } from '@lucide/vue'
import api from '../api'
import Swal from 'sweetalert2'
import { useConversationsStore } from '../store/conversations'

// Tela de Tarefas (briefing seção 28.4). Antes as tarefas eram DERIVADAS em
// tempo real (status + dias no ciclo, sem persistir nada) — não dava pra
// marcar "concluída" de verdade nem auditar quem fez o quê. Agora consome o
// motor de tarefas real (model Tarefa, criado automaticamente pelo
// ReguaAutoAdvanceJob na transição de status).
const PRIORITY_LABELS = { urgente: 'Urgente', alta: 'Alta', normal: 'Normal' }

// Mesma lista do backend (Tarefa::MANUAL_TIPO_LABELS) — tipo de tarefa
// escolhível ao criar manualmente ou ao criar o follow-up na conclusão
// (PDF Etapa 2, página 10: "no Kommo dava pra criar vários tipos de tarefa").
const MANUAL_TIPO_LABELS = {
  manual_ligar: 'Ligar',
  manual_mensagem: 'Enviar mensagem',
  manual_agendamento: 'Agendar acerto',
  manual_cobranca: 'Cobrança',
  manual_acompanhamento: 'Acompanhamento',
  manual_outro: 'Outro'
}
const tipoLabel = (tipo) => MANUAL_TIPO_LABELS[tipo] || null

const router = useRouter()
const convStore = useConversationsStore()

const isLoading = ref(true)
const isCompleting = ref(null)
const searchQuery = ref('')
const responsavelFilter = ref('all')
const priorityFilter = ref('all')
const groupFilter = ref('all')
const carteiraFilter = ref('all')
const tarefas = ref([])

// Aba Pendentes/Concluídas (PDF Etapa 2, página 9) — cada uma busca da API
// com um status diferente, não é filtro client-side (tarefa concluída de
// meses atrás não vem por padrão na lista de pendentes).
const viewMode = ref('pendentes')

// Ordenar por data ASC/DESC (antes não existia, era sempre a ordem que a API
// mandava) + filtro de período — ambos client-side, lista de tarefas é
// pequena o bastante pra não precisar ir pro backend.
const sortDir = ref('asc')
const dateFrom = ref('')
const dateTo = ref('')

// "Carteira" = time de vendas do Jueri (custom_attributes.gerente_jueri_nome,
// mesmo campo já usado em RevendedorasAtivas.vue) — diferente de
// responsavelFilter (Contact#user_id, atribuição manual individual, hoje
// vazia pra quase toda revendedora). Toda tarefa nasce vinculada a uma
// revendedora que já tem carteira sincronizada do Jueri, então filtrar por
// aqui é útil mesmo sem nenhuma atribuição pessoa a pessoa feita ainda.
const carteiraNome = (t) => t.contact?.custom_attributes?.gerente_jueri_nome || null

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

const formatDateTime = (iso) => {
  if (!iso) return null
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return `${d.toLocaleDateString('pt-BR')} ${d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}`
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

const carteiraOptions = computed(() => {
  const presentes = [...new Set(tarefas.value.map(carteiraNome).filter(Boolean))].sort()
  return [{ value: 'all', label: 'Todas as carteiras' }, ...presentes.map(nome => ({ value: nome, label: nome }))]
})

const filteredTasks = computed(() => {
  let list = tarefas.value

  if (carteiraFilter.value !== 'all') {
    list = list.filter(t => carteiraNome(t) === carteiraFilter.value)
  }

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

  // Filtro de período (PDF Etapa 2, página 9) — pendente filtra por
  // vencimento, concluída filtra por quando foi concluída (faz mais
  // sentido pra gerência revisar "o que foi feito entre X e Y").
  const dateField = viewMode.value === 'concluidas' ? 'concluida_em' : 'vencimento_em'
  if (dateFrom.value) {
    const from = new Date(`${dateFrom.value}T00:00:00`)
    list = list.filter(t => t[dateField] && new Date(t[dateField]) >= from)
  }
  if (dateTo.value) {
    const to = new Date(`${dateTo.value}T23:59:59`)
    list = list.filter(t => t[dateField] && new Date(t[dateField]) <= to)
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

// Ordenar por data ASC/DESC (PDF Etapa 2, página 9) — pendente ordena pelo
// vencimento, concluída pela data de conclusão.
const sortByDate = (items, field) => {
  const sorted = [...items].sort((a, b) => {
    const da = a[field] ? new Date(a[field]).getTime() : 0
    const db = b[field] ? new Date(b[field]).getTime() : 0
    return sortDir.value === 'asc' ? da - db : db - da
  })
  return sorted
}

const taskGroups = computed(() => {
  if (viewMode.value === 'concluidas') {
    return [{ key: 'concluidas', label: 'Concluídas', items: sortByDate(filteredTasks.value, 'concluida_em') }]
  }

  const groups = { atrasadas: [], hoje: [], amanha: [], depois: [] }
  filteredTasks.value.forEach(t => {
    const venc = t.vencimento_em ? new Date(t.vencimento_em) : null
    if (!venc || venc < todayStart.value) groups.atrasadas.push(t)
    else if (venc < tomorrowStart.value) groups.hoje.push(t)
    else if (venc < dayAfterTomorrowStart.value) groups.amanha.push(t)
    else groups.depois.push(t)
  })
  return [
    { key: 'atrasadas', label: 'Atrasadas', items: sortByDate(groups.atrasadas, 'vencimento_em') },
    { key: 'hoje', label: 'Hoje', items: sortByDate(groups.hoje, 'vencimento_em') },
    { key: 'amanha', label: 'Amanhã', items: sortByDate(groups.amanha, 'vencimento_em') },
    { key: 'depois', label: 'Mais adiante', items: sortByDate(groups.depois, 'vencimento_em') }
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
    const status = viewMode.value === 'concluidas' ? 'concluida' : 'pendente'
    const { data } = await api.get('/tarefas', { params: { status } })
    tarefas.value = data
  } catch (e) {
    console.error('Erro ao buscar tarefas:', e)
  } finally {
    isLoading.value = false
  }
}

watch(viewMode, () => { groupFilter.value = 'all'; fetchTarefas() })

// Modal de conclusão (PDF Etapa 2, página 9) — antes "Concluir" era 1 clique
// sem registrar nada. Agora abre um modal pra registrar o resultado (fica
// gravado, a gerente vê depois na aba Concluídas) e, opcionalmente, já criar
// o follow-up (tipo + data) na mesma hora, igual o exemplo do Kommo.
const showCompleteModal = ref(false)
const completingTask = ref(null)
const completeForm = ref({ resultado: '', criarProxima: false, proximaTipo: 'manual_ligar', proximaData: '', proximaTitulo: '' })
const isSavingComplete = ref(false)

const openCompleteModal = (t) => {
  completingTask.value = t
  const amanha = new Date(Date.now() + 86_400_000)
  amanha.setHours(9, 0, 0, 0)
  completeForm.value = {
    resultado: '',
    criarProxima: false,
    proximaTipo: 'manual_ligar',
    proximaData: amanha.toISOString().slice(0, 16),
    proximaTitulo: ''
  }
  showCompleteModal.value = true
}

const closeCompleteModal = () => {
  showCompleteModal.value = false
  completingTask.value = null
}

const confirmComplete = async () => {
  const t = completingTask.value
  if (!t) return
  isSavingComplete.value = true
  try {
    const payload = { resultado: completeForm.value.resultado.trim() || undefined }
    if (completeForm.value.criarProxima) {
      payload.proxima_tarefa = {
        tipo: completeForm.value.proximaTipo,
        titulo: completeForm.value.proximaTitulo.trim() || undefined,
        vencimento_em: completeForm.value.proximaData ? new Date(completeForm.value.proximaData).toISOString() : undefined
      }
    }
    await api.patch(`/tarefas/${t.id}/complete`, payload)
    tarefas.value = tarefas.value.filter(x => x.id !== t.id)
    closeCompleteModal()
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Tarefa concluída!', showConfirmButton: false, timer: 2500 })
  } catch (e) {
    console.error('Erro ao concluir tarefa:', e)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao concluir tarefa.', showConfirmButton: false, timer: 3000 })
  } finally {
    isSavingComplete.value = false
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
        <p v-if="viewMode === 'pendentes'">{{ visibleTasksCount }} tarefa{{ visibleTasksCount === 1 ? '' : 's' }} pendente{{ visibleTasksCount === 1 ? '' : 's' }}, geradas automaticamente pela régua do ciclo</p>
        <p v-else>{{ visibleTasksCount }} tarefa{{ visibleTasksCount === 1 ? '' : 's' }} concluída{{ visibleTasksCount === 1 ? '' : 's' }}</p>
      </div>
      <div class="view-tabs">
        <button class="view-tab" :class="{ active: viewMode === 'pendentes' }" @click="viewMode = 'pendentes'">Pendentes</button>
        <button class="view-tab" :class="{ active: viewMode === 'concluidas' }" @click="viewMode = 'concluidas'">
          <CheckCheck class="icon-xs" /> Concluídas
        </button>
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
      <select v-model="carteiraFilter" class="responsavel-select">
        <option v-for="opt in carteiraOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <div class="date-range-box">
        <input type="date" v-model="dateFrom" title="De" />
        <span>até</span>
        <input type="date" v-model="dateTo" title="Até" />
      </div>
      <button class="sort-btn" @click="sortDir = sortDir === 'asc' ? 'desc' : 'asc'" :title="sortDir === 'asc' ? 'Mais antigas primeiro' : 'Mais recentes primeiro'">
        <ArrowUpDown class="icon-xs" /> {{ sortDir === 'asc' ? 'Data ↑' : 'Data ↓' }}
      </button>
      <div class="stage-chips" v-if="viewMode === 'pendentes'">
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
              <span v-if="tipoLabel(t.tipo)" class="tipo-badge">{{ tipoLabel(t.tipo) }}</span>
              <span v-if="carteiraNome(t)" class="carteira-badge">{{ carteiraNome(t) }}</span>
              <span class="priority-badge">{{ PRIORITY_LABELS[t.prioridade] }}</span>
            </div>
            <ul class="task-checklist">
              <li v-for="(item, idx) in (t.descricao || '').split('\n')" :key="idx">{{ item }}</li>
            </ul>

            <div v-if="viewMode === 'concluidas'" class="task-resultado">
              <span class="task-resultado-label">Resultado:</span>
              <span v-if="t.resultado">{{ t.resultado }}</span>
              <span v-else class="empty-text">Nenhum resultado registrado</span>
            </div>

            <div class="task-footer">
              <span>{{ agentsById[t.user_id] || 'Não atribuído' }}</span>
              <template v-if="viewMode === 'concluidas'">
                <span v-if="t.concluida_em">Concluída em {{ formatDateTime(t.concluida_em) }}</span>
              </template>
              <template v-else>
                <span v-if="daysInCycle(t) !== null">{{ daysInCycle(t) }} dias em aberto</span>
                <button class="whatsapp-btn" :disabled="isStartingConversation === t.contact?.id" @click="startConversation(t.contact)" title="Iniciar conversa no WhatsApp">
                  <MessageCircle class="icon-xs" />
                </button>
                <button class="complete-btn" :disabled="isCompleting === t.id" @click="openCompleteModal(t)">
                  <Check class="icon-xs" /> Concluir
                </button>
              </template>
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
      <h3 v-if="viewMode === 'pendentes'">Nenhuma tarefa pendente</h3>
      <h3 v-else>Nenhuma tarefa concluída ainda</h3>
      <p v-if="viewMode === 'pendentes'">Todas as revendedoras ativas estão em dia com a régua.</p>
      <p v-else>Ajuste os filtros ou aguarde a equipe concluir alguma tarefa.</p>
    </div>

    <!-- Modal de conclusão (PDF Etapa 2, página 9) -->
    <div v-if="showCompleteModal" class="modal-backdrop" @click.self="closeCompleteModal">
      <div class="modal-card">
        <div class="modal-header">
          <h3>Concluir tarefa</h3>
          <button class="close-btn" @click="closeCompleteModal"><X class="icon-sm" /></button>
        </div>

        <form @submit.prevent="confirmComplete" class="modal-form">
          <p class="modal-context">{{ completingTask?.contact?.name || 'Sem nome' }} — {{ completingTask?.titulo }}</p>

          <div class="form-group">
            <label>Resultado</label>
            <textarea v-model="completeForm.resultado" rows="3" placeholder="Ex: Liguei, ela vai fechar até sexta"></textarea>
          </div>

          <label class="checkbox-row">
            <input type="checkbox" v-model="completeForm.criarProxima" />
            Criar próxima tarefa
          </label>

          <template v-if="completeForm.criarProxima">
            <div class="form-group">
              <label>Tipo</label>
              <select v-model="completeForm.proximaTipo">
                <option v-for="(label, tipo) in MANUAL_TIPO_LABELS" :key="tipo" :value="tipo">{{ label }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Título (opcional)</label>
              <input type="text" v-model="completeForm.proximaTitulo" :placeholder="MANUAL_TIPO_LABELS[completeForm.proximaTipo]" />
            </div>
            <div class="form-group">
              <label>Data</label>
              <input type="datetime-local" v-model="completeForm.proximaData" />
            </div>
          </template>

          <div class="modal-actions">
            <button type="button" class="btn-cancel" @click="closeCompleteModal">Cancelar</button>
            <button type="submit" class="btn-submit" :disabled="isSavingComplete">
              {{ isSavingComplete ? 'Salvando...' : 'Concluir tarefa' }}
            </button>
          </div>
        </form>
      </div>
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
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 1.25rem;

  h1 { font-size: 1.35rem; font-weight: 700; color: var(--text-main); }
  p { font-size: 0.85rem; color: var(--text-muted); margin-top: 0.25rem; }
}

.view-tabs {
  display: flex;
  gap: 0.4rem;
  background: var(--bg-tertiary);
  border-radius: 10px;
  padding: 0.25rem;
}

.view-tab {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.45rem 0.9rem;
  border-radius: 8px;
  border: none;
  background: none;
  color: var(--text-muted);
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s, color 0.15s;

  &:hover { color: var(--text-main); }
  &.active { background: var(--bg-secondary); color: var(--primary); box-shadow: 0 1px 2px rgba(43,0,22,0.08); }
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

.date-range-box {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.4rem 0.6rem;
  font-size: 0.8rem;
  color: var(--text-muted);

  input[type="date"] {
    border: none;
    outline: none;
    background: transparent;
    color: var(--text-main);
    font-size: 0.8rem;
  }
}

.sort-btn {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-secondary);
  color: var(--text-main);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;

  &:hover { background: var(--bg-hover); }
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

.carteira-badge {
  font-size: 0.7rem;
  font-weight: 600;
  padding: 0.2rem 0.55rem;
  border-radius: 20px;
  background: var(--bg-tertiary);
  color: var(--text-main);
  white-space: nowrap;
  flex-shrink: 0;
}

.tipo-badge {
  font-size: 0.7rem;
  font-weight: 600;
  padding: 0.2rem 0.55rem;
  border-radius: 20px;
  background: var(--input-focus, rgba(255, 0, 127, 0.12));
  color: var(--primary);
  white-space: nowrap;
  flex-shrink: 0;
}

.task-resultado {
  margin: 0 0 0.7rem 3.1rem;
  font-size: 0.82rem;
  color: var(--text-main);
  background: var(--bg-tertiary);
  border-radius: 8px;
  padding: 0.5rem 0.7rem;

  .task-resultado-label { font-weight: 700; color: var(--text-muted); margin-right: 0.3rem; }
  .empty-text { color: var(--text-muted); font-style: italic; }
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

.modal-backdrop {
  position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0, 0, 0, 0.4);
  display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.modal-card {
  background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px;
  width: 100%; max-width: 460px; max-height: 85vh; box-shadow: 0 20px 25px -5px rgba(43,0,22,0.15);
  overflow: hidden; display: flex; flex-direction: column;
}
.modal-header {
  display: flex; justify-content: space-between; align-items: center; padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-color); background: var(--bg-tertiary);
  h3 { font-size: 1.05rem; font-weight: 700; color: var(--text-main); margin: 0; }
  .close-btn { background: transparent; border: none; color: var(--text-muted); cursor: pointer; display: flex; &:hover { color: var(--text-main); } }
}
.modal-form { padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem; overflow-y: auto; }
.modal-context { font-size: 0.85rem; color: var(--text-muted); margin: -0.5rem 0 0; font-weight: 600; }
.form-group {
  display: flex; flex-direction: column; gap: 0.4rem;
  label { font-size: 0.85rem; font-weight: 500; color: var(--text-main); }
  input, select, textarea {
    padding: 0.65rem 0.75rem; border: 1px solid var(--border-color); background: var(--bg-primary);
    color: var(--text-main); border-radius: 6px; font-size: 0.9rem; outline: none; font-family: inherit;
    &:focus { border-color: var(--primary); }
  }
  textarea { resize: vertical; }
}
.checkbox-row {
  display: flex; align-items: center; gap: 0.5rem; font-size: 0.88rem; color: var(--text-main);
  font-weight: 500; cursor: pointer;
  input { width: 16px; height: 16px; cursor: pointer; }
}
.modal-actions {
  display: flex; justify-content: flex-end; gap: 0.75rem; margin-top: 0.5rem;
  .btn-cancel { background: var(--bg-tertiary); color: var(--text-main); border: 1px solid var(--border-color); padding: 0.55rem 1rem; border-radius: 6px; font-weight: 500; cursor: pointer; &:hover { background: var(--bg-hover); } }
  .btn-submit { background: var(--primary); color: white; border: none; padding: 0.55rem 1rem; border-radius: 6px; font-weight: 500; cursor: pointer; &:hover { background: var(--primary-hover); } &:disabled { opacity: 0.6; cursor: not-allowed; } }
}
</style>
