<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Plus, MoreHorizontal, Phone, X, Search, Trash2, Pencil, ArrowUpDown, Menu as MenuIcon, Zap } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'
import { usePipelinesStore } from '../store/pipelines'
import { useContactsStore } from '../store/contacts'
import { isFullPortfolio } from '../config/roles'

// Board genérico pra qualquer pipeline customizado (Varejo, Onboarding, Atacado,
// Prospecção, ou qualquer outro criado pela empresa). O Consignado NÃO passa por aqui
// — continua em Kanban.vue, usando a régua automática de Contact#status.
const route = useRoute()
const router = useRouter()
const pipelinesStore = usePipelinesStore()
const contactsStore = useContactsStore()

const isOwner = computed(() => {
  const user = JSON.parse(localStorage.getItem('user') || '{}')
  return isFullPortfolio(user)
})

const pipeline = computed(() => pipelinesStore.findBySlug(route.params.slug))
const isLoading = ref(true)
const cards = ref([])
const searchQuery = ref('')

const cardsByStage = computed(() => {
  const map = {}
  if (!pipeline.value) return map
  pipeline.value.pipeline_stages.forEach(s => { map[s.id] = [] })
  cards.value.forEach(c => {
    if (searchQuery.value && !(c.contact.name || '').toLowerCase().includes(searchQuery.value.toLowerCase())) return
    if (map[c.pipeline_stage_id]) map[c.pipeline_stage_id].push(c)
  })
  return map
})

const totalLeads = computed(() => cards.value.length)
const totalValor = computed(() => cards.value.reduce((s, c) => s + (parseFloat(c.contact.venda) || 0), 0))
const brl = (v) => v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
const columnTotal = (stageId) => (cardsByStage.value[stageId] || []).reduce((s, c) => s + (parseFloat(c.contact.venda) || 0), 0)

const fetchCards = async () => {
  if (!pipeline.value) return
  isLoading.value = true
  try {
    const res = await api.get(`/pipelines/${pipeline.value.id}/pipeline_cards`)
    cards.value = res.data
  } catch (e) {
    console.error('Erro ao carregar cards do pipeline:', e)
  } finally {
    isLoading.value = false
  }
}

onMounted(async () => {
  if (!pipelinesStore.isLoadedOnce) await pipelinesStore.fetchPipelines()
  if (!contactsStore.isLoadedOnce) await contactsStore.fetchContacts()
  fetchCards()
})

watch(() => route.params.slug, fetchCards)

// Drag and drop
const draggedCard = ref(null)
const activeStageDrag = ref(null)

const dragCard = (event, card) => {
  draggedCard.value = card
  event.dataTransfer.effectAllowed = 'move'
}

const moveCardToStage = async (card, stageId) => {
  if (card.pipeline_stage_id === stageId) return
  const oldStageId = card.pipeline_stage_id
  card.pipeline_stage_id = stageId
  try {
    await api.put(`/pipeline_cards/${card.id}`, { pipeline_card: { pipeline_stage_id: stageId } })
  } catch (e) {
    card.pipeline_stage_id = oldStageId
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível mover o card.', confirmButtonColor: '#ff007f' })
  }
}

const dropCard = async (event, stageId) => {
  activeStageDrag.value = null
  if (!draggedCard.value) return
  const card = draggedCard.value
  draggedCard.value = null
  await moveCardToStage(card, stageId)
}

const openMoveMenuCardId = ref(null)
const toggleMoveMenu = (cardId) => { openMoveMenuCardId.value = openMoveMenuCardId.value === cardId ? null : cardId }
const moveCardViaMenu = async (card, stageId) => { openMoveMenuCardId.value = null; await moveCardToStage(card, stageId) }

const removeCard = async (card) => {
  const result = await Swal.fire({
    title: 'Remover do pipeline?',
    text: `${card.contact.name} sai deste pipeline (o cadastro dela continua existindo).`,
    icon: 'warning', showCancelButton: true, confirmButtonColor: '#ff007f', confirmButtonText: 'Remover', cancelButtonText: 'Cancelar'
  })
  if (!result.isConfirmed) return
  await api.delete(`/pipeline_cards/${card.id}`)
  cards.value = cards.value.filter(c => c.id !== card.id)
}

