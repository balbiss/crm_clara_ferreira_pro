<template>
  <div v-if="isOpen" class="modal-overlay" @click.self="close">
    <div class="modal-content">
      <div class="modal-header">
        <h2>Mesclar Contato</h2>
        <button class="close-btn" @click="close">&times;</button>
      </div>
      <div class="modal-body">
        <p class="description">
          Selecione o contato principal para onde deseja mover todas as conversas do contato <strong>{{ contact?.name }}</strong>.
          <br><br>
          <span class="warning-text">Aviso: O contato atual será excluído após a mesclagem.</span>
        </p>
        
        <div class="form-group">
          <label>Contato de Destino</label>
          <select v-model="selectedContactId" class="contact-select">
            <option value="" disabled>Selecione um contato</option>
            <option v-for="c in otherContacts" :key="c.id" :value="c.id">
              {{ c.name }} ({{ c.phone || c.email || 'Sem dados' }})
            </option>
          </select>
        </div>
      </div>

      <div class="modal-actions">
        <button type="button" class="btn-cancel" @click="close">Cancelar</button>
        <button type="button" class="btn-primary" @click="merge" :disabled="!selectedContactId || loading">
          {{ loading ? 'Mesclando...' : 'Confirmar Mesclagem' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useConversationsStore } from '../store/conversations'
import Swal from 'sweetalert2'

const props = defineProps({
  isOpen: Boolean,
  contact: Object
})

const emit = defineEmits(['close'])
const store = useConversationsStore()

const selectedContactId = ref('')
const loading = ref(false)

// Extract unique contacts from conversations that are NOT the current contact
const otherContacts = computed(() => {
  if (!props.contact) return []
  const uniqueContacts = []
  const seenIds = new Set()
  
  store.conversations.forEach(conv => {
    if (conv.contact && conv.contact.id !== props.contact.id) {
      if (!seenIds.has(conv.contact.id)) {
        seenIds.add(conv.contact.id)
        uniqueContacts.push(conv.contact)
      }
    }
  })
  
  return uniqueContacts
})

const close = () => {
  selectedContactId.value = ''
  emit('close')
}

const merge = async () => {
  if (!props.contact || !selectedContactId.value) return
  
  loading.value = true
  try {
    await store.mergeContact(props.contact.id, selectedContactId.value)
    close()
  } catch (error) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao mesclar contato.', showConfirmButton: false, timer: 3500 })
  } finally {
    loading.value = false
  }
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
.warning-text {
  color: #e53e3e;
  font-weight: 500;
  font-size: 0.85rem;
}
.form-group {
  margin-bottom: 16px;
}
.form-group label {
  display: block;
  margin-bottom: 6px;
  font-size: 0.875rem;
  color: #4a5568;
  font-weight: 500;
}
.contact-select {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 1rem;
  background-color: #fff;
}
.contact-select:focus {
  outline: none;
  border-color: #0052CC;
}
.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 24px;
}
.btn-cancel {
  background: transparent;
  border: 1px solid #e2e8f0;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  color: #4a5568;
}
.btn-primary {
  background: #0052CC;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
}
.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
  background: #a0aec0;
}
</style>
