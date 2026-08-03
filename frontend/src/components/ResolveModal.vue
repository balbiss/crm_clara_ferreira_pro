<script setup>
import { ref } from 'vue'
import { X, CheckCircle } from 'lucide-vue-next'

defineProps({
  conversationId: { type: [Number, String], required: true }
})
const emit = defineEmits(['confirm', 'close'])

const kanbanStage   = ref('')
const sendClosing   = ref(false)
const closingText   = ref('Obrigado pelo seu contato! Encerramos seu atendimento por agora. Se precisar de algo mais, é só nos chamar. 😊')
const isSubmitting  = ref(false)

const confirm = async () => {
  isSubmitting.value = true
  try {
    emit('confirm', {
      kanbanStage:        kanbanStage.value,
      sendClosingMessage: sendClosing.value,
      closingMessageText: sendClosing.value ? closingText.value : ''
    })
  } finally {
    isSubmitting.value = false
  }
}

const kanbanOptions = [
  { value: '',         label: 'Não mover no funil', icon: '—' },
  { value: 'proposal', label: 'Proposta Feita',     icon: '📋' },
  { value: 'won',      label: 'Negócio Fechado 🎉', icon: '🏆' },
]
</script>

<template>
  <div class="modal-overlay" @click.self="emit('close')">
    <div class="resolve-modal">
      <div class="modal-header">
        <div class="modal-title-row">
          <CheckCircle class="modal-icon" />
          <h3>Encerrar atendimento</h3>
        </div>
        <button class="btn-close" @click="emit('close')"><X :size="16" /></button>
      </div>

      <p class="modal-subtitle">A IA será pausada. Se o cliente mandar mensagem, a conversa reabrirá automaticamente.</p>

      <!-- Kanban Stage -->
      <div class="field-group">
        <label class="field-label">Mover lead no funil para</label>
        <div class="kanban-options">
          <button
            v-for="opt in kanbanOptions"
            :key="opt.value"
            class="kanban-option"
            :class="{ active: kanbanStage === opt.value }"
            @click="kanbanStage = opt.value"
          >
            <span>{{ opt.icon }}</span>
            <span>{{ opt.label }}</span>
          </button>
        </div>
      </div>

      <!-- Closing Message -->
      <div class="field-group">
        <label class="checkbox-label">
          <input type="checkbox" v-model="sendClosing" />
          <span>Enviar mensagem de encerramento no WhatsApp</span>
        </label>
        <textarea
          v-if="sendClosing"
          class="closing-textarea"
          v-model="closingText"
          rows="3"
          placeholder="Mensagem de encerramento..."
        />
      </div>

      <!-- Actions -->
      <div class="modal-actions">
        <button class="btn-cancel" @click="emit('close')">Cancelar</button>
        <button class="btn-resolve" @click="confirm" :disabled="isSubmitting">
          <CheckCircle :size="15" />
          {{ isSubmitting ? 'Encerrando...' : 'Encerrar' }}
        </button>
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

.resolve-modal {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  width: 380px;
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
  color: #10b981;
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
  margin: 0 0 1.25rem 0;
}

.field-group {
  margin-bottom: 1rem;
}

.field-label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.5rem;
}

.kanban-options {
  display: flex;
  gap: 0.4rem;
  flex-wrap: wrap;
}

.kanban-option {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.75rem;
  background: #f9fafb;
  border: 1.5px solid #e5e7eb;
  border-radius: 8px;
  font-size: 0.82rem;
  color: #374151;
  cursor: pointer;
  transition: all 0.15s;
  font-weight: 500;
}

.kanban-option:hover {
  border-color: #10b981;
  background: #ecfdf5;
}

.kanban-option.active {
  border-color: #10b981;
  background: #ecfdf5;
  color: #065f46;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-size: 0.88rem;
  color: #374151;
  font-weight: 500;
}

.checkbox-label input[type="checkbox"] {
  width: 16px;
  height: 16px;
  cursor: pointer;
  accent-color: #10b981;
}

.closing-textarea {
  display: block;
  margin-top: 0.6rem;
  width: 100%;
  padding: 0.6rem 0.75rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  font-size: 0.85rem;
  color: #374151;
  resize: vertical;
  outline: none;
  font-family: inherit;
  box-sizing: border-box;
}
.closing-textarea:focus { border-color: #10b981; }

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 1.25rem;
  padding-top: 1rem;
  border-top: 1px solid #e5e7eb;
}

.btn-cancel {
  padding: 0.5rem 1rem;
  background: transparent;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  font-size: 0.88rem;
  color: #374151;
  cursor: pointer;
}
.btn-cancel:hover { background: #f3f4f6; }

.btn-resolve {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.5rem 1.1rem;
  background: #10b981;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 0.88rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
}
.btn-resolve:hover:not(:disabled) { background: #059669; }
.btn-resolve:disabled { opacity: 0.6; cursor: not-allowed; }
</style>
