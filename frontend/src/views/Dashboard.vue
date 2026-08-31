<script setup>
import { onMounted, computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  Users, Handshake, CalendarDays, Flame, RefreshCw,
  MessageCircle, UserCheck, CalendarCheck, TrendingUp, BarChart2,
  ChevronRight, ArrowRight, CheckCircle2, Circle, ClipboardList
} from 'lucide-vue-next'
import { Doughnut } from 'vue-chartjs'
import { Chart as ChartJS, Title, Tooltip, Legend, ArcElement, CategoryScale } from 'chart.js'
import { useDashboardStore } from '../store/dashboard'
import { useConversationsStore } from '../store/conversations'
import { storeToRefs } from 'pinia'
import api from '../api'

ChartJS.register(Title, Tooltip, Legend, ArcElement, CategoryScale)

const router = useRouter()
const store = useDashboardStore()
const conversationsStore = useConversationsStore()
const { kpis, isLoading, isOwner, todayLeads } = storeToRefs(store)

const openConversation = (conversationId) => {
  conversationsStore.setActiveConversation(conversationId)
  router.push('/conversas')
}

const dashTitle = computed(() => isOwner.value ? 'Dashboard' : 'Meu Painel')

// ── Tarefas do Dia (checklist real, não contador) ──────────────────────────
const TAREFA_TIPO_LABELS = {
  terceiro_dia: '3º Dia',
  decimo_dia:   '10º Dia',
  vigesimo_dia: '20º Dia',
  atrasada:     'Atrasada',
  manual:       'Manual'
}

const tarefasPendentes = ref([])
const isLoadingTarefas = ref(true)
const completingId = ref(null)

const fetchTarefasPendentes = async () => {
  isLoadingTarefas.value = true
  try {
    const { data } = await api.get('/tarefas', { params: { status: 'pendente' } })
    tarefasPendentes.value = data
  } catch (e) {
    console.error('Erro ao buscar tarefas do dia:', e)
  } finally {
    isLoadingTarefas.value = false
  }
}

const completeTarefa = async (tarefa) => {
  completingId.value = tarefa.id
  try {
    await api.patch(`/tarefas/${tarefa.id}/complete`)
    tarefasPendentes.value = tarefasPendentes.value.filter(t => t.id !== tarefa.id)
  } catch (e) {
    console.error('Erro ao concluir tarefa:', e)
  } finally {
    completingId.value = null
  }
}

const openTarefaContact = (tarefa) => {
  if (tarefa.contact?.id) router.push(`/contatos/${tarefa.contact.id}`)
}

onMounted(() => {
  store.fetchDashboard()
  fetchTarefasPendentes()
})

const refreshAll = () => {
  store.fetchDashboard()
  fetchTarefasPendentes()
}

// ── Régua (funil) + Distribuição por status — paleta monocromática vinho,
// só o alerta crítico (Atrasada) sai do tom institucional.
const WINE_SHADES = ['#2b0016', '#5c1a35', '#8a3355', '#b45a78', '#ff007f']
const ALERT_COLOR = '#a24a3a'

const funnelTotal = computed(() => {
  const k = kpis.value?.kanban
  if (!k) return 1
  return (k.revendedor_ativo + k.terceiro_dia + k.decimo_dia + k.vigesimo_dia + k.agendado) || 1
})

const funnelItems = computed(() => {
  const k = kpis.value?.kanban || {}
  return [
    { label: 'Ativa',    value: k.revendedor_ativo || 0, color: WINE_SHADES[0] },
    { label: '3º Dia',   value: k.terceiro_dia      || 0, color: WINE_SHADES[1] },
    { label: '10º Dia',  value: k.decimo_dia        || 0, color: WINE_SHADES[2] },
    { label: '20º Dia',  value: k.vigesimo_dia      || 0, color: WINE_SHADES[3] },
    { label: 'Agendado', value: k.agendado          || 0, color: WINE_SHADES[4] }
  ]
})

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '72%',
  plugins: {
    legend: { position: 'bottom', labels: { font: { family: "'Inter', sans-serif", size: 12 }, padding: 16, usePointStyle: true } }
  }
}

