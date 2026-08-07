<script setup>
import { ref, computed, onMounted } from 'vue'
import { Users2, X, Save, Check } from 'lucide-vue-next'
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
          Times sincronizados do Jueri (Vendas 1, Vendas 4 etc). Escolha quem, além do responsável direto de cada revendedora, pode ver a carteira inteira de cada time.
        </p>
      </div>
    </div>

    <div class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>Time (Jueri)</th>
            <th>Quem pode ver a carteira inteira</th>
            <th width="140">Ações</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="isLoading">
            <td colspan="3" class="text-center py-4">Carregando times...</td>
          </tr>
          <tr v-else-if="teams.length === 0">
            <td colspan="3" class="text-center py-4 text-muted">
              Nenhum time encontrado ainda — aparece automaticamente depois da próxima sincronização com o Jueri.
            </td>
          </tr>
          <tr v-for="team in teams" :key="team.id">
            <td class="font-medium">
              <div class="team-name">
                <Users2 class="icon-sm" />
                {{ team.nome }}
              </div>
            </td>
            <td>
              <div v-if="team.users.length === 0" class="text-muted text-xs">Ninguém ainda</div>
              <div v-else class="member-chips">
                <span v-for="u in team.users" :key="u.id" class="member-chip">
                  {{ u.name }} <span class="member-role">{{ roleLabels[u.role] || u.role }}</span>
                </span>
              </div>
            </td>
            <td class="actions-cell">
              <button class="btn-secondary" @click="openModal(team)">Gerenciar acesso</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <div class="modal-header">
          <h2>Acesso ao time "{{ editingTeam?.nome }}"</h2>
          <button class="btn-icon" @click="closeModal"><X class="icon-sm" /></button>
        </div>
        <div class="modal-body">
          <p class="modal-hint">Marque quem pode ver todas as revendedoras deste time, além do responsável direto de cada uma.</p>
          <div class="user-list">
            <label v-for="agent in availableAgents" :key="agent.id" class="user-row">
              <input type="checkbox" :checked="selectedUserIds.has(agent.id)" @change="toggleUser(agent.id)" />
              <span class="user-name">{{ agent.first_name }} {{ agent.last_name }}</span>
              <span class="user-role">{{ roleLabels[agent.role] || agent.role }}</span>
              <Check v-if="selectedUserIds.has(agent.id)" class="icon-xs check-icon" />
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
  h1 { font-size: 1.2rem; color: var(--text-main); font-weight: 500; margin-bottom: 0.5rem; }
  .description { color: var(--text-muted); font-size: 0.85rem; max-width: 640px; line-height: 1.5; }
}
.table-container {
  background: var(--bg-secondary); border: 1px solid var(--border-color);
  border-radius: 8px; overflow: hidden; box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
}
.data-table {
  width: 100%; border-collapse: collapse;
  th, td { padding: 1rem 1.5rem; text-align: left; border-bottom: 1px solid var(--border-color); vertical-align: top; }
  th { font-weight: 600; color: var(--text-main); font-size: 0.9rem; background: rgba(0,0,0,0.01); }
  td { color: var(--text-muted); font-size: 0.9rem; }
  tr:last-child td { border-bottom: none; }
  tr { transition: background-color 0.2s; &:hover { background: rgba(212, 155, 167, 0.02); } }
}
.team-name { display: flex; align-items: center; gap: 0.5rem; color: var(--text-main); font-weight: 500; }
.member-chips { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.member-chip {
  display: inline-flex; align-items: center; gap: 0.35rem; background: var(--input-focus);
  color: var(--primary); padding: 0.25rem 0.6rem; border-radius: 12px; font-size: 0.8rem; font-weight: 500;
}
.member-role { font-weight: 400; opacity: 0.75; font-size: 0.72rem; }
.actions-cell { display: flex; gap: 0.5rem; }
.btn-secondary {
  background: var(--bg-tertiary); color: var(--text-main); border: 1px solid var(--border-color);
  padding: 0.5rem 0.9rem; border-radius: 6px; cursor: pointer; font-size: 0.82rem; font-weight: 500;
  &:hover { background: var(--bg-hover); }
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
.btn-icon {
  background: transparent; border: none; cursor: pointer; padding: 0.5rem; border-radius: 4px;
  display: flex; align-items: center; justify-content: center; color: var(--text-muted);
  &:hover { background: rgba(0,0,0,0.05); }
}

.modal-overlay {
  position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.modal-content {
  background: var(--bg-secondary); border-radius: 8px; width: 100%; max-width: 440px;
  max-height: 80vh; display: flex; flex-direction: column;
  box-shadow: 0 10px 25px rgba(0,0,0,0.1);
}
.modal-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: 1.5rem; border-bottom: 1px solid var(--border-color);
  h2 { font-size: 1.05rem; color: var(--text-main); margin: 0; }
}
.modal-body { padding: 1.5rem; overflow-y: auto; }
.modal-hint { color: var(--text-muted); font-size: 0.82rem; margin-bottom: 1rem; line-height: 1.4; }
.modal-footer {
  padding: 1.25rem 1.5rem; border-top: 1px solid var(--border-color); display: flex; justify-content: flex-end; gap: 1rem;
}
.user-list { display: flex; flex-direction: column; gap: 0.25rem; }
.user-row {
  display: flex; align-items: center; gap: 0.6rem; padding: 0.6rem 0.5rem; border-radius: 6px; cursor: pointer;
  &:hover { background: var(--bg-hover); }
  input[type="checkbox"] { width: 16px; height: 16px; cursor: pointer; }
  .user-name { color: var(--text-main); font-size: 0.9rem; flex: 1; }
  .user-role { color: var(--text-muted); font-size: 0.75rem; }
  .check-icon { color: var(--primary); }
}

.text-xs { font-size: 0.75rem; }
.text-muted { color: var(--text-muted); }
.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 14px; height: 14px; }
.text-center { text-align: center; }
.py-4 { padding: 1.5rem 0; }
</style>
