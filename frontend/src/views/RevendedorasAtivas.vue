<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Search, Users, Clock, AlertTriangle, X, MessageCircle } from '@lucide/vue'
import Swal from 'sweetalert2'
import api from '../api'
import { useContactsStore } from '../store/contacts'
import { useConversationsStore } from '../store/conversations'
import { ACTIVE_STATUS_LABELS, statusLabel } from '../constants/regua'
import { isFullPortfolio as isFullPortfolioRole } from '../config/roles'
import { nivelInfo, nivelLimpo, NIVEL_META } from '../constants/nivel'

// Tela "Minhas Revendedoras Ativas" (briefing seção 28.1) — visão de carteira/lista,
// não kanban (briefing seção 9 pede explicitamente pra não copiar o modelo de etapas
// do Kommo). O board Kanban em Kanban.vue continua existindo à parte, aprovado como
// visualização alternativa; esta tela é o padrão pedido pelo cliente pra gestão de carteira.
const router = useRouter()
const contactsStore = useContactsStore()
const convStore = useConversationsStore()

const currentUser = JSON.parse(localStorage.getItem('user') || '{}')
const isFullPortfolio = computed(() => isFullPortfolioRole(currentUser))

const isLoading = ref(true)
const searchQuery = ref('')
const activeStageFilter = ref('all')
const responsavelFilter = ref('all')
const nivelFilter = ref('all')

// Ordem fixa (do nível mais baixo pro mais alto) pra não depender da ordem
// de chegada dos dados — só entram no filtro os níveis que existem de
// verdade na carteira carregada, pra não mostrar opção vazia.
const NIVEL_ORDEM = ['Pré-consignado', 'Consignado', 'Safira', 'Rubi', 'Esmeralda', 'Diamante']
const nivelOptions = computed(() => {
  const presentes = new Set(activeContacts.value.map(c => nivelLimpo(c.nivel)).filter(Boolean))
  const ordenados = NIVEL_ORDEM.filter(n => presentes.has(n))
  const outros = [...presentes].filter(n => !NIVEL_ORDEM.includes(n))
  return [
    { value: 'all', label: 'Todos os níveis' },
    ...[...ordenados, ...outros].map(n => ({ value: n, label: `${NIVEL_META[n]?.emoji || '•'} ${n}` }))
  ]
})

// Time Travel (Engine AtivasSnapshotService) — quando uma data é escolhida,
// a tela troca pro snapshot histórico reconstruído via GET /contacts/ativas.
// Como pedidos.open_at(D) não guarda a sub-etapa da régua (só "estava aberta
// em D"), o modo histórico mostra um conjunto de colunas mais enxuto.
const timeTravelDate = ref('')
const isTimeTravel = computed(() => !!timeTravelDate.value)
const snapshot = ref([])
const isSnapshotLoading = ref(false)

const fetchSnapshot = async () => {
  isSnapshotLoading.value = true
  try {
    const { data } = await api.get('/contacts/ativas', { params: { data: timeTravelDate.value } })
    snapshot.value = data.revendedoras
  } catch (e) {
    console.error('Erro ao buscar snapshot de Time Travel:', e)
    snapshot.value = []
  } finally {
    isSnapshotLoading.value = false
  }
}

watch(timeTravelDate, (val) => { if (val) fetchSnapshot() })

const stageOptions = [
  { value: 'all', label: 'Todas as etapas' },
  ...Object.entries(ACTIVE_STATUS_LABELS).map(([value, label]) => ({ value, label })),
]
const stageLabel = (status) => statusLabel(status)
const stageBadgeClass = (status) => `stage-${status || 'revendedor_ativo'}`

// "Dias com Maleta" = desde o início do ciclo ativo atual (cycle_started_at),
// não desde a última troca de sub-etapa (status_changed_at mudava a cada 3º/
// 10º/20º dia, subestimando o tempo real com a maleta).
const daysInCycle = (contact) => {
  const since = contact?.cycle_started_at || contact?.status_changed_at || contact?.created_at
  if (!since) return null
  const days = Math.floor((Date.now() - new Date(since).getTime()) / 86_400_000)
  return days >= 0 ? days : null
}

const isAtrasada = (contact) => contact.status === 'atrasada' || (daysInCycle(contact) ?? 0) > 35

