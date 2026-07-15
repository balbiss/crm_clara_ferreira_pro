<script setup>
import { ref, onMounted } from 'vue'
import api from '../../api'
import Swal from 'sweetalert2'
import {
  Eye, EyeOff, CheckCircle, XCircle, Loader2,
  Zap, ShieldCheck, ShieldOff, FlaskConical, Globe
} from 'lucide-vue-next'

const apiKey       = ref('')
const showKey      = ref(false)
const isConfigured = ref(false)
const isSandbox    = ref(false)
const isSaving     = ref(false)
const isTesting    = ref(false)
const testResult   = ref(null)

onMounted(async () => {
  try {
    const res = await api.get('/account')
    isConfigured.value = res.data.asaas_configured
    isSandbox.value    = res.data.asaas_sandbox ?? false
    if (res.data.asaas_api_key) apiKey.value = res.data.asaas_api_key
  } catch (e) { console.error(e) }
})

const saveKey = async () => {
  if (!apiKey.value.trim()) {
    return Swal.fire({ icon: 'warning', title: 'API Key vazia', text: 'Digite a chave antes de salvar.', confirmButtonColor: '#4338ca' })
  }
  isSaving.value = true
  try {
    await api.put('/account', { account: { asaas_api_key: apiKey.value.trim(), asaas_sandbox: isSandbox.value } })
    isConfigured.value = true
    testResult.value   = null
    Swal.fire({ icon: 'success', title: 'Salvo!', text: 'Configuração salva com sucesso.', timer: 1800, showConfirmButton: false })
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível salvar a configuração.', confirmButtonColor: '#4338ca' })
  } finally {
    isSaving.value = false
  }
}

const testConnection = async () => {
  isTesting.value  = true
  testResult.value = null
  try {
    const res = await api.get('/account/test_asaas')
    testResult.value = res.data
  } catch (e) {
    testResult.value = { ok: false, message: 'Erro ao testar conexão.' }
  } finally {
    isTesting.value = false
  }
}

const saveSandboxMode = async () => {
  try {
    await api.put('/account', { account: { asaas_sandbox: isSandbox.value } })
    testResult.value = null
  } catch (e) { console.error(e) }
}

const removeKey = async () => {
  const { isConfirmed } = await Swal.fire({
    title: 'Remover integração?',
    text: 'A cobrança via Asaas será desativada.',
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#dc2626',
    cancelButtonText: 'Cancelar',
    confirmButtonText: 'Sim, remover'
  })
  if (!isConfirmed) return
  try {
    await api.put('/account', { account: { asaas_api_key: '' } })
    apiKey.value       = ''
    isConfigured.value = false
    testResult.value   = null
    Swal.fire({ icon: 'success', title: 'Integração removida', timer: 1500, showConfirmButton: false })
  } catch (e) { console.error(e) }
}

const departments = [
  { label: 'Financeiro',  allowed: true  },
  { label: 'Suporte',     allowed: true  },
  { label: 'Manutenção',  allowed: true  },
  { label: 'Dono / Admin', allowed: true  },
  { label: 'Corretor',    allowed: false },
]
</script>

