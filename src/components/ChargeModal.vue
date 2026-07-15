<script setup>
import { ref, computed, watch } from 'vue'
import { X, Loader2, FileText, QrCode, AlertCircle, CheckCircle } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const props = defineProps({
  contact: { type: Object, required: true },
  show:    { type: Boolean, default: false }
})
const emit = defineEmits(['close', 'charged'])

// ── State ──────────────────────────────────────────────────────────
const step         = ref(1) // 1 = check/fill CPF, 2 = fill charge
const cpfInput     = ref('')
const billingType  = ref('PIX')
const value        = ref('')
const dueDate      = ref(defaultDueDate())
const description  = ref('')
const isLoading    = ref(false)
const isSavingCpf  = ref(false)

const hasCpf = computed(() => props.contact?.cpf?.trim().length > 0)

watch(() => props.show, (v) => {
  if (v) {
    cpfInput.value    = props.contact?.cpf || ''
    billingType.value = 'PIX'
    value.value       = ''
    dueDate.value     = defaultDueDate()
    description.value = ''
    step.value        = hasCpf.value ? 2 : 1
  }
})

function defaultDueDate() {
  const d = new Date()
  d.setDate(d.getDate() + 3)
  return d.toISOString().slice(0, 10)
}

// ── CPF step ───────────────────────────────────────────────────────
const saveCpf = async () => {
  const clean = cpfInput.value.replace(/\D/g, '')
  if (clean.length < 11) {
    return Swal.fire({ icon: 'warning', title: 'CPF inválido', text: 'Digite um CPF ou CNPJ válido.', confirmButtonColor: '#4338ca' })
  }
  isSavingCpf.value = true
  try {
    await api.patch(`/contacts/${props.contact.id}`, { contact: { cpf: cpfInput.value.trim() } })
    props.contact.cpf = cpfInput.value.trim()
    step.value = 2
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível salvar o CPF.', confirmButtonColor: '#4338ca' })
  } finally {
    isSavingCpf.value = false
  }
}

// ── Charge step ────────────────────────────────────────────────────
const submitCharge = async () => {
  if (!value.value || parseFloat(value.value) <= 0) {
    return Swal.fire({ icon: 'warning', title: 'Valor inválido', text: 'Informe um valor maior que zero.', confirmButtonColor: '#4338ca' })
  }

  isLoading.value = true
  try {
    await api.post(`/contacts/${props.contact.id}/charges`, {
      billing_type: billingType.value,
      value:        parseFloat(value.value),
      due_date:     dueDate.value,
      description:  description.value || undefined
    })

    emit('close')
    emit('charged')

    Swal.fire({
      icon: 'success',
      title: '✅ Cobrança gerada!',
      html:  billingType.value === 'BOLETO'
        ? 'O boleto em PDF foi enviado pelo WhatsApp ao cliente.'
        : 'O QR Code PIX e o Copia e Cola foram enviados pelo WhatsApp.',
      confirmButtonColor: '#4338ca',
      timer: 4000,
      showConfirmButton: false
    })
  } catch (e) {
    const msg = e.response?.data?.error || e.response?.data?.message || 'Erro ao gerar cobrança.'
    Swal.fire({ icon: 'error', title: 'Erro', text: msg, confirmButtonColor: '#4338ca' })
  } finally {
    isLoading.value = false
  }
}

const formatCpf = (v) => {
  const d = v.replace(/\D/g, '')
  if (d.length <= 11) return d.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4')
  return d.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5')
}
</script>

