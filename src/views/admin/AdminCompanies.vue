<script setup>
import { ref, onMounted } from 'vue'
import api from '../../api'
import Swal from 'sweetalert2'

const companies = ref([])
const loading = ref(true)

// Estado do Modal
const isModalOpen = ref(false)
const modalMode = ref('create') // 'create' ou 'edit'
const currentCompanyId = ref(null)

const formData = ref({
  account: { name: '', subscription_status: 'trialing', trial_ends_at: '' },
  user: { first_name: '', last_name: '', email: '', password: '' }
})

const fetchCompanies = async () => {
  try {
    const response = await api.get('/admin/accounts')
    companies.value = response.data
  } catch (error) {
    console.error("Erro ao buscar empresas:", error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchCompanies()
})

const formatDate = (dateString) => {
  if (!dateString) return '-'
  const date = new Date(dateString)
  return new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' }).format(date)
}

const formatStatus = (status) => {
  const map = {
    'active': { text: 'Ativo', class: 'success' },
    'trialing': { text: 'Em Teste', class: 'warning' },
    'past_due': { text: 'Atrasado', class: 'danger' },
    'canceled': { text: 'Cancelado', class: 'danger' },
    'blocked': { text: 'Bloqueado', class: 'danger' },
    'unpaid': { text: 'Inadimplente', class: 'danger' }
  }
  return map[status] || { text: status || 'Desconhecido', class: 'secondary' }
}

const openCreateModal = () => {
  modalMode.value = 'create'
  
  // Calcula data + 7 dias pro trial padrão
  const nextWeek = new Date()
  nextWeek.setDate(nextWeek.getDate() + 7)
  const tzOffset = nextWeek.getTimezoneOffset() * 60000;
  const localISOTime = (new Date(nextWeek - tzOffset)).toISOString().slice(0, -1);

  formData.value = {
    account: { name: '', subscription_status: 'trialing', trial_ends_at: localISOTime.substring(0, 16) },
    user: { first_name: '', last_name: '', email: '', password: '' }
  }
  isModalOpen.value = true
}

const openEditModal = (company) => {
  modalMode.value = 'edit'
  currentCompanyId.value = company.id
  
  // Format trial_ends_at for input datetime-local
  let formattedDate = ''
  if (company.trial_ends_at) {
    const d = new Date(company.trial_ends_at)
    const tzOffset = d.getTimezoneOffset() * 60000;
    formattedDate = (new Date(d - tzOffset)).toISOString().slice(0, 16);
  }

  // Tenta extrair primeiro e ultimo nome do owner_name
  let fName = company.owner_name || ''
  let lName = ''
  if (fName.includes(' ')) {
    const parts = fName.split(' ')
    fName = parts[0]
    lName = parts.slice(1).join(' ')
  }

  formData.value = {
    account: { 
      name: company.name || '', 
      subscription_status: company.subscription_status || 'active', 
      trial_ends_at: formattedDate 
    },
    user: { 
      first_name: fName, 
      last_name: lName, 
      email: company.owner_email || '', 
      password: '' // Vazio, se preencher = altera a senha
    }
  }
  isModalOpen.value = true
}

const closeModal = () => {
  isModalOpen.value = false
}

const saveCompany = async () => {
  try {
    if (modalMode.value === 'create') {
      await api.post('/admin/accounts', formData.value)
      Swal.fire('Criado!', 'A empresa foi criada com sucesso.', 'success')
    } else {
      await api.put(`/admin/accounts/${currentCompanyId.value}`, formData.value)
      Swal.fire('Atualizado!', 'Os dados da empresa foram atualizados.', 'success')
    }
    closeModal()
    fetchCompanies()
  } catch (error) {
    console.error("Erro ao salvar:", error)
    const msg = error.response?.data?.error || 'Verifique os dados e tente novamente.'
    Swal.fire('Erro', msg, 'error')
  }
}

const blockCompany = async (company) => {
  const result = await Swal.fire({
    title: `Bloquear ${company.name}?`,
    text: "Esta empresa não poderá mais acessar o sistema.",
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#ef4444',
    cancelButtonColor: '#64748b',
    confirmButtonText: 'Sim, bloquear!',
    cancelButtonText: 'Cancelar'
  })

  if (result.isConfirmed) {
    try {
      await api.put(`/admin/accounts/${company.id}/block`)
      Swal.fire('Bloqueado!', 'Acesso da empresa foi bloqueado.', 'success')
      fetchCompanies()
    } catch (error) {
      Swal.fire('Erro', 'Não foi possível bloquear a empresa.', 'error')
    }
  }
}

const deleteCompany = async (company) => {
  const result = await Swal.fire({
    title: `Excluir PERMANENTEMENTE ${company.name}?`,
    text: "Todos os contatos, conversas e imóveis dessa empresa serão apagados para sempre. Esta ação não pode ser desfeita!",
    icon: 'error',
    showCancelButton: true,
    confirmButtonColor: '#dc2626',
    cancelButtonColor: '#64748b',
    confirmButtonText: 'EXCLUIR TUDO',
    cancelButtonText: 'Cancelar'
  })

  if (result.isConfirmed) {
    try {
      await api.delete(`/admin/accounts/${company.id}`)
      Swal.fire('Excluído!', 'A empresa foi excluída do banco de dados.', 'success')
      fetchCompanies()
    } catch (error) {
      Swal.fire('Erro', 'Não foi possível excluir a empresa.', 'error')
    }
  }
}
</script>

<template>
  <div class="admin-companies">
    <div class="header-row">
      <h2 class="page-title">Gerenciamento de Empresas</h2>
      <div class="header-actions">
        <button class="btn btn-outline" @click="fetchCompanies">Atualizar Lista</button>
        <button class="btn btn-primary" @click="openCreateModal">+ Nova Empresa</button>
      </div>
    </div>
    
    <div v-if="loading" class="loading">Carregando empresas...</div>
    
    <div v-else class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Nome da Empresa</th>
            <th>Proprietário (E-mail)</th>
            <th>Status do Plano</th>
            <th>Fim do Teste</th>
            <th>Ações</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="company in companies" :key="company.id">
            <td>#{{ company.id }}</td>
            <td class="font-medium">{{ company.name || 'Sem nome' }}</td>
            <td>
              <div class="owner-name">{{ company.owner_name }}</div>
              <div class="owner-email">{{ company.owner_email }}</div>
            </td>
            <td>
              <span class="badge" :class="formatStatus(company.subscription_status).class">
                {{ formatStatus(company.subscription_status).text }}
              </span>
            </td>
            <td>{{ formatDate(company.trial_ends_at) }}</td>
            <td class="actions-cell">
              <button class="action-btn edit-btn" @click="openEditModal(company)" title="Editar Dados">
                Editar
              </button>
              <button class="action-btn block-btn" @click="blockCompany(company)" title="Bloquear Acesso" v-if="company.subscription_status !== 'blocked'">
                Bloquear
              </button>
              <button class="action-btn delete-btn" @click="deleteCompany(company)" title="Excluir Permanentemente">
                Excluir
              </button>
            </td>
          </tr>
          <tr v-if="companies.length === 0">
            <td colspan="6" class="empty-state">Nenhuma empresa encontrada.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal Form -->
    <div v-if="isModalOpen" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <h3 class="modal-title">{{ modalMode === 'create' ? 'Adicionar Nova Empresa' : 'Editar Empresa e Usuário' }}</h3>
        
        <form @submit.prevent="saveCompany" class="admin-form">
          <div class="form-section">
            <h4>Dados da Empresa (SaaS)</h4>
            <div class="form-group">
              <label>Nome da Empresa</label>
              <input type="text" v-model="formData.account.name" required placeholder="Ex: Imobiliária Silva" />
            </div>
            
            <div class="form-row">
              <div class="form-group">
                <label>Status do Plano</label>
                <select v-model="formData.account.subscription_status">
                  <option value="active">Ativo (Pagante)</option>
                  <option value="trialing">Em Teste (Trial)</option>
                  <option value="blocked">Bloqueado</option>
                  <option value="canceled">Cancelado</option>
                  <option value="unpaid">Inadimplente</option>
                </select>
              </div>
              <div class="form-group">
                <label>Limite do Acesso (Trial / Expiração)</label>
                <input type="datetime-local" v-model="formData.account.trial_ends_at" />
              </div>
            </div>
          </div>

          <div class="form-section">
            <h4>Acesso do Proprietário</h4>
            <div class="form-row">
              <div class="form-group">
                <label>Primeiro Nome</label>
                <input type="text" v-model="formData.user.first_name" required placeholder="João" />
              </div>
              <div class="form-group">
                <label>Sobrenome</label>
                <input type="text" v-model="formData.user.last_name" placeholder="Silva" />
              </div>
            </div>

            <div class="form-group">
              <label>E-mail de Login</label>
              <input type="email" v-model="formData.user.email" required placeholder="joao@imobiliaria.com" />
            </div>

            <div class="form-group">
              <label>Senha de Acesso</label>
              <input type="text" v-model="formData.user.password" :required="modalMode === 'create'" :placeholder="modalMode === 'create' ? 'Digite uma senha' : '(Deixe em branco para manter a atual)'" />
              <small v-if="modalMode === 'edit'" class="help-text">Somente preencha se quiser forçar a troca da senha do cliente.</small>
            </div>
          </div>

          <div class="modal-actions">
            <button type="button" class="btn btn-outline" @click="closeModal">Cancelar</button>
            <button type="submit" class="btn btn-primary">Salvar Mudanças</button>
          </div>
        </form>
      </div>
    </div>

  </div>
</template>

<style scoped lang="scss">
.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  
  .page-title {
    font-size: 1.1rem;
    font-weight: 600;
    color: #1e293b;
    margin: 0;
  }

  .header-actions {
    display: flex;
    gap: 1rem;
  }
}

