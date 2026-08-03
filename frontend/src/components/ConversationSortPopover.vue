<script setup>
import { ref, watch } from 'vue'
import { useConversationsStore } from '../store/conversations'

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  }
})

const store = useConversationsStore()

const localStatus = ref(store.sortStatus)
const localSortBy = ref(store.sortBy)
const localType = ref(store.sortType)

watch(() => store.sortStatus, (val) => localStatus.value = val)
watch(() => store.sortBy, (val) => localSortBy.value = val)
watch(() => store.sortType, (val) => localType.value = val)

const emit = defineEmits(['close'])

const applySort = () => {
  store.setSortFilters({
    status: localStatus.value,
    sortBy: localSortBy.value,
    type: localType.value
  })
}

// Watchers to auto-apply when a select changes
watch([localStatus, localSortBy, localType], () => {
  applySort()
})
</script>

<template>
  <div v-if="isOpen" class="sort-popover" @click.stop>
    
    <div class="sort-row">
      <label>Status</label>
      <select v-model="localStatus" class="sort-select">
        <option value="open">Abertas</option>
        <option value="resolved">Resolvidas</option>
        <option value="snoozed">Adiadas</option>
        <option value="all">Todas</option>
      </select>
    </div>

    <div class="sort-row">
      <label>Ordenar por</label>
      <select v-model="localSortBy" class="sort-select">
        <option value="latest">Última atividade</option>
        <option value="oldest">Mais antigas</option>
      </select>
    </div>

    <div class="sort-row">
      <label>Tipo</label>
      <select v-model="localType" class="sort-select">
        <option value="all">Todos</option>
        <option value="mentions">Menções</option>
        <option value="unread">Não lidas</option>
      </select>
    </div>

  </div>
</template>

<style scoped>
.sort-popover {
  position: absolute;
  top: 100%;
  left: 0;
  margin-top: 8px;
  width: 250px;
  max-width: calc(100vw - 2rem);
  background: white;
  border-radius: 8px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  border: 1px solid var(--border-color);
  padding: 1rem;
  z-index: 100;
  cursor: default;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.sort-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.sort-row label {
  font-size: 0.9rem;
  color: var(--text-main);
  font-weight: 500;
}

.sort-select {
  padding: 0.4rem 0.5rem;
  border: none;
  border-radius: 6px;
  background: rgba(0,0,0,0.04);
  color: var(--text-main);
  font-size: 0.85rem;
  font-weight: 500;
  outline: none;
  cursor: pointer;
  min-width: 130px;
}

.sort-select:hover {
  background: rgba(0,0,0,0.08);
}
</style>