// "Tempo de Revenda" (revendedoras-ativas-criterios.md) = nº de meses DISTINTOS
// com baixa de pedido — não é "desde o 1º pedido" (uma revendedora que já
// vendeu há anos mas sumiu meses no meio não deve contar como revenda contínua).

const brl = (v) => {
  const n = parseFloat(v)
  if (!n) return null
  return n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
}

const formatDate = (iso) => {
  if (!iso) return null
  const d = new Date(iso.includes('T') ? iso : `${iso}T00:00:00`)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleDateString('pt-BR')
}

// Próximo agendamento e última interação vêm prontos do backend (proximo_agendamento_em
// / ultima_interacao_em), já com hora — diferente de formatDate (só data), aqui mostra
// data + hora curta.
const formatDateTime = (iso) => {
  if (!iso) return null
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return `${d.toLocaleDateString('pt-BR')} ${d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}`
}

const agentsById = computed(() => {
  const map = {}
  ;(convStore.agents || []).forEach(a => { map[a.id] = `${a.first_name || ''} ${a.last_name || ''}`.trim() })
  return map
})
const responsavelNome = (contact) => agentsById.value[contact.user_id] || null

// "Carteira" = time de vendas do Jueri (campo "gerente" no cadastro do
// revendedor, sincronizado em custom_attributes.gerente_jueri_nome) —
// diferente do responsável direto no CRM (Contact#user_id), que é quem
// realmente atende. Pedido do cliente: essa coluna mostra o time, não o
// responsável.
const carteiraNome = (contact) => contact.custom_attributes?.gerente_jueri_nome || null

const responsavelOptions = computed(() => [
  { value: 'all', label: 'Todos os responsáveis' },
  { value: 'none', label: 'Sem responsável' },
  ...(convStore.agents || []).map(a => ({ value: a.id, label: `${a.first_name || ''} ${a.last_name || ''}`.trim() }))
])

// Seleção em lote pra atribuir várias revendedoras de uma vez (gerente/diretoria) —
// sem isso, atribuir a carteira sincronizada do Jueri (que entra sem responsável,
// briefing seção 22) exigiria abrir modal por modal, uma a uma.
const selectedIds = ref(new Set())
const isBulkAssigning = ref(false)
const bulkAssignTarget = ref('')

const toggleSelected = (id) => {
  const next = new Set(selectedIds.value)
  next.has(id) ? next.delete(id) : next.add(id)
  selectedIds.value = next
}
const clearSelection = () => { selectedIds.value = new Set() }
const allVisibleSelected = computed(() =>
  filteredContacts.value.length > 0 && filteredContacts.value.every(c => selectedIds.value.has(c.id))
)
const toggleSelectAllVisible = () => {
  selectedIds.value = allVisibleSelected.value ? new Set() : new Set(filteredContacts.value.map(c => c.id))
}

const applyBulkAssign = async () => {
  if (!selectedIds.value.size || !bulkAssignTarget.value) return
  isBulkAssigning.value = true
  try {
    await api.patch('/contacts/bulk_assign', {
      contact_ids: [...selectedIds.value],
      user_id: bulkAssignTarget.value === 'null' ? null : bulkAssignTarget.value
    })
    await contactsStore.fetchContacts()
    clearSelection()
    bulkAssignTarget.value = ''
  } catch (e) {
    console.error('Erro ao atribuir em lote:', e)
  } finally {
    isBulkAssigning.value = false
  }
}

// Próxima tarefa pendente por revendedora (Motor de Tarefas real, não mais
// derivado) — um GET só, indexado por contact_id.
const tarefasByContact = ref({})
const fetchTarefas = async () => {
  try {
    const { data } = await api.get('/tarefas', { params: { status: 'pendente' } })
    const map = {}
    data.forEach(t => { if (!map[t.contact_id]) map[t.contact_id] = t })
    tarefasByContact.value = map
  } catch (e) {
    console.error('Erro ao buscar tarefas:', e)
  }
}
const proximaTarefa = (contact) => tarefasByContact.value[contact.id]?.titulo || null

// "Ativa" = tem pedido em aberto (régua 3º/10º/20º/agendado/reagendar/atrasada) — hoje
// aproximado pelo campo status já usado no Kanban. Revendedoras em status de inativa
// (briefing seção 14) ficam de fora, veja a tela "Revendedoras Inativas".
const activeStatuses = Object.keys(ACTIVE_STATUS_LABELS)

