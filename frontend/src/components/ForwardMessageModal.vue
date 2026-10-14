<template>
  <div v-if="isOpen" class="modal-overlay" @click.self="close">
    <div class="modal-content">
      <div class="modal-header">
        <h2>Encaminhar {{ tipoLabel }}</h2>
        <button class="close-btn" @click="close">&times;</button>
      </div>
      <div class="modal-body">
        <p class="description">Busque a revendedora pelo nome ou telefone. A mensagem sai pelo WhatsApp da caixa escolhida, como se você tivesse enviado.</p>

        <div class="form-group">
          <div class="contact-search">
            <Search class="icon-xs search-icon" />
            <input
              ref="searchInput"
              :value="query"
              @input="buscarContato($event.target.value)"
              type="text"
              placeholder="Buscar por nome ou telefone..."
              :disabled="isSending"
            />
          </div>
          <div v-if="isSending" class="search-status">Encaminhando...</div>
          <div v-else-if="isSearching" class="search-status">Buscando...</div>
          <div v-else-if="query.trim() && resultados.length === 0" class="search-status">
            Nenhuma revendedora encontrada.
            <button v-if="telefoneDigitado" type="button" class="btn-novo-numero" @click="encaminharParaNumero">
              Encaminhar para {{ telefoneDigitado }}
            </button>
          </div>
          <div v-if="resultados.length" class="contact-results">
            <button
              v-for="c in resultados"
              :key="c.id"
              type="button"
              class="contact-result-item"
              :disabled="isSending"
              @click="encaminharParaContato(c)"
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
import { ref, computed, nextTick, watch } from 'vue'
import { Search } from '@lucide/vue'
import Swal from 'sweetalert2'
import api from '../api'
import { useConversationsStore } from '../store/conversations'
import { pickWhatsappInbox } from '../composables/useInboxPicker'

const props = defineProps({
  isOpen: Boolean,
  message: Object
})

const emit = defineEmits(['close'])
const store = useConversationsStore()

const query = ref('')
const resultados = ref([])
const isSearching = ref(false)
const isSending = ref(false)
const searchInput = ref(null)
let buscaTimeout = null

const tipoLabel = computed(() => {
  const t = props.message?.attachmentType || ''
  if (t.startsWith('audio/')) return 'áudio'
  if (t.startsWith('image/')) return 'foto'
  if (t.startsWith('video/')) return 'vídeo'
  if (t) return 'arquivo'
  return 'mensagem'
})

// Texto que vai junto: em anexo vindo do WhatsApp o text é só marcador
// interno ("📎 Anexo recebido", "[Áudio Transcrito] ..."), não manda isso.
const textoEncaminhado = computed(() => {
  const msg = props.message
  if (!msg) return ''
  const text = (msg.text || '').trim()
  if (!msg.attachmentType) return text
  if (text.startsWith('📎') || text.startsWith('[Áudio Transcrito]')) return ''
  return text
})

const telefoneDigitado = computed(() => {
  if (/[a-zA-ZÀ-ÿ]/.test(query.value)) return null
  const digitos = query.value.replace(/\D/g, '')
  if (digitos.length < 10 || digitos.length > 13) return null
  const local = digitos.length >= 12 ? digitos.slice(2) : digitos
  return `(${local.slice(0, 2)}) ${local.slice(2, -4)}-${local.slice(-4)}`
})

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

function encaminharParaContato(contact) {
  return encaminhar(inboxId => store.startConversation(contact.id, inboxId), contact.name || contact.phone)
}

function encaminharParaNumero() {
  const phone = query.value.replace(/\D/g, '')
  return encaminhar(inboxId => store.startConversationWithPhone(phone, inboxId), telefoneDigitado.value)
}

async function encaminhar(abrirConversa, destino) {
  const { inboxId, cancelled } = await pickWhatsappInbox()
  if (cancelled) return

  isSending.value = true
  try {
    const conv = await abrirConversa(inboxId)
    await api.post(`/conversations/${conv.id}/messages`, {
      text: textoEncaminhado.value,
      forward_message_id: props.message.id
    })
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: `Encaminhado para ${destino}`, showConfirmButton: false, timer: 3000 })
    close()
  } catch (e) {
    console.error('Erro ao encaminhar:', e)
    const msg = e.response?.data?.message || e.response?.data?.error || 'Erro ao encaminhar.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 3500 })
  } finally {
    isSending.value = false
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
.btn-novo-numero {
  display: block;
  width: 100%;
  margin-top: 8px;
  padding: 10px 12px;
  background: #ff007f;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 0.9rem;
  cursor: pointer;
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