// Adicionar contato ao pipeline
const showAddModal = ref(false)
const targetStageId = ref(null)
const addSearch = ref('')
const creatingNew = ref(false)
const newContact = ref({ first_name: '', last_name: '', phone: '' })

const availableContacts = computed(() => {
  const idsNoPipeline = new Set(cards.value.map(c => c.contact.id))
  const q = addSearch.value.toLowerCase()
  return contactsStore.contacts
    .filter(c => !idsNoPipeline.has(c.id))
    .filter(c => !q || (c.name || '').toLowerCase().includes(q) || (c.phone || '').includes(q))
    .slice(0, 20)
})

const openAddModal = (stageId) => {
  targetStageId.value = stageId
  addSearch.value = ''
  creatingNew.value = false
  newContact.value = { first_name: '', last_name: '', phone: '' }
  showAddModal.value = true
}

const addExistingContact = async (contact) => {
  try {
    const res = await api.post(`/pipelines/${pipeline.value.id}/pipeline_cards`, {
      contact_id: contact.id,
      pipeline_stage_id: targetStageId.value
    })
    cards.value.push(res.data)
    showAddModal.value = false
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'Erro', text: e.response?.data?.errors?.join(', ') || 'Não foi possível adicionar.' })
  }
}

const createAndAddContact = async () => {
  if (!newContact.value.first_name) {
    Swal.fire({ icon: 'warning', title: 'Atenção', text: 'O nome é obrigatório.' })
    return
  }
  try {
    const user = JSON.parse(localStorage.getItem('user') || '{}')
    const contactRes = await api.post('/contacts', {
      contact: {
        first_name: newContact.value.first_name,
        last_name: newContact.value.last_name,
        name: `${newContact.value.first_name} ${newContact.value.last_name}`.trim(),
        phone: newContact.value.phone,
        account_id: user.account_id
      }
    })
    await contactsStore.fetchContacts()
    await addExistingContact(contactRes.data)
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível criar o contato.' })
  }
}

// Gestão do pipeline (dono/admin)
const renamePipeline = async () => {
  const { value: name } = await Swal.fire({
    title: 'Renomear pipeline', input: 'text', inputValue: pipeline.value.name,
    showCancelButton: true, confirmButtonColor: '#ff007f', confirmButtonText: 'Salvar', cancelButtonText: 'Cancelar'
  })
  if (!name || !name.trim()) return
  await pipelinesStore.renamePipeline(pipeline.value.id, name.trim())
}

const deletePipeline = async () => {
  const result = await Swal.fire({
    title: `Apagar o pipeline "${pipeline.value.name}"?`,
    text: 'Todos os cards dele serão removidos (os contatos continuam existindo). Essa ação não pode ser desfeita.',
    icon: 'warning', showCancelButton: true, confirmButtonColor: '#dc2626', confirmButtonText: 'Apagar', cancelButtonText: 'Cancelar'
  })
  if (!result.isConfirmed) return
  try {
    await pipelinesStore.deletePipeline(pipeline.value.id)
    router.push('/carteira')
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'Erro', text: e.response?.data?.error || 'Não foi possível apagar.' })
  }
}

const addStage = async () => {
  const { value: name } = await Swal.fire({
    title: 'Nova etapa', input: 'text', inputPlaceholder: 'Ex: Em negociação',
    showCancelButton: true, confirmButtonColor: '#ff007f', confirmButtonText: 'Criar', cancelButtonText: 'Cancelar'
  })
  if (!name || !name.trim()) return
  await pipelinesStore.createStage(pipeline.value.id, name.trim())
}

const renameStage = async (stage) => {
  const { value: name } = await Swal.fire({
    title: 'Renomear etapa', input: 'text', inputValue: stage.name,
    showCancelButton: true, confirmButtonColor: '#ff007f', confirmButtonText: 'Salvar', cancelButtonText: 'Cancelar'
  })
  if (!name || !name.trim()) return
  await pipelinesStore.renameStage(stage.id, name.trim())
}

