<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Edit2, Trash2, Lock, Unlock, ShieldAlert, RefreshCw, X, Check } from 'lucide-vue-next'

const DEPT_CONFIG = {
  corretor:    { label: 'Corretor',    color: '#4338ca', bg: 'rgba(67,56,202,0.1)' },
  suporte:     { label: 'Suporte',     color: '#059669', bg: 'rgba(5,150,105,0.1)' },
  financeiro:  { label: 'Financeiro',  color: '#d97706', bg: 'rgba(217,119,6,0.1)' },
  manutencao:  { label: 'Manutenção',  color: '#ea580c', bg: 'rgba(234,88,12,0.1)' },
}
import api from '../api'
import { useAgentsStore } from '../store/agents'
import { storeToRefs } from 'pinia'

const router = useRouter()
const agentsStore = useAgentsStore()
const { agents, isLoading } = storeToRefs(agentsStore)
const currentUser = ref(null)
const togglingId = ref(null)

const groups = ref([])
const groupsLoading = ref(false)
const newGroupName = ref('')
const editingGroupId = ref(null)
const editingGroupName = ref('')
const showGroupManager = ref(false)

const fetchAgents = () => agentsStore.fetchAgents()

const fetchGroups = async () => {
  groupsLoading.value = true
  try {
    const res = await api.get('/round_robin_groups')
    groups.value = res.data
  } catch (e) {
    console.error('Erro ao carregar grupos de rodízio', e)
  } finally {
    groupsLoading.value = false
  }
}

onMounted(() => {
  const stored = localStorage.getItem('user')
  if (stored) currentUser.value = JSON.parse(stored)
  fetchAgents()
  fetchGroups()
})

const createGroup = async () => {
  const name = newGroupName.value.trim()
  if (!name) return
  try {
    const res = await api.post('/round_robin_groups', { round_robin_group: { name } })
    groups.value.push(res.data)
    newGroupName.value = ''
  } catch (e) {
    console.error('Erro ao criar grupo', e)
  }
}

const startEditGroup = (group) => {
  editingGroupId.value = group.id
  editingGroupName.value = group.name
}

const cancelEditGroup = () => {
  editingGroupId.value = null
  editingGroupName.value = ''
}

const saveGroupName = async (group) => {
  const name = editingGroupName.value.trim()
  if (!name) return
  try {
    const res = await api.put(`/round_robin_groups/${group.id}`, { round_robin_group: { name } })
    const idx = groups.value.findIndex(g => g.id === group.id)
    if (idx !== -1) groups.value[idx] = res.data
    cancelEditGroup()
  } catch (e) {
    console.error('Erro ao renomear grupo', e)
  }
}

const deleteGroup = async (group) => {
  if (!confirm(`Excluir o grupo "${group.name}"? Os corretores e números de WhatsApp vinculados a ele voltam a usar o rodízio geral da conta.`)) return
  try {
    await api.delete(`/round_robin_groups/${group.id}`)
    groups.value = groups.value.filter(g => g.id !== group.id)
    fetchAgents()
  } catch (e) {
    console.error('Erro ao excluir grupo', e)
  }
}

const queueByGroup = computed(() => {
  const corretores = agents.value.filter(a =>
    a.available_for_roundrobin && a.status === 'active' && a.department === 'corretor'
  )
  const sortFn = (a, b) => (a.queue_position ?? 9999) - (b.queue_position ?? 9999)

  const buckets = groups.value.map(group => ({
    group,
    agents: corretores.filter(a => a.round_robin_group_id === group.id).sort(sortFn)
  }))

  const semGrupo = corretores.filter(a => !a.round_robin_group_id).sort(sortFn)
  if (semGrupo.length > 0 || groups.value.length === 0) {
    buckets.push({ group: null, agents: semGrupo })
  }

  return buckets
})

const agentQueuePosition = (agent) => {
  const bucket = queueByGroup.value.find(b => (b.group?.id ?? null) === (agent.round_robin_group_id ?? null))
  if (!bucket) return '?'
  const idx = bucket.agents.findIndex(a => a.id === agent.id)
  return idx === -1 ? '?' : idx + 1
}

const blockAgent = async (agent) => {
  if (!confirm(`Deseja bloquear ${agent.first_name}?`)) return
  try {
    await api.patch(`/agents/${agent.id}/block`)
    fetchAgents()
  } catch (e) { console.error(e) }
}

const unblockAgent = async (agent) => {
  try {
    await api.patch(`/agents/${agent.id}/unblock`)
    fetchAgents()
  } catch (e) { console.error(e) }
}

const deleteAgent = async (id) => {
  if (!confirm('Tem certeza que deseja apagar este corretor permanentemente?')) return
  try {
    await api.delete(`/agents/${id}`)
    fetchAgents()
  } catch (e) { console.error(e) }
}

