<script setup>
import { onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import {
  Users, Flame, ThermometerSun, Snowflake, Calendar, CalendarCheck,
  CalendarDays, MessageCircle, UserCheck, TrendingUp, BarChart2,
  CheckCircle, ChevronRight, Handshake, Phone, ArrowRight, Inbox
} from 'lucide-vue-next'
import { Doughnut } from 'vue-chartjs'
import { Chart as ChartJS, Title, Tooltip, Legend, ArcElement, CategoryScale } from 'chart.js'
import { useDashboardStore } from '../store/dashboard'
import { useConversationsStore } from '../store/conversations'
import { storeToRefs } from 'pinia'

ChartJS.register(Title, Tooltip, Legend, ArcElement, CategoryScale)

const router = useRouter()
const store = useDashboardStore()
const conversationsStore = useConversationsStore()
const { kpis, leadsBySourceData, isLoading, isOwner, todayLeads } = storeToRefs(store)

const openConversation = (conversationId) => {
  conversationsStore.setActiveConversation(conversationId)
  router.push('/conversas')
}

const tempColor = (t) => {
  if (!t) return { bg: '#f1f5f9', text: '#64748b', label: 'Sem temp.' }
  const l = t.toLowerCase()
  if (l === 'quente') return { bg: '#fef2f2', text: '#dc2626', label: 'Quente' }
  if (l === 'morno')  return { bg: '#fffbeb', text: '#d97706', label: 'Morno'  }
  return                     { bg: '#eff6ff', text: '#2563eb', label: 'Frio'   }
}

const kanbanLabel = (s) => {
  const map = { lead: 'Novo Lead', visit: 'Visita Agendada', proposal: 'Proposta', won: 'Fechado' }
  return map[s] || s || '—'
}

onMounted(() => store.fetchDashboard())

const dashTitle    = computed(() => isOwner.value ? 'Dashboard Imobiliário' : 'Meu Painel')
const dashSubtitle = computed(() => isOwner.value
  ? 'Visão estratégica da sua imobiliária em tempo real.'
  : 'Seus leads e atendimentos atribuídos a você.')

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '72%',
  plugins: {
    legend: { position: 'bottom', labels: { font: { family: "'Inter', sans-serif", size: 12 }, padding: 16, usePointStyle: true } }
  }
}

const funnelTotal = computed(() => {
  const k = kpis.value?.kanban
  if (!k) return 1
  return (k.lead + k.visit + k.proposal + k.won) || 1
})

const funnelItems = computed(() => {
  const k = kpis.value?.kanban || {}
  return [
    { label: 'Novos Leads',      value: k.lead     || 0, color: '#6366f1', icon: Users },
    { label: 'Visita Agendada',  value: k.visit    || 0, color: '#f59e0b', icon: Calendar },
    { label: 'Proposta Feita',   value: k.proposal || 0, color: '#3b82f6', icon: Handshake },
    { label: 'Negócio Fechado',  value: k.won      || 0, color: '#10b981', icon: CheckCircle }
  ]
})
</script>

