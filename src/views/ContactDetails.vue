<script setup>
import { ref, onMounted, computed, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Search, ChevronDown, Activity, AtSign, Plus, X } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const route = useRoute()
const router = useRouter()
const contact = ref(null)
const isLoading = ref(true)

const activeTab = ref('Atributos')
const tabs = ['Atributos', 'Histórico', 'Notas', 'Mesclar']

// Fetch Contact
const fetchContact = async () => {
  isLoading.value = true
  try {
    const response = await api.get(`/contacts/${route.params.id}`)
    contact.value = response.data
  } catch (error) {
    console.error('Error fetching contact:', error)
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Contato não encontrado.' })
    router.push('/contatos')
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  fetchContact()
  document.addEventListener('click', closeDropdown)
})

onUnmounted(() => {
  document.removeEventListener('click', closeDropdown)
})

const updateContact = async () => {
  try {
    await api.put(`/contacts/${contact.value.id}`, {
      contact: {
        first_name: contact.value.first_name,
        last_name: contact.value.last_name,
        email: contact.value.email,
        phone: contact.value.phone,
        city: contact.value.city,
        country: contact.value.country,
        bio: contact.value.bio,
        company_name: contact.value.company_name,
        temperature: contact.value.temperature,
        source: contact.value.source,
        intention: contact.value.intention,
        name: `${contact.value.first_name || ''} ${contact.value.last_name || ''}`.trim() || contact.value.name
      }
    })
    
    Swal.fire({
      icon: 'success',
      title: 'Sucesso',
      text: 'Contato atualizado com sucesso!',
      timer: 1500,
      showConfirmButton: false
    })
  } catch (error) {
    console.error('Error updating contact:', error)
    Swal.fire({
      icon: 'error',
      title: 'Erro',
      text: 'Não foi possível atualizar o contato.'
    })
  }
}

const deleteContact = async () => {
  const result = await Swal.fire({
    title: 'Tem certeza?',
    text: "Excluir permanentemente este contato. Esta ação é irreversível.",
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#ef4444',
    cancelButtonColor: '#6b7280',
    confirmButtonText: 'Sim, excluir',
    cancelButtonText: 'Cancelar'
  })

  if (result.isConfirmed) {
    try {
      await api.delete(`/contacts/${contact.value.id}`)
      Swal.fire({
        icon: 'success',
        title: 'Excluído!',
        text: 'O contato foi excluído.',
        timer: 1500,
        showConfirmButton: false
      })
      router.push('/contatos')
    } catch (error) {
      console.error('Error deleting contact:', error)
      Swal.fire({ icon: 'error', title: 'Erro', text: 'Não foi possível excluir o contato.' })
    }
  }
}