const toggleRoundRobin = async (agent) => {
  togglingId.value = agent.id
  try {
    const res = await api.patch(`/agents/${agent.id}/toggle_roundrobin`)
    const idx = agents.value.findIndex(a => a.id === agent.id)
    if (idx !== -1) {
      agents.value[idx] = { ...agents.value[idx], ...res.data }
    }
  } catch (e) {
    console.error('Erro ao alterar rodízio', e)
  } finally {
    togglingId.value = null
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-content">
        <h1>Agentes (Corretores)</h1>
        <div class="header-actions">
          <button class="btn-secondary" @click="showGroupManager = !showGroupManager">
            {{ showGroupManager ? 'Fechar grupos' : 'Grupos de Rodízio' }}
          </button>
          <button class="btn-primary" @click="router.push('/agentes/novo')">
            <Plus class="icon-sm" /> Novo Agente
          </button>
        </div>
      </div>
    </div>

    <!-- Gestão de Grupos de Rodízio -->
    <div class="groups-card" v-if="showGroupManager">
      <div class="groups-header">
        <span>Grupos de Rodízio</span>
        <span class="queue-hint">Ex: Venda, Locação, Equipe do João — vincule cada número de WhatsApp a um grupo em Configurações → Canais.</span>
      </div>
      <div class="groups-list">
        <div v-for="group in groups" :key="group.id" class="group-row">
          <template v-if="editingGroupId === group.id">
            <input v-model="editingGroupName" class="group-name-input" @keyup.enter="saveGroupName(group)" @keyup.esc="cancelEditGroup" />
            <button class="btn-icon text-success" @click="saveGroupName(group)" title="Salvar"><Check class="icon-sm" /></button>
            <button class="btn-icon" @click="cancelEditGroup" title="Cancelar"><X class="icon-sm" /></button>
          </template>
          <template v-else>
            <span class="group-name">{{ group.name }}</span>
            <button class="btn-icon" @click="startEditGroup(group)" title="Renomear"><Edit2 class="icon-sm" /></button>
            <button class="btn-icon text-danger" @click="deleteGroup(group)" title="Excluir"><Trash2 class="icon-sm" /></button>
          </template>
        </div>
        <div v-if="!groupsLoading && groups.length === 0" class="text-xs text-muted">Nenhum grupo criado ainda. Sem grupos, o rodízio funciona normalmente com todos os corretores da conta.</div>
      </div>
      <div class="group-add-row">
        <input v-model="newGroupName" placeholder="Nome do novo grupo (ex: Locação)" @keyup.enter="createGroup" />
        <button class="btn-secondary" @click="createGroup"><Plus class="icon-sm" /> Adicionar</button>
      </div>
    </div>

    <!-- Fila de Rodízio -->
    <div class="queue-card" v-if="queueByGroup.some(b => b.agents.length > 0)">
      <div v-for="bucket in queueByGroup" :key="bucket.group?.id ?? 'sem-grupo'">
        <div v-if="bucket.agents.length > 0">
          <div class="queue-header">
            <RefreshCw class="icon-sm" />
            <span>Fila de Rodízio — {{ bucket.group ? bucket.group.name : 'Sem grupo (conta inteira)' }}</span>
            <span class="queue-hint">Novos leads são atribuídos ao 1º da fila</span>
          </div>
          <div class="queue-list">
            <div v-for="(agent, idx) in bucket.agents" :key="agent.id" class="queue-item">
              <span class="queue-pos">{{ idx + 1 }}º</span>
              <span class="queue-name">{{ agent.first_name }} {{ agent.last_name }}</span>
              <span v-if="idx === 0" class="queue-next-badge">próximo</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="queue-empty" v-else-if="!isLoading">
      <RefreshCw class="icon-sm" /> Nenhum agente na fila de rodízio. Ative o rodízio nos agentes abaixo.
    </div>

    <!-- Tabela de Agentes -->
    <div class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>Status</th>
            <th>Nome</th>
            <th>Departamento</th>
            <th>E-mail</th>
            <th>WhatsApp</th>
            <th>Rodízio</th>
            <th width="120">Ações</th>
          </tr>
        </thead>
        <tbody>
          <template v-if="isLoading">
            <tr v-for="i in 3" :key="'skel'+i" class="skeleton-row">
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-action"></div></td>
            </tr>
          </template>
          <tr v-else-if="agents.length === 0">
            <td colspan="7" class="text-center py-4 text-muted">Nenhum agente cadastrado.</td>
          </tr>
          <tr v-for="agent in agents" :key="agent.id" :class="{'row-blocked': agent.status === 'blocked'}">
            <td>
              <span :class="['badge', agent.status === 'blocked' ? 'badge-danger' : 'badge-success']">
                {{ agent.status === 'blocked' ? 'Bloqueado' : 'Ativo' }}
              </span>
            </td>
            <td class="font-medium">
              {{ agent.first_name }} {{ agent.last_name }}
              <div v-if="agent.role === 'empresa' || agent.role === 'admin'" class="badge-admin inline">
                <ShieldAlert class="icon-xs" /> Dono
              </div>
            </td>
            <td>
              <span
                class="dept-badge"
                :style="{
                  color: (DEPT_CONFIG[agent.department] || DEPT_CONFIG.corretor).color,
                  background: (DEPT_CONFIG[agent.department] || DEPT_CONFIG.corretor).bg
                }"
              >
                {{ (DEPT_CONFIG[agent.department] || DEPT_CONFIG.corretor).label }}
              </span>
            </td>
            <td>{{ agent.email }}</td>
            <td>{{ agent.phone || '-' }}</td>
            <td>
              <template v-if="agent.department === 'corretor' || !agent.department">
                <button
                  class="toggle-btn"
                  :class="{ 'toggle-on': agent.available_for_roundrobin, 'toggle-loading': togglingId === agent.id }"
                  :disabled="togglingId === agent.id || agent.status === 'blocked'"
                  @click="toggleRoundRobin(agent)"
                  :title="agent.available_for_roundrobin ? 'Remover da fila de rodízio' : 'Adicionar à fila de rodízio'"
                >
                  <span class="toggle-track"><span class="toggle-thumb"></span></span>
                  <span class="toggle-label">
                    {{ agent.available_for_roundrobin ? `${agentQueuePosition(agent)}º na fila` : 'Desligado' }}
                  </span>
                </button>
              </template>
              <span v-else class="text-xs text-muted">— encaminhado pela IA</span>
            </td>
            <td class="actions-cell">
              <button class="btn-icon" @click="router.push(`/agentes/${agent.id}/editar`)" title="Editar">
                <Edit2 class="icon-sm" />
              </button>
              <template v-if="currentUser && agent.id !== currentUser.id">
                <button v-if="agent.status === 'active'" class="btn-icon text-warning" @click="blockAgent(agent)" title="Bloquear">
                  <Lock class="icon-sm" />
                </button>
                <button v-else class="btn-icon text-success" @click="unblockAgent(agent)" title="Desbloquear">
                  <Unlock class="icon-sm" />
                </button>
                <button class="btn-icon text-danger" @click="deleteAgent(agent.id)" title="Excluir">
                  <Trash2 class="icon-sm" />
                </button>
              </template>
              <template v-else>
                <span class="text-xs text-muted" style="margin-left:0.5rem">(Você)</span>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  padding: 2rem;
  background: var(--bg-primary);
  height: 100%;
}