const activeContacts = computed(() => contactsStore.contacts.filter(c => activeStatuses.includes(c.status || 'revendedor_ativo')))

const filteredContacts = computed(() => {
  let list = activeContacts.value

  if (activeStageFilter.value !== 'all') {
    list = list.filter(c => (c.status || 'revendedor_ativo') === activeStageFilter.value)
  }

  if (isFullPortfolio.value && responsavelFilter.value === 'none') {
    list = list.filter(c => !c.user_id)
  } else if (isFullPortfolio.value && responsavelFilter.value !== 'all') {
    list = list.filter(c => c.user_id === responsavelFilter.value)
  }

  if (nivelFilter.value !== 'all') {
    list = list.filter(c => nivelLimpo(c.nivel) === nivelFilter.value)
  }

  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(c =>
      (c.name || `${c.first_name || ''} ${c.last_name || ''}`).toLowerCase().includes(q) ||
      (c.phone || '').includes(q)
    )
  }

  return [...list].sort((a, b) => (daysInCycle(b) ?? 0) - (daysInCycle(a) ?? 0))
})

const filteredSnapshot = computed(() => {
  let list = snapshot.value
  if (isFullPortfolio.value && responsavelFilter.value === 'none') {
    list = list.filter(c => !c.user_id)
  } else if (isFullPortfolio.value && responsavelFilter.value !== 'all') {
    list = list.filter(c => c.user_id === responsavelFilter.value)
  }
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(c => (c.name || '').toLowerCase().includes(q) || (c.phone || '').includes(q))
  }
  return list
})

// Valor real da carteira em aberto — vem de valor_aberto (soma dos pedidos
// abertos sincronizados do Jueri, calculada no backend). Antes somava
// custom_attributes.venda, um campo de texto livre nunca preenchido por
// ninguém (por isso sempre aparecia R$ 0,00 aqui).
const totalValor = computed(() => filteredContacts.value.reduce((s, c) => s + (parseFloat(c.valor_aberto) || 0), 0))

const openContact = (contact) => router.push(`/contatos/${contact.id}`)

