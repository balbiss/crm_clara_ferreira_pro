<script setup>
import { ref, computed, onMounted } from 'vue'
import { Users2, UserCircle2, X, Save, Check, Plus } from 'lucide-vue-next'
import api from '../../api'
import Swal from 'sweetalert2'
import { useAgentsStore } from '../../store/agents'

// "Times de vendas" do Jueri (Vendas 1, Vendas 4 etc) — cada revendedora
// pertence a um time (fk_revendedor_gerente_id lá no Jueri). Aqui a
// gerência/diretoria escolhe quais usuários do CRM podem ver a carteira
// inteira de cada time, igual ao "gerenciar agendas" do próprio Jueri.
const agentsStore = useAgentsStore()

const teams = ref([])
const isLoading = ref(false)
const showModal = ref(false)
const editingTeam = ref(null)
const selectedUserIds = ref(new Set())
const isSaving = ref(false)

const fetchTeams = async () => {
  isLoading.value = true
  try {
    const response = await api.get('/sales_teams')
    teams.value = response.data
  } catch (error) {
    console.error('Erro ao buscar times de vendas:', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  fetchTeams()
  if (!agentsStore.isLoadedOnce) agentsStore.fetchAgents()
})

const roleLabels = { consultor: 'Consultor', gerente: 'Gerente', diretoria: 'Diretoria', financeiro: 'Financeiro' }

// Times cujo nome no Jueri é só o rótulo do time ("Vendas 4") ganham um
// ícone de grupo; os que são o nome de uma pessoa de verdade (Nathalia,
// Letícia etc) ganham um avatar de iniciais, pra diferenciar visualmente.
const isNamedTeam = (nome) => /^(vendas\s*\d*|g[eê]r[eê]nci?a?\s*comercial|gerente\s*de\s*opera[çc][õo]es)$/i.test(nome.trim())

const AVATAR_COLORS = ['#ba5e72', '#6366f1', '#10b981', '#f59e0b', '#ec4899', '#3b82f6', '#8b5cf6', '#14b8a6']
const colorFor = (str) => {
  let hash = 0
  for (let i = 0; i < (str || '?').length; i++) hash = str.charCodeAt(i) + ((hash << 5) - hash)
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length]
}
const initials = (name) => (name || '?').trim().split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase()

const openModal = (team) => {
  editingTeam.value = team
  selectedUserIds.value = new Set(team.users.map(u => u.id))
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingTeam.value = null
}

const toggleUser = (userId) => {
  if (selectedUserIds.value.has(userId)) {
    selectedUserIds.value.delete(userId)
  } else {
    selectedUserIds.value.add(userId)
  }
  // Vue não reage a mutação direta de Set — força atualização
  selectedUserIds.value = new Set(selectedUserIds.value)
}

const saveMembers = async () => {
  if (!editingTeam.value) return
  isSaving.value = true
  try {
    const { data } = await api.patch(`/sales_teams/${editingTeam.value.id}/members`, {
      user_ids: Array.from(selectedUserIds.value)
    })
    const idx = teams.value.findIndex(t => t.id === data.id)
    if (idx !== -1) teams.value[idx] = data
    closeModal()
  } catch (error) {
    console.error('Erro ao salvar acesso do time:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao salvar acesso do time.', showConfirmButton: false, timer: 3500 })
  } finally {
    isSaving.value = false
  }
}

