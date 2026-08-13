<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { ChevronLeft, ChevronRight, Plus, X, Trash2 } from '@lucide/vue'
import Swal from 'sweetalert2'
import { useAgendamentosStore } from '../store/agendamentos'
import { useConversationsStore } from '../store/conversations'
import { isFullPortfolio as isFullPortfolioRole } from '../config/roles'

const agendaStore = useAgendamentosStore()
const convStore = useConversationsStore()

const currentUser = JSON.parse(localStorage.getItem('user') || '{}')
const isFullPortfolio = computed(() => isFullPortfolioRole(currentUser))

const hoje = new Date()
const anoAtual = ref(hoje.getFullYear())
const mesAtual = ref(hoje.getMonth()) // 0-11
const userFilter = ref('all')

const isModalOpen = ref(false)
const editingId = ref(null)
const isSubmitting = ref(false)
const form = ref({ titulo: '', descricao: '', data: '', horaInicio: '', horaFim: '', userId: null })

const DIAS_SEMANA = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
const MESES = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro']

const tituloMes = computed(() => `${MESES[mesAtual.value]} de ${anoAtual.value}`)

const responsavelOptions = computed(() => [
  { value: 'all', label: 'Todos' },
  ...(convStore.agents || []).map(a => ({ value: a.id, label: `${a.first_name || ''} ${a.last_name || ''}`.trim() }))
])

