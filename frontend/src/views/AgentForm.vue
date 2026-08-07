<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeft, Save, Eye, EyeOff, Shuffle } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const isEditing = ref(false)
const isLoading = ref(false)
const showPassword = ref(false)
const groups = ref([])

const DEPARTMENTS = [
  { value: 'corretor',    label: 'Consultora',  desc: 'Atende novas revendedoras e a régua de relacionamento' },
  { value: 'suporte',     label: 'Suporte',     desc: 'Atende clientes com dúvidas e problemas' },
  { value: 'financeiro',  label: 'Financeiro',  desc: 'Cobranças, boletos e contratos' },
  { value: 'manutencao',  label: 'Manutenção',  desc: 'Reparos e serviços técnicos' },
]

// Perfil de acesso (RBAC, briefing seção 30) — diferente de department (que só
// controla o rodízio de WhatsApp). Controla o que a pessoa vê/pode fazer no CRM.
const ROLES = [
  { value: 'consultor',  label: 'Consultor',  desc: 'Só a própria carteira. Não vê configurações nem outras carteiras.' },
  { value: 'gerente',    label: 'Gerente',    desc: 'Vê a carteira inteira, reatribui responsáveis. Não mexe em configurações.' },
  { value: 'financeiro', label: 'Financeiro', desc: 'Vê inadimplência/cobrança e a carteira inteira pra cruzar consultores.' },
  { value: 'diretoria',  label: 'Diretoria',  desc: 'Acesso total, inclusive configurações críticas do sistema.' },
]

const form = ref({
  first_name: '',
  last_name: '',
  email: '',
  phone: '',
  password: '',
  role: 'consultor',
  department: 'corretor',
  jueri_gerente_id: '',
  round_robin_group_id: null,
  status: 'active',
  permissions: {
    view_all_contacts: true,
    export_data: false,
    delete_data: false
  }
})

const fetchAgent = async (id) => {
  isLoading.value = true
  try {
    const response = await api.get(`/agents/${id}`)
    const data = response.data
    form.value = {
      first_name: data.first_name || '',
      last_name: data.last_name || '',
      email: data.email || '',
      phone: data.phone || '',
      password: '',
      role: data.role || 'consultor',
      department: data.department || 'corretor',
      jueri_gerente_id: data.jueri_gerente_id || '',
      round_robin_group_id: data.round_robin_group_id || null,
      status: data.status || 'active',
      permissions: data.permissions || {
        view_all_contacts: false,
        export_data: false,
        delete_data: false
      }
    }
  } catch (error) {
    console.error('Erro ao carregar agente:', error)
  } finally {
    isLoading.value = false
  }
}

const fetchGroups = async () => {
  try {
    const res = await api.get('/round_robin_groups')
    groups.value = res.data
  } catch (e) {
    console.error('Erro ao carregar grupos de rodízio', e)
  }
}

onMounted(() => {
  fetchGroups()
  if (route.params.id) {
    isEditing.value = true
    fetchAgent(route.params.id)
  }
})