const availableAgents = computed(() => agentsStore.agents)
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-content">
        <h1>Times de Vendas</h1>
        <p class="description">
          Times sincronizados automaticamente do Jueri. Escolha quem, além do responsável direto de cada revendedora, pode ver a carteira inteira de cada time.
        </p>
      </div>
    </div>

    <div v-if="isLoading" class="teams-grid">
      <div class="team-card skeleton" v-for="i in 4" :key="i">
        <div class="skeleton-line title"></div>
        <div class="skeleton-line"></div>
      </div>
    </div>

    <div v-else-if="teams.length === 0" class="empty-state">
      <Users2 class="empty-icon" />
      <p>Nenhum time encontrado ainda.</p>
      <span class="text-muted text-xs">Aparece automaticamente depois da próxima sincronização com o Jueri.</span>
    </div>

    <div v-else class="teams-grid">
      <div v-for="team in teams" :key="team.id" class="team-card">
        <div class="team-card-header">
          <div class="team-icon" :class="{ 'team-icon--person': !isNamedTeam(team.nome) }">
            <Users2 v-if="isNamedTeam(team.nome)" class="icon-md" />
            <UserCircle2 v-else class="icon-md" />
          </div>
          <div class="team-info">
            <h3>{{ team.nome }}</h3>
            <span class="team-count">{{ team.users.length }} {{ team.users.length === 1 ? 'pessoa com acesso' : 'pessoas com acesso' }}</span>
          </div>
        </div>

        <div class="team-members">
          <div v-if="team.users.length === 0" class="no-members">Ninguém com acesso ainda</div>
          <div v-else class="member-avatars">
            <div v-for="u in team.users" :key="u.id" class="member-avatar" :title="`${u.name} · ${roleLabels[u.role] || u.role}`">
              <img v-if="u.avatar_url" :src="u.avatar_url" alt="" />
              <span v-else :style="{ backgroundColor: colorFor(u.name) }" class="member-avatar-fallback">{{ initials(u.name) }}</span>
            </div>
          </div>
        </div>

        <button class="btn-manage" @click="openModal(team)">
          <Plus class="icon-xs" /> Gerenciar acesso
        </button>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <div class="modal-header">
          <div class="modal-header-info">
            <div class="team-icon modal-icon" :class="{ 'team-icon--person': !isNamedTeam(editingTeam?.nome || '') }">
              <Users2 v-if="isNamedTeam(editingTeam?.nome || '')" class="icon-sm" />
              <UserCircle2 v-else class="icon-sm" />
            </div>
            <h2>{{ editingTeam?.nome }}</h2>
          </div>
          <button class="btn-icon" @click="closeModal"><X class="icon-sm" /></button>
        </div>
        <div class="modal-body">
          <p class="modal-hint">Marque quem pode ver todas as revendedoras deste time, além do responsável direto de cada uma.</p>
          <div class="user-list">
            <label v-for="agent in availableAgents" :key="agent.id" class="user-row" :class="{ selected: selectedUserIds.has(agent.id) }">
              <input type="checkbox" :checked="selectedUserIds.has(agent.id)" @change="toggleUser(agent.id)" />
              <div class="user-avatar">
                <img v-if="agent.avatar_url" :src="agent.avatar_url" alt="" />
                <span v-else :style="{ backgroundColor: colorFor(`${agent.first_name} ${agent.last_name}`) }" class="user-avatar-fallback">{{ initials(`${agent.first_name} ${agent.last_name}`) }}</span>
              </div>
              <div class="user-details">
                <span class="user-name">{{ agent.first_name }} {{ agent.last_name }}</span>
                <span class="user-role">{{ roleLabels[agent.role] || agent.role }}</span>
              </div>
              <Check v-if="selectedUserIds.has(agent.id)" class="icon-sm check-icon" />
            </label>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn-cancel" @click="closeModal">Cancelar</button>
          <button class="btn-primary" :disabled="isSaving" @click="saveMembers">
            <Save class="icon-sm" /> {{ isSaving ? 'Salvando...' : 'Salvar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 2rem; background: var(--bg-primary); height: 100%; overflow-y: auto; }
.page-header {
  margin-bottom: 2rem;
  h1 { font-size: 1.3rem; color: var(--text-main); font-weight: 600; margin-bottom: 0.4rem; }
  .description { color: var(--text-muted); font-size: 0.85rem; max-width: 640px; line-height: 1.5; }
}

.teams-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.team-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  box-shadow: 0 1px 2px rgba(43,0,22,0.05), 0 4px 12px rgba(43,0,22,0.06);
  transition: box-shadow 0.2s, transform 0.15s;

  &:hover:not(.skeleton) {
    box-shadow: 0 4px 10px rgba(43,0,22,0.08), 0 10px 24px rgba(43,0,22,0.1);
    transform: translateY(-2px);
  }
}

.team-card-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.team-icon {
  width: 42px; height: 42px; border-radius: 10px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: var(--input-focus); color: var(--primary);

  &--person {
    background: rgba(99, 102, 241, 0.12);
    color: #6366f1;
  }
}
.modal-icon { width: 34px; height: 34px; border-radius: 8px; }

.team-info {
  min-width: 0;
  h3 { font-size: 0.95rem; font-weight: 600; color: var(--text-main); margin: 0 0 0.15rem 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .team-count { font-size: 0.78rem; color: var(--text-muted); }
}

.team-members {
  min-height: 32px;
  .no-members { font-size: 0.8rem; color: var(--text-muted); font-style: italic; }
}

.member-avatars { display: flex; flex-wrap: wrap; gap: -0.4rem; }
.member-avatar {
  width: 32px; height: 32px; border-radius: 50%; overflow: hidden;
  border: 2px solid var(--bg-secondary);
  margin-right: -0.5rem;
  cursor: default;

  img { width: 100%; height: 100%; object-fit: cover; display: block; }
}
.member-avatar-fallback {
  width: 100%; height: 100%; color: white; font-size: 0.72rem; font-weight: 700;
  display: flex; align-items: center; justify-content: center;
}

.btn-manage {
  margin-top: auto;
  display: inline-flex; align-items: center; justify-content: center; gap: 0.4rem;
  background: var(--bg-tertiary); color: var(--text-main); border: 1px solid var(--border-color);
  padding: 0.55rem 0.9rem; border-radius: 8px; cursor: pointer; font-size: 0.82rem; font-weight: 500;
  transition: background 0.15s;
  &:hover { background: var(--input-focus); color: var(--primary); border-color: var(--primary); }
}

.empty-state {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  padding: 4rem 2rem; text-align: center; color: var(--text-muted);
  background: var(--bg-secondary); border: 1px dashed var(--border-color); border-radius: 12px;

  .empty-icon { width: 40px; height: 40px; opacity: 0.4; margin-bottom: 1rem; }
  p { font-size: 0.95rem; color: var(--text-main); margin-bottom: 0.3rem; }
}

.skeleton {
  .skeleton-line {
    height: 14px; background: var(--bg-hover); border-radius: 4px; animation: pulse-skeleton 1.5s infinite;
    &.title { width: 60%; height: 18px; margin-bottom: 0.5rem; }
  }
}
@keyframes pulse-skeleton { 0% { opacity: 0.6; } 50% { opacity: 1; } 100% { opacity: 0.6; } }

.btn-icon {
  background: transparent; border: none; cursor: pointer; padding: 0.5rem; border-radius: 4px;
  display: flex; align-items: center; justify-content: center; color: var(--text-muted);
  &:hover { background: rgba(0,0,0,0.05); }
}
.btn-primary {
  display: inline-flex; align-items: center; gap: 0.5rem; background: var(--primary);
  color: white; border: none; padding: 0.6rem 1.2rem; border-radius: 6px; font-weight: 500; cursor: pointer;
  &:disabled { opacity: 0.6; cursor: not-allowed; }
}
.btn-cancel {
  background: transparent; color: var(--text-muted); border: 1px solid var(--border-color);
  padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer;
  &:hover { background: var(--bg-primary); color: var(--text-main); }
}

.modal-overlay {
  position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.modal-content {
  background: var(--bg-secondary); border-radius: 12px; width: 100%; max-width: 460px;
  max-height: 80vh; display: flex; flex-direction: column;
  box-shadow: 0 10px 25px rgba(0,0,0,0.15);
}
.modal-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--border-color);

  .modal-header-info { display: flex; align-items: center; gap: 0.75rem; min-width: 0; }
  h2 { font-size: 1rem; color: var(--text-main); margin: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
}
.modal-body { padding: 1.25rem 1.5rem; overflow-y: auto; }
.modal-hint { color: var(--text-muted); font-size: 0.82rem; margin-bottom: 1rem; line-height: 1.4; }
.modal-footer {
  padding: 1.1rem 1.5rem; border-top: 1px solid var(--border-color); display: flex; justify-content: flex-end; gap: 0.75rem;
}

.user-list { display: flex; flex-direction: column; gap: 0.3rem; }
.user-row {
  display: flex; align-items: center; gap: 0.65rem; padding: 0.55rem 0.6rem; border-radius: 8px; cursor: pointer;
  border: 1px solid transparent;
  transition: background 0.15s, border-color 0.15s;
  &:hover { background: var(--bg-hover); }
  &.selected { background: var(--input-focus); border-color: rgba(212, 155, 167, 0.35); }

  input[type="checkbox"] { display: none; }

  .user-avatar {
    width: 30px; height: 30px; border-radius: 50%; overflow: hidden; flex-shrink: 0;
    img { width: 100%; height: 100%; object-fit: cover; display: block; }
  }
  .user-avatar-fallback {
    width: 100%; height: 100%; color: white; font-size: 0.68rem; font-weight: 700;
    display: flex; align-items: center; justify-content: center;
  }
  .user-details { display: flex; flex-direction: column; flex: 1; min-width: 0; }
  .user-name { color: var(--text-main); font-size: 0.88rem; font-weight: 500; }
  .user-role { color: var(--text-muted); font-size: 0.72rem; }
  .check-icon { color: var(--primary); flex-shrink: 0; }
}

.text-xs { font-size: 0.75rem; }
.text-muted { color: var(--text-muted); }
.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 14px; height: 14px; }
.icon-md { width: 20px; height: 20px; }
</style>