const deleteStage = async (stage) => {
  if (pipeline.value.pipeline_stages.length <= 1) {
    Swal.fire({ icon: 'warning', title: 'Não é possível', text: 'O pipeline precisa de pelo menos uma etapa.' })
    return
  }
  const result = await Swal.fire({
    title: `Apagar a etapa "${stage.name}"?`,
    text: 'Os cards dela vão pra outra etapa automaticamente.',
    icon: 'warning', showCancelButton: true, confirmButtonColor: '#dc2626', confirmButtonText: 'Apagar', cancelButtonText: 'Cancelar'
  })
  if (!result.isConfirmed) return
  await pipelinesStore.deleteStage(pipeline.value.id, stage.id)
  fetchCards()
}

const colors = [
  { bg: '#ffd9ec', color: '#a80050' }, { bg: '#d1fae5', color: '#065f46' },
  { bg: '#fee2e2', color: '#991b1b' }, { bg: '#fef3c7', color: '#92400e' },
  { bg: '#f3e8ff', color: '#6b21a8' }
]
const getAvatarStyle = (name) => {
  if (!name) return { backgroundColor: '#e5e7eb', color: '#4b5563' }
  const index = name.charCodeAt(0) % colors.length
  return { backgroundColor: colors[index].bg, color: colors[index].color }
}

</script>

