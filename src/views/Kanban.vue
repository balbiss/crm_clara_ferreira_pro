<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { Plus, MoreHorizontal, User, Phone, X, AlertCircle } from '@lucide/vue'
import api from '../api'
import Swal from 'sweetalert2'
import { useConversationsStore } from '../store/conversations'
import { useContactsStore } from '../store/contacts'

const columns = ref([
  { id: 'lead', name: 'Novos Leads', color: '#3b82f6', cards: [] },
  { id: 'visit', name: 'Visita Agendada', color: '#f59e0b', cards: [] },
  { id: 'proposal', name: 'Proposta Feita', color: '#8b5cf6', cards: [] },
  { id: 'won', name: 'Negócio Fechado', color: '#10b981', cards: [] }
])

const isLoading = ref(true)
const showModal = ref(false)
const targetColumnId = ref('lead')
const store = useConversationsStore()
const contactsStore = useContactsStore()

const newContact = ref({
  first_name: '',
  last_name: '',
  email: '',
  phone: '',
  intention: 'Venda',
  temperature: 'Quente',
  source: 'WhatsApp API'
})

const distributeContacts = (contacts) => {
  columns.value.forEach(col => { col.cards = [] })
  contacts.forEach(contact => {
    const status = contact.status || 'lead'
    const targetCol = columns.value.find(c => c.id === status) || columns.value[0]
    targetCol.cards.push({
      id: contact.id,
      title: `${contact.first_name || contact.name || ''} ${contact.last_name || ''}`.trim(),
      subtitle: contact.intention ? (contact.intention.startsWith('Visita:') ? contact.intention : `Intenção: ${contact.intention}`) : 'Sem pretensão definida',
      phone: contact.phone || 'Sem telefone',
      temperature: contact.temperature || 'Morno',
      raw: contact
    })
  })
}

const fetchContacts = async (showLoading = true) => {
  if (showLoading) isLoading.value = true
  try {
    if (contactsStore.isLoadedOnce) {
      distributeContacts(contactsStore.contacts)
    } else {
      await contactsStore.fetchContacts()
      distributeContacts(contactsStore.contacts)
    }
  } catch (error) {
    console.error('Error fetching contacts for Kanban:', error)
  } finally {
    if (showLoading) isLoading.value = false
  }
}

const colors = [
  { bg: '#dbeafe', color: '#1e40af' }, // Blue
  { bg: '#d1fae5', color: '#065f46' }, // Green
  { bg: '#fee2e2', color: '#991b1b' }, // Red
  { bg: '#fef3c7', color: '#92400e' }, // Yellow
  { bg: '#f3e8ff', color: '#6b21a8' }  // Purple
]

const getAvatarStyle = (name) => {
  if (!name) return { backgroundColor: '#e5e7eb', color: '#4b5563' }
  const index = name.charCodeAt(0) % colors.length
  return {
    backgroundColor: colors[index].bg,
    color: colors[index].color
  }
}

const handleContactUpdated = () => {
  fetchContacts(false) // Atualiza em background sem mostrar tela de carregamento
}

const closeMoveMenuOnOutsideClick = (event) => {
  if (!event.target.closest('.move-menu-wrapper')) {
    openMoveMenuCardId.value = null
  }
}

onMounted(() => {
  store.setupWebSocket() // Garante que o websocket está conectado
  fetchContacts()
  window.addEventListener('contact-updated', handleContactUpdated)
  document.addEventListener('click', closeMoveMenuOnOutsideClick)
})

onUnmounted(() => {
  window.removeEventListener('contact-updated', handleContactUpdated)
  document.removeEventListener('click', closeMoveMenuOnOutsideClick)
})

// Drag and Drop Logic
const draggedCard = ref(null)
const activeColumnDrag = ref(null)

const dragCard = (event, card) => {
  draggedCard.value = card
  event.dataTransfer.effectAllowed = 'move'
}

const moveCardToStage = async (card, columnId) => {
  const oldStatus = card.raw.status || 'lead'
  if (oldStatus === columnId) return

  // Optimistic update
  const sourceCol = columns.value.find(c => c.id === oldStatus)
  const targetCol = columns.value.find(c => c.id === columnId)

  if (sourceCol && targetCol) {
    sourceCol.cards = sourceCol.cards.filter(c => c.id !== card.id)
    card.raw.status = columnId
    targetCol.cards.push(card)
  }

  try {
    await api.put(`/contacts/${card.id}`, {
      contact: {
        status: columnId
      }
    })
  } catch (error) {
    console.error('Error updating contact status:', error)
    Swal.fire({
      icon: 'error',
      title: 'Erro',
      text: 'Não foi possível salvar o novo status no servidor.',
      confirmButtonColor: '#1f93ff'
    })
    fetchContacts()
  }
}