function chaveDia(date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

// Grade de 6 semanas fixas (42 células) começando no domingo da semana do
// dia 1 — suficiente pra cobrir qualquer mês sem grade de tamanho variável.
const diasDaGrade = computed(() => {
  const primeiro = new Date(anoAtual.value, mesAtual.value, 1)
  const inicioGrade = new Date(primeiro)
  inicioGrade.setDate(primeiro.getDate() - primeiro.getDay())

  const dias = []
  for (let i = 0; i < 42; i++) {
    const d = new Date(inicioGrade)
    d.setDate(inicioGrade.getDate() + i)
    dias.push(d)
  }
  return dias
})

const eventosPorDia = computed(() => {
  const map = {}
  for (const ev of agendaStore.agendamentos) {
    const chave = chaveDia(new Date(ev.inicio_em))
    if (!map[chave]) map[chave] = []
    map[chave].push(ev)
  }
  Object.values(map).forEach(lista => lista.sort((a, b) => new Date(a.inicio_em) - new Date(b.inicio_em)))
  return map
})

function horaCurta(iso) {
  return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
}

function nomeResponsavel(ev) {
  if (!ev.user) return ''
  return `${ev.user.first_name || ''} ${ev.user.last_name || ''}`.trim()
}

async function carregar() {
  const de = new Date(anoAtual.value, mesAtual.value, 1)
  const ate = new Date(anoAtual.value, mesAtual.value + 1, 0)
  await agendaStore.fetchAgendamentos({
    de: chaveDia(de),
    ate: chaveDia(ate),
    userId: isFullPortfolio.value && userFilter.value !== 'all' ? userFilter.value : undefined
  })
}

function mudarMes(delta) {
  let novoMes = mesAtual.value + delta
  let novoAno = anoAtual.value
  if (novoMes < 0) { novoMes = 11; novoAno -= 1 }
  if (novoMes > 11) { novoMes = 0; novoAno += 1 }
  mesAtual.value = novoMes
  anoAtual.value = novoAno
}

function irParaHoje() {
  mesAtual.value = hoje.getMonth()
  anoAtual.value = hoje.getFullYear()
}

function abrirCriacao(date) {
  editingId.value = null
  const base = date || new Date()
  form.value = {
    titulo: '',
    descricao: '',
    data: chaveDia(base),
    horaInicio: '09:00',
    horaFim: '',
    userId: currentUser.id
  }
  isModalOpen.value = true
}

function abrirEdicao(ev) {
  editingId.value = ev.id
  const inicio = new Date(ev.inicio_em)
  form.value = {
    titulo: ev.titulo,
    descricao: ev.descricao || '',
    data: chaveDia(inicio),
    horaInicio: inicio.toTimeString().slice(0, 5),
    horaFim: ev.fim_em ? new Date(ev.fim_em).toTimeString().slice(0, 5) : '',
    userId: ev.user?.id || currentUser.id
  }
  isModalOpen.value = true
}

function fecharModal() {
  isModalOpen.value = false
}

async function salvar() {
  if (!form.value.titulo.trim() || !form.value.data || !form.value.horaInicio) return

  isSubmitting.value = true
  try {
    const payload = {
      titulo: form.value.titulo.trim(),
      descricao: form.value.descricao,
      inicio_em: new Date(`${form.value.data}T${form.value.horaInicio}:00`).toISOString(),
      fim_em: form.value.horaFim ? new Date(`${form.value.data}T${form.value.horaFim}:00`).toISOString() : null
    }
    if (isFullPortfolio.value) payload.user_id = form.value.userId

    if (editingId.value) {
      await agendaStore.atualizar(editingId.value, payload)
    } else {
      await agendaStore.criar(payload)
    }
    fecharModal()
  } catch (error) {
    const msg = error.response?.data?.error || 'Erro ao salvar o compromisso.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 3500 })
  } finally {
    isSubmitting.value = false
  }
}

async function apagar() {
  if (!editingId.value) return
  const confirmacao = await Swal.fire({
    icon: 'warning',
    title: 'Apagar este compromisso?',
    text: 'Essa ação não pode ser desfeita.',
    showCancelButton: true,
    confirmButtonText: 'Apagar',
    cancelButtonText: 'Cancelar',
    confirmButtonColor: '#dc2626'
  })
  if (!confirmacao.isConfirmed) return

  try {
    await agendaStore.remover(editingId.value)
    fecharModal()
  } catch {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao apagar o compromisso.', showConfirmButton: false, timer: 3500 })
  }
}

watch([mesAtual, anoAtual, userFilter], carregar)

onMounted(async () => {
  if (!convStore.agents.length) await convStore.fetchAgents()
  await carregar()
})
</script>

<template>
  <div class="calendario-page">
    <div class="page-header">
      <div class="title-block">
        <h1>Calendário</h1>
        <p>Agenda de compromissos{{ isFullPortfolio ? ' da equipe' : '' }}</p>
      </div>
      <button class="btn-primary" @click="abrirCriacao(null)"><Plus class="icon-sm" /> Novo compromisso</button>
    </div>

    <div class="toolbar">
      <div class="month-nav">
        <button class="icon-btn" @click="mudarMes(-1)"><ChevronLeft class="icon-sm" /></button>
        <span class="month-label">{{ tituloMes }}</span>
        <button class="icon-btn" @click="mudarMes(1)"><ChevronRight class="icon-sm" /></button>
        <button class="btn-secondary btn-hoje" @click="irParaHoje">Hoje</button>
      </div>
      <select v-if="isFullPortfolio" v-model="userFilter" class="responsavel-select">
        <option v-for="opt in responsavelOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
    </div>

    <div class="calendar-grid">
      <div class="weekday-row">
        <div v-for="d in DIAS_SEMANA" :key="d" class="weekday-cell">{{ d }}</div>
      </div>
      <div class="days-grid">
        <div
          v-for="dia in diasDaGrade"
          :key="dia.toISOString()"
          class="day-cell"
          :class="{ 'is-outside': dia.getMonth() !== mesAtual, 'is-today': chaveDia(dia) === chaveDia(hoje) }"
          @click="abrirCriacao(dia)"
        >
          <span class="day-number">{{ dia.getDate() }}</span>
          <div class="day-events">
            <button
              v-for="ev in (eventosPorDia[chaveDia(dia)] || [])"
              :key="ev.id"
              class="event-chip"
              :class="{ 'is-mine': ev.user?.id === currentUser.id }"
              @click.stop="abrirEdicao(ev)"
            >
              <span class="event-time">{{ horaCurta(ev.inicio_em) }}</span>
              <span class="event-title">{{ ev.titulo }}</span>
              <span v-if="isFullPortfolio" class="event-owner">{{ nomeResponsavel(ev) }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="isModalOpen" class="modal-overlay" @click.self="fecharModal">
      <div class="modal-content">
        <div class="modal-header">
          <h2>{{ editingId ? 'Editar compromisso' : 'Novo compromisso' }}</h2>
          <button class="icon-btn" @click="fecharModal"><X class="icon-sm" /></button>
        </div>
        <div class="modal-body">
          <form @submit.prevent="salvar">
            <div class="form-group">
              <label>Título</label>
              <input v-model="form.titulo" type="text" placeholder="Ex: Acerto com a revendedora" required />
            </div>
            <div class="form-group">
              <label>Descrição (opcional)</label>
              <textarea v-model="form.descricao" rows="3" placeholder="Detalhes do compromisso..."></textarea>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Data</label>
                <input v-model="form.data" type="date" required />
              </div>
              <div class="form-group">
                <label>Início</label>
                <input v-model="form.horaInicio" type="time" required />
              </div>
              <div class="form-group">
                <label>Fim (opcional)</label>
                <input v-model="form.horaFim" type="time" />
              </div>
            </div>
            <div class="form-group" v-if="isFullPortfolio">
              <label>Responsável</label>
              <select v-model="form.userId">
                <option v-for="a in convStore.agents" :key="a.id" :value="a.id">{{ `${a.first_name || ''} ${a.last_name || ''}`.trim() }}</option>
              </select>
            </div>

            <div class="modal-footer">
              <button v-if="editingId" type="button" class="btn-danger" @click="apagar"><Trash2 class="icon-sm" /> Apagar</button>
              <div class="footer-spacer"></div>
              <button type="button" class="btn-secondary" @click="fecharModal">Cancelar</button>
              <button type="submit" class="btn-primary" :disabled="isSubmitting">
                {{ isSubmitting ? 'Salvando...' : 'Salvar' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.calendario-page {
  padding: 1.5rem;
  height: 100%;
  overflow-y: auto;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1rem;

  h1 {
    font-size: 1.3rem;
    font-weight: 700;
    color: var(--text-main);
    margin: 0 0 0.2rem;
  }

  p {
    color: var(--text-muted);
    font-size: 0.85rem;
    margin: 0;
  }
}

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.month-nav {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.month-label {
  font-weight: 600;
  color: var(--text-main);
  min-width: 160px;
  text-align: center;
  text-transform: capitalize;
}

.btn-hoje {
  margin-left: 0.5rem;
}

.calendar-grid {
  border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 12px;
  overflow: hidden;
  background: var(--bg-primary, #fff);
}

.weekday-row {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  background: var(--bg-tertiary, #f1e9ed);
}

.weekday-cell {
  padding: 0.5rem;
  text-align: center;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-muted);
}

.days-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  grid-auto-rows: minmax(90px, auto);
}

.day-cell {
  border-top: 1px solid var(--border-color, #e2e8f0);
  border-right: 1px solid var(--border-color, #e2e8f0);
  padding: 0.35rem;
  cursor: pointer;
  transition: background 0.15s;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;

  &:nth-child(7n) {
    border-right: none;
  }

  &:hover {
    background: var(--bg-tertiary, #f8f4f6);
  }

  &.is-outside {
    opacity: 0.4;
  }

  &.is-today .day-number {
    background: var(--primary, #d49ba7);
    color: white;
    border-radius: 50%;
  }
}

.day-number {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-main);
  width: 22px;
  height: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.day-events {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.event-chip {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0;
  padding: 0.15rem 0.35rem;
  border-radius: 5px;
  border: none;
  background: var(--bg-tertiary, #f1e9ed);
  color: var(--text-main);
  font-size: 0.7rem;
  text-align: left;
  cursor: pointer;
  width: 100%;
  overflow: hidden;

  &.is-mine {
    background: var(--primary, #d49ba7);
    color: white;
  }
}

.event-time {
  font-weight: 700;
  font-size: 0.65rem;
}

.event-title {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  width: 100%;
}

.event-owner {
  font-size: 0.6rem;
  opacity: 0.8;
}

.btn-primary, .btn-secondary, .btn-danger {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  font-size: 0.85rem;
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.btn-primary {
  background: var(--primary, #d49ba7);
  color: white;
}

.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.btn-secondary {
  background: transparent;
  border: 1px solid var(--border-color, #e2e8f0);
  color: var(--text-main);
}

.btn-danger {
  background: transparent;
  color: #dc2626;
  border: 1px solid #fecaca;
}

.icon-btn {
  background: transparent;
  border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 6px;
  padding: 0.4rem;
  cursor: pointer;
  display: flex;
  color: var(--text-main);
}

.responsavel-select {
  padding: 0.5rem 0.75rem;
  border-radius: 6px;
  border: 1px solid var(--border-color, #e2e8f0);
  background: var(--bg-primary, #fff);
  color: var(--text-main);
  font-size: 0.85rem;
}

.icon-sm {
  width: 16px;
  height: 16px;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(15, 23, 42, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: var(--bg-secondary, #f8fafc);
  border-radius: 12px;
  width: 90%;
  max-width: 460px;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

.modal-header {
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-color, #e2e8f0);
  display: flex;
  justify-content: space-between;
  align-items: center;

  h2 {
    margin: 0;
    font-size: 1rem;
    font-weight: 600;
    color: var(--text-main);
  }
}

.modal-body {
  padding: 1.25rem;
}

.form-group {
  margin-bottom: 1rem;
  flex: 1;

  label {
    display: block;
    margin-bottom: 0.4rem;
    font-weight: 500;
    color: var(--text-main);
    font-size: 0.85rem;
  }
}

.form-row {
  display: flex;
  gap: 0.75rem;
}

input[type="text"], input[type="date"], input[type="time"], textarea, select {
  width: 100%;
  padding: 0.6rem;
  border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 6px;
  background: var(--bg-primary, #fff);
  color: var(--text-main);
  font-family: inherit;
  font-size: 0.9rem;
}

textarea {
  resize: vertical;
  min-height: 70px;
}

.modal-footer {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1.5rem;
}

.footer-spacer {
  flex: 1;
}
</style>