<template>
  <div class="page">

    <!-- Page header -->
    <div class="page-header">
      <div class="page-header-left">
        <div class="page-icon"><Zap :size="18" /></div>
        <div>
          <h1>Integração Asaas</h1>
          <p>Geração de cobranças via PIX e Boleto com envio automático pelo WhatsApp.</p>
        </div>
      </div>
      <div class="status-badge" :class="isConfigured ? 'badge-active' : 'badge-inactive'">
        <component :is="isConfigured ? CheckCircle : XCircle" :size="13" />
        {{ isConfigured ? 'Ativa' : 'Não configurada' }}
      </div>
    </div>

    <div class="content">

      <!-- API Key card -->
      <div class="section-card">
        <div class="section-header">
          <span class="section-title">Credenciais</span>
          <span class="section-hint">Acesse: Asaas → Configurações → Integrações → API</span>
        </div>

        <div class="field-block">
          <label class="field-label">API Key</label>
          <div class="key-row">
            <div class="input-wrap">
              <input
                :type="showKey ? 'text' : 'password'"
                v-model="apiKey"
                placeholder="$aact_..."
                class="field-input mono"
                autocomplete="off"
              />
              <button class="eye-btn" type="button" @click="showKey = !showKey" tabindex="-1">
                <EyeOff v-if="showKey" :size="15" />
                <Eye    v-else          :size="15" />
              </button>
            </div>
            <button class="btn-primary" :disabled="isSaving" @click="saveKey">
              <Loader2 v-if="isSaving" :size="14" class="spin" />
              {{ isSaving ? 'Salvando...' : 'Salvar chave' }}
            </button>
          </div>
        </div>

        <div class="divider" />

        <div class="field-block">
          <label class="field-label">Ambiente de operação</label>
          <div class="seg-control">
            <label class="seg-option" :class="{ active: !isSandbox }">
              <input type="radio" :value="false" v-model="isSandbox" @change="saveSandboxMode" />
              <Globe :size="14" />
              Produção
            </label>
            <label class="seg-option" :class="{ active: isSandbox }">
              <input type="radio" :value="true" v-model="isSandbox" @change="saveSandboxMode" />
              <FlaskConical :size="14" />
              Sandbox
            </label>
          </div>
          <p class="field-hint">
            Use <strong>Sandbox</strong> para testes sem movimentação financeira real.
            Troque para <strong>Produção</strong> ao ativar com clientes reais.
          </p>
        </div>

        <div class="divider" />

        <div class="action-row">
          <div class="action-left">
            <button class="btn-outline" :disabled="!isConfigured || isTesting" @click="testConnection">
              <Loader2 v-if="isTesting" :size="13" class="spin" />
              {{ isTesting ? 'Verificando...' : 'Testar conexão' }}
            </button>
            <div v-if="testResult" class="inline-result" :class="testResult.ok ? 'result-ok' : 'result-err'">
              <component :is="testResult.ok ? CheckCircle : XCircle" :size="13" />
              {{ testResult.message }}
            </div>
          </div>
          <button class="btn-ghost-danger" :disabled="!isConfigured" @click="removeKey">
            Remover integração
          </button>
        </div>
      </div>

      <!-- Permissions card -->
      <div class="section-card">
        <div class="section-header">
          <span class="section-title">Permissões de cobrança</span>
          <span class="section-hint">Quais departamentos podem gerar cobranças pelo painel</span>
        </div>

        <table class="perm-table">
          <tbody>
            <tr v-for="dept in departments" :key="dept.label" class="perm-row">
              <td class="perm-name">{{ dept.label }}</td>
              <td class="perm-access">
                <span class="perm-badge" :class="dept.allowed ? 'perm-allow' : 'perm-deny'">
                  <component :is="dept.allowed ? ShieldCheck : ShieldOff" :size="12" />
                  {{ dept.allowed ? 'Permitido' : 'Bloqueado' }}
                </span>
              </td>
              <td class="perm-desc">
                <span v-if="dept.allowed">Pode gerar boletos e PIX a partir do painel de conversas</span>
                <span v-else class="text-muted">Sem acesso à geração de cobranças</span>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="delivery-note">
          <div class="note-row">
            <span class="note-type">Boleto</span>
            <span>Arquivo PDF enviado diretamente na conversa do WhatsApp</span>
          </div>
          <div class="note-row">
            <span class="note-type">PIX</span>
            <span>Imagem do QR Code + código Copia e Cola enviados na conversa</span>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<style lang="scss" scoped>
.page {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow-y: auto;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.5rem 2rem 1.25rem;
  border-bottom: 1px solid var(--border-color);
  gap: 1rem;
}

.page-header-left {
  display: flex;
  align-items: center;
  gap: 0.875rem;

  h1 {
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--text-main);
    margin-bottom: 0.1rem;
  }
  p {
    font-size: 0.82rem;
    color: var(--text-muted);
    margin: 0;
  }
}

.page-icon {
  width: 36px;
  height: 36px;
  background: rgba(67,56,202,0.1);
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #4338ca;
  flex-shrink: 0;
}

.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.3rem 0.8rem;
  border-radius: 6px;
  font-size: 0.78rem;
  font-weight: 600;
  white-space: nowrap;
  flex-shrink: 0;

  &.badge-active   { background: rgba(16,185,129,0.1);  color: #059669; border: 1px solid rgba(16,185,129,0.25); }
  &.badge-inactive { background: rgba(107,114,128,0.08); color: #6b7280; border: 1px solid rgba(107,114,128,0.2); }
}

.content {
  padding: 1.5rem 2rem;
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  max-width: 860px;
}

.section-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  overflow: hidden;
}

.section-header {
  display: flex;
  align-items: baseline;
  gap: 0.75rem;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-color);
  background: var(--bg-primary);
}

.section-title {
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--text-main);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.section-hint {
  font-size: 0.8rem;
  color: var(--text-muted);
}

.field-block {
  padding: 1.1rem 1.25rem;
}