// Avatar Logic
const getInitials = (name) => {
  if (!name) return '?'
  return name.substring(0, 2).toUpperCase()
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

// Country Selector Logic
const showCountryDropdown = ref(false)
const searchCountryQuery = ref('')

const countriesList = [
  { code: 'AF', name: 'Afghanistan' },
  { code: 'AX', name: 'Aland Islands' },
  { code: 'AL', name: 'Albania' },
  { code: 'DZ', name: 'Algeria' },
  { code: 'AD', name: 'Andorra' },
  { code: 'AO', name: 'Angola' },
  { code: 'AI', name: 'Anguilla' },
  { code: 'AQ', name: 'Antarctica' },
  { code: 'AG', name: 'Antigua and Barbuda' },
  { code: 'AR', name: 'Argentina' },
  { code: 'AM', name: 'Armenia' },
  { code: 'AW', name: 'Aruba' },
  { code: 'AU', name: 'Australia' },
  { code: 'AT', name: 'Austria' },
  { code: 'AZ', name: 'Azerbaijan' },
  { code: 'BS', name: 'Bahamas' },
  { code: 'BR', name: 'Brazil' },
  { code: 'CA', name: 'Canada' },
  { code: 'PT', name: 'Portugal' },
  { code: 'US', name: 'United States' }
]

const filteredCountries = computed(() => {
  if (!searchCountryQuery.value) return countriesList
  return countriesList.filter(c => 
    c.name.toLowerCase().includes(searchCountryQuery.value.toLowerCase()) || 
    c.code.toLowerCase().includes(searchCountryQuery.value.toLowerCase())
  )
})

const selectCountry = (country) => {
  contact.value.country_code = country.code
  showCountryDropdown.value = false
  searchCountryQuery.value = ''
}

const closeDropdown = () => {
  if (showCountryDropdown.value) {
    showCountryDropdown.value = false
  }
}

const newNote = ref('')
const selectedNote = ref(null)
const showNoteModal = ref(false)

const openNote = (note) => {
  selectedNote.value = note
  showNoteModal.value = true
}

const closeNoteModal = () => {
  showNoteModal.value = false
  selectedNote.value = null
}

const saveNote = async () => {
  if (!newNote.value.trim()) return
  try {
    const response = await api.post(`/contacts/${route.params.id}/add_note`, {
      content: newNote.value
    })
    
    if (!contact.value.notes) {
      contact.value.notes = []
    }
    contact.value.notes.unshift(response.data)
    newNote.value = ''
    
    Swal.fire({
      icon: 'success',
      title: 'Nota salva!',
      timer: 1500,
      showConfirmButton: false
    })
  } catch (error) {
    console.error('Erro ao salvar nota', error)
  }
}

</script>

<template>
  <div class="view-wrapper" style="height: 100%;">
    <div class="page-container" v-if="contact">
    <div class="page-header">
      <div class="header-left">
        <router-link to="/contatos" class="breadcrumb-link">Contatos</router-link>
        <span class="breadcrumb-separator">&gt;</span>
        <span class="breadcrumb-current">{{ contact.first_name || contact.name }}</span>
      </div>
      <div class="header-actions">
        <button class="btn-secondary">Bloquear contato</button>
        <button class="btn-primary">Enviar mensagem</button>
      </div>
    </div>

    <div class="content-grid">
      <!-- Left Pane -->
      <div class="left-pane">
        <div class="profile-header">
          <div class="avatar-large" :style="getAvatarStyle(contact.first_name || contact.name)" v-if="!contact.avatar_url">
            {{ getInitials(contact.first_name || contact.name) }}
          </div>
          <img :src="contact.avatar_url" alt="Avatar" class="avatar-large" style="object-fit: cover;" v-else />
          <h2 class="profile-name">{{ contact.first_name || contact.name }} {{ contact.last_name || '' }}</h2>
          <div class="profile-meta">
            <div class="meta-item"><AtSign class="icon-xs" /> {{ contact.email || 'Sem e-mail' }}</div>
            <div class="meta-item"><Activity class="icon-xs" /> Criado há pouco • Última atividade há pouco</div>
          </div>
          <button class="btn-tag"><Plus class="icon-xs" /> etiqueta</button>
        </div>

        <div class="form-section">
          <h4 class="form-title">Alterar detalhes do contato</h4>
          <div class="form-grid">
            <input type="text" v-model="contact.first_name" placeholder="Digite o nome" class="form-input" />
            <input type="text" v-model="contact.last_name" placeholder="Digite o sobrenome" class="form-input" />
            
            <input type="email" v-model="contact.email" placeholder="Digite o endereço de e-mail" class="form-input" />
            
            <div class="phone-input-group">
              <div class="country-selector-wrapper">
                <div class="country-selector" @click.stop="showCountryDropdown = !showCountryDropdown">
                  {{ contact.country_code || 'BR' }} <ChevronDown class="icon-xs" />
                </div>
                
                <div class="country-dropdown-menu" v-if="showCountryDropdown" @click.stop>
                  <div class="country-search-wrapper">
                    <Search class="icon-xs search-icon-sm" />
                    <input type="text" v-model="searchCountryQuery" placeholder="Pesquisar..." />
                  </div>
                  <div class="country-list">
                    <div 
                      class="country-item" 
                      v-for="c in filteredCountries" 
                      :key="c.code"
                      @click="selectCountry(c)"
                    >
                      <span class="c-code">{{ c.code }}</span>
                      <span class="c-name">{{ c.name }}</span>
                    </div>
                  </div>
                </div>
              </div>
              <input type="text" v-model="contact.phone" placeholder="+55 99999999999" class="form-input phone-input" />
            </div>
            
            <input type="text" v-model="contact.city" placeholder="Digite o nome da cidade" class="form-input" />
            <select v-model="contact.country" class="form-input">
              <option value="" disabled>Selecione o país</option>
              <option value="Brasil">Brasil</option>
              <option value="Portugal">Portugal</option>
              <option value="EUA">EUA</option>
            </select>
            
            <input type="text" v-model="contact.bio" placeholder="Digite uma biografia" class="form-input" />
            <input type="text" v-model="contact.company_name" placeholder="Digite o nome da empresa" class="form-input" />
            
            <select v-model="contact.temperature" class="form-input">
              <option value="" disabled>Selecione a Temperatura</option>
              <option value="Quente">Quente</option>
              <option value="Morno">Morno</option>
              <option value="Frio">Frio</option>
            </select>

            <select v-model="contact.intention" class="form-input">
              <option value="" disabled>Pretensão</option>
              <option value="Venda">Venda</option>
              <option value="Locação">Locação</option>
            </select>
            
            <select v-model="contact.source" class="form-input">
              <option value="" disabled>Mídia de Origem</option>
              <option value="WhatsApp API">WhatsApp API</option>
              <option value="Facebook">Facebook</option>
              <option value="Instagram">Instagram</option>
              <option value="Portal Imobiliário">Portal Imobiliário</option>
              <option value="Indicação">Indicação</option>
            </select>
          </div>
          
          <button class="btn-update" @click="updateContact">Atualizar contato</button>
        </div>

        <div class="danger-zone">
          <h4 class="form-title">Excluir contato</h4>
          <p class="danger-text">Excluir permanentemente este contato. Esta ação é irreversível</p>
          <button class="btn-danger" @click="deleteContact">Excluir contato</button>
        </div>
      </div>

      <!-- Right Pane -->
      <div class="right-pane">
        <div class="tabs-header">
          <button 
            v-for="tab in tabs" 
            :key="tab" 
            class="tab-btn" 
            :class="{ active: activeTab === tab }"
            @click="activeTab = tab"
          >
            {{ tab }}
          </button>
        </div>
        <div class="tab-content">
          <!-- Tab Atributos -->
          <div v-show="activeTab === 'Atributos'">
            <p class="empty-state-text">
              Não há atributos personalizados de contatos disponíveis nesta conta. Você pode criar um atributo personalizado nas configurações.
            </p>
          </div>
          
          <!-- Tab Histórico -->
          <div v-show="activeTab === 'Histórico'" class="history-tab">
            <div class="history-item">
              <span class="history-date">Data de Criação</span>
              <p>Contato adicionado ao CRM.</p>
            </div>
            
            <div v-if="contact.conversations && contact.conversations.length > 0">
              <div class="history-item" v-for="conv in contact.conversations" :key="conv.id">
                <span class="history-date">Conversa #{{ conv.id }} - {{ new Date(conv.created_at).toLocaleDateString() }}</span>
                <p>Status: {{ conv.status === 'open' ? 'Aberta' : (conv.status === 'resolved' ? 'Resolvida' : conv.status) }}</p>
                <p v-if="conv.messages && conv.messages.length > 0">
                  Última mensagem: "{{ conv.messages[conv.messages.length - 1].text }}"
                </p>
                <button class="btn-secondary" style="margin-top: 0.5rem; font-size: 0.8rem; padding: 0.25rem 0.5rem;" @click="$router.push('/conversas')">
                  Ir para a Conversa
                </button>
              </div>
            </div>
            <p v-else class="empty-state-text" style="margin-top: 1rem;">Nenhuma conversa registrada.</p>
          </div>
          
          <!-- Tab Notas -->
          <div v-show="activeTab === 'Notas'">
            <div class="notes-input-area">
              <textarea v-model="newNote" placeholder="Adicione uma nota sobre este contato..." rows="3"></textarea>
              <button class="btn-primary" @click="saveNote" :disabled="!newNote.trim()">Salvar Nota</button>
            </div>
            
            <div class="notes-list-compact" v-if="contact.notes && contact.notes.length > 0" style="margin-top: 1.5rem;">
              <div class="note-list-item" v-for="note in contact.notes" :key="note.id" @click="openNote(note)">
                <div class="note-content-row">
                  <span class="note-author">{{ note.user ? (note.user.first_name || note.user.name) : 'Usuário' }}</span>
                  <span class="note-preview-inline">- {{ note.content }}</span>
                </div>
                <span class="note-date">{{ new Date(note.created_at).toLocaleDateString('pt-BR') }}</span>
              </div>
            </div>
            <p class="empty-state-text" v-else style="margin-top: 1rem;">Nenhuma nota encontrada.</p>
          </div>
          
          <!-- Tab Mesclar -->
          <div v-show="activeTab === 'Mesclar'">
            <p class="empty-state-text">
              Pesquise outro contato para mesclar com este.
            </p>
            <input type="text" class="form-input" placeholder="Pesquisar contatos..." style="width: 100%; max-width: 300px; margin: 1rem auto; display: block;" />
          </div>
        </div>
      </div>
    </div>
  </div>
  <div class="loading-state" v-else-if="isLoading">
    Carregando...
  </div>

  <!-- Note Modal -->
  <div class="modal-overlay" v-show="showNoteModal" @click="closeNoteModal">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <h3>Detalhes da Nota</h3>
        <button class="btn-close" @click="closeNoteModal"><X class="icon-sm" /></button>
      </div>
      <div class="modal-body" v-if="selectedNote">
        <div class="modal-meta">
          <strong>Criado por:</strong> {{ selectedNote.user ? (selectedNote.user.first_name || selectedNote.user.name) : 'Usuário' }} <br />
          <strong>Data:</strong> {{ new Date(selectedNote.created_at).toLocaleDateString('pt-BR') }} às {{ new Date(selectedNote.created_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) }}
        </div>
        <div class="modal-text">
          {{ selectedNote.content }}
        </div>
      </div>
    </div>
  </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #ffffff;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 2rem;
  border-bottom: 1px solid #e5e7eb;

  .header-left {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.95rem;

    .breadcrumb-link {
      color: #6b7280;
      text-decoration: none;
      &:hover { color: #1f2937; }
    }
    
    .breadcrumb-separator {
      color: #9ca3af;
    }

    .breadcrumb-current {
      font-weight: 500;
      color: #1f2937;
    }
  }

  .header-actions {
    display: flex;
    gap: 0.75rem;
  }
}

.btn-secondary {
  background: transparent;
  color: #374151;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid #d1d5db;
  font-weight: 500;
  font-size: 0.85rem;
  cursor: pointer;
  
  &:hover { background: #f3f4f6; }
}

.btn-primary {
  background: #2563eb;
  color: white;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: none;
  font-weight: 500;
  font-size: 0.85rem;
  cursor: pointer;
  
  &:hover { background: #1d4ed8; }
}

.content-grid {
  display: grid;
  grid-template-columns: minmax(400px, 1fr) 1fr;
  flex: 1;
  overflow: hidden;
}

/* LEFT PANE */
.left-pane {
  padding: 2rem;
  overflow-y: auto;
  border-right: 1px solid #e5e7eb;
}

.profile-header {
  margin-bottom: 2.5rem;

  .avatar-large {
    width: 64px;
    height: 64px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.5rem;
    font-weight: 500;
    margin-bottom: 1rem;
  }

  .profile-name {
    font-size: 1.25rem;
    font-weight: 600;
    color: #1f2937;
    margin: 0 0 0.5rem 0;
  }

  .profile-meta {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    margin-bottom: 1rem;

    .meta-item {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      font-size: 0.85rem;
      color: #6b7280;
    }
  }

  .btn-tag {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    background: transparent;
    border: 1px dashed #d1d5db;
    color: #4b5563;
    padding: 0.25rem 0.5rem;
    border-radius: 16px;
    font-size: 0.75rem;
    cursor: pointer;
    
    &:hover { border-color: #9ca3af; }
  }
}

.form-section {
  margin-bottom: 2.5rem;
}

.form-title {
  font-size: 0.95rem;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 1rem;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.form-input {
  width: 100%;
  padding: 0.75rem 1rem;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  font-size: 0.85rem;
  color: #1f2937;
  outline: none;

  &::placeholder { color: #9ca3af; }
  &:focus { box-shadow: 0 0 0 2px #bfdbfe; border-color: transparent; }
}

.phone-input-group {
  display: flex;
  gap: 0.5rem;
  
  .country-selector-wrapper {
    position: relative;
    width: 100px;
  }

  .country-selector {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.75rem;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    font-size: 0.85rem;
    color: #1f2937;
    cursor: pointer;
    user-select: none;
  }

  .country-dropdown-menu {
    position: absolute;
    top: 100%;
    left: 0;
    margin-top: 4px;
    width: 250px;
    background: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
    z-index: 10;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .country-search-wrapper {
    display: flex;
    align-items: center;
    padding: 0.5rem 0.75rem;
    border-bottom: 1px solid #e5e7eb;
    background: #ffffff;

    .search-icon-sm {
      color: #9ca3af;
      margin-right: 0.5rem;
    }

    input {
      border: none;
      background: transparent;
      outline: none;
      font-size: 0.85rem;
      color: #1f2937;
      width: 100%;
      &::placeholder { color: #9ca3af; }
    }
  }

  .country-list {
    max-height: 200px;
    overflow-y: auto;
    
    .country-item {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      padding: 0.5rem 0.75rem;
      cursor: pointer;
      font-size: 0.85rem;
      
      &:hover { background: #f3f4f6; }
      
      .c-code {
        font-weight: 600;
        color: #1f2937;
        min-width: 20px;
      }
      
      .c-name {
        color: #6b7280;
      }
    }
  }
  
  .phone-input {
    flex: 1;
  }
}

.btn-update {
  background: #2563eb;
  color: white;
  padding: 0.6rem 1.2rem;
  border-radius: 6px;
  border: none;
  font-weight: 500;
  font-size: 0.85rem;
  cursor: pointer;
  
  &:hover { background: #1d4ed8; }
}

.danger-zone {
  border-top: 1px solid #e5e7eb;
  padding-top: 2rem;

  .danger-text {
    font-size: 0.85rem;
    color: #4b5563;
    margin-bottom: 1rem;
  }

  .btn-danger {
    background: #ef4444;
    color: white;
    padding: 0.6rem 1.2rem;
    border-radius: 6px;
    border: none;
    font-weight: 500;
    font-size: 0.85rem;
    cursor: pointer;
    
    &:hover { background: #dc2626; }
  }
}

/* RIGHT PANE */
.right-pane {
  background: #ffffff;
  display: flex;
  flex-direction: column;
}

.tabs-header {
  display: flex;
  padding: 1rem 2rem 0;
  border-bottom: 1px solid #e5e7eb;
  gap: 2rem;
}

.tab-btn {
  background: transparent;
  border: none;
  padding: 0.75rem 0;
  font-size: 0.85rem;
  color: #6b7280;
  font-weight: 500;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
  
  &.active {
    color: #2563eb;
    border-bottom-color: #2563eb;
  }
  
  &:hover:not(.active) {
    color: #374151;
  }
}

.tab-content {
  padding: 3rem 2rem;
  text-align: center;
  flex: 1;

  .empty-state-text {
    color: #6b7280;
    font-size: 0.95rem;
    text-align: center;
    line-height: 1.5;
  }

  .history-item {
    text-align: left;
    padding: 1.25rem;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    background: #ffffff;
    margin-bottom: 1rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
    border-left: 4px solid #3b82f6;
    
    .history-date {
      font-size: 0.8rem;
      color: #6b7280;
      font-weight: 500;
      margin-bottom: 0.75rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    
    p {
      margin: 0;
      color: #1f2937;
      font-size: 0.95rem;
      line-height: 1.5;
    }
  }

  .notes-input-area {
    display: flex;
    flex-direction: column;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 1rem;
    
    textarea {
      width: 100%;
      border: 1px solid #d1d5db;
      border-radius: 6px;
      padding: 0.75rem;
      font-family: inherit;
      resize: vertical;
      outline: none;
      font-size: 0.95rem;
      
      &:focus {
        border-color: #3b82f6;
        box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2);
      }
    }
    
    .btn-primary {
      align-self: flex-end;
      margin-top: 0.75rem;
      padding: 0.5rem 1.25rem;
      font-size: 0.9rem;
      border-radius: 6px;
    }
  }

  .notes-list-compact {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    text-align: left;
  }

  .note-list-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.85rem 1rem;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    background: #ffffff;
    cursor: pointer;
    transition: all 0.2s;
    
    &:hover {
      border-color: #3b82f6;
      box-shadow: 0 2px 4px rgba(59, 130, 246, 0.1);
      background: #f8fafc;
    }

    .note-content-row {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      flex: 1;
      min-width: 0;
    }
    
    .note-author {
      font-weight: 600;
      color: #374151;
      white-space: nowrap;
      font-size: 0.9rem;
    }

    .note-preview-inline {
      color: #6b7280;
      font-size: 0.9rem;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    
    .note-date {
      color: #9ca3af;
      font-size: 0.85rem;
      white-space: nowrap;
      margin-left: 1rem;
      flex-shrink: 0;
    }
  }
}

.empty-state-text {
  font-size: 0.85rem;
  color: #6b7280;
  max-width: 400px;
  margin: 0 auto;
  line-height: 1.5;
}

.icon-xs {
  width: 14px;
  height: 14px;
}

.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #6b7280;
}

/* Modal CSS */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(2px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
}

.modal-content {
  background: white;
  width: 90%;
  max-width: 500px;
  border-radius: 12px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.modal-header {
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  justify-content: space-between;
  align-items: center;

  h3 {
    margin: 0;
    font-size: 1.1rem;
    color: #1f2937;
  }

  .btn-close {
    background: none;
    border: none;
    color: #9ca3af;
    cursor: pointer;
    padding: 0.25rem;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;

    &:hover {
      background: #f3f4f6;
      color: #4b5563;
    }
  }
}

.modal-body {
  padding: 1.5rem;

  .modal-meta {
    background: #f9fafb;
    padding: 1rem;
    border-radius: 6px;
    font-size: 0.9rem;
    color: #4b5563;
    margin-bottom: 1rem;
    line-height: 1.5;
  }

  .modal-text {
    font-size: 0.95rem;
    color: #1f2937;
    line-height: 1.6;
    white-space: pre-wrap;
  }
}

@media (max-width: 900px) {
  .content-grid {
    grid-template-columns: 1fr;
    overflow-y: auto;
  }

  .page-header {
    padding: 1rem;
    flex-wrap: wrap;
    gap: 0.75rem;
  }
}

@media (max-width: 500px) {
  .form-grid {
    grid-template-columns: 1fr;
  }
}
</style>
