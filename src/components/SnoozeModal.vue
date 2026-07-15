<script setup>
import { ref } from 'vue'
import { X, Clock, AlarmClock } from 'lucide-vue-next'

defineProps({
  conversationId: { type: [Number, String], required: true }
})
const emit = defineEmits(['confirm', 'close'])

const customTime = ref('')

const addMinutes = (minutes) => {
  const d = new Date()
  d.setMinutes(d.getMinutes() + minutes)
  return d.toISOString()
}

const nextDayAt = (hour) => {
  const d = new Date()
  d.setDate(d.getDate() + 1)
  d.setHours(hour, 0, 0, 0)
  return d.toISOString()
}

const nextMondayAt = (hour) => {
  const d = new Date()
  const daysUntilMonday = (8 - d.getDay()) % 7 || 7
  d.setDate(d.getDate() + daysUntilMonday)
  d.setHours(hour, 0, 0, 0)
  return d.toISOString()
}

const quickOptions = [
  { label: 'Em 30 minutos', icon: '⏱️', fn: () => addMinutes(30) },
  { label: 'Em 2 horas',    icon: '⏰', fn: () => addMinutes(120) },
  { label: 'Amanhã às 9h',  icon: '🌅', fn: () => nextDayAt(9) },
  { label: 'Amanhã às 14h', icon: '☀️', fn: () => nextDayAt(14) },
  { label: 'Segunda às 8h', icon: '📅', fn: () => nextMondayAt(8) },
]

const select = (opt) => emit('confirm', opt.fn())

const confirmCustom = () => {
  if (!customTime.value) return
  emit('confirm', new Date(customTime.value).toISOString())
}
</script>

<template>
  <div class="modal-overlay" @click.self="emit('close')">
    <div class="snooze-modal">
      <div class="modal-header">
        <div class="modal-title-row">
          <AlarmClock class="modal-icon" />
          <h3>Adiar conversa</h3>
        </div>
        <button class="btn-close" @click="emit('close')"><X :size="16" /></button>
      </div>

      <p class="modal-subtitle">A IA continuará respondendo. Você será notificado quando o tempo acabar.</p>

      <div class="snooze-options">
        <button
          v-for="opt in quickOptions"
          :key="opt.label"
          class="snooze-option"
          @click="select(opt)"
        >
          <span class="option-icon">{{ opt.icon }}</span>
          <span class="option-label">{{ opt.label }}</span>
        </button>
      </div>

      <div class="custom-section">
        <label class="custom-label">Personalizado</label>
        <div class="custom-row">
          <input
            type="datetime-local"
            class="custom-input"
            v-model="customTime"
            :min="new Date().toISOString().slice(0, 16)"
          />
          <button class="btn-confirm" @click="confirmCustom" :disabled="!customTime">
            Confirmar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  backdrop-filter: blur(2px);
}

.snooze-modal {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  width: 340px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
  animation: pop-in 0.18s ease;
}

@keyframes pop-in {
  from { opacity: 0; transform: scale(0.94) translateY(8px); }
  to   { opacity: 1; transform: scale(1) translateY(0); }
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.modal-title-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.modal-icon {
  color: #f59e0b;
  width: 20px;
  height: 20px;
}

h3 {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
  color: #111827;
}

.btn-close {
  background: transparent;
  border: none;
  cursor: pointer;
  color: #6b7280;
  padding: 4px;
  border-radius: 4px;
  display: flex;
  align-items: center;
}
.btn-close:hover { background: #f3f4f6; }

.modal-subtitle {
  font-size: 0.8rem;
  color: #6b7280;
  margin: 0 0 1rem 0;
}

.snooze-options {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin-bottom: 1rem;
}

.snooze-option {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.65rem 0.9rem;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.15s;
  text-align: left;
  width: 100%;
}

.snooze-option:hover {
  background: #fffbeb;
  border-color: #f59e0b;
}

.option-icon { font-size: 1.1rem; }

.option-label {
  font-size: 0.9rem;
  color: #374151;
  font-weight: 500;
}

.custom-section {
  border-top: 1px solid #e5e7eb;
  padding-top: 0.75rem;
}

.custom-label {
  display: block;
  font-size: 0.78rem;
  font-weight: 600;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin-bottom: 0.5rem;
}

.custom-row {
  display: flex;
  gap: 0.5rem;
}

.custom-input {
  flex: 1;
  padding: 0.5rem 0.6rem;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  font-size: 0.85rem;
  color: #374151;
  outline: none;
}
.custom-input:focus { border-color: #f59e0b; }

.btn-confirm {
  padding: 0.5rem 0.9rem;
  background: #f59e0b;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
  white-space: nowrap;
}
.btn-confirm:hover:not(:disabled) { background: #d97706; }
.btn-confirm:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
