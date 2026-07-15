<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import api from '../api'
import { useAppointmentsStore } from '../store/appointments'
import { storeToRefs } from 'pinia'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const appointmentsStore = useAppointmentsStore()
const { contacts, properties, brokers } = storeToRefs(appointmentsStore)

const isEditing = ref(false)
const isLoading = ref(false)
const isSubmitting = ref(false)

const form = ref({
  status: 'Confirmado',
  appointment_date: '',
  start_time: '',
  end_time: '',
  contact_id: '',
  property_id: '',
  broker_name: ''
})

const selectedProperty = computed(() => {
  if (!form.value.property_id) return null
  return properties.value.find(p => p.id === form.value.property_id)
})

const loadAppointment = async (id) => {
  isLoading.value = true
  try {
    const response = await api.get(`/appointments/${id}`)
    const data = response.data
    
    let st = data.start_time || ''
    let et = data.end_time || ''
    
    // Formata o HH:MM para YYYY-MM-DDTHH:MM para funcionar no input datetime-local
    if (st.length === 5 && data.appointment_date) st = `${data.appointment_date}T${st}`
    if (et.length === 5 && data.appointment_date) et = `${data.appointment_date}T${et}`
    if (st && st.length > 16) st = st.substring(0, 16)
    if (et && et.length > 16) et = et.substring(0, 16)

    form.value = {
      ...data,
      start_time: st,
      end_time: et,
      contact_id: data.contact_id || '',
      property_id: data.property_id || ''
    }
  } catch (error) {
    console.error('Erro ao carregar agendamento', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(async () => {
  await appointmentsStore.fetchMetaData()
  if (route.params.id) {
    isEditing.value = true
    loadAppointment(route.params.id)
  }
})

const formatCurrency = (val) => {
  if (!val) return 'R$ 0,00'
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
}

const formatAddress = (prop) => {
  const parts = [prop.address, prop.neighborhood, prop.city, prop.state].filter(Boolean)
  return parts.join(', ') || 'Endereço não informado'
}

const submitForm = async () => {
  if (!form.value.contact_id || !form.value.property_id) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'Por favor, selecione um Cliente e um Imóvel antes de salvar.', showConfirmButton: false, timer: 4000 })
    return
  }

  if (isSubmitting.value) return
  isSubmitting.value = true

  try {
    // If appointment_date is missing but start_time has a date, use it
    if (!form.value.appointment_date && form.value.start_time) {
      form.value.appointment_date = form.value.start_time.split('T')[0]
    }

    const payload = { ...form.value }
    if (isEditing.value) {
      await api.put(`/appointments/${route.params.id}`, { appointment: payload })
    } else {
      await api.post('/appointments', { appointment: payload })
    }
    router.push('/agendamentos')
  } catch (error) {
    console.error('Erro ao salvar', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao salvar agendamento.', showConfirmButton: false, timer: 3500 })
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="page-container">
    <div class="split-layout">
      
      <!-- Lado Esquerdo: Card do Imóvel -->
      <div class="property-preview">
        <div class="preview-card" v-if="selectedProperty">
          <div class="preview-image">
            <img v-if="selectedProperty.photo_urls && selectedProperty.photo_urls.length > 0" :src="selectedProperty.photo_urls[0]" alt="Foto do Imóvel">
            <div v-else class="image-placeholder"></div>
          </div>
          <div class="preview-body">
            <h4 class="preview-title">{{ selectedProperty.title || `${selectedProperty.property_type} à venda` }}</h4>
            <p class="preview-address">{{ formatAddress(selectedProperty) }}</p>
            <p class="preview-price">{{ formatCurrency(selectedProperty.price) }}</p>
          </div>
        </div>
        <div class="preview-card empty-card" v-else>
          <div class="image-placeholder"></div>
          <div class="preview-body">
            <p class="text-muted">Selecione um imóvel para ver os detalhes.</p>
          </div>
        </div>
      </div>

      <!-- Lado Direito: Formulário -->
      <div class="form-panel">
        <div class="form-grid">
          
          <div class="input-group">
            <label>Horário Inicial</label>
            <input type="datetime-local" v-model="form.start_time">
          </div>
          
          <div class="input-group">
            <label>Horário Final</label>
            <input type="datetime-local" v-model="form.end_time">
          </div>
          
          <div class="input-group">
            <label>Status</label>
            <select v-model="form.status">
              <option value="Pendente">Pendente</option>
              <option value="Confirmado">Confirmado</option>
              <option value="Finalizado">Finalizado</option>
              <option value="Cancelado">Cancelado</option>
            </select>
          </div>

          <div class="input-group full-width">
            <label>Cliente</label>
            <select v-model="form.contact_id" required>
              <option value="">Selecione um Cliente</option>
              <option v-for="c in contacts" :key="c.id" :value="c.id">
                {{ c.phone ? `(${c.phone}) ` : '' }}{{ c.name }} {{ c.last_name || '' }}
              </option>
            </select>
          </div>

          <div class="input-group full-width">
            <label>Imóvel / Lançamento</label>
            <select v-model="form.property_id" required>
              <option value="">Selecione um Imóvel</option>
              <option v-for="p in properties" :key="p.id" :value="p.id">
                AP{{ p.id }} - {{ p.title || p.address || 'Imóvel sem título' }}
              </option>
            </select>
          </div>

          <div class="input-group full-width">
            <label>Responsável</label>
            <select v-model="form.broker_name">
              <option value="">Selecione um Responsável</option>
              <option v-for="b in brokers" :key="b" :value="b">{{ b }}</option>
            </select>
          </div>
        </div>

        <div class="form-actions">
          <button class="btn-outline round" @click="router.push('/agendamentos')">VOLTAR</button>
          <button class="btn-outline round text-primary" @click="router.push('/agendamentos')">CANCELAR</button>
          <button class="btn-secondary round" @click="submitForm">CONFIRMAR</button>
          <button class="btn-primary round-outline" @click="submitForm">FINALIZAR</button>
        </div>
      </div>

    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  padding: 2rem;
  background: var(--bg-primary);
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.split-layout {
  display: flex;
  gap: 2rem;
  width: 100%;
  max-width: 1000px;
}

/* Esquerda: Card */
.property-preview {
  flex: 0 0 300px;
}

.preview-card {
  background: var(--bg-secondary);
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);

  &.empty-card {
    opacity: 0.6;
  }
}

.image-placeholder {
  width: 100%;
  height: 200px;
  background: rgba(0,0,0,0.05);
}

.preview-image img {
  width: 100%;
  height: 200px;
  object-fit: cover;
}

.preview-body {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;

  .preview-title {
    font-size: 0.9rem;
    color: var(--text-main);
    line-height: 1.4;
    font-weight: 500;
  }

  .preview-address {
    font-size: 0.8rem;
    color: var(--text-muted);
  }

  .preview-price {
    font-size: 1rem;
    color: var(--text-main);
    font-weight: 600;
  }
}

/* Direita: Formulario */
.form-panel {
  flex: 1;
  background: var(--bg-secondary);
  border-radius: 12px;
  padding: 2.5rem;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2rem 1.5rem;
  margin-bottom: 3rem;

  .full-width {
    grid-column: span 3;
  }
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;

  label {
    font-size: 0.8rem;
    color: var(--text-muted);
  }

  input, select {
    border: none;
    border-bottom: 1px dotted var(--border-color);
    padding: 0.5rem 0;
    background: transparent;
    color: var(--text-main);
    font-size: 0.9rem;
    outline: none;
    
    &:focus {
      border-bottom: 1px solid #4338ca;
    }
  }

  /* Styling select element to look like the design (border around full width ones) */
  &.full-width {
    label {
      position: absolute;
      top: -8px;
      left: 12px;
      background: var(--bg-secondary);
      padding: 0 4px;
      z-index: 1;
    }
    position: relative;
    
    select {
      border: 1px solid var(--border-color);
      border-radius: 6px;
      padding: 1rem;
      &:focus {
        border-color: #4338ca;
      }
    }
  }
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;

  button {
    padding: 0.6rem 1.5rem;
    font-weight: 600;
    font-size: 0.8rem;
    cursor: pointer;
    transition: all 0.2s;

    &.round {
      border-radius: 20px;
    }

    &.btn-outline {
      background: transparent;
      border: 1px solid var(--border-color);
      color: var(--text-main);
      &:hover { background: rgba(0,0,0,0.02); }
      
      &.text-primary {
        color: #4338ca;
        border-color: rgba(67, 56, 202, 0.3);
        &:hover { background: rgba(67, 56, 202, 0.05); }
      }
    }

    &.btn-secondary {
      background: #e5e7eb;
      border: none;
      color: var(--text-muted);
      &:hover { background: #d1d5db; }
    }

    &.btn-primary {
      background: transparent;
      border: 1px solid #4338ca;
      color: #4338ca;
      border-radius: 20px;
      &:hover { background: rgba(67, 56, 202, 0.05); }
    }
  }
}

.text-muted { color: var(--text-muted); }

@media (max-width: 768px) {
  .page-container {
    padding: 1rem;
    align-items: flex-start;
  }

  .split-layout {
    flex-direction: column;
    gap: 1rem;
  }

  .property-preview {
    flex: 1 1 auto;
  }

  .form-panel {
    padding: 1.25rem;
  }

  .form-grid {
    grid-template-columns: 1fr;
    gap: 1.25rem;
    margin-bottom: 2rem;

    .full-width {
      grid-column: span 1;
    }
  }

  .form-actions {
    flex-wrap: wrap;

    button {
      flex: 1 1 calc(50% - 0.5rem);
    }
  }
}
</style>