// Menu "Mover para..." — fallback pra touch, onde o drag-and-drop nativo nao funciona
const openMoveMenuCardId = ref(null)

const toggleMoveMenu = (cardId) => {
  openMoveMenuCardId.value = openMoveMenuCardId.value === cardId ? null : cardId
}

const moveCardViaMenu = async (card, columnId) => {
  openMoveMenuCardId.value = null
  await moveCardToStage(card, columnId)
}

const dropCard = async (event, columnId) => {
  activeColumnDrag.value = null
  if (!draggedCard.value) return

  const card = draggedCard.value
  try {
    await moveCardToStage(card, columnId)
  } finally {
    draggedCard.value = null
  }
}

const openCreateModal = (columnId) => {
  targetColumnId.value = columnId
  showModal.value = true
}

const handleCreateContact = async () => {
  if (!newContact.value.first_name) {
    Swal.fire({
      icon: 'warning',
      title: 'Atenção',
      text: 'O nome é obrigatório!',
      confirmButtonColor: '#1f93ff'
    })
    return
  }

  try {
    const user = JSON.parse(localStorage.getItem('user'))
    const account_id = user ? user.account_id : null

    await api.post('/contacts', {
      contact: {
        first_name: newContact.value.first_name,
        last_name: newContact.value.last_name,
        name: `${newContact.value.first_name} ${newContact.value.last_name}`.trim(),
        email: newContact.value.email,
        phone: newContact.value.phone,
        intention: newContact.value.intention,
        temperature: newContact.value.temperature,
        source: newContact.value.source,
        status: targetColumnId.value,
        account_id: account_id
      }
    })

    Swal.fire({
      icon: 'success',
      title: 'Lead Criado',
      text: 'Contato adicionado ao funil!',
      timer: 1500,
      showConfirmButton: false
    })

    showModal.value = false
    newContact.value = {
      first_name: '',
      last_name: '',
      email: '',
      phone: '',
      intention: 'Venda',
      temperature: 'Quente',
      source: 'WhatsApp API'
    }
    fetchContacts()
  } catch (error) {
    console.error('Error creating contact from Kanban:', error)
    Swal.fire({
      icon: 'error',
      title: 'Erro',
      text: 'Não foi possível adicionar o contato.'
    })
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div>
        <h1>Funil de Vendas</h1>
        <p class="subtitle">Acompanhe e movimente o progresso das suas negociações</p>
      </div>
      <button class="btn-primary" @click="openCreateModal('lead')"><Plus class="icon-sm" /> Novo Negócio</button>
    </div>

    <div class="kanban-board" v-if="!isLoading">
      <div 
        class="kanban-column" 
        v-for="col in columns" 
        :key="col.id"
        :class="{ 'column-drag-over': activeColumnDrag === col.id }"
        :style="{ borderTop: `3px solid ${col.color}` }"
        @dragover.prevent="activeColumnDrag = col.id"
        @dragleave="activeColumnDrag = null"
        @drop="dropCard($event, col.id)"
      >
        <div class="column-header">
          <div class="header-left">
            <h3>{{ col.name }}</h3>
            <span class="count">{{ col.cards.length }}</span>
          </div>
          <button class="icon-btn" @click="openCreateModal(col.id)"><Plus class="icon-sm" /></button>
        </div>

        <div class="column-content">
          <div 
            class="kanban-card" 
            v-for="card in col.cards" 
            :key="card.id"
            draggable="true"
            @dragstart="dragCard($event, card)"
            @click="$router.push(`/contatos/${card.id}`)"
          >
            <div class="card-header">
              <h4>{{ card.title }}</h4>
              <div class="move-menu-wrapper">
                <button class="icon-btn-sm" @click.stop="toggleMoveMenu(card.id)"><MoreHorizontal class="icon-sm" /></button>
                <div v-if="openMoveMenuCardId === card.id" class="move-menu" @click.stop>
                  <div class="move-menu-title">Mover para...</div>
                  <button
                    v-for="target in columns.filter(c => c.id !== col.id)"
                    :key="target.id"
                    class="move-menu-item"
                    @click="moveCardViaMenu(card, target.id)"
                  >
                    {{ target.name }}
                  </button>
                </div>
              </div>
            </div>
            <p class="card-subtitle">{{ card.subtitle }}</p>

            <div class="card-details">
              <span class="phone-info"><Phone class="icon-xs" /> {{ card.phone }}</span>
              <span class="temp-badge" :class="card.temperature.toLowerCase()">{{ card.temperature }}</span>
            </div>

            <div class="card-footer">
              <div class="avatar-sm" :style="getAvatarStyle(card.title)">{{ card.title.substring(0,2).toUpperCase() }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="loading-state">
      Carregando Funil de Vendas...
    </div>

    <!-- Modal de Cadastro Rápido de Contato/Lead -->
    <div v-if="showModal" class="modal-backdrop" @click.self="showModal = false">
      <div class="modal-card">
        <div class="modal-header">
          <h3>Adicionar Lead ao Funil</h3>
          <button class="close-btn" @click="showModal = false"><X class="icon-sm" /></button>
        </div>
        <form @submit.prevent="handleCreateContact" class="modal-form">
          <div class="form-row">
            <div class="form-group">
              <label for="first_name">Nome</label>
              <input type="text" id="first_name" v-model="newContact.first_name" placeholder="Ex: João" required />
            </div>
            <div class="form-group">
              <label for="last_name">Sobrenome</label>
              <input type="text" id="last_name" v-model="newContact.last_name" placeholder="Ex: Silva" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label for="email">E-mail</label>
              <input type="email" id="email" v-model="newContact.email" placeholder="joao@email.com" />
            </div>
            <div class="form-group">
              <label for="phone">Telefone</label>
              <input type="text" id="phone" v-model="newContact.phone" placeholder="+55 11 99999-9999" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label for="intention">Pretensão</label>
              <select id="intention" v-model="newContact.intention">
                <option value="Venda">Compra / Venda</option>
                <option value="Locação">Locação</option>
              </select>
            </div>
            <div class="form-group">
              <label for="temperature">Temperatura</label>
              <select id="temperature" v-model="newContact.temperature">
                <option value="Quente">Quente 🔥</option>
                <option value="Morno">Morno ☕</option>
                <option value="Frio">Frio ❄️</option>
              </select>
            </div>
          </div>
          <div class="form-group">
            <label for="source">Mídia de Origem</label>
            <select id="source" v-model="newContact.source">
              <option value="WhatsApp API">WhatsApp API</option>
              <option value="Facebook">Facebook</option>
              <option value="Instagram">Instagram</option>
              <option value="Portal Imobiliário">Portal Imobiliário</option>
              <option value="Indicação">Indicação</option>
            </select>
          </div>
          <div class="modal-actions">
            <button type="button" class="btn-cancel" @click="showModal = false">Cancelar</button>
            <button type="submit" class="btn-submit">Criar Lead</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 1.5rem 2rem;
  background: var(--bg-primary);
  overflow: hidden;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-bottom: 1.5rem;
  flex-shrink: 0;

  h1 {
    font-size: 1.5rem;
    font-weight: 600;
    color: var(--text-main);
  }
  
  .subtitle {
    color: var(--text-muted);
    font-size: 0.9rem;
    margin-top: 0.2rem;
  }
}

.btn-primary {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: var(--primary);
  color: white;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: none;
  font-weight: 500;
  cursor: pointer;
  
  &:hover { background: var(--primary-hover); }
}

.kanban-board {
  display: flex;
  gap: 0.75rem;
  overflow-x: auto;
  flex: 1;
  padding-bottom: 1rem;
  
  &::-webkit-scrollbar { height: 6px; }
  &::-webkit-scrollbar-track { background: transparent; }
  &::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 10px; }
  &::-webkit-scrollbar-thumb:hover { background: #94a3b8; }
}

.kanban-column {
  width: 270px;
  min-width: 270px;
  display: flex;
  flex-direction: column;
  background: #f4f5f7;
  border-radius: 6px;
  max-height: 100%;
  transition: background-color 0.2s, box-shadow 0.2s;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);

  &.column-drag-over {
    background-color: #ebecf0;
    box-shadow: 0 0 0 2px var(--primary) inset;
  }
}

.column-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 0.75rem 0.5rem;

  .header-left {
    display: flex;
    align-items: center;
    gap: 0.4rem;

    h3 {
      font-size: 0.85rem;
      font-weight: 700;
      color: #172b4d;
    }

    .count {
      background: #e1e4e8;
      color: #5e6c84;
      padding: 0.1rem 0.4rem;
      border-radius: 10px;
      font-size: 0.7rem;
      font-weight: 700;
    }
  }
}