<template>
  <div class="page-container" v-if="pipeline">
    <div class="page-header">
      <div class="header-left">
        <h1>{{ pipeline.name.toUpperCase() }}</h1>
        <button class="icon-btn" title="Ordenar"><ArrowUpDown class="icon-sm" /></button>
        <button class="icon-btn" title="Ver como lista"><MenuIcon class="icon-sm" /></button>
        <template v-if="isOwner && !pipeline.system">
          <button class="icon-btn" title="Renomear pipeline" @click="renamePipeline"><Pencil class="icon-sm" /></button>
          <button class="icon-btn danger" title="Apagar pipeline" @click="deletePipeline"><Trash2 class="icon-sm" /></button>
        </template>
      </div>
      <div class="header-search">
        <Search class="icon-sm" />
        <input v-model="searchQuery" type="text" placeholder="Pesquisar e filtrar" />
      </div>
      <div class="header-right">
        <span class="board-total">{{ totalLeads }} leads: {{ brl(totalValor) }}</span>
        <button class="btn-secondary" @click="router.push(`/pipelines/${pipeline.slug}/automatize`)"><Zap class="icon-sm" /> Automatize</button>
        <button v-if="isOwner" class="btn-secondary" @click="addStage"><Plus class="icon-sm" /> Nova Etapa</button>
        <button class="btn-primary" @click="openAddModal(pipeline.pipeline_stages[0]?.id)"><Plus class="icon-sm" /> Novo Lead</button>
      </div>
    </div>

    <div class="kanban-board" v-if="!isLoading">
      <div
        class="kanban-column"
        v-for="stage in pipeline.pipeline_stages"
        :key="stage.id"
        :class="{ 'column-drag-over': activeStageDrag === stage.id }"
        @dragover.prevent="activeStageDrag = stage.id"
        @dragleave="activeStageDrag = null"
        @drop="dropCard($event, stage.id)"
      >
        <div class="column-header">
          <h3>{{ stage.name }}</h3>
          <div class="column-header-actions">
            <button class="icon-btn" @click="openAddModal(stage.id)"><Plus class="icon-sm" /></button>
            <template v-if="isOwner">
              <button class="icon-btn" title="Renomear etapa" @click="renameStage(stage)"><Pencil class="icon-xs" /></button>
              <button class="icon-btn danger" title="Apagar etapa" @click="deleteStage(stage)"><Trash2 class="icon-xs" /></button>
            </template>
          </div>
        </div>
        <div class="column-totals">{{ (cardsByStage[stage.id] || []).length }} leads: {{ brl(columnTotal(stage.id)) }}</div>

        <div class="column-content">
          <div
            class="kanban-card"
            v-for="card in (cardsByStage[stage.id] || [])"
            :key="card.id"
            draggable="true"
            @dragstart="dragCard($event, card)"
            @click="router.push(`/contatos/${card.contact.id}`)"
          >
            <div class="card-header">
              <div class="avatar-sm" :style="getAvatarStyle(card.contact.name)">{{ (card.contact.name || '?').substring(0,2).toUpperCase() }}</div>
              <h4>{{ card.contact.name }}</h4>
              <div class="move-menu-wrapper">
                <button class="icon-btn-sm" @click.stop="toggleMoveMenu(card.id)"><MoreHorizontal class="icon-sm" /></button>
                <div v-if="openMoveMenuCardId === card.id" class="move-menu" @click.stop>
                  <div class="move-menu-title">Mover para...</div>
                  <button v-for="target in pipeline.pipeline_stages.filter(s => s.id !== stage.id)" :key="target.id" class="move-menu-item" @click="moveCardViaMenu(card, target.id)">
                    {{ target.name }}
                  </button>
                  <div class="move-menu-divider"></div>
                  <button class="move-menu-item danger" @click="removeCard(card)">Remover do pipeline</button>
                </div>
              </div>
            </div>
            <div class="card-details">
              <span class="phone-info"><Phone class="icon-xs" /> {{ card.contact.phone || 'Sem telefone' }}</span>
              <span v-if="parseFloat(card.contact.venda) > 0" class="venda-info">{{ brl(parseFloat(card.contact.venda)) }}</span>
            </div>
          </div>
          <p v-if="(cardsByStage[stage.id] || []).length === 0" class="empty-column">Nenhum contato nessa etapa.</p>
        </div>
      </div>
    </div>

    <div v-else class="loading-state">Carregando pipeline...</div>

    <!-- Modal Adicionar Contato -->
    <div v-if="showAddModal" class="modal-backdrop" @click.self="showAddModal = false">
      <div class="modal-card">
        <div class="modal-header">
          <h3>Adicionar ao Pipeline</h3>
          <button class="close-btn" @click="showAddModal = false"><X class="icon-sm" /></button>
        </div>

        <div class="modal-body" v-if="!creatingNew">
          <input v-model="addSearch" type="text" placeholder="Buscar revendedora por nome ou telefone..." class="search-input" autofocus />
          <div class="contact-results">
            <button v-for="c in availableContacts" :key="c.id" class="contact-result" @click="addExistingContact(c)">
              <div class="avatar-sm" :style="getAvatarStyle(c.name)">{{ (c.name || '?').substring(0,2).toUpperCase() }}</div>
              <div class="contact-result-info">
                <span class="contact-result-name">{{ c.name || `${c.first_name} ${c.last_name}` }}</span>
                <span class="contact-result-phone">{{ c.phone || 'Sem telefone' }}</span>
              </div>
            </button>
            <p v-if="availableContacts.length === 0" class="empty-column">Nenhum resultado.</p>
          </div>
          <button class="btn-link" @click="creatingNew = true">+ Cadastrar nova revendedora</button>
        </div>

        <form v-else @submit.prevent="createAndAddContact" class="modal-form">
          <div class="form-row">
            <div class="form-group">
              <label>Nome</label>
              <input type="text" v-model="newContact.first_name" required />
            </div>
            <div class="form-group">
              <label>Sobrenome</label>
              <input type="text" v-model="newContact.last_name" />
            </div>
          </div>
          <div class="form-group">
            <label>Telefone</label>
            <input type="text" v-model="newContact.phone" placeholder="+55 11 99999-9999" />
          </div>
          <div class="modal-actions">
            <button type="button" class="btn-cancel" @click="creatingNew = false">Voltar</button>
            <button type="submit" class="btn-submit">Criar e Adicionar</button>
          </div>
        </form>
      </div>
    </div>

  </div>

  <div v-else class="loading-state">Carregando pipeline...</div>
</template>

<style lang="scss" scoped>
.page-container { display: flex; flex-direction: column; height: 100%; padding: 1rem 1.5rem; background: var(--bg-primary); overflow: hidden; }

.page-header {
  display: flex; align-items: center; gap: 1rem; margin-bottom: 1rem; flex-shrink: 0; flex-wrap: wrap;
  .header-left { display: flex; align-items: center; gap: 0.4rem; h1 { font-size: 1.15rem; font-weight: 700; color: var(--text-main); letter-spacing: 0.02em; } }
  .header-search {
    flex: 1; min-width: 200px; display: flex; align-items: center; gap: 0.5rem;
    background: var(--bg-tertiary); padding: 0.45rem 0.75rem; border-radius: 8px; color: var(--text-muted);
    input { flex: 1; background: none; border: none; outline: none; font-size: 0.85rem; color: var(--text-main); }
  }
  .header-right { display: flex; align-items: center; gap: 0.6rem; .board-total { font-size: 0.8rem; font-weight: 600; color: var(--text-muted); white-space: nowrap; } }
}

