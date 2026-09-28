<template>
  <div v-if="isOpen" class="modal-overlay" @click.self="close">
    <div class="modal-content">
      <div class="modal-header">
        <h2>Nova Conversa</h2>
        <button class="close-btn" @click="close">&times;</button>
      </div>
      <div class="modal-body">
        <p class="description">Busque a revendedora pelo nome ou telefone pra abrir uma conversa nova com ela.</p>

        <div class="form-group">
          <div class="contact-search">
            <Search class="icon-xs search-icon" />
            <input
              ref="searchInput"
              :value="query"
              @input="buscarContato($event.target.value)"
              type="text"
              placeholder="Buscar por nome ou telefone..."
              :disabled="isStarting"
            />
          </div>
          <div v-if="isSearching" class="search-status">Buscando...</div>
          <div v-else-if="query.trim() && resultados.length === 0" class="search-status">Nenhuma revendedora encontrada.</div>
          <div v-if="resultados.length" class="contact-results">
            <button
              v-for="c in resultados"
              :key="c.id"
              type="button"
              class="contact-result-item"
              :disabled="isStarting"
              @click="selecionarContato(c)"
            >
              <span class="contact-result-name">{{ c.name || 'Sem nome' }}</span>
              <span class="contact-result-phone">{{ c.phone }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, nextTick, watch } from 'vue'
import { Search } from '@lucide/vue'
import Swal from 'sweetalert2'
import api from '../api'
import { useConversationsStore } from '../store/conversations'
import { pickWhatsappInbox } from '../composables/useInboxPicker'

const props = defineProps({
  isOpen: Boolean
})

const emit = defineEmits(['close', 'created'])
const store = useConversationsStore()

const query = ref('')
const resultados = ref([])
const isSearching = ref(false)
const isStarting = ref(false)
const searchInput = ref(null)
let buscaTimeout = null

watch(() => props.isOpen, (open) => {
  if (open) {
    query.value = ''
    resultados.value = []
    nextTick(() => searchInput.value?.focus())
  }
})

function buscarContato(q) {
  query.value = q
  clearTimeout(buscaTimeout)
  if (!q.trim()) { resultados.value = []; return }

  buscaTimeout = setTimeout(async () => {
    isSearching.value = true
    try {
      const { data } = await api.get('/contacts', { params: { q, per_page: 8 } })
      resultados.value = data
    } catch (e) {
      console.error('Erro ao buscar revendedora:', e)
    } finally {
      isSearching.value = false
    }
  }, 300)
}

async function selecionarContato(contact) {
  const { inboxId, cancelled } = await pickWhatsappInbox()
  if (cancelled) return

  isStarting.value = true
  try {
    const conv = await store.startConversation(contact.id, inboxId)
    emit('created', conv)
    close()
  } catch (e) {
    console.error('Erro ao iniciar conversa:', e)
    const msg = e.response?.data?.message || 'Erro ao iniciar conversa.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 3500 })
  } finally {
    isStarting.value = false
  }
}

function close() {
  clearTimeout(buscaTimeout)
  query.value = ''
  resultados.value = []
  emit('close')
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}
.modal-content {
  background: white;
  border-radius: 8px;
  width: 450px;
  max-width: 90%;
  padding: 24px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.modal-header h2 {
  margin: 0;
  font-size: 1.25rem;
  color: #1a1a1a;
}
.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #666;
}
.description {
  color: #4a5568;
  font-size: 0.95rem;
  margin-bottom: 20px;
  line-height: 1.5;
}
.form-group {
  margin-bottom: 4px;
}
.contact-search {
  position: relative;
  display: flex;
  align-items: center;
}
.icon-xs {
  width: 16px;
  height: 16px;
}
.search-icon {
  position: absolute;
  left: 12px;
  color: #a0aec0;
}
.contact-search input {
  width: 100%;
  padding: 10px 12px 10px 36px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 1rem;
}
.contact-search input:focus {
  outline: none;
  border-color: #cc0066;
}
.search-status {
  margin-top: 8px;
  font-size: 0.85rem;
  color: #718096;
}
.contact-results {
  margin-top: 8px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  max-height: 260px;
  overflow-y: auto;
}
.contact-result-item {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  width: 100%;
  padding: 10px 12px;
  background: none;
  border: none;
  border-bottom: 1px solid #f1f1f1;
  cursor: pointer;
  text-align: left;
}
.contact-result-item:last-child {
  border-bottom: none;
}
.contact-result-item:hover {
  background: #fdf2f8;
}
.contact-result-item:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.contact-result-name {
  font-weight: 500;
  color: #1a1a1a;
  font-size: 0.9rem;
}
.contact-result-phone {
  font-size: 0.8rem;
  color: #718096;
}
</style>