.column-content {
  flex: 1;
  overflow-y: auto;
  padding: 0.5rem 0.75rem 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  
  &::-webkit-scrollbar { width: 4px; }
  &::-webkit-scrollbar-track { background: transparent; }
  &::-webkit-scrollbar-thumb { background: #d1d5db; border-radius: 10px; }
  &::-webkit-scrollbar-thumb:hover { background: #9ca3af; }
}

.kanban-card {
  background: #ffffff;
  border-radius: 6px;
  padding: 0.75rem;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
  border: 1px solid rgba(0,0,0,0.05);
  cursor: grab;
  transition: all 0.15s ease-in-out;

  &:hover {
    box-shadow: 0 3px 6px rgba(0, 0, 0, 0.08);
    transform: translateY(-1px);
  }

  &:active {
    cursor: grabbing;
    transform: scale(0.98);
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    
    h4 {
      font-size: 0.85rem;
      font-weight: 700;
      color: #111827;
      margin-bottom: 0.2rem;
      line-height: 1.2;
    }
  }

  .card-subtitle {
    font-size: 0.75rem;
    color: #4b5563;
    margin-bottom: 0.5rem;
    line-height: 1.3;
    font-weight: 500;
  }

  .card-details {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;

    .phone-info {
      font-size: 0.7rem;
      color: #6b7280;
      display: flex;
      align-items: center;
      gap: 0.2rem;
      font-weight: 500;
    }

    .temp-badge {
      font-size: 0.6rem;
      font-weight: 700;
      padding: 0.1rem 0.3rem;
      border-radius: 12px;
      text-transform: uppercase;
      letter-spacing: 0.02em;

      &.quente { background: #fee2e2; color: #b91c1c; }
      &.morno { background: #fef3c7; color: #b45309; }
      &.frio { background: #e0f2fe; color: #0369a1; }
    }
  }

  .card-footer {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    border-top: 1px solid #f3f4f6;
    padding-top: 0.4rem;

    .avatar-sm {
      width: 20px;
      height: 20px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.6rem;
      font-weight: 700;
    }
  }
}

.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 12px; height: 12px; }

.icon-btn, .icon-btn-sm {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--text-muted);
  display: flex;
  align-items: center;
  justify-content: center;

  &:hover { color: var(--text-main); }
}

.move-menu-wrapper {
  position: relative;
}

.move-menu {
  position: absolute;
  top: calc(100% + 4px);
  right: 0;
  background: white;
  border: 1px solid rgba(0,0,0,0.08);
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.15);
  min-width: 180px;
  max-width: calc(100vw - 3rem);
  z-index: 50;
  padding: 0.35rem 0;
  display: flex;
  flex-direction: column;
}

.move-menu-title {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #9ca3af;
  padding: 0.3rem 0.9rem 0.4rem;
}

.move-menu-item {
  background: none;
  border: none;
  text-align: left;
  padding: 0.5rem 0.9rem;
  font-size: 0.82rem;
  color: #1f2937;
  cursor: pointer;

  &:hover { background: rgba(0,0,0,0.04); }
}

.loading-state {
  text-align: center;
  padding: 5rem;
  color: var(--text-muted);
}

/* Modal Styling */
.modal-backdrop {
  position: fixed;
  top: 0; left: 0;
  width: 100vw; height: 100vh;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  width: 100%;
  max-width: 500px;
  box-shadow: 0 20px 25px -5px var(--shadow-color), 0 10px 10px -5px var(--shadow-sm);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-color);
  background: var(--bg-tertiary);

  h3 {
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--text-main);
  }

  .close-btn {
    background: transparent;
    border: none;
    color: var(--text-muted);
    cursor: pointer;
    &:hover { color: var(--text-main); }
  }
}

.modal-form {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;

  label {
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text-main);
  }

  input, select {
    padding: 0.65rem 0.75rem;
    border: 1px solid var(--border-color);
    background: var(--bg-primary);
    color: var(--text-main);
    border-radius: 6px;
    font-size: 0.9rem;
    outline: none;
    &:focus {
      border-color: var(--primary);
    }
  }
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  margin-top: 1rem;

  .btn-cancel {
    background: var(--bg-tertiary);
    color: var(--text-main);
    border: 1px solid var(--border-color);
    padding: 0.5rem 1rem;
    border-radius: 6px;
    font-weight: 500;
    cursor: pointer;
    &:hover { background: var(--bg-hover); }
  }

  .btn-submit {
    background: var(--primary);
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    font-weight: 500;
    cursor: pointer;
    &:hover { background: var(--primary-hover); }
  }
}
</style>
style>
