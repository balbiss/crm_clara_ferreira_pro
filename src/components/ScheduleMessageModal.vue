<template>
  <div v-if="isOpen" class="modal-overlay" @click.self="close">
    <div class="modal-content">
      <div class="modal-header">
        <h2>Agendar Mensagem</h2>
        <button class="icon-btn" @click="close"><X class="icon-sm" /></button>
      </div>
      <div class="modal-body">
        <form @submit.prevent="submitForm">
          <div class="form-group">
            <label>Data e Hora do Envio</label>
            <input type="datetime-local" v-model="sendAt" required />
          </div>

          <div class="form-group">
            <label>Mensagem</label>
            <textarea v-model="text" rows="3" placeholder="Digite a mensagem..." :required="!selectedFile"></textarea>
          </div>

          <div class="form-group attachment-section">
            <label>Anexo (Opcional)</label>
            <div class="file-input-wrapper">
              <input type="file" ref="fileInput" @change="handleFileChange" class="hidden-file-input" />
              <button type="button" class="btn-secondary" @click="$refs.fileInput.click()">
                <Paperclip class="icon-sm" /> Escolher Arquivo
              </button>
              <span class="file-name" v-if="selectedFile">{{ selectedFile.name }}</span>
              <button type="button" v-if="selectedFile" class="icon-btn clear-file" @click="clearFile"><X class="icon-xs" /></button>
            </div>
            <img v-if="selectedFilePreview" :src="selectedFilePreview" class="preview-img-small" />
          </div>

          <div class="modal-footer">
            <button type="button" class="btn-secondary" @click="close">Cancelar</button>
            <button type="submit" class="btn-primary" :disabled="isSubmitting">
              {{ isSubmitting ? 'Agendando...' : 'Agendar' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { X, Paperclip } from '@lucide/vue'
import api from '../api'
import { useConversationsStore } from '../store/conversations'
import Swal from 'sweetalert2'

const props = defineProps({
  isOpen: Boolean,
  conversationId: Number
})

const emit = defineEmits(['close', 'scheduled'])
const store = useConversationsStore()

const sendAt = ref('')
const text = ref('')
const selectedFile = ref(null)
const selectedFilePreview = ref(null)
const isSubmitting = ref(false)

watch(() => props.isOpen, (newVal) => {
  if (newVal) {
    text.value = ''
    selectedFile.value = null
    selectedFilePreview.value = null
    
    // Set default time to 5 minutes from now
    const now = new Date()
    now.setMinutes(now.getMinutes() + 5)
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset())
    sendAt.value = now.toISOString().slice(0, 16)
  }
})

const handleFileChange = (e) => {
  const file = e.target.files[0]
  if (!file) return
  selectedFile.value = file

  if (file.type.startsWith('image/')) {
    const reader = new FileReader()
    reader.onload = (e) => {
      selectedFilePreview.value = e.target.result
    }
    reader.readAsDataURL(file)
  } else {
    selectedFilePreview.value = null
  }
}

const clearFile = () => {
  selectedFile.value = null
  selectedFilePreview.value = null
}

const submitForm = async () => {
  if (!props.conversationId) return
  
  isSubmitting.value = true
  
  try {
    const formData = new FormData()
    if (text.value) formData.append('text', text.value)
    formData.append('send_at', new Date(sendAt.value).toISOString())
    if (selectedFile.value) {
      formData.append('attachment', selectedFile.value)
    }

    const response = await api.post(`/conversations/${props.conversationId}/scheduled_messages`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    
    emit('scheduled', response.data)
    close()
  } catch (error) {
    console.error('Error scheduling message:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao agendar a mensagem. Tente novamente.', showConfirmButton: false, timer: 3500 })
  } finally {
    isSubmitting.value = false
  }
}

const close = () => {
  emit('close')
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(15, 23, 42, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}
.modal-content {
  background: var(--bg-secondary, #f8fafc);
  border-radius: 12px;
  width: 90%;
  max-width: 420px;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}
@keyframes slideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}
.modal-header {
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--border-color, #e2e8f0);
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.modal-header h2 {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
  color: var(--text-main, #1e293b);
}
.modal-body {
  padding: 1.25rem;
}
.form-group {
  margin-bottom: 1rem;
}
.form-group label {
  display: block;
  margin-bottom: 0.4rem;
  font-weight: 500;
  color: var(--text-main, #1e293b);
  font-size: 0.85rem;
}
input[type="datetime-local"], textarea {
  width: 100%;
  padding: 0.6rem;
  border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 6px;
  background: var(--bg-primary, #ffffff);
  color: var(--text-main, #1e293b);
  font-family: inherit;
  font-size: 0.9rem;
}
textarea {
  resize: vertical;
  min-height: 80px;
}
.attachment-section {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.file-input-wrapper {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.hidden-file-input {
  display: none;
}
.file-name {
  font-size: 0.85rem;
  color: #64748b;
  max-width: 200px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.preview-img-small {
  max-width: 80px;
  max-height: 80px;
  border-radius: 6px;
  object-fit: cover;
  margin-top: 0.5rem;
}
.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 1.5rem;
}
.btn-primary, .btn-secondary {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  font-size: 0.9rem;
}
.btn-primary {
  background: var(--primary, #3b82f6);
  color: white;
}
.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}
.btn-secondary {
  background: transparent;
  border: 1px solid var(--border-color, #e2e8f0);
  color: var(--text-main, #1e293b);
  display: flex;
  align-items: center;
  gap: 0.4rem;
}
</style>