const statusDistributionData = computed(() => {
  const k = kpis.value?.kanban || {}
  const entries = [
    ['Ativa',     k.revendedor_ativo, WINE_SHADES[0]],
    ['3º Dia',    k.terceiro_dia,     WINE_SHADES[1]],
    ['10º Dia',   k.decimo_dia,       WINE_SHADES[2]],
    ['20º Dia',   k.vigesimo_dia,     WINE_SHADES[3]],
    ['Agendado',  k.agendado,         WINE_SHADES[4]],
    ['Reagendar', k.reagendar,        '#94a3b8'],
    ['Atrasada',  k.atrasada,         ALERT_COLOR]
  ].filter(([, v]) => v > 0)

  if (entries.length === 0) {
    return { labels: ['Sem dados'], datasets: [{ data: [1], backgroundColor: ['#e5e7eb'] }] }
  }

  return {
    labels: entries.map(([l]) => l),
    datasets: [{ data: entries.map(([, v]) => v), backgroundColor: entries.map(([, , c]) => c) }]
  }
})
</script>

<template>
  <div class="db">
    <!-- Header -->
    <div class="db-header">
      <h1>{{ dashTitle }}</h1>
      <button class="btn-outline" @click="refreshAll">
        <RefreshCw class="ic" /> Atualizar
      </button>
    </div>

    <div v-if="isLoading" class="skeleton-wrap">
      <div class="skel-bar"></div>
      <div class="skel-row">
        <div class="skel-wide"></div>
        <div class="skel-narrow"></div>
      </div>
    </div>

    <template v-else>

      <!-- Revendedoras atribuídas hoje — compacto, uma linha por item -->
      <div v-if="todayLeads.length > 0" class="today-strip">
        <span class="today-strip-label">{{ isOwner ? 'Chegaram hoje' : 'Atribuídas a você hoje' }}</span>
        <button
          v-for="lead in todayLeads.slice(0, 6)"
          :key="lead.conversation_id"
          class="today-chip"
          @click="openConversation(lead.conversation_id)"
        >
          {{ lead.contact_name }}
        </button>
        <span v-if="todayLeads.length > 6" class="today-chip-more">+{{ todayLeads.length - 6 }}</span>
      </div>

      <!-- Barra unificada da carteira -->
      <div class="metrics-bar">
        <div class="metric">
          <Users class="metric-ic" />
          <div>
            <div class="metric-val">{{ kpis.carteira.ativas_total }}</div>
            <div class="metric-lbl">Revendedoras Ativas</div>
          </div>
        </div>
        <div class="metric-sep"></div>
        <div class="metric">
          <Handshake class="metric-ic" />
          <div>
            <div class="metric-val">{{ kpis.carteira.com_maleta }}</div>
            <div class="metric-lbl">Com Maleta (&gt;25 peças)</div>
          </div>
        </div>
        <div class="metric-sep"></div>
        <div class="metric">
          <CalendarDays class="metric-ic" />
          <div>
            <div class="metric-val">{{ kpis.carteira.agendadas }}</div>
            <div class="metric-lbl">Agendadas</div>
          </div>
        </div>
        <div class="metric-sep"></div>
        <div class="metric" :class="{ alert: kpis.carteira.atrasadas > 0 }">
          <Flame class="metric-ic" />
          <div>
            <div class="metric-val">{{ kpis.carteira.atrasadas }}</div>
            <div class="metric-lbl">Atrasadas</div>
          </div>
        </div>
      </div>

      <!-- Corpo: 60% Tarefas do Dia / 40% Central de Atendimento -->
      <div class="main-grid">

        <!-- Esquerda: checklist de tarefas -->
        <div class="panel tasks-panel">
          <div class="panel-head">
            <ClipboardList class="ic" /> Tarefas do Dia
            <span class="panel-count">{{ tarefasPendentes.length }}</span>
          </div>

          <router-link v-if="kpis.tarefas_do_dia.reagendar > 0" to="/carteira" class="reagendar-banner">
            {{ kpis.tarefas_do_dia.reagendar }} revendedora{{ kpis.tarefas_do_dia.reagendar === 1 ? '' : 's' }} aguardando reagendamento
            <ChevronRight class="ic-xs" />
          </router-link>

          <div class="task-list" v-if="!isLoadingTarefas && tarefasPendentes.length > 0">
            <div v-for="t in tarefasPendentes" :key="t.id" class="task-row">
              <button class="task-check" :disabled="completingId === t.id" @click="completeTarefa(t)" title="Concluir">
                <CheckCircle2 v-if="completingId === t.id" class="ic-sm spin" />
                <Circle v-else class="ic-sm" />
              </button>
              <div class="task-body" @click="openTarefaContact(t)">
                <div class="task-top">
                  <span class="task-name">{{ t.contact?.name || t.contact?.phone || 'Sem nome' }}</span>
                  <span class="task-tag">{{ TAREFA_TIPO_LABELS[t.tipo] || t.tipo }}</span>
                </div>
                <div class="task-title">{{ t.titulo }}</div>
              </div>
            </div>
          </div>

          <div v-else-if="isLoadingTarefas" class="panel-empty"><p>Carregando tarefas...</p></div>
          <div v-else class="panel-empty">
            <CheckCircle2 class="panel-empty-ic" />
            <p>Nenhuma tarefa pendente — carteira em dia.</p>
          </div>
        </div>

        <!-- Direita: central de atendimento -->
        <div class="panel attendance-panel">
          <div class="panel-head">
            <MessageCircle class="ic" /> Central de Atendimento
          </div>
          <div class="attendance-list">
            <div class="attendance-row">
              <MessageCircle class="ic-sm" />
              <span class="attendance-lbl">Conversas Abertas</span>
              <span class="attendance-val">{{ kpis.conversations.open }}</span>
            </div>
            <div class="attendance-row">
              <UserCheck class="ic-sm" />
              <span class="attendance-lbl">Com Atendente Humano</span>
              <span class="attendance-val">{{ kpis.conversations.with_human }}</span>
            </div>
            <div class="attendance-row">
              <CalendarCheck class="ic-sm" />
              <span class="attendance-lbl">Conversas Resolvidas</span>
              <span class="attendance-val">{{ kpis.conversations.resolved }}</span>
            </div>
            <div class="attendance-row highlight">
              <Handshake class="ic-sm" />
              <span class="attendance-lbl">Acertos da Semana</span>
              <span class="attendance-val">{{ kpis.conversations.acertos_semana }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Régua + Distribuição -->
      <div class="section-label mt-section">Régua de Relacionamento &amp; Distribuição por Status</div>
      <div class="grid-2-3">
        <div class="panel">
          <div class="panel-head">
            <BarChart2 class="ic" /> Régua de Relacionamento
          </div>
          <div class="funnel-list">
            <div v-for="item in funnelItems" :key="item.label" class="funnel-item">
              <div class="funnel-meta">
                <span class="funnel-label">{{ item.label }}</span>
                <span class="funnel-val" :style="{ color: item.color }">{{ item.value }}</span>
              </div>
              <div class="funnel-track">
                <div class="funnel-fill" :style="{
                  width: Math.max((item.value / funnelTotal) * 100, item.value > 0 ? 4 : 0) + '%',
                  background: item.color
                }"></div>
              </div>
            </div>
          </div>
          <div class="funnel-footer">
            <button class="btn-link" @click="router.push('/funil')">
              Ver funil completo <ChevronRight class="ic-xs" />
            </button>
          </div>
        </div>

        <div class="panel">
          <div class="panel-head">
            <TrendingUp class="ic" /> Distribuição por Status
          </div>
          <div class="chart-wrap" v-if="statusDistributionData.labels[0] !== 'Sem dados'">
            <Doughnut :data="statusDistributionData" :options="chartOptions" />
          </div>
          <div class="no-data" v-else>
            <BarChart2 class="no-data-ic" />
            <p>Nenhum dado ainda</p>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<style lang="scss" scoped>
