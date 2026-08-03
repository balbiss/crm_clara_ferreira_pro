<script setup>
import { ref } from 'vue'
import { MoreVertical, VolumeX, VolumeX as UnmuteIcon, Share, Loader2 } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  contactId:      { type: [Number, String], required: true },
  contactStatus:  { type: String, default: 'active' }
})

const emit = defineEmits(['contact-blocked', 'contact-unblocked'])

const isOpen    = ref(false)
const isLoading = ref(false)

const toggleDropdown = () => { isOpen.value = !isOpen.value }
const closeDropdown  = () => { isOpen.value = false }

const blockContact = async () => {
  closeDropdown()
  const result = await Swal.fire({
    title: 'Bloquear contato?',
    html: 'O contato não poderá mais enviar mensagens e a IA será pausada permanentemente para ele.',
    icon: 'warning',
    showCancelButton: true,
    confirmButtonText: 'Sim, bloquear',
    cancelButtonText: 'Cancelar',
    confirmButtonColor: '#ef4444'
  })
  if (!result.isConfirmed) return

  isLoading.value = true
  try {
    await api.patch(`/contacts/${props.contactId}/block`)
    emit('contact-blocked')
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Contato bloqueado', showConfirmButton: false, timer: 3000 })
  } catch (e) {
    Swal.fire('Erro', 'Não foi possível bloquear o contato.', 'error')
  } finally {
    isLoading.value = false
  }
}

const unblockContact = async () => {
  closeDropdown()
  isLoading.value = true
  try {
    await api.patch(`/contacts/${props.contactId}/unblock`)
    emit('contact-unblocked')
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Contato desbloqueado', showConfirmButton: false, timer: 3000 })
  } catch (e) {
    Swal.fire('Erro', 'Não foi possível desbloquear o contato.', 'error')
  } finally {
    isLoading.value = false
  }
}

const downloadTranscript = async () => {
  closeDropdown()
  isLoading.value = true
  try {
    const response = await api.get(`/conversations/${props.conversationId}/transcript`, {
      responseType: 'blob'
    })
    const url  = window.URL.createObjectURL(new Blob([response.data], { type: 'text/plain' }))
    const link = document.createElement('a')
    link.href  = url
    const disp = response.headers['content-disposition'] || ''
    const name = disp.match(/filename="?([^"]+)"?/)?.[1] || `transcricao_${props.conversationId}.txt`
    link.setAttribute('download', name)
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.URL.revokeObjectURL(url)
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Transcrição baixada!', showConfirmButton: false, timer: 3000 })
  } catch (e) {
    Swal.fire('Erro', 'Não foi possível gerar a transcrição.', 'error')
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="more-options-wrapper" v-click-outside="closeDropdown">
    <button class="icon-btn" @click.stop="toggleDropdown" :disabled="isLoading">
      <Loader2 v-if="isLoading" class="icon spinning" />
      <MoreVertical v-else class="icon" />
    </button>

    <div v-if="isOpen" class="dropdown-menu">
      <button v-if="contactStatus !== 'blocked'" class="dropdown-item danger" @click="blockContact">
        <VolumeX class="icon-sm" />
        <span>Bloquear Contato</span>
      </button>
      <button v-else class="dropdown-item success" @click="unblockContact">
        <UnmuteIcon class="icon-sm" />
        <span>Desbloquear Contato</span>
      </button>

      <div class="dropdown-divider"></div>

      <button class="dropdown-item" @click="downloadTranscript">
        <Share class="icon-sm" />
        <span>Baixar Transcrição</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.more-options-wrapper {
  position: relative;
  display: inline-block;
  margin-left: 0.5rem;
}

.icon-btn {
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 0.4rem;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  transition: all 0.2s;
  &:disabled { opacity: 0.5; cursor: not-allowed; }
  &:hover:not(:disabled) { background: rgba(0,0,0,0.05); color: var(--text-main); }
}

.icon { width: 18px; height: 18px; }
.icon-sm { width: 15px; height: 15px; }

.spinning { animation: spin 0.8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 4px;
  background: var(--bg-secondary, white);
  border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.12);
  min-width: 210px;
  max-width: calc(100vw - 2rem);
  z-index: 100;
  padding: 0.3rem 0;
  display: flex;
  flex-direction: column;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 0.55rem 1rem;
  background: transparent;
  border: none;
  color: var(--text-main, #334155);
  font-size: 0.875rem;
  text-align: left;
  cursor: pointer;
  transition: background 0.15s;
  &:hover { background: rgba(0,0,0,0.04); }
  &.danger { color: #dc2626; &:hover { background: rgba(239,68,68,0.08); } }
  &.success { color: #059669; &:hover { background: rgba(16,185,129,0.08); } }
}

.dropdown-divider {
  height: 1px;
  background: var(--border-color, #f1f5f9);
  margin: 0.25rem 0;
}
</style>
