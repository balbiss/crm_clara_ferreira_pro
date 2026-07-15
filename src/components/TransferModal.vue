<script setup>
import { ref, computed } from 'vue'
import { X, ArrowRightLeft } from 'lucide-vue-next'

const props = defineProps({
  agents: { type: Array, default: () => [] },
  currentAssigneeId: { type: [Number, String, null], default: null }
})

const emit = defineEmits(['close', 'confirm'])

const selectedUserId = ref(props.currentAssigneeId || '')
const note = ref('')
const isLoading = ref(false)

const agentsByDept = computed(() => {
  const LABELS = { corretor: 'Corretores', suporte: 'Suporte', financeiro: 'Financeiro', manutencao: 'Manutenção' }
  const groups = {}
  for (const a of props.agents) {
    const d = a.department || 'outros'
    if (!groups[d]) groups[d] = []
    groups[d].push(a)
  }
  return Object.entries(groups).map(([dept, agents]) => ({
    dept,
    label: LABELS[dept] || dept,
    agents
  }))
})

const canConfirm = computed(() => selectedUserId.value && note.value.trim().length > 0)

const confirm = () => {
  if (!canConfirm.value) return
  emit('confirm', { userId: parseInt(selectedUserId.value), note: note.value.trim() })
}
</script>

<template>
  <div class="modal-overlay" @click.self="emit('close')">
    <div class="modal-box">
      <div class="modal-header">
        <div class="modal-title">
          <ArrowRightLeft :size="16" />
          <span>Transferir Conversa</span>
        </div>
        <button class="btn-close" @click="emit('close')"><X :size="16" /></button>
      </div>

      <div class="modal-body">
        <div class="field">
          <label>Transferir para</label>
          <select v-model="selectedUserId" class="select-field">
            <option value="">Selecionar agente...</option>
            <optgroup v-for="g in agentsByDept" :key="g.dept" :label="'— ' + g.label">
              <option v-for="a in g.agents" :key="a.id" :value="a.id">
                {{ a.first_name }} {{ a.last_name }}
              </option>
            </optgroup>
          </select>
        </div>

        <div class="field">
          <label>Nota de contexto <span class="required">*</span></label>
          <textarea
            v-model="note"
            class="textarea-field"
            placeholder="Explique o motivo da transferência e o contexto para o próximo agente..."
            rows="4"
            maxlength="500"
          />
          <span class="char-count">{{ note.length }}/500</span>
        </div>

        <div class="hint">
          A nota aparecerá como mensagem privada no chat, visível apenas para a equipe.
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn-cancel" @click="emit('close')">Cancelar</button>
        <button class="btn-confirm" :disabled="!canConfirm" @click="confirm">
          <ArrowRightLeft :size="14" />
          Transferir
        </button>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.45);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}

.modal-box {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  width: 100%;
  max-width: 440px;
  box-shadow: 0 20px 40px rgba(0,0,0,0.2);
  display: flex;
  flex-direction: column;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-color);
}

.modal-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.92rem;
  font-weight: 700;
  color: var(--text-main);
}

.btn-close {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--text-muted);
  display: flex;
  padding: 0.25rem;
  border-radius: 4px;
  &:hover { background: var(--bg-hover); }
}

.modal-body {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  position: relative;

  label {
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .required { color: #ef4444; }
}

.select-field {
  background: var(--bg-primary);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.55rem 0.75rem;
  font-size: 0.85rem;
  color: var(--text-main);
  outline: none;
  width: 100%;
  &:focus { border-color: #4338ca; }
}

.textarea-field {
  background: var(--bg-primary);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.6rem 0.75rem;
  font-size: 0.85rem;
  color: var(--text-main);
  font-family: inherit;
  resize: none;
  outline: none;
  width: 100%;
  &:focus { border-color: #4338ca; }
}

.char-count {
  font-size: 0.72rem;
  color: var(--text-muted);
  text-align: right;
  margin-top: -0.2rem;
}

.hint {
  font-size: 0.78rem;
  color: var(--text-muted);
  background: var(--bg-tertiary);
  border-radius: 6px;
  padding: 0.6rem 0.75rem;
  border-left: 3px solid #4338ca;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.25rem;
  border-top: 1px solid var(--border-color);
}

.btn-cancel {
  background: none;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.5rem 1rem;
  font-size: 0.85rem;
  color: var(--text-muted);
  cursor: pointer;
  &:hover { background: var(--bg-hover); }
}

.btn-confirm {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: #4338ca;
  color: white;
  border: none;
  border-radius: 6px;
  padding: 0.5rem 1.1rem;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
  &:hover:not(:disabled) { background: #3730a3; }
  &:disabled { opacity: 0.45; cursor: not-allowed; }
}
</style>