const generatePassword = () => {
  const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
  let pass = ""
  for (let i = 0; i < 12; i++) {
    pass += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  form.value.password = pass
  showPassword.value = true
}

const saveAgent = async () => {
  try {
    if (isEditing.value) {
      // Se a senha estiver vazia, não enviamos na edição (backend já trata isso)
      const dataToSubmit = { ...form.value }
      if (!dataToSubmit.password) delete dataToSubmit.password
      
      await api.put(`/agents/${route.params.id}`, { agent: dataToSubmit })
    } else {
      await api.post('/agents', { agent: form.value })
    }
    router.push('/agentes')
  } catch (error) {
    console.error('Erro ao salvar agente:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Ocorreu um erro ao salvar os dados. Verifique o e-mail ou a senha.', showConfirmButton: false, timer: 3500 })
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <button class="btn-back" @click="router.push('/agentes')">
        <ArrowLeft class="icon-sm" /> Voltar
      </button>
      <h1>{{ isEditing ? 'Editar Agente' : 'Novo Agente' }}</h1>
    </div>

    <div v-if="isLoading" class="loading-state">Carregando dados...</div>
    
    <div v-else class="form-grid">
      <!-- Coluna da Esquerda: Dados Principais -->
      <div class="card form-card">
        <h3>Dados do Agente</h3>

        <div class="input-row">
          <div class="input-group">
            <label>Nome</label>
            <input type="text" v-model="form.first_name" required placeholder="Ex: João" />
          </div>
          <div class="input-group">
            <label>Sobrenome</label>
            <input type="text" v-model="form.last_name" placeholder="Ex: Silva" />
          </div>
        </div>

        <div class="input-group">
          <label>WhatsApp</label>
          <input type="tel" v-model="form.phone" placeholder="(11) 99999-9999" />
        </div>

        <div class="input-group">
          <label>E-mail de Login</label>
          <input type="email" v-model="form.email" required placeholder="joao@claraferreira.com" />
        </div>

        <div class="input-group">
          <label>Senha de Acesso <span v-if="isEditing" class="text-muted text-xs">(Deixe em branco para não alterar)</span></label>
          <div class="password-wrapper">
            <input :type="showPassword ? 'text' : 'password'" v-model="form.password" :required="!isEditing" placeholder="Digite uma senha forte" class="pwd-input" />
            <div class="pwd-actions">
              <button type="button" @click="showPassword = !showPassword" title="Mostrar/Ocultar Senha">
                <EyeOff v-if="showPassword" class="icon-sm" />
                <Eye v-else class="icon-sm" />
              </button>
              <button type="button" @click="generatePassword" title="Gerar Senha Aleatória">
                <Shuffle class="icon-sm" />
              </button>
            </div>
          </div>
        </div>

        <div class="input-group">
          <label>Perfil de Acesso</label>
          <div class="dept-options">
            <label
              v-for="r in ROLES"
              :key="r.value"
              class="dept-option"
              :class="{ active: form.role === r.value }"
            >
              <input type="radio" :value="r.value" v-model="form.role" />
              <span class="dept-dot" :class="'dept-' + r.value"></span>
              <span class="dept-info">
                <strong>{{ r.label }}</strong>
                <small>{{ r.desc }}</small>
              </span>
            </label>
          </div>
        </div>

        <div class="input-group" v-if="form.role === 'gerente' || form.role === 'consultor'">
          <label>ID do Gerente no Jueri <span class="text-muted text-xs">(opcional)</span></label>
          <input type="text" v-model="form.jueri_gerente_id" placeholder="Ex: 42" />
          <small class="field-hint">Se preenchido, toda revendedora nova sincronizada do Jueri sob esse gerente já entra atribuída direto pra esta pessoa (sem precisar de atribuição manual). A Clara informa esse ID.</small>
        </div>

        <div class="input-group">
          <label>Departamento <span class="text-muted text-xs">(rodízio de WhatsApp)</span></label>
          <div class="dept-options">
            <label
              v-for="dept in DEPARTMENTS"
              :key="dept.value"
              class="dept-option"
              :class="{ active: form.department === dept.value }"
            >
              <input type="radio" :value="dept.value" v-model="form.department" />
              <span class="dept-dot" :class="'dept-' + dept.value"></span>
              <span class="dept-info">
                <strong>{{ dept.label }}</strong>
                <small>{{ dept.desc }}</small>
              </span>
            </label>
          </div>
        </div>

        <div class="input-group" v-if="form.department === 'corretor' && groups.length > 0">
          <label>Grupo de Rodízio <span class="text-muted text-xs">(opcional)</span></label>
          <select v-model="form.round_robin_group_id">
            <option :value="null">Sem grupo (rodízio com todas as consultoras da conta)</option>
            <option v-for="group in groups" :key="group.id" :value="group.id">{{ group.name }}</option>
          </select>
        </div>

        <div class="input-group" v-if="isEditing">
          <label>Status</label>
          <select v-model="form.status">
            <option value="active">Ativo (Acesso Liberado)</option>
            <option value="blocked">Bloqueado (Acesso Negado)</option>
          </select>
        </div>
      </div>

      <!-- Coluna da Direita: Permissões -->
      <div class="card permissions-card">
        <h3>Permissões de Acesso</h3>
        <p class="subtitle">Defina o que esta consultora poderá ver ou fazer no sistema.</p>

        <div class="permission-list">
          <div class="permission-item">
            <label class="switch-container">
              <div class="toggle-switch">
                <input type="checkbox" v-model="form.permissions.view_all_contacts">
                <span class="slider"></span>
              </div>
              <div class="perm-text">
                <strong>Ver Todos os Clientes</strong>
                <span>Se desmarcado, ele só verá os clientes atribuídos a ele.</span>
              </div>
            </label>
          </div>

          <div class="permission-item">
            <label class="switch-container">
              <div class="toggle-switch">
                <input type="checkbox" v-model="form.permissions.export_data">
                <span class="slider"></span>
              </div>
              <div class="perm-text">
                <strong>Permitir Exportação</strong>
                <span>Pode baixar listas de clientes e relatórios em CSV/Excel.</span>
              </div>
            </label>
          </div>

          <div class="permission-item text-danger-hover">
            <label class="switch-container">
              <div class="toggle-switch">
                <input type="checkbox" v-model="form.permissions.delete_data">
                <span class="slider"></span>
              </div>
              <div class="perm-text">
                <strong>Apagar Registros</strong>
                <span>Pode excluir permanentemente contatos e negociações.</span>
              </div>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- Barra Inferior -->
    <div class="bottom-bar">
      <div class="actions">
        <button class="btn-cancel" @click="router.push('/agentes')">Cancelar</button>
        <button class="btn-primary" @click="saveAgent">
          <Save class="icon-sm" /> {{ isEditing ? 'Salvar Alterações' : 'Criar Consultora' }}
        </button>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  padding: 2rem;
  background: var(--bg-primary);
  min-height: 100%;
}

.page-header {
  margin-bottom: 2rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  
  h1 { font-size: 1.2rem; color: var(--text-main); font-weight: 500; margin: 0; }
  .btn-back {
    display: flex; align-items: center; gap: 0.5rem;
    background: transparent; border: none;
    color: var(--text-muted); cursor: pointer;
    &:hover { color: var(--primary); }
  }
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
}

.card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);

  h3 { margin-bottom: 1.5rem; color: var(--text-main); font-size: 1.2rem; }
  .subtitle { color: var(--text-muted); font-size: 0.9rem; margin-top: -1rem; margin-bottom: 1.5rem; }
}

