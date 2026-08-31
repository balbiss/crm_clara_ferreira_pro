<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search, Phone, ListChecks } from 'lucide-vue-next'
import api from '../api'
import { usePipelinesStore } from '../store/pipelines'

// Visão consolidada de todos os pipelines customizados juntos (Varejo, Onboarding,
// Atacado, Prospecção, e qualquer outro criado pela empresa). O Consignado não entra
// aqui — ele tem sua própria régua e telas dedicadas (Carteira Ativa / Inativas).
const router = useRouter()
const pipelinesStore = usePipelinesStore()
const isLoading = ref(true)
const cards = ref([])
const searchQuery = ref('')
const pipelineFilter = ref('all')

const fetchAll = async () => {
  isLoading.value = true
  try {
    const res = await api.get('/pipeline_cards')
    cards.value = res.data
  } catch (e) {
    console.error('Erro ao carregar todos os leads:', e)
  } finally {
    isLoading.value = false
  }
}

onMounted(async () => {
  if (!pipelinesStore.isLoadedOnce) await pipelinesStore.fetchPipelines()
  fetchAll()
})

const filteredCards = computed(() => {
  let list = cards.value
  if (pipelineFilter.value !== 'all') list = list.filter(c => c.pipeline_id === pipelineFilter.value)
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(c => (c.contact.name || '').toLowerCase().includes(q) || (c.contact.phone || '').includes(q))
  }
  return list
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-left">
        <h1><ListChecks class="h-icon" /> Todos os Leads</h1>
        <p>{{ filteredCards.length }} contato{{ filteredCards.length === 1 ? '' : 's' }} em todos os pipelines</p>
      </div>
    </div>

    <div class="toolbar">
      <div class="search-box">
        <Search class="icon-sm" />
        <input v-model="searchQuery" type="text" placeholder="Buscar por nome ou telefone..." />
      </div>
      <div class="pipeline-chips">
        <button class="chip" :class="{ active: pipelineFilter === 'all' }" @click="pipelineFilter = 'all'">Todos</button>
        <button v-for="p in pipelinesStore.pipelines" :key="p.id" class="chip" :class="{ active: pipelineFilter === p.id }" @click="pipelineFilter = p.id">
          {{ p.name }}
        </button>
      </div>
    </div>

    <div class="table-wrapper" v-if="!isLoading">
      <table v-if="filteredCards.length > 0" class="leads-table">
        <thead>
          <tr>
            <th>Contato</th>
            <th>Telefone</th>
            <th>Pipeline</th>
            <th>Etapa</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in filteredCards" :key="c.id" @click="router.push(`/contatos/${c.contact.id}`)">
            <td class="cell-name">{{ c.contact.name || 'Sem nome' }}</td>
            <td><span class="phone-cell"><Phone class="icon-xs" /> {{ c.contact.phone || '—' }}</span></td>
            <td><span class="pipeline-badge">{{ c.pipeline_name }}</span></td>
            <td>{{ c.pipeline_stage_name }}</td>
          </tr>
        </tbody>
      </table>
      <div v-else class="empty-state">
        <ListChecks :size="28" />
        <h3>Nenhum lead encontrado</h3>
        <p>Ajuste os filtros ou adicione contatos aos pipelines.</p>
      </div>
    </div>
    <div v-else class="loading-state">Carregando...</div>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 1.5rem 2rem; height: 100%; overflow-y: auto; }

.page-header {
  margin-bottom: 1.25rem;
  h1 { font-size: 1.35rem; font-weight: 700; color: var(--text-main); display: flex; align-items: center; gap: 0.5rem; .h-icon { width: 20px; height: 20px; color: var(--primary); } }
  p { font-size: 0.85rem; color: var(--text-muted); margin-top: 0.25rem; }
}

.toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 0.75rem; margin-bottom: 1.25rem; }

.search-box {
  display: flex; align-items: center; gap: 0.5rem; background: var(--bg-secondary);
  border: 1px solid var(--border-color); border-radius: 8px; padding: 0.5rem 0.75rem; min-width: 260px;
  .icon-sm { width: 16px; height: 16px; color: var(--text-muted); }
  input { border: none; outline: none; background: transparent; color: var(--text-main); font-size: 0.85rem; flex: 1; }
}

.pipeline-chips { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.chip {
  padding: 0.4rem 0.75rem; border-radius: 20px; border: 1px solid var(--border-color); background: var(--bg-secondary);
  color: var(--text-muted); font-size: 0.78rem; font-weight: 600; cursor: pointer; white-space: nowrap;
  transition: background 0.15s, color 0.15s, border-color 0.15s;
  &:hover { background: var(--bg-hover); }
  &.active { background: var(--primary-hover); border-color: var(--primary-hover); color: white; }
}

.table-wrapper { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 10px; overflow: hidden; overflow-x: auto; }

.leads-table {
  width: 100%; border-collapse: collapse; font-size: 0.85rem;
  thead th { text-align: left; padding: 0.75rem 1rem; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; color: var(--text-muted); background: var(--bg-tertiary); border-bottom: 1px solid var(--border-color); }
  tbody tr { cursor: pointer; transition: background 0.15s; border-bottom: 1px solid var(--border-color); &:hover { background: var(--bg-hover); } &:last-child { border-bottom: none; } }
  td { padding: 0.7rem 1rem; color: var(--text-main); white-space: nowrap; }
  .cell-name { font-weight: 600; }
}

.phone-cell { display: flex; align-items: center; gap: 0.3rem; color: var(--text-muted); .icon-xs { width: 12px; height: 12px; } }

.pipeline-badge { font-size: 0.72rem; font-weight: 700; padding: 0.2rem 0.6rem; border-radius: 20px; background: rgba(255, 0, 127,0.1); color: var(--primary); }

.empty-state { padding: 3rem 1.5rem; text-align: center; color: var(--text-muted); h3 { font-size: 1rem; font-weight: 700; color: var(--text-main); margin: 0.75rem 0 0.4rem; } p { font-size: 0.85rem; } }

.loading-state { text-align: center; padding: 5rem; color: var(--text-muted); }
</style>
