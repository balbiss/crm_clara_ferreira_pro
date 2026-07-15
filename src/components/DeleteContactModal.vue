<template>
  <div v-if="isOpen" class="modal-overlay" @click.self="close">
    <div class="delete-modal-content">
      <h2 class="delete-title">Confirmar Exclusão</h2>
      <p class="delete-message">
        Você tem certeza que deseja excluir<br>
        {{ contact?.name }}?
      </p>
      
      <div class="delete-actions">
        <button type="button" class="btn-cancel" @click="close">Não, Mantenha</button>
        <button type="button" class="btn-danger" @click="confirm" :disabled="loading">
          {{ loading ? 'Excluindo...' : 'Sim, Excluir' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useConversationsStore } from '../store/conversations'
import Swal from 'sweetalert2'

const props = defineProps({
  isOpen: Boolean,
  contact: Object
})

const emit = defineEmits(['close', 'deleted'])
const store = useConversationsStore()
const loading = ref(false)

const close = () => {
  emit('close')
}

const confirm = async () => {
  if (!props.contact) return
  loading.value = true
  try {
    await store.deleteContact(props.contact.id)
    emit('deleted')
    close()
  } catch (error) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao excluir contato.', showConfirmButton: false, timer: 3500 })
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.15); /* Very subtle overlay for popover feel */
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.delete-modal-content {
  background: white;
  border-radius: 12px;
  width: 360px;
  max-width: 90%;
  padding: 24px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.1);
  text-align: left;
}

.delete-title {
  margin: 0 0 12px 0;
  font-size: 1.25rem;
  color: #1f2937;
  font-weight: 600;
}

.delete-message {
  color: #6b7280;
  font-size: 1rem;
  line-height: 1.5;
  margin-bottom: 24px;
}

.delete-actions {
  display: flex;
  justify-content: flex-start;
  gap: 12px;
}

.btn-cancel {
  background: #f3f4f6;
  border: none;
  padding: 10px 16px;
  border-radius: 6px;
  cursor: pointer;
  color: #374151;
  font-weight: 500;
  font-size: 0.95rem;
  transition: background 0.2s;
}

.btn-cancel:hover {
  background: #e5e7eb;
}

.btn-danger {
  background: #ef4444; /* Red / pinkish like original */
  color: white;
  border: none;
  padding: 10px 16px;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
  font-size: 0.95rem;
  transition: background 0.2s;
}

.btn-danger:hover {
  background: #dc2626;
}

.btn-danger:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}
</style>