<template>
  <Teleport to="body">
    <div v-if="show" class="modal-backdrop" @click.self="emit('close')">
      <div class="modal-box">

        <!-- Header -->
        <div class="modal-header">
          <div class="modal-title">
            <span class="title-icon">💳</span>
            Gerar Cobrança
          </div>
          <button class="close-btn" @click="emit('close')">
            <X :size="18" />
          </button>
        </div>

        <!-- ── STEP 1: Coletar CPF ── -->
        <div v-if="step === 1" class="modal-body">
          <div class="alert-box">
            <AlertCircle :size="18" />
            <div>
              <strong>CPF/CNPJ necessário</strong>
              <p>O contato <strong>{{ contact.name || contact.first_name }}</strong> não tem CPF/CNPJ cadastrado. Preencha antes de gerar a cobrança.</p>
            </div>
          </div>

          <div class="form-group">
            <label>CPF ou CNPJ do cliente</label>
            <input
              v-model="cpfInput"
              type="text"
              placeholder="000.000.000-00 ou 00.000.000/0001-00"
              maxlength="18"
              @input="cpfInput = formatCpf(cpfInput)"
            />
          </div>

          <div class="btn-row">
            <button class="btn-ghost" @click="emit('close')">Cancelar</button>
            <button class="btn-primary" :disabled="isSavingCpf" @click="saveCpf">
              <Loader2 v-if="isSavingCpf" :size="15" class="spin" />
              {{ isSavingCpf ? 'Salvando...' : 'Continuar' }}
            </button>
          </div>
        </div>

        <!-- ── STEP 2: Dados da cobrança ── -->
        <div v-else class="modal-body">

          <!-- CPF display -->
          <div class="cpf-tag">
            <CheckCircle :size="13" />
            CPF/CNPJ: {{ contact.cpf }}
          </div>

          <!-- Tipo -->
          <div class="form-group">
            <label>Tipo de cobrança</label>
            <div class="type-options">
              <label class="type-card" :class="{ active: billingType === 'PIX' }">
                <input type="radio" v-model="billingType" value="PIX" />
                <QrCode :size="22" />
                <span>PIX</span>
                <small>QR Code + Copia e Cola</small>
              </label>
              <label class="type-card" :class="{ active: billingType === 'BOLETO' }">
                <input type="radio" v-model="billingType" value="BOLETO" />
                <FileText :size="22" />
                <span>Boleto</span>
                <small>PDF enviado no WhatsApp</small>
              </label>
            </div>
          </div>

          <!-- Valor -->
          <div class="form-row">
            <div class="form-group">
              <label>Valor (R$)</label>
              <input v-model="value" type="number" min="0.01" step="0.01" placeholder="0,00" />
            </div>
            <div class="form-group">
              <label>Vencimento</label>
              <input v-model="dueDate" type="date" />
            </div>
          </div>

          <!-- Descrição -->
          <div class="form-group">
            <label>Descrição <span class="optional">(opcional)</span></label>
            <input v-model="description" type="text" placeholder="Ex: Aluguel julho/2026, Taxa de condomínio..." maxlength="200" />
          </div>

          <div class="btn-row">
            <button class="btn-ghost" @click="emit('close')">Cancelar</button>
            <button class="btn-primary" :disabled="isLoading" @click="submitCharge">
              <Loader2 v-if="isLoading" :size="15" class="spin" />
              {{ isLoading ? 'Gerando...' : `Gerar ${billingType === 'PIX' ? 'PIX' : 'Boleto'}` }}
            </button>
          </div>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style lang="scss" scoped>
.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.45);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}

.modal-box {
  background: var(--bg-secondary, #fff);
  border-radius: 12px;
  width: 100%;
  max-width: 440px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.2);
  overflow: hidden;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-color);

  .modal-title {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1rem;
    font-weight: 700;
    color: var(--text-main);
    .title-icon { font-size: 1.1rem; }
  }

  .close-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-muted);
    display: flex;
    &:hover { color: var(--text-main); }
  }
}

.modal-body { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }

.alert-box {
  display: flex;
  gap: 0.75rem;
  background: rgba(245,158,11,0.08);
  border: 1px solid rgba(245,158,11,0.25);
  border-radius: 8px;
  padding: 0.9rem 1rem;
  color: #92400e;

  svg { flex-shrink: 0; margin-top: 2px; }
  strong { display: block; font-size: 0.88rem; margin-bottom: 0.25rem; }
  p { font-size: 0.83rem; margin: 0; color: #b45309; }
}

.cpf-tag {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  background: rgba(16,185,129,0.1);
  color: #065f46;
  font-size: 0.8rem;
  font-weight: 600;
  padding: 0.3rem 0.75rem;
  border-radius: 20px;
  align-self: flex-start;
}

.type-options {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

.type-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.3rem;
  padding: 0.9rem 0.75rem;
  border: 2px solid var(--border-color);
  border-radius: 10px;
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s;
  text-align: center;

  input[type="radio"] { display: none; }

  span { font-size: 0.9rem; font-weight: 700; color: var(--text-main); }
  small { font-size: 0.72rem; color: var(--text-muted); }

  svg { color: var(--text-muted); }

  &.active {
    border-color: #4338ca;
    background: rgba(67,56,202,0.05);
    svg { color: #4338ca; }
    span { color: #4338ca; }
  }
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;

  label {
    font-size: 0.82rem;
    font-weight: 500;
    color: var(--text-main);
  }

  input {
    padding: 0.65rem 0.9rem;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    font-size: 0.9rem;
    background: var(--bg-primary);
    color: var(--text-main);
    outline: none;
    width: 100%;
    box-sizing: border-box;
    &:focus { border-color: #4338ca; box-shadow: 0 0 0 3px rgba(67,56,202,0.1); }
  }
}

.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }

.optional { font-weight: 400; color: var(--text-muted); font-size: 0.75rem; }

.btn-row {
  display: flex;
  justify-content: flex-end;
  gap: 0.6rem;
  margin-top: 0.25rem;
}

.btn-primary {
  background: #4338ca;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 0.7rem 1.4rem;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  &:disabled { opacity: 0.6; cursor: not-allowed; }
}

.btn-ghost {
  background: none;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.7rem 1.2rem;
  font-size: 0.88rem;
  color: var(--text-muted);
  cursor: pointer;
}

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