.page-header {
  margin-bottom: 1.5rem;
  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    h1 { font-size: 1.2rem; color: var(--text-main); font-weight: 500; }
  }
  .header-actions {
    display: flex;
    gap: 0.75rem;
  }
}

.btn-secondary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  background: var(--bg-secondary);
  color: var(--text-main);
  border: 1px solid var(--border-color);
  padding: 0.6rem 1rem;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  &:hover { border-color: var(--primary); color: var(--primary); }
}

.groups-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1rem 1.25rem;
  margin-bottom: 1.25rem;

  .groups-header {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--text-main);
    margin-bottom: 0.9rem;

    .queue-hint { font-weight: 400; font-size: 0.78rem; color: var(--text-muted); }
  }

  .groups-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-bottom: 0.9rem;
  }

  .group-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.4rem 0.6rem;
    border: 1px solid var(--border-color);
    border-radius: 6px;

    .group-name { flex: 1; color: var(--text-main); font-weight: 500; font-size: 0.88rem; }
    .group-name-input {
      flex: 1;
      padding: 0.35rem 0.5rem;
      border: 1px solid var(--primary);
      border-radius: 4px;
      background: var(--bg-primary);
      color: var(--text-main);
    }
  }

  .group-add-row {
    display: flex;
    gap: 0.5rem;

    input {
      flex: 1;
      padding: 0.6rem 0.75rem;
      border: 1px solid var(--border-color);
      border-radius: 6px;
      background: var(--bg-primary);
      color: var(--text-main);
      &:focus { outline: none; border-color: var(--primary); }
    }
  }
}

.queue-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-left: 4px solid #4338ca;
  border-radius: 8px;
  padding: 1rem 1.25rem;
  margin-bottom: 1.25rem;

  .queue-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--text-main);
    margin-bottom: 0.75rem;

    .queue-hint {
      font-weight: 400;
      font-size: 0.78rem;
      color: var(--text-muted);
      margin-left: auto;
    }
  }

  .queue-list {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .queue-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    background: rgba(67,56,202,0.06);
    border: 1px solid rgba(67,56,202,0.15);
    border-radius: 20px;
    padding: 0.3rem 0.75rem;
    font-size: 0.82rem;

    .queue-pos {
      font-weight: 700;
      color: #4338ca;
      min-width: 1.5rem;
    }
    .queue-name { color: var(--text-main); font-weight: 500; }
    .queue-next-badge {
      background: #4338ca;
      color: white;
      font-size: 0.65rem;
      font-weight: 700;
      padding: 0.1rem 0.4rem;
      border-radius: 6px;
      text-transform: uppercase;
      letter-spacing: 0.03em;
    }
  }
}