<template>
  <div class="db">
    <!-- Header -->
    <div class="db-header">
      <div>
        <h1>{{ dashTitle }}</h1>
        <p>{{ dashSubtitle }}</p>
      </div>
      <div class="header-actions">
        <button class="btn-outline" @click="store.fetchDashboard()">
          <TrendingUp class="ic" /> Atualizar
        </button>
      </div>
    </div>

    <!-- Skeleton -->
    <div v-if="isLoading" class="skeleton-wrap">
      <div class="skel-row">
        <div class="skel-card" v-for="i in 4" :key="i"></div>
      </div>
      <div class="skel-row mt">
        <div class="skel-wide"></div>
        <div class="skel-half-col">
          <div class="skel-sm" v-for="i in 3" :key="i"></div>
        </div>
      </div>
    </div>

    <template v-else>

      <!-- Leads Atribuídos Hoje -->
      <div class="section-label">
        {{ isOwner ? 'Leads Chegaram Hoje' : 'Leads Atribuídos a Você Hoje' }}
        <span class="today-count">{{ todayLeads.length }}</span>
      </div>

      <div v-if="todayLeads.length === 0" class="today-empty">
        <Inbox class="today-empty-ic" />
        <p>{{ isOwner ? 'Nenhuma conversa nova chegou hoje ainda.' : 'Nenhum lead foi atribuído a você hoje ainda.' }}</p>
      </div>

      <div v-else class="today-leads-grid">
        <div
          v-for="lead in todayLeads"
          :key="lead.conversation_id"
          class="today-lead-card"
          @click="openConversation(lead.conversation_id)"
        >
          <div class="tlc-avatar">
            {{ (lead.contact_name || '?')[0].toUpperCase() }}
          </div>
          <div class="tlc-body">
            <div class="tlc-top">
              <span class="tlc-name">{{ lead.contact_name }}</span>
              <span class="tlc-badge" :style="{ background: tempColor(lead.temperature).bg, color: tempColor(lead.temperature).text }">
                {{ tempColor(lead.temperature).label }}
              </span>
            </div>
            <div class="tlc-phone" v-if="lead.contact_phone">
              <Phone class="tlc-icon" /> {{ lead.contact_phone }}
            </div>
            <div class="tlc-intention" v-if="lead.intention">{{ lead.intention }}</div>
            <div class="tlc-footer">
              <span class="tlc-stage">{{ kanbanLabel(lead.kanban_status) }}</span>
              <span class="tlc-agent" v-if="lead.assigned_to">→ {{ lead.assigned_to }}</span>
              <span class="tlc-time">{{ new Date(lead.created_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) }}</span>
            </div>
          </div>
          <ArrowRight class="tlc-arrow" />
        </div>
      </div>

      <!-- Row 1: Temperatura dos Leads -->
      <div class="section-label mt-section">Termômetro de Leads</div>
      <div class="grid-4">
        <div class="kpi-card accent-blue">
          <div class="kpi-left">
            <div class="kpi-icon blue"><Users /></div>
            <div>
              <div class="kpi-val">{{ kpis.total_contacts }}</div>
              <div class="kpi-lbl">Total de Contatos</div>
            </div>
          </div>
          <div class="kpi-bar-mini">
            <span class="dot red"></span><span class="mini-n">{{ kpis.temperature.quente }}</span>
            <span class="dot amber"></span><span class="mini-n">{{ kpis.temperature.morno }}</span>
            <span class="dot teal"></span><span class="mini-n">{{ kpis.temperature.frio }}</span>
          </div>
        </div>

        <div class="kpi-card accent-red">
          <div class="kpi-left">
            <div class="kpi-icon red"><Flame /></div>
            <div>
              <div class="kpi-val">{{ kpis.temperature.quente }}</div>
              <div class="kpi-lbl">Leads Quentes</div>
            </div>
          </div>
          <div class="kpi-badge hot">Alta prioridade</div>
        </div>

        <div class="kpi-card accent-amber">
          <div class="kpi-left">
            <div class="kpi-icon amber"><ThermometerSun /></div>
            <div>
              <div class="kpi-val">{{ kpis.temperature.morno }}</div>
              <div class="kpi-lbl">Leads Mornos</div>
            </div>
          </div>
          <div class="kpi-badge warm">Nutrir</div>
        </div>

        <div class="kpi-card accent-teal">
          <div class="kpi-left">
            <div class="kpi-icon teal"><Snowflake /></div>
            <div>
              <div class="kpi-val">{{ kpis.temperature.frio }}</div>
              <div class="kpi-lbl">Leads Frios</div>
            </div>
          </div>
          <div class="kpi-badge cold">Reconquistar</div>
        </div>
      </div>

      <!-- Row 2: Conversas + Agendamentos -->
      <div class="section-label mt-section">Atendimento & Agenda</div>
      <div class="grid-4">
        <div class="kpi-card accent-purple">
          <div class="kpi-left">
            <div class="kpi-icon purple"><MessageCircle /></div>
            <div>
              <div class="kpi-val">{{ kpis.conversations.open }}</div>
              <div class="kpi-lbl">Conversas Abertas</div>
            </div>
          </div>
          <div class="kpi-sub">{{ kpis.conversations.today }} novas hoje</div>
        </div>

        <div class="kpi-card accent-violet">
          <div class="kpi-left">
            <div class="kpi-icon violet"><UserCheck /></div>
            <div>
              <div class="kpi-val">{{ kpis.conversations.with_human }}</div>
              <div class="kpi-lbl">Com Atendente Humano</div>
            </div>
          </div>
          <div class="kpi-badge human">Em andamento</div>
        </div>

        <div class="kpi-card accent-green">
          <div class="kpi-left">
            <div class="kpi-icon green"><CalendarDays /></div>
            <div>
              <div class="kpi-val">{{ kpis.appointments.upcoming }}</div>
              <div class="kpi-lbl">Visitas Agendadas</div>
            </div>
          </div>
          <div class="kpi-sub">{{ kpis.appointments.today }} hoje</div>
        </div>

        <div class="kpi-card accent-indigo">
          <div class="kpi-left">
            <div class="kpi-icon indigo"><CalendarCheck /></div>
            <div>
              <div class="kpi-val">{{ kpis.appointments.done }}</div>
              <div class="kpi-lbl">Visitas Realizadas</div>
            </div>
          </div>
          <div class="kpi-badge done">Concluídas</div>
        </div>
      </div>

      <!-- Row 3: Funil + Gráfico -->
      <div class="section-label mt-section">Funil de Vendas & Origem dos Leads</div>
      <div class="grid-2-3">

        <!-- Funil -->
        <div class="panel">
          <div class="panel-head">
            <BarChart2 class="ic" /> Funil de Vendas
          </div>
          <div class="funnel-list">
            <div v-for="item in funnelItems" :key="item.label" class="funnel-item">
              <div class="funnel-meta">
                <component :is="item.icon" class="funnel-ic" :style="{ color: item.color }" />
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

        <!-- Doughnut Origem -->
        <div class="panel">
          <div class="panel-head">
            <TrendingUp class="ic" /> Leads por Origem
          </div>
          <div class="chart-wrap" v-if="leadsBySourceData.labels[0] !== 'Sem dados'">
            <Doughnut :data="leadsBySourceData" :options="chartOptions" />
          </div>
          <div class="no-data" v-else>
            <BarChart2 class="no-data-ic" />
            <p>Nenhuma origem cadastrada ainda</p>
          </div>
        </div>

      </div>
    </template>
  </div>
