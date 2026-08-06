<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { Plus, MoreHorizontal, Phone, X, Search, ListFilter, Zap, ArrowUpDown, Menu as MenuIcon } from '@lucide/vue'
import api from '../api'
import Swal from 'sweetalert2'
import { useConversationsStore } from '../store/conversations'
import { useContactsStore } from '../store/contacts'

// Régua da revenda consignada (briefing seção 12) — nomes e checklists batem com o que a
// Clara Ferreira já usa no Kommo, só a lógica automática de mover etapa é que muda depois.
const columns = ref([
  {
    id: 'revendedor_ativo',
    name: 'REVENDEDOR ATIVO',
    checklist: null,
    cards: []
  },
  {
    id: 'terceiro_dia',
    name: '3° DIA',
    checklist: ['Mensagem de incentivo', 'Perguntar se conseguiu ver o catálogo', 'Instruir compartilhar as fotos'],
    cards: []
  },
  {
    id: 'decimo_dia',
    name: '10° DIA',
    checklist: ['Mensagem de incentivo', 'Perguntar como estão as vendas', 'Lembrar do prazo'],
    cards: []
  },
  {
    id: 'vigesimo_dia',
    name: '20° DIA',
    checklist: ['Agendar o acerto', 'Incentivar a vender mais até o último dia', 'Pegar encomendas para o próximo mês'],
    cards: []
  },
  {
    id: 'agendado',
    name: 'AGENDADO',
    checklist: null,
    note: 'Lembrar de incluir a Data de Agendamento na Revendedora ao movê-la para esta etapa. Depois de feito o acerto, mover a Revendedora para Revendedor Ativo e incluir a Data do Último Acerto.',
    cards: []
  }
])

const isLoading = ref(true)
const showModal = ref(false)
const targetColumnId = ref('revendedor_ativo')
const searchQuery = ref('')
const store = useConversationsStore()
const contactsStore = useContactsStore()

const newContact = ref({
  first_name: '',
  last_name: '',
  email: '',
  phone: ''
})