.queue-empty {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--text-muted);
  font-size: 0.85rem;
  margin-bottom: 1rem;
  padding: 0.75rem 1rem;
  background: var(--bg-secondary);
  border: 1px dashed var(--border-color);
  border-radius: 8px;
}

.table-container {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.data-table {
  min-width: 640px;
}

.data-table {
  width: 100%;
  border-collapse: collapse;

  th, td {
    padding: 0.9rem 1.2rem;
    text-align: left;
    border-bottom: 1px solid var(--border-color);
  }

  th {
    font-weight: 600;
    color: var(--text-main);
    font-size: 0.85rem;
    background: rgba(0,0,0,0.01);
  }

  td { color: var(--text-muted); font-size: 0.88rem; }

  tr {
    transition: background-color 0.2s;
    &:hover { background: rgba(67,56,202,0.02); }
    &.row-blocked { background: rgba(239,68,68,0.05); td { opacity: 0.7; } }
  }
}

/* Toggle switch */
.toggle-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.25rem;

  &:disabled { opacity: 0.5; cursor: not-allowed; }

  .toggle-track {
    width: 36px;
    height: 20px;
    background: #d1d5db;
    border-radius: 10px;
    position: relative;
    transition: background 0.2s;
    flex-shrink: 0;

    .toggle-thumb {
      width: 14px;
      height: 14px;
      background: white;
      border-radius: 50%;
      position: absolute;
      top: 3px;
      left: 3px;
      transition: transform 0.2s;
      box-shadow: 0 1px 3px rgba(0,0,0,0.2);
    }
  }

  .toggle-label {
    font-size: 0.78rem;
    color: var(--text-muted);
    min-width: 60px;
  }

  &.toggle-on .toggle-track {
    background: #4338ca;
    .toggle-thumb { transform: translateX(16px); }
  }
  &.toggle-on .toggle-label { color: #4338ca; font-weight: 600; }

  &.toggle-loading .toggle-track { opacity: 0.6; }
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.65rem;
  border-radius: 12px;
  font-size: 0.78rem;
  font-weight: 500;
  &.badge-success { background: rgba(16,185,129,0.15); color: #065f46; }
  &.badge-danger { background: rgba(239,68,68,0.15); color: #991b1b; }
}

.badge-admin {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  background: #4338ca;
  color: white;
  padding: 0.2rem 0.6rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
  &.inline { margin-left: 0.4rem; vertical-align: middle; }
}

.dept-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.65rem;
  border-radius: 12px;
  font-size: 0.78rem;
  font-weight: 600;
}

.actions-cell { display: flex; gap: 0.5rem; }

.btn-icon {
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 0.4rem;
  border-radius: 4px;
  display: flex;
  align-items: center;
  color: var(--text-muted);
  &:hover { background: rgba(0,0,0,0.05); }
  &.text-warning:hover { color: #d97706; background: rgba(217,119,6,0.1); }
  &.text-success:hover { color: #10b981; background: rgba(16,185,129,0.1); }
  &.text-danger:hover { color: #ef4444; background: rgba(239,68,68,0.1); }
}

.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  background: var(--primary);
  color: white;
  border: none;
  padding: 0.6rem 1.2rem;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
}

.skeleton-row {
  animation: pulse-skeleton 1.5s infinite;
  .skeleton-line { height: 12px; background: #e5e7eb; border-radius: 4px; width: 120px; &.short { width: 60px; } }
  .skeleton-action { height: 24px; width: 24px; background: #e5e7eb; border-radius: 4px; }
}
@keyframes pulse-skeleton {
  0% { opacity: 0.6; } 50% { opacity: 1; } 100% { opacity: 0.6; }
}

.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 12px; height: 12px; }
.font-medium { font-weight: 500; color: var(--text-main); }
.text-center { text-align: center; }
.py-4 { padding: 1.5rem 0; }
.text-xs { font-size: 0.75rem; }
.text-muted { color: var(--text-muted); }

@media (max-width: 768px) {
  .page-container {
    padding: 1rem;
  }

  .page-header .header-content {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }

  .page-header .header-actions {
    width: 100%;
    flex-wrap: wrap;

    button {
      flex: 1;
      justify-content: center;
    }
  }

  .groups-card .group-add-row {
    flex-direction: column;
  }
}
</style>
