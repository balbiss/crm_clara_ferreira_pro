<script setup>
import { ref } from 'vue'
import { CheckCircle, Clock, CircleDashed, ChevronDown } from 'lucide-vue-next'
import { useConversationsStore } from '../store/conversations'
import SnoozeModal from './SnoozeModal.vue'
import ResolveModal from './ResolveModal.vue'

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true
  },
  currentStatus: {
    type: String,
    default: 'open'
  }
})

const store         = useConversationsStore()
const isOpen        = ref(false)
const showSnooze    = ref(false)
const showResolve   = ref(false)

const toggleDropdown = () => { isOpen.value = !isOpen.value }
const closeDropdown  = () => { isOpen.value = false }

const openSnooze = () => {
  closeDropdown()
  showSnooze.value = true
}

const openResolve = () => {
  closeDropdown()
  showResolve.value = true
}

const handleSnoozeConfirm = async (snoozedUntil) => {
  showSnooze.value = false
  await store.snoozeConversation(props.conversationId, snoozedUntil)
}

const handleResolveConfirm = async (options) => {
  showResolve.value = false
  await store.resolveConversation(props.conversationId, options)
}

const reopen = async () => {
  closeDropdown()
  await store.updateConversationStatus(props.conversationId, 'open')
}
</script>

<template>
  <div class="status-dropdown-wrapper" v-click-outside="closeDropdown">
    <div class="split-btn-group">
      <!-- Main action button -->
      <button
        v-if="currentStatus !== 'resolved' && currentStatus !== 'snoozed'"
        class="btn-main-action"
        @click="openResolve"
      >
        Resolver
      </button>
      <button
        v-else-if="currentStatus === 'snoozed'"
        class="btn-main-action snoozed"
        @click="reopen"
      >
        ⏰ Adiado
      </button>
      <button
        v-else
        class="btn-main-action resolved"
        @click="reopen"
      >
        ✓ Resolvido
      </button>

      <!-- Chevron toggle -->
      <button class="btn-chevron" @click.stop="toggleDropdown">
        <ChevronDown class="icon-sm" />
      </button>
    </div>

    <!-- Dropdown Menu -->
    <div v-if="isOpen" class="dropdown-menu">
      <button
        v-if="currentStatus !== 'resolved'"
        class="dropdown-item"
        @click="openResolve"
      >
        <CheckCircle class="icon-sm" />
        <span>Resolver</span>
      </button>

      <button
        v-if="currentStatus !== 'snoozed'"
        class="dropdown-item"
        @click="openSnooze"
      >
        <Clock class="icon-sm" />
        <span>Adiar</span>
      </button>

      <button
        v-if="currentStatus !== 'open'"
        class="dropdown-item"
        @click="reopen"
      >
        <CircleDashed class="icon-sm" />
        <span>Deixar pendente</span>
      </button>
    </div>
  </div>

  <!-- Modais (renderizados fora do wrapper para evitar z-index) -->
  <Teleport to="body">
    <SnoozeModal
      v-if="showSnooze"
      :conversation-id="conversationId"
      @confirm="handleSnoozeConfirm"
      @close="showSnooze = false"
    />
    <ResolveModal
      v-if="showResolve"
      :conversation-id="conversationId"
      @confirm="handleResolveConfirm"
      @close="showResolve = false"
    />
  </Teleport>
</template>

<style scoped>
.status-dropdown-wrapper {
  position: relative;
  display: inline-block;
}

.split-btn-group {
  display: flex;
  align-items: center;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: white;
  overflow: hidden;
}

.btn-main-action {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.35rem 0.75rem;
  background: white;
  border: none;
  border-right: 1px solid var(--border-color);
  color: var(--text-main);
  font-weight: 500;
  font-size: 0.85rem;
  cursor: pointer;
  transition: background 0.2s;
}

.btn-main-action:hover { background: rgba(0, 0, 0, 0.03); }

.btn-main-action.resolved { color: #28a745; }
.btn-main-action.resolved:hover { background: rgba(40, 167, 69, 0.05); }

.btn-main-action.snoozed { color: #d97706; }
.btn-main-action.snoozed:hover { background: rgba(217, 119, 6, 0.05); }

.btn-chevron {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0.35rem 0.4rem;
  background: white;
  border: none;
  color: var(--text-main);
  cursor: pointer;
  transition: background 0.2s;
}
.btn-chevron:hover { background: rgba(0, 0, 0, 0.05); }

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 4px;
  background: white;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  min-width: 180px;
  max-width: calc(100vw - 2rem);
  z-index: 100;
  padding: 0.25rem 0;
  display: flex;
  flex-direction: column;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: transparent;
  border: none;
  color: var(--text-main);
  font-size: 0.9rem;
  text-align: left;
  cursor: pointer;
  transition: background 0.2s;
}
.dropdown-item:hover { background: rgba(0, 0, 0, 0.05); }
</style>