const distributeContacts = (contacts) => {
  columns.value.forEach(col => { col.cards = [] })
  contacts.forEach(contact => {
    if (searchQuery.value && !`${contact.first_name} ${contact.last_name} ${contact.name || ''}`.toLowerCase().includes(searchQuery.value.toLowerCase())) return
    const status = contact.status || 'revendedor_ativo'
    const targetCol = columns.value.find(c => c.id === status) || columns.value[0]
    targetCol.cards.push({
      id: contact.id,
      title: `${contact.first_name || contact.name || ''} ${contact.last_name || ''}`.trim(),
      phone: contact.phone || 'Sem telefone',
      venda: parseFloat(contact.custom_attributes?.venda) || 0,
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

const totalLeads = computed(() => columns.value.reduce((s, c) => s + c.cards.length, 0))
const totalValor = computed(() => columns.value.reduce((s, c) => s + c.cards.reduce((cs, card) => cs + card.venda, 0), 0))
const brl = (v) => v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
const columnTotal = (col) => col.cards.reduce((s, c) => s + c.venda, 0)

const colors = [
  { bg: '#ffd9ec', color: '#a80050' },
  { bg: '#d1fae5', color: '#065f46' },
  { bg: '#fee2e2', color: '#991b1b' },
  { bg: '#fef3c7', color: '#92400e' },
  { bg: '#f3e8ff', color: '#6b21a8' }
]

const getAvatarStyle = (name) => {
  if (!name) return { backgroundColor: '#e5e7eb', color: '#4b5563' }
  const index = name.charCodeAt(0) % colors.length
  return { backgroundColor: colors[index].bg, color: colors[index].color }
}

const handleContactUpdated = () => fetchContacts(false)

const closeMoveMenuOnOutsideClick = (event) => {
  if (!event.target.closest('.move-menu-wrapper')) openMoveMenuCardId.value = null
}

onMounted(() => {
  store.setupWebSocket()
  fetchContacts()
  window.addEventListener('contact-updated', handleContactUpdated)
  document.addEventListener('click', closeMoveMenuOnOutsideClick)
})

onUnmounted(() => {
  window.removeEventListener('contact-updated', handleContactUpdated)
  document.removeEventListener('click', closeMoveMenuOnOutsideClick)
})

// Drag and Drop
const draggedCard = ref(null)
const activeColumnDrag = ref(null)

const dragCard = (event, card) => {
  draggedCard.value = card
  event.dataTransfer.effectAllowed = 'move'
}

const moveCardToStage = async (card, columnId) => {
  const oldStatus = card.raw.status || 'revendedor_ativo'
  if (oldStatus === columnId) return

  const sourceCol = columns.value.find(c => c.id === oldStatus)
  const targetCol = columns.value.find(c => c.id === columnId)
  if (sourceCol && targetCol) {
    sourceCol.cards = sourceCol.cards.filter(c => c.id !== card.id)
    card.raw.status = columnId
    targetCol.cards.push(card)
  }

  try {
    await api.put(`/contacts/${card.id}`, { contact: { status: columnId } })
  } catch (error) {
    console.error('Error updating contact status:', error)
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível salvar o novo status no servidor.', confirmButtonColor: '#d49ba7' })
    fetchContacts()
  }
}

const openMoveMenuCardId = ref(null)
const toggleMoveMenu = (cardId) => { openMoveMenuCardId.value = openMoveMenuCardId.value === cardId ? null : cardId }
const moveCardViaMenu = async (card, columnId) => { openMoveMenuCardId.value = null; await moveCardToStage(card, columnId) }

const dropCard = async (event, columnId) => {
  activeColumnDrag.value = null
  if (!draggedCard.value) return
  const card = draggedCard.value
  try { await moveCardToStage(card, columnId) } finally { draggedCard.value = null }
}

const openCreateModal = (columnId) => { targetColumnId.value = columnId; showModal.value = true }

const handleCreateContact = async () => {
  if (!newContact.value.first_name) {
    Swal.fire({ icon: 'warning', title: 'Atenção', text: 'O nome é obrigatório!', confirmButtonColor: '#d49ba7' })
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
        status: targetColumnId.value,
        account_id: account_id
      }
    })
    Swal.fire({ icon: 'success', title: 'Lead criado', text: 'Revendedora adicionada ao pipeline!', timer: 1500, showConfirmButton: false })
    showModal.value = false
    newContact.value = { first_name: '', last_name: '', email: '', phone: '' }
    fetchContacts()
  } catch (error) {
    console.error('Error creating contact from Kanban:', error)
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível adicionar o contato.' })
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-left">
        <h1>CONSIGNADO</h1>
        <button class="icon-btn" title="Ordenar"><ArrowUpDown class="icon-sm" /></button>
        <button class="icon-btn" title="Ver como lista"><MenuIcon class="icon-sm" /></button>
      </div>
      <div class="header-search">
        <Search class="icon-sm" />
        <input v-model="searchQuery" @input="distributeContacts(contactsStore.contacts)" type="text" placeholder="Pesquisar e filtrar" />
      </div>
      <div class="header-right">
        <span class="board-total">{{ totalLeads }} revendedoras: {{ brl(totalValor) }}</span>
        <button class="btn-secondary" @click="$router.push('/funil/automatize')"><Zap class="icon-sm" /> Automatize</button>
        <button class="btn-primary" @click="openCreateModal('revendedor_ativo')"><Plus class="icon-sm" /> Nova Revendedora</button>
      </div>
    </div>

    <div class="kanban-board" v-if="!isLoading">
      <div
        class="kanban-column"
        v-for="col in columns"
        :key="col.id"
        :class="{ 'column-drag-over': activeColumnDrag === col.id }"
        @dragover.prevent="activeColumnDrag = col.id"
        @dragleave="activeColumnDrag = null"
        @drop="dropCard($event, col.id)"
      >
        <div class="column-header">
          <div class="header-left">
            <h3>{{ col.name }}</h3>
          </div>
          <button class="icon-btn" @click="openCreateModal(col.id)"><Plus class="icon-sm" /></button>
        </div>
        <div class="column-totals">{{ col.cards.length }} leads: {{ brl(columnTotal(col)) }}</div>

        <div v-if="col.checklist" class="column-checklist">
          <p class="checklist-title">Check-list de {{ col.name.toLowerCase() }}:</p>
          <ul>
            <li v-for="item in col.checklist" :key="item">{{ item }}</li>
          </ul>
        </div>
        <div v-if="col.note" class="column-note">{{ col.note }}</div>

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
              <div class="avatar-sm" :style="getAvatarStyle(card.title)">{{ card.title.substring(0,2).toUpperCase() }}</div>
              <h4>{{ card.title }}</h4>
              <div class="move-menu-wrapper">
                <button class="icon-btn-sm" @click.stop="toggleMoveMenu(card.id)"><MoreHorizontal class="icon-sm" /></button>
                <div v-if="openMoveMenuCardId === card.id" class="move-menu" @click.stop>
                  <div class="move-menu-title">Mover para...</div>
                  <button v-for="target in columns.filter(c => c.id !== col.id)" :key="target.id" class="move-menu-item" @click="moveCardViaMenu(card, target.id)">
                    {{ target.name }}
                  </button>
                </div>
              </div>
            </div>

            <div class="card-tags">
              <span class="tag tag-consignado">CONSIGNADO</span>
              <span class="tag tag-revendedora">REVENDEDORA ATIVA</span>
            </div>

            <div class="card-details">
              <span class="phone-info"><Phone class="icon-xs" /> {{ card.phone }}</span>
              <span v-if="card.venda > 0" class="venda-info">{{ brl(card.venda) }}</span>
            </div>
          </div>
          <p v-if="col.cards.length === 0" class="empty-column">Nenhum lead nessa etapa.</p>
        </div>
      </div>
    </div>

    <div v-else class="loading-state">Carregando pipeline Consignado...</div>

    <!-- Modal de Cadastro Rápido -->
    <div v-if="showModal" class="modal-backdrop" @click.self="showModal = false">
      <div class="modal-card">
        <div class="modal-header">
          <h3>Adicionar Revendedora ao Pipeline</h3>
          <button class="close-btn" @click="showModal = false"><X class="icon-sm" /></button>
        </div>
        <form @submit.prevent="handleCreateContact" class="modal-form">
          <div class="form-row">
            <div class="form-group">
              <label for="first_name">Nome</label>
              <input type="text" id="first_name" v-model="newContact.first_name" placeholder="Ex: Amanda" required />
            </div>
            <div class="form-group">
              <label for="last_name">Sobrenome</label>
              <input type="text" id="last_name" v-model="newContact.last_name" placeholder="Ex: Rocha" />
            </div>
          </div>
          <div class="form-row">
            <div class="form-group">
              <label for="email">E-mail</label>
              <input type="email" id="email" v-model="newContact.email" placeholder="amanda@email.com" />
            </div>
            <div class="form-group">
              <label for="phone">Telefone</label>
              <input type="text" id="phone" v-model="newContact.phone" placeholder="+55 11 99999-9999" />
            </div>
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
  padding: 1rem 1.5rem;
  background: var(--bg-primary);
  overflow: hidden;
}

.page-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1rem;
  flex-shrink: 0;
  flex-wrap: wrap;

  .header-left {
    display: flex;
    align-items: center;
    gap: 0.4rem;

    h1 {
      font-size: 1.15rem;
      font-weight: 700;
      color: var(--text-main);
      letter-spacing: 0.02em;
    }
  }

  .header-search {
    flex: 1;
    min-width: 200px;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background: var(--bg-tertiary);
    padding: 0.45rem 0.75rem;
    border-radius: 8px;
    color: var(--text-muted);

    input {
      flex: 1;
      background: none;
      border: none;
      outline: none;
      font-size: 0.85rem;
      color: var(--text-main);
    }
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 0.6rem;

    .board-total {
      font-size: 0.8rem;
      font-weight: 600;
      color: var(--text-muted);
      white-space: nowrap;
    }
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
  font-weight: 600;
  font-size: 0.85rem;
  cursor: pointer;
  white-space: nowrap;
  &:hover { background: var(--primary-hover); }
}

.btn-secondary {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: var(--bg-tertiary);
  color: var(--text-main);
  padding: 0.5rem 0.9rem;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  font-weight: 600;
  font-size: 0.85rem;
  cursor: pointer;
  white-space: nowrap;
  &:hover { background: var(--bg-hover); }
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
  width: 280px;
  min-width: 280px;
  display: flex;
  flex-direction: column;
  background: var(--bg-tertiary, #f4f5f7);
  border-radius: 10px;
  max-height: 100%;
  transition: background-color 0.2s, box-shadow 0.2s;
  box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
  border-top: 3px solid var(--primary);

  &.column-drag-over {
    box-shadow: 0 0 0 2px var(--primary) inset;
  }
}

.column-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 0.75rem 0.2rem;

  h3 {
    font-size: 0.78rem;
    font-weight: 800;
    color: var(--text-main);
    letter-spacing: 0.03em;
  }
}

.column-totals {
  padding: 0 0.75rem 0.5rem;
  font-size: 0.7rem;
  font-weight: 600;
  color: var(--text-muted);
}

.column-checklist {
  margin: 0 0.75rem 0.6rem;
  padding: 0.6rem 0.7rem;
  background: var(--bg-secondary, #fff);
  border-radius: 8px;
  border: 1px dashed var(--border-color);

  .checklist-title {
    font-size: 0.7rem;
    font-weight: 700;
    color: var(--text-main);
    margin-bottom: 0.3rem;
  }

  ul {
    margin: 0;
    padding-left: 1rem;
    font-size: 0.7rem;
    color: var(--text-muted);
    line-height: 1.5;
  }
}

.column-note {
  margin: 0 0.75rem 0.6rem;
  padding: 0.6rem 0.7rem;
  background: var(--bg-secondary, #fff);
  border-radius: 8px;
  border: 1px dashed var(--border-color);
  font-size: 0.68rem;
  color: var(--text-muted);
  line-height: 1.5;
}

.column-content {
  flex: 1;
  overflow-y: auto;
  padding: 0.25rem 0.75rem 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;

  &::-webkit-scrollbar { width: 4px; }
  &::-webkit-scrollbar-track { background: transparent; }
  &::-webkit-scrollbar-thumb { background: #d1d5db; border-radius: 10px; }
  &::-webkit-scrollbar-thumb:hover { background: #9ca3af; }
}

.empty-column {
  font-size: 0.75rem;
  color: var(--text-muted);
  text-align: center;
  padding: 1.5rem 0.5rem;
}

.kanban-card {
  background: var(--bg-secondary, #fff);
  border-radius: 10px;
  padding: 0.7rem 0.75rem;
  box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
  border: 1px solid rgba(0,0,0,0.05);
  cursor: grab;
  transition: all 0.15s ease-in-out;

  &:hover {
    box-shadow: 0 3px 6px rgba(0, 0, 0, 0.08);
    transform: translateY(-1px);
  }
  &:active { cursor: grabbing; transform: scale(0.98); }

  .card-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;

    h4 {
      flex: 1;
      font-size: 0.82rem;
      font-weight: 700;
      color: var(--text-main);
      line-height: 1.2;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .avatar-sm {
      width: 26px;
      height: 26px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.65rem;
      font-weight: 700;
      flex-shrink: 0;
    }
  }

  .card-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.3rem;
    margin: 0.4rem 0;

    .tag {
      font-size: 0.6rem;
      font-weight: 700;
      padding: 0.15rem 0.4rem;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 0.02em;
    }
    .tag-consignado { background: #ffd9ec; color: #a80050; }
    .tag-revendedora { background: #d1fae5; color: #065f46; }
  }

  .card-details {
    display: flex;
    justify-content: space-between;
    align-items: center;

    .phone-info {
      font-size: 0.68rem;
      color: var(--text-muted);
      display: flex;
      align-items: center;
      gap: 0.2rem;
      font-weight: 500;
    }

    .venda-info {
      font-size: 0.7rem;
      font-weight: 700;
      color: var(--primary);
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

.move-menu-wrapper { position: relative; }

.move-menu {
  position: absolute;
  top: calc(100% + 4px);
  right: 0;
  background: var(--bg-secondary, #fff);
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
  color: var(--text-main);
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

  h3 { font-size: 1.1rem; font-weight: 600; color: var(--text-main); }

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

  label { font-size: 0.85rem; font-weight: 500; color: var(--text-main); }

  input, select {
    padding: 0.65rem 0.75rem;
    border: 1px solid var(--border-color);
    background: var(--bg-primary);
    color: var(--text-main);
    border-radius: 6px;
    font-size: 0.9rem;
    outline: none;
    &:focus { border-color: var(--primary); }
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