.db {
  --wine: #2b0016;
  --wine-soft: rgba(43, 0, 22, 0.06);
  --wine-soft-2: rgba(43, 0, 22, 0.1);
  --alert: #a24a3a;
  --alert-bg: #fbeeea;

  padding: 2rem 2.5rem;
  background: var(--bg-primary, #f8f9fb);
  min-height: 100%;
  font-family: 'Inter', sans-serif;
}

/* Header */
.db-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;

  h1 {
    font-size: 1.45rem;
    font-weight: 700;
    color: var(--text-main, #0f172a);
    margin: 0;
  }
}

.btn-outline {
  display: inline-flex; align-items: center; gap: 0.4rem;
  border: 1px solid var(--border-color, #e2e8f0);
  background: var(--bg-secondary, #fff);
  color: var(--wine);
  padding: 0.45rem 1rem; border-radius: 8px;
  font-size: 0.82rem; font-weight: 600; cursor: pointer;
  transition: all 0.15s;
  &:hover { background: var(--wine-soft); }
  .ic { width: 14px; height: 14px; }
}

/* Today strip */
.today-strip {
  display: flex; align-items: center; flex-wrap: wrap; gap: 0.5rem;
  margin-bottom: 1.25rem;
}
.today-strip-label {
  font-size: 0.72rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: 0.06em; color: var(--text-muted, #94a3b8); margin-right: 0.25rem;
}
.today-chip {
  background: var(--wine-soft);
  color: var(--wine);
  border: none;
  border-radius: 20px;
  padding: 0.3rem 0.8rem;
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
  &:hover { background: var(--wine-soft-2); }
}
.today-chip-more {
  font-size: 0.75rem; color: var(--text-muted, #94a3b8); padding: 0.3rem 0.4rem;
}

/* Barra unificada da carteira */
.metrics-bar {
  display: flex;
  align-items: center;
  background: linear-gradient(135deg, rgba(255, 0, 127, 0.1), rgba(43, 0, 22, 0.04));
  border: 1px solid rgba(43, 0, 22, 0.12);
  border-radius: 14px;
  padding: 1.1rem 1.5rem;
  margin-bottom: 1.5rem;
  gap: 1.5rem;
}

.metric {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex: 1;
  min-width: 0;

  &.alert {
    .metric-ic { color: var(--alert); }
    .metric-val { color: var(--alert); }
  }
}

.metric-sep {
  width: 1px;
  height: 32px;
  background: rgba(43, 0, 22, 0.12);
  flex-shrink: 0;
}

.metric-ic {
  width: 22px; height: 22px; color: var(--wine); flex-shrink: 0;
}

.metric-val {
  font-size: 1.5rem; font-weight: 800; color: var(--wine); line-height: 1.1;
}

.metric-lbl {
  font-size: 0.72rem; font-weight: 600; color: var(--text-muted, #64748b);
  text-transform: uppercase; letter-spacing: 0.03em; margin-top: 0.15rem;
}

/* Corpo 60/40 */
.main-grid {
  display: grid;
  grid-template-columns: 3fr 2fr;
  gap: 1.25rem;
  margin-bottom: 1.75rem;
  align-items: start;
}

.panel {
  background: var(--bg-secondary, #fff);
  border-radius: 14px;
  border: 1px solid var(--border-color, #e8edf2);
  box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
  overflow: hidden;
  display: flex; flex-direction: column;
}

.panel-head {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 1rem 1.25rem; border-bottom: 1px solid var(--border-color, #f1f5f9);
  font-size: 0.88rem; font-weight: 700; color: var(--wine);
  background: var(--wine-soft);
  .ic { width: 16px; height: 16px; }
}

.panel-count {
  margin-left: auto;
  background: var(--wine);
  color: #fff;
  font-size: 0.68rem;
  font-weight: 700;
  padding: 0.1rem 0.5rem;
  border-radius: 20px;
}

.reagendar-banner {
  display: flex; align-items: center; gap: 0.4rem;
  background: var(--alert-bg);
  color: var(--alert);
  font-size: 0.78rem;
  font-weight: 600;
  padding: 0.6rem 1.25rem;
  text-decoration: none;
  border-bottom: 1px solid var(--border-color, #f1f5f9);
  .ic-xs { width: 13px; height: 13px; margin-left: auto; }
}

.task-list {
  max-height: 420px;
  overflow-y: auto;
}

.task-row {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
  padding: 0.75rem 1.25rem;
  border-bottom: 1px solid var(--border-color, #f4f4f5);
  &:last-child { border-bottom: none; }
}

.task-check {
  background: none; border: none; cursor: pointer; padding: 0.1rem;
  color: var(--text-muted, #94a3b8);
  flex-shrink: 0;
  margin-top: 0.1rem;
  &:hover { color: var(--wine); }
  .ic-sm { width: 18px; height: 18px; }
  .spin { color: var(--wine); animation: pulse 1s infinite; }
}

.task-body {
  flex: 1;
  min-width: 0;
  cursor: pointer;
}

.task-top {
  display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;
}

.task-name {
  font-size: 0.85rem; font-weight: 600; color: var(--text-main, #1e293b);
}

.task-tag {
  font-size: 0.66rem; font-weight: 700; text-transform: uppercase;
  background: var(--bg-tertiary, #f1f5f9); color: var(--text-muted, #64748b);
  padding: 0.1rem 0.45rem; border-radius: 4px; letter-spacing: 0.03em;
}

.task-title {
  font-size: 0.78rem; color: var(--text-muted, #64748b); margin-top: 0.15rem;
}

.panel-empty {
  flex: 1; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 0.5rem;
  color: var(--text-muted, #94a3b8); padding: 2.5rem 1rem;
  .panel-empty-ic { width: 32px; height: 32px; opacity: 0.4; color: var(--wine); }
  p { font-size: 0.82rem; margin: 0; }
}

/* Central de Atendimento */
.attendance-list {
  padding: 0.5rem 1.25rem;
  display: flex; flex-direction: column;
}

.attendance-row {
  display: flex; align-items: center; gap: 0.6rem;
  padding: 0.85rem 0;
  border-bottom: 1px solid var(--border-color, #f4f4f5);
  &:last-child { border-bottom: none; }

  .ic-sm { width: 17px; height: 17px; color: var(--wine); flex-shrink: 0; }
  .attendance-lbl { font-size: 0.82rem; color: var(--text-muted, #64748b); flex: 1; }
  .attendance-val { font-size: 1.05rem; font-weight: 800; color: var(--text-main, #1e293b); }

  &.highlight {
    .ic-sm, .attendance-val { color: var(--wine); }
  }
}

/* Labels de seção */
.section-label {
  font-size: 0.72rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: 0.08em; color: var(--text-muted, #94a3b8);
  margin-bottom: 0.75rem;
  &.mt-section { margin-top: 1.75rem; }
}

.grid-2-3 {
  display: grid;
  grid-template-columns: 1fr 1.2fr;
  gap: 1rem;
}

/* Funil */
.funnel-list {
  padding: 1rem 1.25rem;
  display: flex; flex-direction: column; gap: 1rem;
  flex: 1;
}

.funnel-item { display: flex; flex-direction: column; gap: 0.4rem; }

.funnel-meta {
  display: flex; align-items: center; gap: 0.5rem;
  .funnel-label { flex: 1; font-size: 0.82rem; color: var(--text-muted, #64748b); font-weight: 500; }
  .funnel-val { font-size: 0.9rem; font-weight: 700; }
}

.funnel-track {
  height: 6px; background: var(--border-color, #f1f5f9); border-radius: 3px; overflow: hidden;
}

.funnel-fill {
  height: 100%; border-radius: 3px;
  transition: width 0.6s cubic-bezier(0.4,0,0.2,1);
}

.funnel-footer {
  padding: 0.75rem 1.25rem;
  border-top: 1px solid var(--border-color, #f1f5f9);
}

.btn-link {
  display: inline-flex; align-items: center; gap: 0.25rem;
  background: none; border: none; cursor: pointer;
  font-size: 0.78rem; font-weight: 600; color: var(--wine);
  padding: 0; transition: gap 0.15s;
  &:hover { gap: 0.5rem; }
  .ic-xs { width: 13px; height: 13px; }
}

/* Donut chart */
.chart-wrap {
  padding: 1.25rem;
  height: 260px;
  display: flex; align-items: center; justify-content: center;
}

.no-data {
  flex: 1; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 0.5rem;
  color: var(--text-muted, #94a3b8); padding: 2rem;
  .no-data-ic { width: 40px; height: 40px; opacity: 0.3; }
  p { font-size: 0.82rem; margin: 0; }
}

/* Skeleton */
.skeleton-wrap { display: flex; flex-direction: column; gap: 1rem; }
.skel-bar { height: 80px; background: var(--bg-secondary, #e5e7eb); border-radius: 14px; animation: pulse 1.4s infinite; }
.skel-row { display: grid; grid-template-columns: 3fr 2fr; gap: 1.25rem; animation: pulse 1.4s infinite; }
.skel-wide { height: 320px; background: var(--bg-secondary, #e5e7eb); border-radius: 14px; }
.skel-narrow { height: 320px; background: var(--bg-secondary, #e5e7eb); border-radius: 14px; }

@keyframes pulse {
  0%, 100% { opacity: 0.5; }
  50% { opacity: 1; }
}

/* Responsive */
@media (max-width: 1100px) {
  .main-grid { grid-template-columns: 1fr; }
  .grid-2-3 { grid-template-columns: 1fr; }
  .metrics-bar { flex-wrap: wrap; }
  .metric-sep { display: none; }
}

@media (max-width: 768px) {
  .db { padding: 1rem; }
  .metrics-bar { flex-direction: column; align-items: stretch; gap: 0.75rem; }
}
</style>