.input-row { display: flex; gap: 1rem; }
.input-group {
  margin-bottom: 1rem;
  flex: 1;
  label {
    display: block; margin-bottom: 0.5rem;
    color: var(--text-main); font-size: 0.9rem; font-weight: 500;
  }
  input, select {
    width: 100%; padding: 0.75rem;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: 6px; color: var(--text-main);
    &:focus { outline: none; border-color: var(--primary); }
  }
}

.password-wrapper {
  position: relative;

  .pwd-input {
    padding-right: 5rem !important;
  }

  .pwd-actions {
    position: absolute;
    right: 0.25rem;
    top: 50%;
    transform: translateY(-50%);
    display: flex;
    align-items: center;
    gap: 0.1rem;

    button {
      background: transparent;
      border: none;
      cursor: pointer;
      color: var(--text-muted);
      padding: 0.35rem 0.4rem;
      display: flex;
      align-items: center;
      border-radius: 4px;
      &:hover { color: var(--primary); background: rgba(212, 155, 167, 0.06); }
    }
  }
}

/* Switches para Permissões */
.permission-item {
  margin-bottom: 1.25rem;
}
.switch-container {
  display: flex; align-items: flex-start; gap: 1rem;
  cursor: pointer;
}
.perm-text {
  display: flex; flex-direction: column; gap: 0.2rem;
  strong { color: var(--text-main); font-size: 0.95rem; }
  span { color: var(--text-muted); font-size: 0.8rem; }
}