</template>

<style lang="scss" scoped>
.db {
  padding: 2rem 2.5rem;
  background: var(--bg-primary, #f8f9fb);
  min-height: 100%;
  font-family: 'Inter', sans-serif;
}

/* Header */
.db-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1.75rem;

  h1 {
    font-size: 1.45rem;
    font-weight: 700;
    color: var(--text-main, #0f172a);
    margin: 0 0 0.2rem;
  }
  p { font-size: 0.875rem; color: var(--text-muted, #64748b); margin: 0; }
}

.btn-outline {
  display: inline-flex; align-items: center; gap: 0.4rem;
  border: 1px solid var(--border-color, #e2e8f0);
  background: var(--bg-secondary, #fff);
  color: var(--text-main, #334155);
  padding: 0.45rem 1rem; border-radius: 8px;
  font-size: 0.82rem; font-weight: 500; cursor: pointer;
  transition: all 0.15s;
  &:hover { background: var(--bg-primary, #f1f5f9); }
  .ic { width: 14px; height: 14px; }
}

/* Labels de seção */
.section-label {
  font-size: 0.72rem; font-weight: 700; text-transform: uppercase;
  letter-spacing: 0.08em; color: var(--text-muted, #94a3b8);
  margin-bottom: 0.75rem;
  &.mt-section { margin-top: 1.75rem; }
}
.mt-section { margin-top: 1.75rem; }

/* Grids */
.grid-4 {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
}

.grid-2-3 {
  display: grid;
  grid-template-columns: 1fr 1.2fr;
  gap: 1rem;
}

/* KPI Card */
.kpi-card {
  background: var(--bg-secondary, #fff);
  border-radius: 14px;
  padding: 1.1rem 1.2rem;
  border: 1px solid var(--border-color, #e8edf2);
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  position: relative;
  overflow: hidden;
  transition: transform 0.15s, box-shadow 0.15s;
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);

  &:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0,0,0,0.08); }

  &::before {
    content: '';
    position: absolute; top: 0; left: 0; right: 0; height: 3px;
  }
  &.accent-blue::before   { background: linear-gradient(90deg, #3b82f6, #60a5fa); }
  &.accent-red::before    { background: linear-gradient(90deg, #ef4444, #f87171); }
  &.accent-amber::before  { background: linear-gradient(90deg, #f59e0b, #fbbf24); }
  &.accent-teal::before   { background: linear-gradient(90deg, #0d9488, #2dd4bf); }
  &.accent-purple::before { background: linear-gradient(90deg, #7c3aed, #a78bfa); }
  &.accent-violet::before { background: linear-gradient(90deg, #8b5cf6, #c4b5fd); }
  &.accent-green::before  { background: linear-gradient(90deg, #10b981, #34d399); }
  &.accent-indigo::before { background: linear-gradient(90deg, #4338ca, #818cf8); }
}

.kpi-left {
  display: flex; align-items: center; gap: 0.9rem;
}

.kpi-icon {
  width: 40px; height: 40px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
  svg { width: 20px; height: 20px; }

  &.blue   { background: #eff6ff; color: #2563eb; }
  &.red    { background: #fef2f2; color: #dc2626; }
  &.amber  { background: #fffbeb; color: #d97706; }
  &.teal   { background: #f0fdfa; color: #0f766e; }
  &.purple { background: #f5f3ff; color: #7c3aed; }
  &.violet { background: #f5f3ff; color: #7c3aed; }
  &.green  { background: #ecfdf5; color: #059669; }
  &.indigo { background: #eef2ff; color: #4338ca; }
}

.kpi-val {
  font-size: 1.8rem; font-weight: 800;
  color: var(--text-main, #0f172a); line-height: 1; letter-spacing: -0.02em;
}

.kpi-lbl {
  font-size: 0.72rem; font-weight: 600; color: var(--text-muted, #64748b);
  text-transform: uppercase; letter-spacing: 0.04em; margin-top: 0.2rem;
}

.kpi-sub {
  font-size: 0.75rem; color: var(--text-muted, #94a3b8);
}

.kpi-bar-mini {
  display: flex; align-items: center; gap: 0.3rem; font-size: 0.75rem;
  color: var(--text-muted, #94a3b8);
  .dot {
    width: 8px; height: 8px; border-radius: 50%;
    &.red   { background: #ef4444; }
    &.amber { background: #f59e0b; }
    &.teal  { background: #0d9488; }
  }
  .mini-n { min-width: 1rem; font-weight: 600; color: var(--text-main, #334155); }
}

.kpi-badge {
  display: inline-flex; align-items: center;
  padding: 0.2rem 0.6rem; border-radius: 20px;
  font-size: 0.68rem; font-weight: 700; width: fit-content;

  &.hot   { background: #fef2f2; color: #dc2626; }
  &.warm  { background: #fffbeb; color: #d97706; }
  &.cold  { background: #f0fdfa; color: #0f766e; }
  &.human { background: #f5f3ff; color: #7c3aed; }
  &.done  { background: #ecfdf5; color: #059669; }
}

/* Panels */
.panel {
  background: var(--bg-secondary, #fff);
  border-radius: 14px;
  border: 1px solid var(--border-color, #e8edf2);
  box-shadow: 0 1px 4px rgba(0,0,0,0.04);
  overflow: hidden;
  display: flex; flex-direction: column;
}

.panel-head {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 1rem 1.25rem; border-bottom: 1px solid var(--border-color, #f1f5f9);
  font-size: 0.88rem; font-weight: 600; color: var(--text-main, #1e293b);
  background: var(--bg-primary, #fafafa);
  .ic { width: 16px; height: 16px; color: #6366f1; }
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
  .funnel-ic { width: 15px; height: 15px; flex-shrink: 0; }
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
  font-size: 0.78rem; font-weight: 600; color: #6366f1;
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
.skeleton-wrap { display: flex; flex-direction: column; gap: 1.5rem; }

.skel-row {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem;
  animation: pulse 1.4s infinite;
  &.mt { grid-template-columns: 1fr 1fr; }
}

.skel-card {
  height: 100px; background: var(--bg-secondary, #e5e7eb);
  border-radius: 14px;
}
.skel-wide { height: 240px; background: var(--bg-secondary, #e5e7eb); border-radius: 14px; }
.skel-half-col { display: flex; flex-direction: column; gap: 0.75rem; }
.skel-sm { height: 70px; background: var(--bg-secondary, #e5e7eb); border-radius: 14px; }

@keyframes pulse {
  0%, 100% { opacity: 0.5; }
  50% { opacity: 1; }
}

/* Today's leads */
.section-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;

  .today-count {
    background: #6366f1;
    color: #fff;
    font-size: 0.65rem;
    font-weight: 700;
    padding: 0.1rem 0.45rem;
    border-radius: 20px;
    letter-spacing: 0;
  }
}

.today-empty {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  background: var(--bg-secondary, #fff);
  border: 1px dashed var(--border-color, #e2e8f0);
  border-radius: 12px;
  padding: 1.1rem 1.5rem;
  color: var(--text-muted, #94a3b8);
  font-size: 0.82rem;

  .today-empty-ic { width: 22px; height: 22px; opacity: 0.4; flex-shrink: 0; }
  p { margin: 0; }
}

.today-leads-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(290px, 1fr));
  gap: 0.75rem;
}

.today-lead-card {
  display: flex;
  align-items: flex-start;
  gap: 0.85rem;
  background: var(--bg-secondary, #fff);
  border: 1px solid var(--border-color, #e8edf2);
  border-radius: 12px;
  padding: 0.9rem 1rem;
  cursor: pointer;
  transition: all 0.15s;
  position: relative;
  box-shadow: 0 1px 3px rgba(0,0,0,0.04);

  &:hover {
    border-color: #6366f1;
    box-shadow: 0 4px 16px rgba(99,102,241,0.12);
    transform: translateY(-1px);

    .tlc-arrow { opacity: 1; transform: translateX(2px); }
  }
}

.tlc-avatar {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: #fff;
  font-size: 0.95rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.tlc-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}

.tlc-top {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.tlc-name {
  font-size: 0.88rem;
  font-weight: 600;
  color: var(--text-main, #1e293b);
}

.tlc-badge {
  font-size: 0.65rem;
  font-weight: 700;
  padding: 0.15rem 0.5rem;
  border-radius: 20px;
}

.tlc-phone {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.75rem;
  color: var(--text-muted, #64748b);

  .tlc-icon { width: 12px; height: 12px; flex-shrink: 0; }
}

.tlc-intention {
  font-size: 0.75rem;
  color: var(--text-muted, #64748b);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tlc-footer {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.1rem;
}

.tlc-stage {
  font-size: 0.68rem;
  font-weight: 600;
  background: var(--bg-primary, #f1f5f9);
  color: #6366f1;
  padding: 0.15rem 0.5rem;
  border-radius: 4px;
}

.tlc-agent {
  font-size: 0.68rem;
  color: #10b981;
  font-weight: 500;
}

.tlc-time {
  font-size: 0.68rem;
  color: var(--text-muted, #94a3b8);
  margin-left: auto;
}

.tlc-arrow {
  width: 16px;
  height: 16px;
  color: #6366f1;
  opacity: 0;
  transition: all 0.15s;
  flex-shrink: 0;
  margin-top: 0.2rem;
}

/* Responsive */
@media (max-width: 1100px) {
  .grid-4 { grid-template-columns: repeat(2, 1fr); }
  .grid-2-3 { grid-template-columns: 1fr; }
  .today-leads-grid { grid-template-columns: 1fr; }
}

@media (max-width: 768px) {
  .page-container, .dashboard-container {
    padding: 1rem;
  }

  .grid-4 { grid-template-columns: repeat(2, 1fr); gap: 0.5rem; }
  .grid-2-3 { grid-template-columns: 1fr; }
  .today-leads-grid { grid-template-columns: 1fr; }

  .stat-card {
    padding: 1rem;
    .stat-value { font-size: 1.5rem; }
  }
}

@media (max-width: 480px) {
  .grid-4 { grid-template-columns: 1fr; }
}
</style>