.table-container {
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
  border: 1px solid #e2e8f0;
  overflow: hidden;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  
  th, td {
    padding: 0.8rem 1rem;
    text-align: left;
    border-bottom: 1px solid #f1f5f9;
  }
  
  th {
    background-color: #f8fafc;
    font-size: 0.75rem;
    font-weight: 600;
    color: #64748b;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  
  td {
    font-size: 0.85rem;
    color: #334155;
    vertical-align: middle;
  }

  .font-medium {
    font-weight: 500;
    color: #0f172a;
  }
  
  .owner-name {
    font-weight: 500;
  }
  
  .owner-email {
    font-size: 0.75rem;
    color: #64748b;
  }

  .badge {
    padding: 0.2rem 0.6rem;
    border-radius: 9999px;
    font-size: 0.7rem;
    font-weight: 600;
    
    &.success { background: #dcfce7; color: #166534; }
    &.warning { background: #fef9c3; color: #854d0e; }
    &.danger { background: #fee2e2; color: #991b1b; }
    &.secondary { background: #f1f5f9; color: #475569; }
  }

  .actions-cell {
    display: flex;
    gap: 0.5rem;
  }

  .action-btn {
    padding: 0.3rem 0.6rem;
    border-radius: 6px;
    font-size: 0.75rem;
    font-weight: 500;
    cursor: pointer;
    border: 1px solid transparent;
    transition: all 0.2s;
    
    &.edit-btn {
      background: #f1f5f9;
      color: #3b82f6;
      border-color: #e2e8f0;
      &:hover { background: #e2e8f0; }
    }

    &.block-btn {
      background: #fffbeb;
      color: #b45309;
      border-color: #fde68a;
      &:hover { background: #fef3c7; }
    }
    
    &.delete-btn {
      background: #fef2f2;
      color: #b91c1c;
      border-color: #fecaca;
      &:hover { background: #fee2e2; }
    }
  }

  .empty-state {
    text-align: center;
    padding: 3rem;
    color: #64748b;
  }
}

.btn-primary {
  background: #38bdf8;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.85rem;
  font-weight: 500;
  cursor: pointer;
  
  &:hover { background: #0ea5e9; }
}

.btn-outline {
  background: white;
  color: #64748b;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.85rem;
  font-weight: 500;
  cursor: pointer;
  
  &:hover { background: #f8fafc; color: #0f172a; }
}

/* Modal Styles */
.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(15, 23, 42, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
  backdrop-filter: blur(2px);
}

.modal-content {
  background: white;
  width: 100%;
  max-width: 600px;
  border-radius: 12px;
  padding: 2rem;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  max-height: 90vh;
  overflow-y: auto;
  
  .modal-title {
    font-size: 1.25rem;
    font-weight: 600;
    color: #0f172a;
    margin-top: 0;
    margin-bottom: 1.5rem;
  }
}

.admin-form {
  .form-section {
    margin-bottom: 2rem;
    padding-bottom: 1.5rem;
    border-bottom: 1px solid #e2e8f0;
    
    h4 {
      font-size: 0.95rem;
      color: #334155;
      margin-bottom: 1rem;
      font-weight: 600;
    }
  }

  .form-row {
    display: flex;
    gap: 1rem;
    
    .form-group { flex: 1; }
  }

  .form-group {
    margin-bottom: 1rem;
    
    label {
      display: block;
      font-size: 0.85rem;
      font-weight: 500;
      color: #475569;
      margin-bottom: 0.4rem;
    }
    
    input, select {
      width: 100%;
      box-sizing: border-box;
      padding: 0.6rem;
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      font-size: 0.9rem;
      
      &:focus {
        outline: none;
        border-color: #38bdf8;
        box-shadow: 0 0 0 2px rgba(56, 189, 248, 0.2);
      }
    }

    .help-text {
      display: block;
      font-size: 0.75rem;
      color: #94a3b8;
      margin-top: 0.3rem;
    }
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
    margin-top: 1rem;
  }
}
</style>
