<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { Bar, Doughnut } from 'vue-chartjs'
import { Chart as ChartJS, Title, Tooltip, Legend, BarElement, ArcElement, CategoryScale, LinearScale } from 'chart.js'
import { Download, Users, TrendingUp, Tag, CalendarCheck, RefreshCw, FileText, BarChart2, Clock, Home } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const currentUser = JSON.parse(localStorage.getItem('user') || '{}')
const isOwner     = computed(() => ['empresa', 'admin'].includes(currentUser.role))

ChartJS.register(Title, Tooltip, Legend, BarElement, ArcElement, CategoryScale, LinearScale)

const activeTab          = ref('appointments')
const period             = ref('month')
const startDate          = ref('')
const endDate            = ref('')
const isLoading          = ref(false)
const overview           = ref(null)
const agentsData         = ref([])
const tagsData           = ref([])
const selectedTag        = ref(null)
const appointmentsReport = ref(null)
const performanceData    = ref(null)

const periodOptions = [
  { value: 'today',  label: 'Hoje' },
  { value: 'week',   label: 'Esta semana' },
  { value: 'month',  label: 'Este mês' },
  { value: 'custom', label: 'Personalizado' }
]

const periodParams = computed(() => {
  const p = { period: period.value }
  if (period.value === 'custom') { p.start_date = startDate.value; p.end_date = endDate.value }
  return p
})