const isStartingConversation = ref(null)
const startConversation = async (contact) => {
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
  <div class="revendedoras-page">
    <div class="page-header">
      <div class="title-block">
        <h1>Minhas Revendedoras Ativas</h1>
        <p v-if="isTimeTravel">Snapshot de {{ formatDate(timeTravelDate) }} — {{ filteredSnapshot.length }} revendedora{{ filteredSnapshot.length === 1 ? '' : 's' }} ativa{{ filteredSnapshot.length === 1 ? '' : 's' }} naquela data</p>
        <p v-else>Carteira de revendedoras em ciclo consignado — {{ filteredContacts.length }} ativa{{ filteredContacts.length === 1 ? '' : 's' }}, {{ brl(totalValor) || 'R$ 0,00' }} em maleta aberta</p>
      </div>
    </div>

    <div class="toolbar">
      <div class="search-box">
        <Search class="icon-sm" />
        <input v-model="searchQuery" type="text" placeholder="Buscar por nome ou telefone..." />
      </div>
      <select v-if="isFullPortfolio" v-model="responsavelFilter" class="responsavel-select">
        <option v-for="opt in responsavelOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <select v-if="!isTimeTravel" v-model="nivelFilter" class="responsavel-select">
        <option v-for="opt in nivelOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <div class="time-travel-box">
        <Clock class="icon-sm" />
        <input type="date" v-model="timeTravelDate" :max="new Date().toISOString().slice(0,10)" />
        <button v-if="isTimeTravel" class="clear-tt-btn" title="Voltar para hoje" @click="timeTravelDate = ''"><X class="icon-xs" /></button>
      </div>
      <div class="stage-chips" v-if="!isTimeTravel">
        <button
          v-for="opt in stageOptions"
          :key="opt.value"
          class="stage-chip"
          :class="{ active: activeStageFilter === opt.value }"
          @click="activeStageFilter = opt.value"
        >
          {{ opt.label }}
        </button>
      </div>
    </div>

    <div v-if="isFullPortfolio && selectedIds.size > 0 && !isTimeTravel" class="bulk-bar">
      <span>{{ selectedIds.size }} selecionada{{ selectedIds.size === 1 ? '' : 's' }}</span>
      <select v-model="bulkAssignTarget" class="responsavel-select">
        <option value="" disabled>Atribuir para...</option>
        <option value="null">Sem responsável</option>
        <option v-for="a in convStore.agents" :key="a.id" :value="a.id">{{ `${a.first_name || ''} ${a.last_name || ''}`.trim() }}</option>
      </select>
      <button class="btn-primary-sm" :disabled="!bulkAssignTarget || isBulkAssigning" @click="applyBulkAssign">
        {{ isBulkAssigning ? 'Aplicando...' : 'Aplicar' }}
      </button>
      <button class="btn-text" @click="clearSelection">Cancelar</button>
    </div>

    <p v-if="isTimeTravel" class="time-travel-note">
      Mostrando o snapshot reconstruído de <strong>{{ formatDate(timeTravelDate) }}</strong> — etapa da régua e tarefas não se aplicam a datas passadas, só o volume de peças em aberto naquele momento.
    </p>

    <!-- Modo Time Travel: colunas mais enxutas, vindas de AtivasSnapshotService -->
    <div class="table-wrapper" v-if="isTimeTravel">
      <table v-if="!isSnapshotLoading && filteredSnapshot.length > 0" class="revendedoras-table">
        <thead>
          <tr>
            <th>Revendedora</th>
            <th>Telefone</th>
            <th>Peças em aberto</th>
            <th>Pedidos abertos</th>
            <th>Responsável</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in filteredSnapshot" :key="c.id" @click="openContact(c)">
            <td class="cell-name">
              <div class="row-avatar">{{ (c.name || '?').charAt(0).toUpperCase() }}</div>
              <span>{{ c.name || 'Sem nome' }}</span>
            </td>
            <td>{{ c.phone || '...' }}</td>
            <td>{{ c.pecas_abertas }}</td>
            <td>{{ c.pedidos_abertos_count }}</td>
            <td>{{ agentsById[c.user_id] || 'Não atribuído' }}</td>
          </tr>
        </tbody>
      </table>
      <div v-else-if="isSnapshotLoading" class="empty-state"><p>Reconstruindo snapshot...</p></div>
      <div v-else class="empty-state">
        <div class="empty-icon"><Clock :size="28" /></div>
        <h3>Nenhuma revendedora ativa nessa data</h3>
        <p>Ninguém tinha peças em aberto acima do limiar em {{ formatDate(timeTravelDate) }}.</p>
      </div>
    </div>

    <!-- Modo normal (hoje): dados completos, filtros de etapa -->
    <div class="table-wrapper" v-else>
      <table v-if="!isLoading && filteredContacts.length > 0" class="revendedoras-table">
        <thead>
          <tr>
            <th v-if="isFullPortfolio" class="cell-check"><input type="checkbox" :checked="allVisibleSelected" @click.stop="toggleSelectAllVisible" /></th>
            <th class="cell-name">Revendedora</th>
            <th class="cell-nivel">Nível</th>
            <th class="cell-etapa">Etapa</th>
            <th class="cell-tarefa">Tarefa</th>
            <th class="cell-dias">Dias maleta</th>
            <th class="cell-pecas">Peças aberto</th>
            <th class="cell-valor">Valor aberto</th>
            <th class="cell-previsao">Previsão acerto</th>
            <th class="cell-agendamento">Agendamento</th>
            <th class="cell-interacao">Interação</th>
            <th class="cell-alerta">Alerta</th>
            <th class="cell-carteira">Carteira</th>
            <th class="cell-acao">Ação</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in filteredContacts" :key="c.id" @click="openContact(c)" :class="{ 'row-atrasada': isAtrasada(c) }">
            <td v-if="isFullPortfolio" class="cell-check" @click.stop>
              <input type="checkbox" :checked="selectedIds.has(c.id)" @change="toggleSelected(c.id)" />
            </td>
            <td class="cell-name">
              <div class="row-avatar">{{ (c.name || c.first_name || '?').charAt(0).toUpperCase() }}</div>
              <span>{{ c.name || `${c.first_name || ''} ${c.last_name || ''}`.trim() || 'Sem nome' }}</span>
            </td>
            <td class="cell-nivel">
              <span
                v-if="c.nivel"
                class="nivel-badge"
                :style="{ color: nivelInfo(c.nivel).color, backgroundColor: nivelInfo(c.nivel).bg }"
              >{{ nivelInfo(c.nivel).emoji }} {{ nivelInfo(c.nivel).nome }}</span>
              <span v-else>...</span>
            </td>
            <td class="cell-etapa"><span class="stage-badge" :class="stageBadgeClass(c.status)">{{ stageLabel(c.status) }}</span></td>
            <td class="cell-tarefa">{{ proximaTarefa(c) || '—' }}</td>
            <td class="cell-dias">{{ daysInCycle(c) !== null ? daysInCycle(c) + ' dias' : '...' }}</td>
            <td class="cell-pecas">{{ c.pecas_abertas_atual ?? '...' }}</td>
            <td class="cell-valor">{{ brl(c.valor_aberto) || '—' }}</td>
            <td class="cell-previsao">{{ formatDate(c.data_prevista_acerto) || '—' }}</td>
            <td class="cell-agendamento">{{ formatDateTime(c.proximo_agendamento_em) || '—' }}</td>
            <td class="cell-interacao">{{ formatDateTime(c.ultima_interacao_em) || '—' }}</td>
            <td class="cell-alerta">
              <span v-if="isAtrasada(c)" class="alerta-badge"><AlertTriangle class="icon-xxs" /> Atrasada</span>
              <span v-else class="alerta-ok">Em dia</span>
            </td>
            <td class="cell-carteira">{{ carteiraNome(c) || 'Sem time' }}</td>
            <td class="cell-acao" @click.stop>
              <button
                class="btn-start-conversation"
                :disabled="isStartingConversation === c.id"
                @click="startConversation(c)"
                title="Iniciar conversa no WhatsApp"
              >
                <MessageCircle class="icon-xs" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>

      <div v-else-if="isLoading" class="empty-state">
        <p>Carregando carteira...</p>
      </div>

      <div v-else class="empty-state">
        <div class="empty-icon"><Users :size="28" /></div>
        <h3>Nenhuma revendedora ativa encontrada</h3>
        <p>Ajuste os filtros ou aguarde novas revendedoras entrarem em ciclo.</p>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.revendedoras-page {
  // Padding lateral enxuto — com 13 colunas de dado, cada cm de largura
  // conta; 2rem de "parede" de cada lado tirava ~64px que fariam falta
  // pra tabela caber sem quebrar palavra no cabeçalho.
  padding: 1.25rem 0.9rem;
  height: 100%;
  overflow-y: auto;
}

.page-header {
  margin-bottom: 1.25rem;

  h1 {
    font-size: 1.35rem;
    font-weight: 700;
    color: var(--text-main);
  }

  p {
    font-size: 0.85rem;
    color: var(--text-muted);
    margin-top: 0.25rem;
  }
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

.bulk-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  background: var(--bg-secondary);
  border: 1px solid var(--primary, #ff007f);
  border-radius: 8px;
  padding: 0.6rem 0.9rem;
  margin-bottom: 1rem;
  font-size: 0.85rem;
  color: var(--text-main);
}

.btn-primary-sm {
  background: var(--primary, #ff007f);
  color: #fff;
  border: none;
  border-radius: 6px;
  padding: 0.4rem 0.9rem;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  &:disabled { opacity: 0.5; cursor: not-allowed; }
}

.btn-text {
  background: none;
  border: none;
  color: var(--text-muted);
  font-size: 0.8rem;
  cursor: pointer;
  &:hover { color: var(--text-main); }
}

.cell-check {
  width: 2rem;
  text-align: center;
}

.time-travel-box {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.4rem 0.6rem;

  .icon-sm { width: 16px; height: 16px; color: var(--text-muted); }

  input[type="date"] {
    border: none;
    outline: none;
    background: transparent;
    color: var(--text-main);
    font-size: 0.82rem;
  }

  .clear-tt-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-tertiary);
    border: none;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    cursor: pointer;
    color: var(--text-muted);
    &:hover { background: var(--bg-hover); }
  }
}

.time-travel-note {
  font-size: 0.8rem;
  color: var(--text-muted);
  background: var(--bg-tertiary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.6rem 0.9rem;
  margin-bottom: 1rem;

  strong { color: var(--text-main); }
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
  // Sem borda/raio lateral: numa tabela de 13 colunas, o "quadro" em
  // volta só rouba largura sem ajudar em nada — deixa a tabela usar o
  // espaço disponível até a borda da tela em vez de ficar "encaixotada".
  border-top: 1px solid var(--border-color);
  border-bottom: 1px solid var(--border-color);
  border-radius: 0;
  // Cliente pediu pra caber todas as colunas na tela sem precisar dar
  // zoom out no navegador (antes só resolvia com rolagem horizontal, que
  // ele não queria). Solução: table-layout: fixed com largura por coluna
  // (abaixo) + quebra de linha no texto em vez de cortar/rolar — troca
  // linha mais alta por não perder nenhuma coluna de vista.
  overflow-x: hidden;
}

.revendedoras-table {
  width: 100%;
  table-layout: fixed;
  border-collapse: collapse;
  font-size: 0.78rem;

  thead th {
    text-align: left;
    padding: 0.55rem 0.4rem;
    font-size: 0.64rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.01em;
    color: var(--text-muted);
    background: var(--bg-tertiary);
    border-bottom: 1px solid var(--border-color);
    // keep-all em vez de break-word: quebra só entre palavras, nunca no
    // meio de uma palavra (era isso que deixava "AGENDAMENTO" e "AÇÃO"
    // cortados de um jeito feio/ilegível).
    word-break: keep-all;
    overflow-wrap: normal;
  }

  .cell-check { width: 2.2%; }
  .cell-name { width: 13.5%; }
  .cell-nivel { width: 7.5%; }
  .cell-etapa { width: 6.5%; }
  .cell-tarefa { width: 10.5%; }
  .cell-dias { width: 6.5%; }
  .cell-pecas { width: 5.5%; }
  .cell-valor { width: 7.5%; }
  .cell-previsao { width: 7%; }
  .cell-agendamento { width: 7.5%; }
  .cell-interacao { width: 7.5%; }
  .cell-alerta { width: 5.5%; }
  .cell-carteira { width: 6.5%; }
  .cell-acao { width: 3.7%; text-align: center; }

  tbody tr {
    cursor: pointer;
    transition: background 0.15s;
    border-bottom: 1px solid var(--border-color);

    &:hover { background: var(--bg-hover); }
    &:last-child { border-bottom: none; }

    &.row-atrasada { background: rgba(239, 68, 68, 0.05); }
  }

  td {
    padding: 0.5rem 0.4rem;
    color: var(--text-main);
    // Quebra em vez de cortar/rolar — é o que garante que as 13 colunas
    // cabem na largura da tela (pedido do cliente).
    white-space: normal;
    word-break: keep-all;
    overflow-wrap: normal;
  }

  td.cell-name {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 600;
  }

  .nivel-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.2rem;
    font-size: 0.66rem;
    font-weight: 700;
    padding: 0.15rem 0.4rem;
    border-radius: 20px;
    white-space: nowrap;
  }

  .cell-tarefa {
    font-size: 0.76rem;
    color: var(--text-muted);
  }

  .row-avatar {
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: var(--primary);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.8rem;
    font-weight: 700;
    flex-shrink: 0;
  }
}

.stage-badge {
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.25rem 0.6rem;
  border-radius: 20px;
  white-space: nowrap;

  &.stage-revendedor_ativo { background: #e0e7ff; color: #3730a3; }
  &.stage-terceiro_dia { background: #fef3c7; color: #92400e; }
  &.stage-decimo_dia { background: #fde68a; color: #92400e; }
  &.stage-vigesimo_dia { background: #fed7aa; color: #9a3412; }
  &.stage-agendado { background: #d1fae5; color: #065f46; }
  &.stage-reagendar { background: #ede9fe; color: #5b21b6; }
  &.stage-atrasada { background: #fee2e2; color: #991b1b; }
}

.alerta-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.25rem 0.55rem;
  border-radius: 20px;
  background: #fee2e2;
  color: #991b1b;
  white-space: nowrap;

  .icon-xxs { width: 12px; height: 12px; }
}

.alerta-ok {
  font-size: 0.78rem;
  color: var(--text-muted);
}

.btn-start-conversation {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
  color: var(--primary);
  cursor: pointer;

  &:hover:not(:disabled) { background: var(--primary); color: white; }
  &:disabled { opacity: 0.5; cursor: not-allowed; }
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

  h3 {
    font-size: 1rem;
    font-weight: 700;
    color: var(--text-main);
    margin-bottom: 0.4rem;
  }

  p { font-size: 0.85rem; }
}
</style>