.toggle-switch {
  position: relative; width: 44px; height: 24px; flex-shrink: 0;
  input { opacity: 0; width: 0; height: 0; }
  .slider {
    position: absolute; cursor: pointer;
    top: 0; left: 0; right: 0; bottom: 0;
    background-color: var(--border-color);
    transition: .3s; border-radius: 24px;
    &:before {
      position: absolute; content: "";
      height: 18px; width: 18px; left: 3px; bottom: 3px;
      background-color: white; transition: .3s;
      border-radius: 50%; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
  }
  input:checked + .slider { background-color: var(--primary); }
  input:checked + .slider:before { transform: translateX(20px); }
  input:disabled + .slider { opacity: 0.5; cursor: not-allowed; }
}

.admin-highlight {
  background: rgba(212, 155, 167, 0.05);
  padding: 1rem;
  border-radius: 8px;
  border: 1px solid rgba(212, 155, 167, 0.1);
}
.disabled-list {
  opacity: 0.6; pointer-events: none;
}
.divider { border: 0; border-top: 1px solid var(--border-color); margin: 1.5rem 0; }

.text-danger-hover:hover strong { color: #ef4444; }

.bottom-bar {
  position: sticky; bottom: 0;
  margin: 2rem -2rem -2rem;
  background: var(--bg-secondary);
  border-top: 1px solid var(--border-color);
  padding: 1rem 2rem;
  z-index: 100;
  .actions {
    max-width: 1200px; margin: 0 auto;
    display: flex; justify-content: flex-end; gap: 1rem;
  }
}

.btn-cancel {
  background: transparent; color: var(--text-muted);
  border: 1px solid var(--border-color);
  padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer;
  &:hover { background: var(--bg-primary); color: var(--text-main); }
}
.btn-primary {
  display: inline-flex; align-items: center; gap: 0.5rem;
  background: var(--primary); color: white;
  border: none; padding: 0.6rem 1.2rem; border-radius: 6px;
  font-weight: 500; cursor: pointer;
  &:hover { opacity: 0.9; }
}
.icon-sm { width: 16px; height: 16px; }
.text-muted { color: var(--text-muted); }
.text-xs { font-size: 0.75rem; }
.field-hint { display: block; margin-top: 0.4rem; color: var(--text-muted); font-size: 0.78rem; line-height: 1.3; }

.dept-options {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.dept-option {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.65rem 0.9rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s;
  input[type="radio"] { display: none; }
  &.active {
    border-color: var(--primary);
    background: rgba(212, 155, 167,0.04);
  }
  &:hover { border-color: var(--primary); }
}
.dept-dot {
  width: 10px; height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
  &.dept-corretor   { background: #d49ba7; }
  &.dept-suporte    { background: #10b981; }
  &.dept-financeiro { background: #f59e0b; }
  &.dept-manutencao { background: #f97316; }
  &.dept-consultor  { background: #d49ba7; }
  &.dept-gerente    { background: #6366f1; }
  &.dept-diretoria  { background: #2b0016; }
}
.dept-info {
  display: flex; flex-direction: column; gap: 0.1rem;
  strong { font-size: 0.88rem; color: var(--text-main); }
  small  { font-size: 0.75rem; color: var(--text-muted); }
}

@media (max-width: 768px) {
  .page-container {
    padding: 1rem;
  }

  .form-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  .input-row {
    flex-direction: column;
    gap: 0;
  }

  .bottom-bar {
    margin: 1.5rem -1rem -1rem;
    padding: 0.75rem 1rem;
    .actions { gap: 0.5rem; }
    .btn-cancel, .btn-primary {
      flex: 1;
      justify-content: center;
    }
  }
}
</style>
