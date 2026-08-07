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
const tarefas = ref([])

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

const responsavelOptions = computed(() => {
  const ids = new Set(tarefas.value.map(t => t.user_id).filter(Boolean))
  return [{ value: 'all', label: 'Todos os responsáveis' }, ...[...ids].map(id => ({ value: id, label: agentsById.value[id] || `Usuário #${id}` }))]
})

const filteredTasks = computed(() => {
  let list = tarefas.value

  if (responsavelFilter.value !== 'all') {
    list = list.filter(t => t.user_id === responsavelFilter.value)
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
        <p>{{ filteredTasks.length }} tarefa{{ filteredTasks.length === 1 ? '' : 's' }} pendente{{ filteredTasks.length === 1 ? '' : 's' }}, geradas automaticamente pela régua do ciclo</p>
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
    </div>

    <div v-if="!isLoading && filteredTasks.length > 0" class="tasks-list">
      <div v-for="t in filteredTasks" :key="t.id" class="task-card" :class="'priority-' + t.prioridade">
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

.tasks-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
  gap: 0.65rem;
  align-items: start;
}

.task-card {
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