const fetchOverview = async (silent = false) => {
  if (!silent) isLoading.value = true
  try {
    const r = await api.get('/reports/overview', { params: periodParams.value })
    overview.value = r.data
  } catch { Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar visão geral.', showConfirmButton: false, timer: 3000 }) }
  finally { isLoading.value = false }
}

const fetchAgents = async (silent = false) => {
  if (!silent) isLoading.value = true
  try {
    const r = await api.get('/reports/by_agent', { params: periodParams.value })
    agentsData.value = r.data.agents || []
  } catch { Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar corretores.', showConfirmButton: false, timer: 3000 }) }
  finally { isLoading.value = false }
}

const fetchTags = async (silent = false) => {
  if (!silent) isLoading.value = true
  try {
    const r = await api.get('/reports/by_tag')
    tagsData.value = r.data.tags || []
    if (tagsData.value.length && !selectedTag.value) selectedTag.value = tagsData.value[0]
  } catch { Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar etiquetas.', showConfirmButton: false, timer: 3000 }) }
  finally { isLoading.value = false }
}

const fetchAppointments = async (silent = false) => {
  if (!silent) isLoading.value = true
  try {
    const r = await api.get('/appointments/report', { params: periodParams.value })
    appointmentsReport.value = r.data
  } catch { Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar agendamentos.', showConfirmButton: false, timer: 3000 }) }
  finally { isLoading.value = false }
}

const downloadBlob = (r, fallbackName) => {
  const url  = window.URL.createObjectURL(new Blob([r.data], { type: 'text/csv' }))
  const link = document.createElement('a')
  link.href  = url
  const disp = r.headers['content-disposition'] || ''
  link.setAttribute('download', disp.match(/filename="?([^"]+)"?/)?.[1] || fallbackName)
  document.body.appendChild(link); link.click(); link.remove()
  window.URL.revokeObjectURL(url)
  Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'CSV exportado!', showConfirmButton: false, timer: 2500 })
}

const exportCSV = async (type, tagId = null) => {
  try {
    const params = { ...periodParams.value, type }
    if (tagId) params.tag_id = tagId
    const r = await api.get('/reports/export', { params, responseType: 'blob' })
    downloadBlob(r, `relatorio_${type}.csv`)
  } catch { Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao exportar.', showConfirmButton: false, timer: 3000 }) }
}

const exportAppointments = async () => {
  try {
    const r = await api.get('/appointments/export', { params: periodParams.value, responseType: 'blob' })
    downloadBlob(r, 'agendamentos.csv')
  } catch { Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao exportar.', showConfirmButton: false, timer: 3000 }) }
}

const fetchPerformance = async (silent = false) => {
  if (!silent) isLoading.value = true
  try {
    const [perfR, agentsR] = await Promise.all([
      api.get('/reports/performance'),
      api.get('/reports/by_agent', { params: periodParams.value })
    ])
    performanceData.value = perfR.data
    agentsData.value = agentsR.data.agents || []
  } catch { Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar desempenho.', showConfirmButton: false, timer: 3000 }) }
  finally { isLoading.value = false }
}

const loadTab = (silent = false) => {
  if (activeTab.value === 'overview')          fetchOverview(silent)
  else if (activeTab.value === 'agents')       fetchAgents(silent)
  else if (activeTab.value === 'tags')         fetchTags(silent)
  else if (activeTab.value === 'appointments') fetchAppointments(silent)
  else if (activeTab.value === 'performance')  fetchPerformance(silent)
}

watch(activeTab, () => loadTab(false))
watch(period, () => { if (period.value !== 'custom') loadTab(false) })

const lastUpdated   = ref('')
const justRefreshed = ref(false)
let autoRefreshTimer = null

const silentRefresh = () => {
  loadTab(true)
  const now = new Date()
  lastUpdated.value = now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  justRefreshed.value = true
  setTimeout(() => { justRefreshed.value = false }, 1000)
}

onMounted(() => {
  loadTab(false)
  lastUpdated.value = new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  autoRefreshTimer = setInterval(silentRefresh, 30000)
})
onUnmounted(() => clearInterval(autoRefreshTimer))

// Chart data
const funnelChart = computed(() => {
  if (!overview.value) return { labels: [], datasets: [] }
  const f = overview.value.funnel
  return {
    labels: ['Novos Leads', 'Visita Agendada', 'Proposta', 'Fechado'],
    datasets: [{ label: 'Leads', data: [f.lead, f.visit, f.proposal, f.won],
      backgroundColor: ['#6366f1','#f59e0b','#3b82f6','#10b981'],
      borderRadius: 6, borderSkipped: false }]
  }
})

const sourceChart = computed(() => {
  if (!overview.value?.by_source) return { labels: ['Sem dados'], datasets: [{ data: [1], backgroundColor: ['#e5e7eb'] }] }
  const src = overview.value.by_source
  const labels = Object.keys(src)
  if (!labels.length) return { labels: ['Sem dados'], datasets: [{ data: [1], backgroundColor: ['#e5e7eb'] }] }
  return {
    labels,
    datasets: [{ data: Object.values(src),
      backgroundColor: ['#6366f1','#10b981','#f59e0b','#ef4444','#3b82f6','#ec4899','#0d9488'] }]
  }
})

const agentLeadsChart = computed(() => ({
  labels: agentsData.value.map(a => a.name.split(' ')[0]),
  datasets: [
    { label: 'Leads', data: agentsData.value.map(a => a.leads_received), backgroundColor: '#6366f1', borderRadius: 4 },
    { label: 'Fechados', data: agentsData.value.map(a => a.won), backgroundColor: '#10b981', borderRadius: 4 }
  ]
}))

const convTrendChart = computed(() => {
  if (!performanceData.value?.conv_trend) return { labels: [], datasets: [] }
  const trend = performanceData.value.conv_trend
  return {
    labels: trend.map(d => d.date),
    datasets: [
      { label: 'Abertas', data: trend.map(d => d.opened), backgroundColor: '#6366f1', borderRadius: 4, borderSkipped: false },
      { label: 'Resolvidas', data: trend.map(d => d.resolved), backgroundColor: '#10b981', borderRadius: 4, borderSkipped: false }
    ]
  }
})

const barOptions = {
  responsive: true, maintainAspectRatio: false,
  plugins: { legend: { position: 'bottom' } },
  scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } }
}
const donutOptions = {
  responsive: true, maintainAspectRatio: false, cutout: '65%',
  plugins: { legend: { position: 'bottom', labels: { font: { size: 12 }, padding: 12, usePointStyle: true } } }
}
</script>

<template>
  <div class="reports-page">
    <!-- Header -->
    <div class="page-header">
      <div>
        <h1><FileText class="h-icon" /> Relatórios</h1>
        <p>Análise completa de leads, corretores e campanhas</p>
      </div>
      <div class="header-actions">
        <select v-model="period" class="period-select">
          <option v-for="o in periodOptions" :key="o.value" :value="o.value">{{ o.label }}</option>
        </select>
        <div v-if="period === 'custom'" class="custom-dates">
          <input type="date" v-model="startDate" class="date-input" />
          <span>até</span>
          <input type="date" v-model="endDate" class="date-input" />
          <button class="btn-apply" @click="loadTab">Aplicar</button>
        </div>
        <span v-if="lastUpdated" class="last-updated">
          atualizado às {{ lastUpdated }}
        </span>
        <button class="btn-refresh" @click="() => { loadTab(false); lastUpdated = new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) }" :disabled="isLoading">
          <RefreshCw class="ic" :class="{ spinning: isLoading }" />
        </button>
      </div>
    </div>

    <!-- Tabs -->
    <div class="tabs">
      <button :class="['tab', { active: activeTab === 'appointments' }]" @click="activeTab = 'appointments'">
        <CalendarCheck class="ic" /> Agendamentos
      </button>
      <button v-if="isOwner" :class="['tab', { active: activeTab === 'overview' }]" @click="activeTab = 'overview'">
        <TrendingUp class="ic" /> Visão Geral
      </button>
      <button v-if="isOwner" :class="['tab', { active: activeTab === 'agents' }]" @click="activeTab = 'agents'">
        <Users class="ic" /> Por Corretor
      </button>
      <button v-if="isOwner" :class="['tab', { active: activeTab === 'tags' }]" @click="activeTab = 'tags'">
        <Tag class="ic" /> Por Etiqueta
      </button>
      <button v-if="isOwner" :class="['tab', { active: activeTab === 'performance' }]" @click="activeTab = 'performance'">
        <BarChart2 class="ic" /> Desempenho
      </button>
    </div>

    <!-- Skeleton -->
    <div v-if="isLoading" class="skeleton-grid">
      <div class="skel" v-for="i in 6" :key="i"></div>
    </div>

    <!-- ===== OVERVIEW ===== -->
    <template v-else-if="activeTab === 'overview' && overview">
      <div :class="['kpi-row', { refreshed: justRefreshed }]">
        <div class="kpi-card">
          <div class="kpi-top">
            <span class="kpi-label">Total de Leads</span>
            <span class="kpi-badge blue">{{ period === 'month' ? 'Este mês' : '' }}</span>
          </div>
          <div class="kpi-val">{{ overview.total_leads }}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Leads Quentes</span></div>
          <div class="kpi-val red">{{ overview.by_temperature.quente }}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Negócios Fechados</span></div>
          <div class="kpi-val green">{{ overview.funnel.won }}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Taxa de Conversão</span></div>
          <div class="kpi-val indigo">
            {{ overview.total_leads > 0 ? ((overview.funnel.won / overview.total_leads) * 100).toFixed(1) : 0 }}%
          </div>
        </div>
      </div>

      <div class="chart-row">
        <div class="chart-panel">
          <div class="chart-head">
            Funil de Vendas
            <button class="btn-export" @click="exportCSV('leads')"><Download class="ic" /> Exportar Leads CSV</button>
          </div>
          <div class="chart-body">
            <Bar :data="funnelChart" :options="barOptions" />
          </div>
        </div>
        <div class="chart-panel">
          <div class="chart-head">Origem dos Leads</div>
          <div class="chart-body">
            <Doughnut :data="sourceChart" :options="donutOptions" />
          </div>
        </div>
      </div>

      <!-- Temperatura breakdown -->
      <div class="breakdown-panel">
        <div class="chart-head">Termômetro Detalhado</div>
        <div class="temp-row">
          <div class="temp-item hot">
            <span class="temp-icon">🔥</span>
            <span class="temp-n">{{ overview.by_temperature.quente }}</span>
            <span class="temp-lbl">Quentes</span>
          </div>
          <div class="temp-item warm">
            <span class="temp-icon">🌤</span>
            <span class="temp-n">{{ overview.by_temperature.morno }}</span>
            <span class="temp-lbl">Mornos</span>
          </div>
          <div class="temp-item cold">
            <span class="temp-icon">❄️</span>
            <span class="temp-n">{{ overview.by_temperature.frio }}</span>
            <span class="temp-lbl">Frios</span>
          </div>
        </div>
      </div>
    </template>

    <!-- ===== POR CORRETOR ===== -->
    <template v-else-if="activeTab === 'agents'">
      <div class="chart-row" v-if="agentsData.length">
        <div class="chart-panel wide">
          <div class="chart-head">
            Leads por Corretor
            <button class="btn-export" @click="exportCSV('agents')"><Download class="ic" /> Exportar CSV</button>
          </div>
          <div class="chart-body">
            <Bar :data="agentLeadsChart" :options="barOptions" />
          </div>
        </div>
      </div>

      <div class="table-panel">
        <div class="chart-head">Desempenho Detalhado por Corretor</div>
        <div class="table-scroll-wrapper">
        <table class="report-table">
          <thead>
            <tr>
              <th>Corretor</th>
              <th>Leads Recebidos</th>
              <th>Quentes</th>
              <th>Visitas Agendadas</th>
              <th>Visitas Realizadas</th>
              <th>Fechados</th>
              <th>Conversão</th>
              <th>Conv. Abertas</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="agentsData.length === 0">
              <td colspan="8" class="no-data-cell">Nenhum corretor encontrado.</td>
            </tr>
            <tr v-for="a in agentsData" :key="a.id">
              <td class="agent-name">{{ a.name }}</td>
              <td class="center"><span class="badge-num blue">{{ a.leads_received }}</span></td>
              <td class="center"><span class="badge-num red">{{ a.quentes }}</span></td>
              <td class="center">{{ a.visits_scheduled }}</td>
              <td class="center">{{ a.visits_done }}</td>
              <td class="center"><span class="badge-num green">{{ a.won }}</span></td>
              <td class="center">
                <span :class="['rate', a.conversion_rate >= 20 ? 'rate-good' : a.conversion_rate >= 5 ? 'rate-mid' : 'rate-low']">
                  {{ a.conversion_rate }}%
                </span>
              </td>
              <td class="center">{{ a.open_conversations }}</td>
            </tr>
          </tbody>
        </table>
        </div>
      </div>
    </template>

    <!-- ===== POR ETIQUETA ===== -->
    <template v-else-if="activeTab === 'tags'">
      <div class="tags-layout">
        <!-- Sidebar de etiquetas -->
        <div class="tags-sidebar">
          <div class="sidebar-head">Etiquetas</div>
          <div v-for="tag in tagsData" :key="tag.id"
            :class="['tag-item', { active: selectedTag?.id === tag.id }]"
            @click="selectedTag = tag">
            <span class="tag-dot" :style="{ background: tag.color }"></span>
            <span class="tag-name">{{ tag.name }}</span>
            <span class="tag-count">{{ tag.count }}</span>
          </div>
          <div v-if="!tagsData.length" class="no-tags">Nenhuma etiqueta encontrada.</div>
        </div>

        <!-- Lista de contatos da etiqueta selecionada -->
        <div class="tags-content" v-if="selectedTag">
          <div class="chart-head">
            <span>
              <span class="tag-badge" :style="{ background: selectedTag.color }">{{ selectedTag.name }}</span>
              — {{ selectedTag.count }} contatos
            </span>
            <div class="export-group">
              <button class="btn-export green" @click="exportCSV('remarketing', selectedTag.id)">
                <Download class="ic" /> Exportar para Remarketing
              </button>
            </div>
          </div>
          <div class="table-scroll-wrapper">
          <table class="report-table">
            <thead>
              <tr>
                <th>Nome</th>
                <th>Telefone</th>
                <th>Temperatura</th>
                <th>Origem</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!selectedTag.contacts?.length">
                <td colspan="4" class="no-data-cell">Nenhum contato nesta etiqueta.</td>
              </tr>
              <tr v-for="c in selectedTag.contacts" :key="c.id">
                <td class="agent-name">{{ c.name || '—' }}</td>
                <td>{{ c.phone }}</td>
                <td>
                  <span :class="['temp-badge', c.temperature?.toLowerCase()]">{{ c.temperature || '—' }}</span>
                </td>
                <td>{{ c.source || '—' }}</td>
              </tr>
            </tbody>
          </table>
          </div>
        </div>
      </div>
    </template>

    <!-- ===== AGENDAMENTOS ===== -->
    <template v-else-if="activeTab === 'appointments' && appointmentsReport">
      <!-- KPIs de status -->
      <div :class="['kpi-row', { refreshed: justRefreshed }]">
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Total</span></div>
          <div class="kpi-val">{{ appointmentsReport.total }}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Pendentes</span></div>
          <div class="kpi-val" style="color:#f59e0b">{{ appointmentsReport.by_status.pending }}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Realizados</span></div>
          <div class="kpi-val green">{{ appointmentsReport.by_status.completed }}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-top"><span class="kpi-label">Cancelados</span></div>
          <div class="kpi-val red">{{ appointmentsReport.by_status.cancelled }}</div>
        </div>
      </div>

      <!-- Por corretor (só owner) -->
      <div class="table-panel" v-if="isOwner && appointmentsReport.by_agent?.length" style="margin-bottom:1rem">
        <div class="chart-head">Agendamentos por Corretor</div>
        <div class="table-scroll-wrapper">
        <table class="report-table">
          <thead>
            <tr>
              <th>Corretor</th>
              <th class="center">Total</th>
              <th class="center">Realizados</th>
              <th class="center">Taxa</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in appointmentsReport.by_agent" :key="a.id">
              <td class="agent-name">{{ a.name }}</td>
              <td class="center"><span class="badge-num blue">{{ a.total }}</span></td>
              <td class="center"><span class="badge-num green">{{ a.done }}</span></td>
              <td class="center">
                <span :class="['rate', a.total > 0 && (a.done/a.total) >= 0.5 ? 'rate-good' : 'rate-mid']">
                  {{ a.total > 0 ? ((a.done / a.total) * 100).toFixed(0) : 0 }}%
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        </div>
      </div>

      <!-- Lista completa -->
      <div class="table-panel">
        <div class="chart-head">
          Lista de Agendamentos
          <button class="btn-export" @click="exportAppointments"><Download class="ic" /> Exportar CSV</button>
        </div>
        <div class="table-scroll-wrapper">
        <table class="report-table">
          <thead>
            <tr>
              <th>Data</th>
              <th>Horário</th>
              <th>Cliente</th>
              <th>Imóvel</th>
              <th v-if="isOwner">Corretor</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!appointmentsReport.appointments?.length">
              <td :colspan="isOwner ? 6 : 5" class="no-data-cell">Nenhum agendamento no período.</td>
            </tr>
            <tr v-for="a in appointmentsReport.appointments" :key="a.id">
              <td>{{ a.appointment_date ? new Date(a.appointment_date).toLocaleDateString('pt-BR') : '—' }}</td>
              <td>{{ a.start_time || '—' }} {{ a.end_time ? '– ' + a.end_time : '' }}</td>
              <td class="agent-name">{{ a.contact?.name || a.contact?.phone || '—' }}</td>
              <td>{{ a.property?.title || '—' }}</td>
              <td v-if="isOwner">{{ a.agent || '—' }}</td>
              <td>
                <span :class="['status-badge', a.status?.toLowerCase()]">{{ a.status || '—' }}</span>
              </td>
            </tr>
          </tbody>
        </table>
        </div>
      </div>
    </template>

    <!-- ===== PERFORMANCE ===== -->
    <template v-else-if="activeTab === 'performance' && performanceData">

      <!-- KPI tempo médio -->
      <div class="kpi-row">
        <div class="kpi-card">
          <div class="kpi-top">
            <Clock class="kpi-icon-sm" />
            <span class="kpi-label">Tempo Médio de 1º Atendimento</span>
          </div>
          <div class="kpi-val" v-if="performanceData.avg_response_time_minutes !== null">
            {{ performanceData.avg_response_time_minutes }} min
          </div>
          <div class="kpi-val grey" v-else>— sem dados</div>
        </div>
      </div>

      <!-- Tendência de conversas 7 dias -->
      <div class="chart-panel mt-section">
        <div class="panel-head-row">
          <BarChart2 class="ic-purple" />
          <span>Conversas — Últimos 7 Dias</span>
        </div>
        <div class="chart-area">
          <Bar :data="convTrendChart" :options="barOptions" />
        </div>
      </div>

      <!-- Taxa de conversão por corretor -->
      <div class="chart-panel mt-section">
        <div class="panel-head-row">
          <Users class="ic-purple" />
          <span>Taxa de Conversão por Corretor</span>
          <button class="btn-export-sm" @click="exportCSV('agents')"><Download class="ic" /> CSV</button>
        </div>
        <div class="table-wrap" v-if="agentsData.length">
          <table class="report-table">
            <thead>
              <tr>
                <th>Corretor</th>
                <th>Leads</th>
                <th>Visitas</th>
                <th>Fechados</th>
                <th>Conversão</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="a in agentsData" :key="a.id">
                <td class="agent-name">{{ a.name }}</td>
                <td>{{ a.leads_received }}</td>
                <td>{{ a.visits_scheduled }}</td>
                <td>{{ a.won }}</td>
                <td>
                  <span class="conv-badge" :class="a.conversion_rate >= 20 ? 'green' : a.conversion_rate >= 5 ? 'amber' : 'grey'">
                    {{ a.conversion_rate }}%
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="no-data-msg" v-else>Nenhum corretor encontrado no período.</div>
      </div>

      <!-- Top imóveis consultados pela IA -->
      <div class="chart-panel mt-section">
        <div class="panel-head-row">
          <Home class="ic-purple" />
          <span>Imóveis Mais Consultados pela IA</span>
        </div>
        <div v-if="performanceData.top_properties.length">
          <div class="prop-rank-item" v-for="(p, i) in performanceData.top_properties" :key="p.id">
            <span class="rank-num">{{ i + 1 }}</span>
            <div class="prop-rank-info">
              <span class="prop-rank-title">{{ p.title || 'Sem título' }}</span>
              <span class="prop-rank-sub">{{ p.neighborhood }} · R$ {{ Number(p.price).toLocaleString('pt-BR') }}</span>
            </div>
            <span class="prop-rank-count">{{ p.search_count }}x</span>
          </div>
        </div>
        <div class="no-data-msg" v-else>Nenhum imóvel consultado ainda. A contagem começa quando a IA busca imóveis para leads.</div>
      </div>

    </template>

  </div>
</template>

<style lang="scss" scoped>
.reports-page {
  padding: 2rem 2.5rem;
  background: var(--bg-primary, #f8f9fb);
  min-height: 100%;
  font-family: 'Inter', sans-serif;
}

.page-header {
  display: flex; justify-content: space-between; align-items: flex-start;
  margin-bottom: 1.5rem;
  h1 { font-size: 1.4rem; font-weight: 700; color: var(--text-main, #0f172a); margin: 0 0 0.2rem; display: flex; align-items: center; gap: 0.5rem; }
  p  { font-size: 0.85rem; color: var(--text-muted, #64748b); margin: 0; }
  .h-icon { width: 22px; height: 22px; color: #6366f1; }
}

.header-actions {
  display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap;
}

.period-select {
  border: 1px solid var(--border-color, #e2e8f0); border-radius: 8px;
  padding: 0.4rem 0.75rem; font-size: 0.85rem; background: var(--bg-secondary, #fff);
  color: var(--text-main, #334155); cursor: pointer;
  &:focus { outline: none; border-color: #6366f1; }
}

.custom-dates {
  display: flex; align-items: center; gap: 0.5rem; font-size: 0.82rem;
  color: var(--text-muted, #64748b);
}

.date-input {
  border: 1px solid var(--border-color, #e2e8f0); border-radius: 6px;
  padding: 0.35rem 0.6rem; font-size: 0.82rem;
  background: var(--bg-secondary, #fff); color: var(--text-main);
}

.btn-apply {
  background: #6366f1; color: white; border: none; border-radius: 6px;
  padding: 0.35rem 0.75rem; font-size: 0.82rem; cursor: pointer;
}

.last-updated {
  display: flex; align-items: center; gap: 0.35rem;
  font-size: 0.75rem; color: var(--text-muted, #94a3b8);
  .ic { width: 12px; height: 12px; }
}

.btn-refresh {
  background: var(--bg-secondary, #fff); border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 8px; padding: 0.4rem 0.5rem; cursor: pointer; display: flex; align-items: center;
  color: var(--text-muted);
  &:disabled { opacity: 0.5; }
  .ic { width: 16px; height: 16px; }
}

.kpi-row.refreshed .kpi-card {
  animation: flash-update 0.6s ease;
}
@keyframes flash-update {
  0%   { box-shadow: 0 0 0 0 rgba(99,102,241,0); }
  30%  { box-shadow: 0 0 0 4px rgba(99,102,241,0.25); }
  100% { box-shadow: 0 1px 4px rgba(0,0,0,0.04); }
}

.spinning { animation: spin 0.8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

/* Tabs */
.tabs {
  display: flex; gap: 0.25rem; margin-bottom: 1.5rem;
  border-bottom: 2px solid var(--border-color, #e2e8f0);
  padding-bottom: 0;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.tab {
  display: flex; align-items: center; gap: 0.4rem;
  padding: 0.6rem 1.25rem;
  background: none; border: none; border-bottom: 2px solid transparent;
  margin-bottom: -2px; cursor: pointer;
  font-size: 0.88rem; font-weight: 500; color: var(--text-muted, #64748b);
  transition: all 0.15s;
  flex-shrink: 0;
  white-space: nowrap;
  .ic { width: 15px; height: 15px; }
  &:hover { color: #6366f1; }
  &.active { color: #6366f1; border-bottom-color: #6366f1; font-weight: 600; }
}

/* KPIs */
.kpi-row {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.5rem;
}

.kpi-card {
  background: var(--bg-secondary, #fff);
  border: 1px solid var(--border-color, #e8edf2);
  border-radius: 12px; padding: 1.1rem 1.25rem;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}

.kpi-top {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 0.5rem;
}

.kpi-label { font-size: 0.72rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted, #94a3b8); }
.kpi-badge { font-size: 0.65rem; padding: 0.15rem 0.5rem; border-radius: 10px; font-weight: 600;
  &.blue { background: #eff6ff; color: #2563eb; } }

.kpi-val {
  font-size: 2rem; font-weight: 800; color: var(--text-main, #0f172a); letter-spacing: -0.02em;
  &.red    { color: #dc2626; }
  &.green  { color: #059669; }
  &.indigo { color: #4338ca; }
}

/* Charts */
.chart-row {
  display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.5rem;
}

.chart-panel {
  background: var(--bg-secondary, #fff); border: 1px solid var(--border-color, #e8edf2);
  border-radius: 12px; overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,0.04);
  &.wide { grid-column: 1 / -1; }
}

.chart-head {
  display: flex; justify-content: space-between; align-items: center;
  padding: 0.9rem 1.25rem; border-bottom: 1px solid var(--border-color, #f1f5f9);
  font-size: 0.9rem; font-weight: 600; color: var(--text-main, #1e293b);
  background: var(--bg-primary, #fafafa);
}

.chart-body { padding: 1.25rem; height: 240px; }

.btn-export {
  display: inline-flex; align-items: center; gap: 0.35rem;
  background: #6366f1; color: white; border: none; border-radius: 7px;
  padding: 0.4rem 0.9rem; font-size: 0.78rem; font-weight: 600; cursor: pointer;
  transition: background 0.15s;
  &:hover { background: #4f46e5; }
  &.green { background: #059669; &:hover { background: #047857; } }
  .ic { width: 13px; height: 13px; }
}

/* Temperatura */
.breakdown-panel {
  background: var(--bg-secondary, #fff); border: 1px solid var(--border-color, #e8edf2);
  border-radius: 12px; margin-bottom: 1.5rem; overflow: hidden;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}

.temp-row { display: flex; gap: 1rem; padding: 1.5rem 1.25rem; }

.temp-item {
  flex: 1; border-radius: 10px; padding: 1.25rem; text-align: center;
  display: flex; flex-direction: column; gap: 0.3rem;
  .temp-icon { font-size: 1.75rem; }
  .temp-n    { font-size: 2rem; font-weight: 800; }
  .temp-lbl  { font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; }
  &.hot  { background: #fef2f2; .temp-n { color: #dc2626; } .temp-lbl { color: #dc2626; } }
  &.warm { background: #fffbeb; .temp-n { color: #d97706; } .temp-lbl { color: #d97706; } }
  &.cold { background: #f0fdfa; .temp-n { color: #0f766e; } .temp-lbl { color: #0f766e; } }
}

/* Tabelas */
.table-panel {
  background: var(--bg-secondary, #fff); border: 1px solid var(--border-color, #e8edf2);
  border-radius: 12px; overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,0.04);
}

.table-wrap,
.table-scroll-wrapper {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.report-table {
  width: 100%; min-width: 640px; border-collapse: collapse;
  th, td { padding: 0.8rem 1rem; text-align: left; border-bottom: 1px solid var(--border-color, #f1f5f9); font-size: 0.85rem; }
  th { font-weight: 600; color: var(--text-main); background: var(--bg-primary, #fafafa); font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.04em; }
  td { color: var(--text-muted); }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: rgba(99,102,241,0.03); }
}

.agent-name { color: var(--text-main) !important; font-weight: 500; }
.center     { text-align: center !important; }
.no-data-cell { text-align: center; color: var(--text-muted); padding: 2rem !important; }

.badge-num {
  display: inline-block; padding: 0.15rem 0.6rem; border-radius: 20px; font-weight: 700; font-size: 0.85rem;
  &.blue  { background: #eff6ff; color: #2563eb; }
  &.red   { background: #fef2f2; color: #dc2626; }
  &.green { background: #ecfdf5; color: #059669; }
}

.rate { padding: 0.2rem 0.5rem; border-radius: 6px; font-weight: 700; font-size: 0.82rem;
  &.rate-good { background: #ecfdf5; color: #059669; }
  &.rate-mid  { background: #fffbeb; color: #d97706; }
  &.rate-low  { background: #f1f5f9; color: #64748b; }
}

/* Tags tab */
.tags-layout { display: grid; grid-template-columns: 240px 1fr; gap: 1rem; }

.tags-sidebar {
  background: var(--bg-secondary, #fff); border: 1px solid var(--border-color, #e8edf2);
  border-radius: 12px; overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,0.04);
  height: fit-content;
}

.sidebar-head {
  padding: 0.9rem 1rem; font-size: 0.75rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.06em;
  color: var(--text-muted, #94a3b8);
  border-bottom: 1px solid var(--border-color, #f1f5f9);
  background: var(--bg-primary, #fafafa);
}

.tag-item {
  display: flex; align-items: center; gap: 0.6rem;
  padding: 0.65rem 1rem; cursor: pointer;
  border-bottom: 1px solid var(--border-color, #f8fafc);
  transition: background 0.15s;
  &:hover { background: rgba(99,102,241,0.04); }
  &.active { background: rgba(99,102,241,0.08); }
}

.tag-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
.tag-name { flex: 1; font-size: 0.85rem; color: var(--text-main); font-weight: 500; }
.tag-count { font-size: 0.75rem; font-weight: 700; color: var(--text-muted); background: var(--bg-primary, #f1f5f9); padding: 0.1rem 0.45rem; border-radius: 10px; }

.no-tags { padding: 1rem; font-size: 0.82rem; color: var(--text-muted); text-align: center; }

.tags-content { background: var(--bg-secondary, #fff); border: 1px solid var(--border-color, #e8edf2); border-radius: 12px; overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,0.04); }

.tag-badge { display: inline-block; padding: 0.2rem 0.7rem; border-radius: 20px; color: white; font-size: 0.82rem; font-weight: 700; }
.export-group { display: flex; gap: 0.5rem; }

.temp-badge {
  display: inline-block; padding: 0.2rem 0.6rem; border-radius: 10px; font-size: 0.72rem; font-weight: 700;
  &.quente { background: #fef2f2; color: #dc2626; }
  &.morno  { background: #fffbeb; color: #d97706; }
  &.frio   { background: #f0fdfa; color: #0f766e; }
}

.status-badge {
  display: inline-block; padding: 0.2rem 0.65rem; border-radius: 10px; font-size: 0.72rem; font-weight: 700;
  &.pending, &.agendado   { background: #fffbeb; color: #d97706; }
  &.confirmed, &.confirmado { background: #eff6ff; color: #2563eb; }
  &.completed, &.realizado  { background: #ecfdf5; color: #059669; }
  &.cancelled, &.cancelado  { background: #fef2f2; color: #dc2626; }
}

/* Skeleton */
.skeleton-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; animation: pulse 1.4s infinite; }
.skel { height: 120px; background: var(--bg-secondary, #e5e7eb); border-radius: 12px; }
@keyframes pulse { 0%, 100% { opacity: 0.5; } 50% { opacity: 1; } }

@media (max-width: 1100px) {
  .kpi-row    { grid-template-columns: repeat(2, 1fr); }
  .chart-row  { grid-template-columns: 1fr; }
  .tags-layout { grid-template-columns: 1fr; }
}

@media (max-width: 640px) {
  .reports-page {
    padding: 1rem;
  }

  .page-header {
    flex-direction: column;
    gap: 0.75rem;
  }

  .kpi-row {
    grid-template-columns: 1fr;
  }
}

/* Performance tab */
.mt-section { margin-top: 1.5rem; }

.chart-panel {
  background: var(--bg-secondary, #fff);
  border: 1px solid var(--border-color, #e8edf2);
  border-radius: 12px;
  overflow: hidden;
}

.panel-head-row {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.9rem 1.25rem;
  border-bottom: 1px solid var(--border-color, #f1f5f9);
  font-size: 0.88rem; font-weight: 600; color: var(--text-main, #1e293b);
  background: var(--bg-primary, #fafafa);
  .ic-purple { width: 16px; height: 16px; color: #6366f1; }
  span { flex: 1; }
}

.chart-area { padding: 1.25rem; height: 240px; }

.kpi-icon-sm { width: 16px; height: 16px; color: #6366f1; margin-right: 0.4rem; }

.kpi-top { display: flex; align-items: center; margin-bottom: 0.5rem; }

.kpi-val.grey { color: var(--text-muted, #94a3b8); font-size: 1.1rem; }

.no-data-msg {
  padding: 2rem 1.25rem; text-align: center;
  font-size: 0.82rem; color: var(--text-muted, #94a3b8);
}

.btn-export-sm {
  display: inline-flex; align-items: center; gap: 0.3rem;
  padding: 0.25rem 0.65rem; border-radius: 6px; font-size: 0.75rem; font-weight: 500;
  border: 1px solid var(--border-color, #e2e8f0); background: var(--bg-secondary, #fff);
  color: var(--text-main, #334155); cursor: pointer;
  .ic { width: 12px; height: 12px; }
  &:hover { background: var(--bg-primary, #f8fafc); }
}

.conv-badge {
  display: inline-block; padding: 0.15rem 0.55rem; border-radius: 12px;
  font-size: 0.75rem; font-weight: 700;
  &.green  { background: #ecfdf5; color: #059669; }
  &.amber  { background: #fffbeb; color: #d97706; }
  &.grey   { background: #f1f5f9; color: #64748b; }
}

.prop-rank-item {
  display: flex; align-items: center; gap: 1rem;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border-color, #f1f5f9);
  &:last-child { border-bottom: none; }
}

.rank-num {
  width: 24px; height: 24px; border-radius: 50%;
  background: #6366f1; color: white;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.72rem; font-weight: 700; flex-shrink: 0;
}

.prop-rank-info { flex: 1; }
.prop-rank-title { display: block; font-size: 0.85rem; font-weight: 600; color: var(--text-main, #1e293b); }
.prop-rank-sub   { display: block; font-size: 0.75rem; color: var(--text-muted, #64748b); margin-top: 0.1rem; }
.prop-rank-count { font-size: 0.88rem; font-weight: 700; color: #6366f1; white-space: nowrap; }
</style>