.btn-primary {
  display: flex; align-items: center; gap: 0.4rem; background: var(--primary); color: white;
  padding: 0.5rem 1rem; border-radius: 6px; border: none; font-weight: 600; font-size: 0.85rem; cursor: pointer; white-space: nowrap;
  &:hover { background: var(--primary-hover); }
}

.btn-secondary {
  display: flex; align-items: center; gap: 0.4rem; background: var(--bg-tertiary); color: var(--text-main);
  padding: 0.5rem 0.9rem; border-radius: 6px; border: 1px solid var(--border-color); font-weight: 600; font-size: 0.85rem; cursor: pointer; white-space: nowrap;
  &:hover { background: var(--bg-hover); }
}

.kanban-board {
  display: flex; gap: 0.75rem; overflow-x: auto; flex: 1; padding-bottom: 1rem;
  &::-webkit-scrollbar { height: 6px; } &::-webkit-scrollbar-track { background: transparent; }
  &::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 10px; } &::-webkit-scrollbar-thumb:hover { background: #94a3b8; }
}

.kanban-column {
  width: 280px; min-width: 280px; display: flex; flex-direction: column;
  background: var(--bg-tertiary, #f4f5f7); border-radius: 10px; max-height: 100%;
  transition: background-color 0.2s, box-shadow 0.2s;
  box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
  border-top: 3px solid var(--primary);
  &.column-drag-over { box-shadow: 0 0 0 2px var(--primary) inset; }
}

.column-header {
  display: flex; justify-content: space-between; align-items: center; padding: 0.75rem 0.75rem 0.2rem;
  h3 { font-size: 0.78rem; font-weight: 800; color: var(--text-main); letter-spacing: 0.03em; }
  .column-header-actions { display: flex; align-items: center; gap: 0.15rem; }
}

.column-totals { padding: 0 0.75rem 0.5rem; font-size: 0.7rem; font-weight: 600; color: var(--text-muted); }

.column-content {
  flex: 1; overflow-y: auto; padding: 0.25rem 0.75rem 0.75rem; display: flex; flex-direction: column; gap: 0.5rem;
  &::-webkit-scrollbar { width: 4px; } &::-webkit-scrollbar-track { background: transparent; }
  &::-webkit-scrollbar-thumb { background: #d1d5db; border-radius: 10px; } &::-webkit-scrollbar-thumb:hover { background: #9ca3af; }
}

.empty-column { font-size: 0.75rem; color: var(--text-muted); text-align: center; padding: 1.5rem 0.5rem; }

.kanban-card {
  background: var(--bg-secondary, #fff); border-radius: 10px; padding: 0.7rem 0.75rem;
  box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
  border: 1px solid rgba(0,0,0,0.05); cursor: grab; transition: all 0.15s ease-in-out;
  &:hover { box-shadow: 0 3px 6px rgba(0, 0, 0, 0.08); transform: translateY(-1px); }
  &:active { cursor: grabbing; transform: scale(0.98); }

  .card-header {
    display: flex; align-items: center; gap: 0.5rem;
    h4 { flex: 1; font-size: 0.82rem; font-weight: 700; color: var(--text-main); line-height: 1.2; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .avatar-sm { width: 26px; height: 26px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 0.65rem; font-weight: 700; flex-shrink: 0; }
  }

  .card-details {
    display: flex; justify-content: space-between; align-items: center; margin-top: 0.4rem;
    .phone-info { font-size: 0.68rem; color: var(--text-muted); display: flex; align-items: center; gap: 0.2rem; font-weight: 500; }
    .venda-info { font-size: 0.7rem; font-weight: 700; color: var(--primary); }
  }
}

.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 12px; height: 12px; }

.icon-btn, .icon-btn-sm {
  background: none; border: none; cursor: pointer; color: var(--text-muted);
  display: flex; align-items: center; justify-content: center; padding: 0.2rem;
  &:hover { color: var(--text-main); }
  &.danger:hover { color: #dc2626; }
}

.move-menu-wrapper { position: relative; }
.move-menu {
  position: absolute; top: calc(100% + 4px); right: 0; background: var(--bg-secondary, #fff);
  border: 1px solid rgba(0,0,0,0.08); border-radius: 8px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);
  min-width: 180px; max-width: calc(100vw - 3rem); z-index: 50; padding: 0.35rem 0; display: flex; flex-direction: column;
}
.move-menu-title { font-size: 0.68rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; color: #9ca3af; padding: 0.3rem 0.9rem 0.4rem; }
.move-menu-item { background: none; border: none; text-align: left; padding: 0.5rem 0.9rem; font-size: 0.82rem; color: var(--text-main); cursor: pointer; &:hover { background: rgba(0,0,0,0.04); } &.danger { color: #dc2626; } }
.move-menu-divider { height: 1px; background: var(--border-color); margin: 0.25rem 0; }

.loading-state { text-align: center; padding: 5rem; color: var(--text-muted); }

.modal-backdrop { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0, 0, 0, 0.4); display: flex; align-items: center; justify-content: center; z-index: 1000; }
.modal-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; width: 100%; max-width: 480px; max-height: 80vh; box-shadow: 0 20px 25px -5px var(--shadow-color), 0 10px 10px -5px var(--shadow-sm); overflow: hidden; display: flex; flex-direction: column; }
.modal-header {
  display: flex; justify-content: space-between; align-items: center; padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-color); background: var(--bg-tertiary);
  h3 { font-size: 1.1rem; font-weight: 600; color: var(--text-main); }
  .close-btn { background: transparent; border: none; color: var(--text-muted); cursor: pointer; &:hover { color: var(--text-main); } }
}
.modal-body { padding: 1.25rem 1.5rem; overflow-y: auto; }
.search-input { width: 100%; padding: 0.65rem 0.75rem; border: 1px solid var(--border-color); background: var(--bg-primary); color: var(--text-main); border-radius: 6px; font-size: 0.9rem; outline: none; margin-bottom: 0.75rem; &:focus { border-color: var(--primary); } }
.contact-results { display: flex; flex-direction: column; gap: 0.3rem; max-height: 280px; overflow-y: auto; }
.contact-result {
  display: flex; align-items: center; gap: 0.6rem; padding: 0.5rem 0.6rem; border-radius: 8px; border: none;
  background: none; cursor: pointer; text-align: left; width: 100%;
  &:hover { background: var(--bg-hover); }
  .avatar-sm { width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 0.7rem; font-weight: 700; flex-shrink: 0; }
  .contact-result-info { display: flex; flex-direction: column; }
  .contact-result-name { font-size: 0.85rem; font-weight: 600; color: var(--text-main); }
  .contact-result-phone { font-size: 0.72rem; color: var(--text-muted); }
}
.btn-link { margin-top: 0.75rem; background: none; border: none; color: var(--primary); font-size: 0.82rem; font-weight: 600; cursor: pointer; padding: 0; &:hover { text-decoration: underline; } }

.modal-form { padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem; }
.form-group {
  display: flex; flex-direction: column; gap: 0.4rem;
  label { font-size: 0.85rem; font-weight: 500; color: var(--text-main); }
  input { padding: 0.65rem 0.75rem; border: 1px solid var(--border-color); background: var(--bg-primary); color: var(--text-main); border-radius: 6px; font-size: 0.9rem; outline: none; &:focus { border-color: var(--primary); } }
}
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.modal-actions {
  display: flex; justify-content: flex-end; gap: 0.75rem; margin-top: 1rem;
  .btn-cancel { background: var(--bg-tertiary); color: var(--text-main); border: 1px solid var(--border-color); padding: 0.5rem 1rem; border-radius: 6px; font-weight: 500; cursor: pointer; &:hover { background: var(--bg-hover); } }
  .btn-submit { background: var(--primary); color: white; border: none; padding: 0.5rem 1rem; border-radius: 6px; font-weight: 500; cursor: pointer; &:hover { background: var(--primary-hover); } }
}

@media (max-width: 640px) {
  .page-header { flex-direction: column; align-items: stretch; }
}
</style>
