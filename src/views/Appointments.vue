<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Filter, Search, Plus, Eye, CalendarDays, X } from '@lucide/vue'
import api from '../api'
import { useAppointmentsStore } from '../store/appointments'
import { storeToRefs } from 'pinia'

const router = useRouter()
const appointmentsStore = useAppointmentsStore()
const { appointments, isLoading, contacts, properties, brokers } = storeToRefs(appointmentsStore)

// Filters
const filterStatus = ref('')
const filterProperty = ref('')
const filterDate = ref('')
const filterBroker = ref('')
const filterContact = ref('')

const fetchAppointments = () => {
  appointmentsStore.fetchAppointments()
}

onMounted(() => {
  appointmentsStore.fetchMetaData()
  fetchAppointments()
})

const clearFilters = () => {
  filterStatus.value = ''
  filterProperty.value = ''
  filterDate.value = ''
  filterBroker.value = ''
  filterContact.value = ''
}

const formatDate = (dateString) => {
  if (!dateString) return '-'
  const [year, month, day] = dateString.split('-')
  return `${day}/${month}/${year}`
}
const formatTime = (datetime) => {
  if (!datetime) return '-'
  if (datetime.includes('T')) {
    return datetime.split('T')[1].substring(0, 5)
  }
  return datetime
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-content">
        <h1>Agendamentos</h1>
        <button class="btn-primary" @click="router.push('/agendamentos/novo')">
          <Plus class="icon-sm" /> Novo Agendamento
        </button>
      </div>
    </div>

    <!-- Filters Bar -->
    <div class="filters-card">
      <div class="filters-grid">
        <div class="input-group">
          <label class="floating-label">Status</label>
          <select v-model="filterStatus">
            <option value="">Selecione</option>
            <option value="Pendente">Pendente</option>
            <option value="Confirmado">Confirmado</option>
          </select>
        </div>

        <div class="input-group">
          <label class="floating-label">Imóvel / Lançamento</label>
          <select v-model="filterProperty">
            <option value="">Selecione</option>
            <option v-for="p in properties" :key="p.id" :value="p.id">
              AP{{ p.id }} - {{ p.title || p.address }}
            </option>
          </select>
        </div>

        <div class="input-group icon-right">
          <label class="floating-label">Data de Agendamento</label>
          <input type="date" v-model="filterDate">
          <CalendarDays class="input-icon" />
        </div>

        <div class="input-group">
          <label class="floating-label">Responsável</label>
          <select v-model="filterBroker">
            <option value="">Selecione</option>
            <option v-for="b in brokers" :key="b" :value="b">{{ b }}</option>
          </select>
        </div>

        <div class="input-group col-2">
          <label class="floating-label">Cliente</label>
          <select v-model="filterContact">
            <option value="">Selecione</option>
            <option v-for="c in contacts" :key="c.id" :value="c.id">
              {{ c.phone ? `(${c.phone}) ` : '' }}{{ c.name }} {{ c.last_name || '' }}
            </option>
          </select>
        </div>
      </div>
      <div class="filters-actions">
        <button class="btn-outline" @click="clearFilters">Limpar</button>
        <button class="btn-primary-outline" @click="fetchAppointments">Buscar</button>
      </div>
    </div>

    <!-- Table -->
    <div class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>Status</th>
            <th>Data de Agendamento</th>
            <th>Início</th>
            <th>Fim</th>
            <th>Cliente</th>
            <th>Corretor</th>
            <th>Imóvel / Lançamento</th>
            <th width="50"></th>
          </tr>
        </thead>
        <tbody>
          <template v-if="isLoading">
            <tr v-for="i in 3" :key="'skel'+i" class="skeleton-row">
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-action"></div></td>
            </tr>
          </template>
          <tr v-else-if="appointments.length === 0">
            <td colspan="8" class="text-center py-4 text-muted">Nenhum agendamento encontrado.</td>
          </tr>
          <tr v-for="app in appointments" :key="app.id" @dblclick="router.push(`/agendamentos/${app.id}/editar`)">
            <td>
              <span :class="['badge', (app.status === 'Confirmado' || app.status === 'Agendado' || app.status === 'scheduled') ? 'badge-success' : 'badge-default']">
                {{ app.status === 'scheduled' ? 'Agendado' : (app.status || 'Pendente') }}
              </span>
            </td>
            <td>{{ formatDate(app.appointment_date) }}</td>
            <td>{{ formatTime(app.start_time) }}</td>
            <td>{{ formatTime(app.end_time) }}</td>
            <td>
              <div v-if="app.contact" class="client-info">
                {{ app.contact.name }} - {{ app.contact.phone }}
              </div>
              <span v-else>-</span>
            </td>
            <td>{{ app.broker_name || '-' }}</td>
            <td>
              <a v-if="app.property" href="#" class="property-link">{{ app.property.title || `Imóvel #${app.property.id}` }}</a>
              <a v-else-if="app.condominium" href="#" class="property-link">{{ app.condominium.name || `Condomínio #${app.condominium.id}` }}</a>
              <span v-else>-</span>
            </td>
            <td class="actions-cell">
              <button class="btn-icon" @click="router.push(`/agendamentos/${app.id}/editar`)" title="Visualizar">
                <Eye class="icon-sm" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
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
  margin-bottom: 2rem;

  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: center;

    h1 {
      font-size: 1.5rem;
      color: var(--text-main);
    }
  }
}