.field-label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-main);
  margin-bottom: 0.5rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.field-hint {
  font-size: 0.8rem;
  color: var(--text-muted);
  margin: 0.5rem 0 0;
  line-height: 1.55;
}

.key-row {
  display: flex;
  gap: 0.6rem;
  align-items: center;
}

.input-wrap {
  flex: 1;
  position: relative;
  display: flex;
  align-items: center;
}

.field-input {
  width: 100%;
  padding: 0.6rem 2.4rem 0.6rem 0.85rem;
  border: 1px solid var(--border-color);
  border-radius: 7px;
  font-size: 0.88rem;
  background: var(--bg-primary);
  color: var(--text-main);
  outline: none;
  &.mono { font-family: 'Courier New', monospace; letter-spacing: 0.02em; }
  &:focus { border-color: #4338ca; box-shadow: 0 0 0 3px rgba(67,56,202,0.1); }
}

.eye-btn {
  position: absolute;
  right: 0.7rem;
  background: none;
  border: none;
  cursor: pointer;
  color: var(--text-muted);
  display: flex;
  padding: 0;
  &:hover { color: #4338ca; }
}

.divider {
  height: 1px;
  background: var(--border-color);
}

// Segmented control
.seg-control {
  display: inline-flex;
  border: 1px solid var(--border-color);
  border-radius: 7px;
  overflow: hidden;
  background: var(--bg-primary);
}

.seg-option {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.5rem 1.1rem;
  font-size: 0.83rem;
  font-weight: 500;
  color: var(--text-muted);
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
  border-right: 1px solid var(--border-color);
  user-select: none;

  &:last-child { border-right: none; }

  input[type="radio"] { display: none; }

  &.active {
    background: #4338ca;
    color: #fff;
    font-weight: 600;
  }
}

.action-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.9rem 1.25rem;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.action-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.inline-result {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.82rem;
  font-weight: 500;
  padding: 0.35rem 0.75rem;
  border-radius: 5px;

  &.result-ok  { background: rgba(16,185,129,0.1);  color: #059669; }
  &.result-err { background: rgba(220,38,38,0.08); color: #dc2626; }
}

// Permissions table
.perm-table {
  width: 100%;
  border-collapse: collapse;
}

.perm-row {
  border-bottom: 1px solid var(--border-color);
  &:last-child { border-bottom: none; }
}

.perm-name {
  padding: 0.75rem 1.25rem;
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--text-main);
  width: 160px;
}

.perm-access {
  padding: 0.75rem 0.75rem;
  width: 130px;
}

.perm-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.2rem 0.65rem;
  border-radius: 5px;
  font-size: 0.76rem;
  font-weight: 600;

  &.perm-allow { background: rgba(16,185,129,0.1);  color: #059669; }
  &.perm-deny  { background: rgba(220,38,38,0.08); color: #dc2626; }
}

.perm-desc {
  padding: 0.75rem 1.25rem 0.75rem 0;
  font-size: 0.82rem;
  color: var(--text-muted);

  .text-muted { color: var(--text-muted); opacity: 0.7; }
}

.delivery-note {
  border-top: 1px solid var(--border-color);
  padding: 0.9rem 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  background: var(--bg-primary);
}

.note-row {
  display: flex;
  align-items: baseline;
  gap: 0.75rem;
  font-size: 0.82rem;
  color: var(--text-muted);
}

.note-type {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #4338ca;
  background: rgba(67,56,202,0.08);
  padding: 0.15rem 0.5rem;
  border-radius: 4px;
  white-space: nowrap;
}

// Buttons
.btn-primary {
  background: #4338ca;
  color: #fff;
  border: none;
  border-radius: 7px;
  padding: 0.6rem 1.15rem;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  white-space: nowrap;
  &:disabled { opacity: 0.55; cursor: not-allowed; }
}

.btn-outline {
  background: transparent;
  color: var(--text-main);
  border: 1px solid var(--border-color);
  border-radius: 7px;
  padding: 0.55rem 1rem;
  font-size: 0.83rem;
  font-weight: 500;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  &:hover:not(:disabled) { border-color: #4338ca; color: #4338ca; }
  &:disabled { opacity: 0.45; cursor: not-allowed; }
}

.btn-ghost-danger {
  background: none;
  color: #dc2626;
  border: 1px solid rgba(220,38,38,0.25);
  border-radius: 7px;
  padding: 0.55rem 1rem;
  font-size: 0.83rem;
  font-weight: 500;
  cursor: pointer;
  &:hover:not(:disabled) { background: rgba(220,38,38,0.06); }
  &:disabled { opacity: 0.35; cursor: not-allowed; }
}

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
