<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Activity, UserPlus, Package, RefreshCw } from '@lucide/vue'
import api from '../api'

// Tela "Atividades" (só gerência) — feed cronológico de tudo que a Jueri
// manda pro nosso webhook (revendedor.*/pedido.*/venda.*/financeiro.*),
// inspirado no painel "Atividades do Dia" da própria Jueri. Sem
// notificação/push de propósito — pedido aberto muda de valor várias vezes
// por dia, isso vira aviso demais; aqui é só consulta.
const router = useRouter()

const atividades = ref([])
const isLoading = ref(true)
const isLoadingMore = ref(false)
const page = ref(1)
const hasMore = ref(true)
const eventoFilter = ref('all')

const eventoOptions = [
  { value: 'all', label: 'Todos os eventos' },
  { value: 'revendedor', label: 'Cadastro (revendedor)' },
  { value: 'pedido', label: 'Pedidos' },
  { value: 'venda', label: 'Vendas' },
  { value: 'financeiro', label: 'Financeiro' },
]

const filteredAtividades = computed(() => {
  if (eventoFilter.value === 'all') return atividades.value
  return atividades.value.filter(a => a.evento?.startsWith(eventoFilter.value))
})

const iconFor = (evento) => {
  if (evento?.startsWith('revendedor')) return UserPlus
  if (evento?.startsWith('pedido')) return Package
  return RefreshCw
}

const formatDateTime = (iso) => {
  if (!iso) return null
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return `${d.toLocaleDateString('pt-BR')} ${d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}`
}

const openContact = (contact) => contact && router.push(`/contatos/${contact.id}`)

const fetchAtividades = async (nextPage = 1) => {
  const isFirst = nextPage === 1
  isFirst ? (isLoading.value = true) : (isLoadingMore.value = true)
  try {
    const { data } = await api.get('/jueri_activities', { params: { page: nextPage, per_page: 50 } })
    atividades.value = isFirst ? data : [...atividades.value, ...data]
    hasMore.value = data.length === 50
    page.value = nextPage
  } catch (e) {
    console.error('Erro ao buscar atividades:', e)
  } finally {
    isLoading.value = false
    isLoadingMore.value = false
  }
}

const loadMore = () => fetchAtividades(page.value + 1)

onMounted(() => fetchAtividades(1))
</script>

<template>
  <div class="atividades-page">
    <div class="page-header">
      <div class="title-block">
        <h1>Atividades</h1>
        <p>Tudo que a Jueri avisou pro CRM — cadastros, pedidos, vendas e financeiro</p>
      </div>
    </div>

    <div class="toolbar">
      <select v-model="eventoFilter" class="evento-select">
        <option v-for="opt in eventoOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
    </div>

    <div v-if="!isLoading && filteredAtividades.length > 0" class="feed">
      <div
        v-for="a in filteredAtividades"
        :key="a.id"
        class="feed-row"
        :class="{ clickable: !!a.contact }"
        @click="openContact(a.contact)"
      >
        <div class="feed-icon">
          <component :is="iconFor(a.evento)" class="icon-sm" />
        </div>
        <div class="feed-body">
          <span class="feed-desc">{{ a.descricao }}</span>
          <span class="feed-meta">{{ a.evento }} · {{ formatDateTime(a.ocorrido_em) }}</span>
        </div>
      </div>
    </div>

    <div v-else-if="isLoading" class="empty-state"><p>Carregando atividades...</p></div>

    <div v-else class="empty-state">
      <div class="empty-icon"><Activity :size="28" /></div>
      <h3>Nenhuma atividade ainda</h3>
      <p>Assim que a Jueri mandar algum evento pro webhook, aparece aqui.</p>
    </div>

    <div v-if="hasMore && !isLoading && filteredAtividades.length > 0" class="load-more">
      <button class="btn-secondary" :disabled="isLoadingMore" @click="loadMore">
        {{ isLoadingMore ? 'Carregando...' : 'Carregar mais' }}
      </button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.atividades-page {
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
  margin-bottom: 1.25rem;
}

.evento-select {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-secondary);
  color: var(--text-main);
  font-size: 0.82rem;
}

.feed {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  overflow: hidden;
}

.feed-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.85rem 1rem;
  border-bottom: 1px solid var(--border-color);

  &:last-child { border-bottom: none; }
  &.clickable { cursor: pointer; }
  &.clickable:hover { background: var(--bg-hover); }
}

.feed-icon {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: var(--bg-tertiary);
  color: var(--primary);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;

  .icon-sm { width: 16px; height: 16px; }
}

.feed-body {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  min-width: 0;
}

.feed-desc {
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--text-main);
}

.feed-meta {
  font-size: 0.75rem;
  color: var(--text-muted);
}

.load-more {
  display: flex;
  justify-content: center;
  margin-top: 1rem;
}

.btn-secondary {
  padding: 0.5rem 1.25rem;
  border-radius: 8px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
  color: var(--text-main);
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;

  &:hover:not(:disabled) { background: var(--bg-hover); }
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
