<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { FileText, ArrowRight, ChevronLeft, ChevronRight } from 'lucide-vue-next'
import api from '../api'

// Mesma lista que o widget "Pedidos Pendentes" do painel do Jueri mostra —
// pedidos com status Aberto (ainda não baixados/cancelados). Não chama a
// API do Jueri: já sincronizamos todo pedido localmente, então isso é só
// leitura filtrada (ver PedidosController#pendentes).
const router = useRouter()

const pedidos = ref([])
const isLoading = ref(true)
const page = ref(1)
const totalPages = ref(1)
const total = ref(0)

const fetchPedidos = async () => {
  isLoading.value = true
  try {
    const { data } = await api.get('/pedidos/pendentes', { params: { page: page.value, per_page: 20 } })
    pedidos.value = data.pedidos
    totalPages.value = data.total_pages
    total.value = data.total
  } catch (error) {
    console.error('Erro ao buscar pedidos pendentes:', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(fetchPedidos)
watch(page, fetchPedidos)

const brl = (v) => {
  const n = parseFloat(v)
  if (!n) return 'R$ 0,00'
  return n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
}

const formatDate = (iso) => {
  if (!iso) return '...'
  const d = new Date(iso.includes('T') ? iso : `${iso}T00:00:00`)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleDateString('pt-BR')
}

const goToContact = (contactId) => {
  if (contactId) router.push(`/contatos/${contactId}`)
}

// Janela de páginas visível (igual ao "1 2 3 4 ... 14" do Jueri)
const visiblePages = () => {
  const pages = new Set([1, totalPages.value, page.value, page.value - 1, page.value + 1])
  return [...pages].filter(p => p >= 1 && p <= totalPages.value).sort((a, b) => a - b)
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-left">
        <FileText class="header-icon" />
        <h1>Pedidos Pendentes</h1>
      </div>
      <span class="total-badge">Total: {{ total }}</span>
    </div>
    <p class="description">Pedidos com maleta ainda em aberto no Jueri (não baixados nem cancelados) — mesma lista do painel do Jueri.</p>

    <div class="pedidos-list">
      <div v-if="isLoading" class="skeleton-list">
        <div class="skeleton-row" v-for="i in 6" :key="i"></div>
      </div>

      <template v-else>
        <div v-if="pedidos.length === 0" class="empty-state">
          Nenhum pedido pendente encontrado{{ total === 0 ? '' : ' nesta página' }}.
        </div>

        <div v-for="pedido in pedidos" :key="pedido.id" class="pedido-row" @click="goToContact(pedido.contact_id)">
          <div class="pedido-info">
            <span class="pedido-tipo">CRIAÇÃO</span>
            <span class="pedido-nome">{{ pedido.contact_name }} <span class="pedido-tag">(Revendedor)</span></span>
            <span class="pedido-detalhe">Quantidade: {{ pedido.quantidade }} | Valor: {{ brl(pedido.valor_total) }} · {{ formatDate(pedido.data_criacao) }}</span>
          </div>
          <button class="btn-arrow" title="Ver revendedora"><ArrowRight class="icon-sm" /></button>
        </div>
      </template>
    </div>

    <div class="pagination" v-if="totalPages > 1">
      <button class="page-btn" :disabled="page <= 1" @click="page = page - 1"><ChevronLeft class="icon-sm" /></button>
      <template v-for="(p, idx) in visiblePages()" :key="p">
        <span v-if="idx > 0 && p - visiblePages()[idx - 1] > 1" class="page-ellipsis">...</span>
        <button class="page-btn" :class="{ active: p === page }" @click="page = p">{{ p }}</button>
      </template>
      <button class="page-btn" :disabled="page >= totalPages" @click="page = page + 1"><ChevronRight class="icon-sm" /></button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  padding: 2rem;
  background: var(--bg-primary);
  height: 100%;
  overflow-y: auto;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;

  .header-left {
    display: flex;
    align-items: center;
    gap: 0.6rem;
  }

  .header-icon {
    width: 22px;
    height: 22px;
    color: #ef4444;
  }

  h1 {
    font-size: 1.2rem;
    font-weight: 600;
    color: var(--text-main);
  }

  .total-badge {
    background: var(--bg-tertiary);
    color: var(--text-main);
    font-size: 0.8rem;
    font-weight: 600;
    padding: 0.3rem 0.75rem;
    border-radius: 20px;
    border: 1px solid var(--border-color);
  }
}

.description {
  color: var(--text-muted);
  font-size: 0.85rem;
  margin-bottom: 1.5rem;
  max-width: 640px;
}

.pedidos-list {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  overflow: hidden;
}

.pedido-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-color);
  cursor: pointer;
  transition: background 0.15s;

  &:last-child { border-bottom: none; }
  &:hover { background: var(--bg-hover); }
}

.pedido-info {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  min-width: 0;
}

.pedido-tipo {
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.03em;
  color: var(--text-muted);
  text-transform: uppercase;
}

.pedido-nome {
  font-size: 0.92rem;
  font-weight: 600;
  color: var(--primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pedido-tag {
  font-weight: 400;
  color: var(--text-muted);
}

.pedido-detalhe {
  font-size: 0.82rem;
  color: var(--text-muted);
}

.btn-arrow {
  flex-shrink: 0;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  border: none;
  background: var(--bg-tertiary);
  color: var(--text-main);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.15s;

  &:hover { background: var(--primary); color: white; }
}

.empty-state {
  padding: 3rem;
  text-align: center;
  color: var(--text-muted);
}

.skeleton-list {
  display: flex;
  flex-direction: column;
}

.skeleton-row {
  height: 62px;
  border-bottom: 1px solid var(--border-color);
  background: linear-gradient(90deg, var(--bg-secondary) 25%, var(--bg-hover) 37%, var(--bg-secondary) 63%);
  background-size: 400% 100%;
  animation: skeleton-shimmer 1.4s ease infinite;

  &:last-child { border-bottom: none; }
}

@keyframes skeleton-shimmer {
  0% { background-position: 100% 50%; }
  100% { background-position: 0 50%; }
}

.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  margin-top: 1.25rem;
}

.page-btn {
  min-width: 32px;
  height: 32px;
  padding: 0 0.5rem;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
  color: var(--text-main);
  font-size: 0.85rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;

  &:hover:not(:disabled) { background: var(--bg-hover); }
  &:disabled { opacity: 0.4; cursor: not-allowed; }
  &.active { background: var(--primary); color: white; border-color: var(--primary); }
}

.page-ellipsis {
  color: var(--text-muted);
  padding: 0 0.25rem;
}
</style>
