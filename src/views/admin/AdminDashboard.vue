<script setup>
import { ref, onMounted } from 'vue'
import api from '../../api'

const metrics = ref({
  total_accounts: 0,
  active_accounts: 0,
  trialing_accounts: 0,
  estimated_mrr: 0
})

const loading = ref(true)

const fetchMetrics = async () => {
  try {
    const response = await api.get('/admin/dashboard')
    metrics.value = response.data.metrics
  } catch (error) {
    console.error("Erro ao buscar métricas:", error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchMetrics()
})

const formatCurrency = (value) => {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)
}
</script>

<template>
  <div class="admin-dashboard">
    <h2 class="page-title">Visão Geral</h2>
    
    <div v-if="loading" class="loading">Carregando métricas...</div>
    
    <div v-else class="metrics-grid">
      <div class="metric-card">
        <div class="metric-title">Total de Empresas</div>
        <div class="metric-value">{{ metrics.total_accounts }}</div>
        <div class="metric-subtitle">Cadastradas no SaaS</div>
      </div>
      
      <div class="metric-card">
        <div class="metric-title">Empresas Ativas</div>
        <div class="metric-value text-success">{{ metrics.active_accounts }}</div>
        <div class="metric-subtitle">Pagantes atuais</div>
      </div>

      <div class="metric-card">
        <div class="metric-title">Em Período de Teste</div>
        <div class="metric-value text-warning">{{ metrics.trialing_accounts }}</div>
        <div class="metric-subtitle">7 dias grátis</div>
      </div>

      <div class="metric-card mrr-card">
        <div class="metric-title">MRR Estimado</div>
        <div class="metric-value">{{ formatCurrency(metrics.estimated_mrr) }}</div>
        <div class="metric-subtitle">Receita Recorrente Mensal</div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.page-title {
  font-size: 1.1rem;
  font-weight: 600;
  color: #1e293b;
  margin-bottom: 2rem;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 1.5rem;
}

.metric-card {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
  border: 1px solid #e2e8f0;
  
  .metric-title {
    font-size: 0.85rem;
    color: #64748b;
    font-weight: 500;
    margin-bottom: 0.5rem;
  }
  
  .metric-value {
    font-size: 1.8rem;
    font-weight: 700;
    color: #0f172a;
    margin-bottom: 0.25rem;
    
    &.text-success { color: #10b981; }
    &.text-warning { color: #f59e0b; }
  }
  
  .metric-subtitle {
    font-size: 0.75rem;
    color: #94a3b8;
  }
  
  &.mrr-card {
    background: linear-gradient(135deg, #0f172a, #1e293b);
    color: white;
    border: none;
    
    .metric-title, .metric-subtitle {
      color: #94a3b8;
    }
    
    .metric-value {
      color: #38bdf8;
    }
  }
}
</style>