.filters-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1.5rem;
  margin-bottom: 2rem;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);

  .filters-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1.5rem;
    margin-bottom: 1.5rem;

    .col-2 {
      grid-column: span 2;
    }
  }

  .filters-actions {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border-color);
  }
}

.input-group {
  position: relative;
  display: flex;
  flex-direction: column;

  .floating-label {
    position: absolute;
    top: -8px;
    left: 12px;
    background: var(--bg-secondary);
    padding: 0 4px;
    font-size: 0.75rem;
    color: var(--text-muted);
    z-index: 1;
  }

  input, select {
    padding: 0.75rem 1rem;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    background: var(--bg-secondary);
    color: var(--text-main);
    outline: none;
    font-size: 0.9rem;
    
    &:focus { border-color: #4338ca; }
  }

  &.icon-right {
    input {
      padding-right: 2.5rem;
    }
    .input-icon {
      position: absolute;
      right: 12px;
      top: 50%;
      transform: translateY(-50%);
      color: var(--text-muted);
      width: 18px;
      height: 18px;
      pointer-events: none;
    }
  }
}

.table-container {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.data-table {
  width: 100%;
  min-width: 640px;
  border-collapse: collapse;

  th, td {
    padding: 1rem 1.5rem;
    text-align: left;
    border-bottom: 1px solid var(--border-color);
  }

  th {
    font-weight: 600;
    color: var(--text-main);
    font-size: 0.9rem;
    background: rgba(0,0,0,0.01);
  }

  td {
    color: var(--text-muted);
    font-size: 0.9rem;
  }

  tbody tr {
    transition: background-color 0.2s;
    &:hover {
      background: rgba(67, 56, 202, 0.02);
    }
    &:last-child td {
      border-bottom: none;
    }
  }
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.8rem;
  font-weight: 500;

  &.badge-success {
    background: rgba(16, 185, 129, 0.2);
    color: #065f46;
  }
  
  &.badge-default {
    background: rgba(156, 163, 175, 0.2);
    color: #374151;
  }
}

.property-link {
  color: #4338ca;
  text-decoration: underline;
  &:hover {
    color: #312e81;
  }
}

.btn-icon {
  background: transparent;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  padding: 0.5rem;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  
  &:hover {
    background: rgba(0,0,0,0.05);
    color: var(--text-main);
  }
}

.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  background: var(--primary);
  color: white;
  border: none;
  padding: 0.6rem 1.2rem;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
}

.btn-outline {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  background: transparent;
  color: var(--text-main);
  border: 1px solid var(--border-color);
  padding: 0.6rem 1.5rem;
  border-radius: 20px;
  font-weight: 500;
  cursor: pointer;
  
  &:hover { background: rgba(0,0,0,0.02); }
}

.btn-primary-outline {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  background: transparent;
  color: #4338ca;
  border: 1px solid #4338ca;
  padding: 0.6rem 1.5rem;
  border-radius: 20px;
  font-weight: 500;
  cursor: pointer;
  
  &:hover { 
    background: rgba(67, 56, 202, 0.05); 
  }
}

/* Skeleton Loader */
.skeleton-row {
  animation: pulse-skeleton 1.5s infinite;
  
  .skeleton-line {
    height: 12px;
    background: #e5e7eb;
    border-radius: 4px;
    width: 120px;
    
    &.short { width: 60px; }
  }
  
  .skeleton-action {
    height: 24px;
    width: 24px;
    background: #e5e7eb;
    border-radius: 4px;
  }
}

@keyframes pulse-skeleton {
  0% { opacity: 0.6; }
  50% { opacity: 1; }
  100% { opacity: 0.6; }
}

.icon-sm { width: 16px; height: 16px; }
.text-center { text-align: center; }
.py-4 { padding-top: 1.5rem; padding-bottom: 1.5rem; }

@media (max-width: 768px) {
  .page-container {
    padding: 1rem;
  }

  .page-header .header-content {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;

    h1 { font-size: 1.2rem; }
  }

  .filters-card {
    padding: 1rem;
    margin-bottom: 1rem;

    .filters-grid {
      grid-template-columns: 1fr;
      gap: 0.75rem;

      .col-2 { grid-column: span 1; }
    }
  }

  .filters-actions {
    flex-direction: column;
    gap: 0.5rem;

    button { width: 100%; justify-content: center; }
  }
}
</style>
