<script setup>
import { ref, onMounted } from 'vue'
import { Plus, Trash2 } from 'lucide-vue-next'

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  },
  initialFilters: {
    type: Array,
    default: () => []
  }
})

const emit = defineEmits(['close', 'apply'])

// Local state for filters while editing
const localFilters = ref([])

onMounted(() => {
  if (props.initialFilters.length > 0) {
    localFilters.value = JSON.parse(JSON.stringify(props.initialFilters))
  } else {
    // Start with one empty filter row by default if none exist
    addFilter()
  }
})

const attributes = [
  { value: 'status', label: 'Status' },
  { value: 'assignee', label: 'Atendente' }
]

const operators = [
  { value: 'equal_to', label: '= Igual a' },
  { value: 'not_equal_to', label: '!= Diferente de' }
]

const getValuesForAttribute = (attr) => {
  if (attr === 'status') {
    return [
      { value: 'open', label: 'Abertas' },
      { value: 'resolved', label: 'Resolvidas' },
      { value: 'snoozed', label: 'Adiadas' }
    ]
  }
  if (attr === 'assignee') {
    return [
      // For a real app, this would be a dynamic list of users
      { value: 'João', label: 'João' },
      { value: 'unassigned', label: 'Não atribuído' }
    ]
  }
  return []
}

const addFilter = () => {
  localFilters.value.push({
    id: Date.now(),
    attribute: 'status',
    operator: 'equal_to',
    value: 'open'
  })
}

const removeFilter = (id) => {
  localFilters.value = localFilters.value.filter(f => f.id !== id)
}

const clearFilters = () => {
  localFilters.value = []
  emit('apply', [])
  emit('close')
}

const applyFilters = () => {
  emit('apply', localFilters.value)
  emit('close')
}
</script>

<template>
  <div v-if="isOpen" class="filter-popover" @click.stop>
    <h3 class="popover-title">Filtrar conversas</h3>
    
    <div class="filters-list">
      <div v-for="(filter, index) in localFilters" :key="filter.id" class="filter-row">
        
        <select v-model="filter.attribute" class="filter-select attr-select">
          <option v-for="attr in attributes" :key="attr.value" :value="attr.value">
            {{ attr.label }}
          </option>
        </select>

        <select v-model="filter.operator" class="filter-select op-select">
          <option v-for="op in operators" :key="op.value" :value="op.value">
            {{ op.label }}
          </option>
        </select>

        <select v-model="filter.value" class="filter-select val-select">
          <option v-for="val in getValuesForAttribute(filter.attribute)" :key="val.value" :value="val.value">
            {{ val.label }}
          </option>
        </select>

        <button class="action-icon add-icon" @click="addFilter" title="Adicionar condição AND">
          <Plus class="icon-sm" />
        </button>

        <button class="action-icon trash-icon" @click="removeFilter(filter.id)" title="Remover regra">
          <Trash2 class="icon-sm" />
        </button>
      </div>
    </div>

    <div class="popover-actions-bottom">
      <button class="add-filter-text-btn" @click="addFilter">
        Adicionar filtro
      </button>

      <div class="right-actions">
        <button class="btn-secondary" @click="clearFilters">Limpar filtros</button>
        <button class="btn-primary" @click="applyFilters">Aplicar filtros</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.filter-popover {
  position: absolute;
  top: 100%;
  left: 0;
  margin-top: 8px;
  width: 600px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  border: 1px solid var(--border-color);
  padding: 1.5rem;
  z-index: 100;
  cursor: default;
}

.popover-title {
  font-size: 1.1rem;
  font-weight: 500;
  color: var(--text-main);
  margin-bottom: 1.5rem;
}

.filters-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 2rem;
}

.filter-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.filter-select {
  padding: 0.5rem;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-primary);
  color: var(--text-main);
  font-size: 0.9rem;
  outline: none;
}

.filter-select:focus {
  border-color: var(--primary-color);
}

.attr-select {
  background-color: rgba(0,0,0,0.03);
  border: none;
  font-weight: 500;
}

.op-select {
  border: none;
  color: var(--primary-color);
  font-weight: 500;
}

.val-select {
  background-color: rgba(0,0,0,0.03);
  border: none;
  font-weight: 500;
}

.action-icon {
  background: transparent;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  cursor: pointer;
  transition: all 0.2s;
}

.action-icon:hover {
  background: rgba(0,0,0,0.05);
  color: var(--text-main);
}

.add-icon {
  margin-left: 0.5rem;
}

.popover-actions-bottom {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.add-filter-text-btn {
  background: transparent;
  border: none;
  color: var(--primary-color);
  font-weight: 500;
  font-size: 0.9rem;
  cursor: pointer;
  padding: 0;
}

.add-filter-text-btn:hover {
  text-decoration: underline;
}

.right-actions {
  display: flex;
  gap: 0.75rem;
}

.btn-secondary {
  background: rgba(0,0,0,0.05);
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  color: var(--text-main);
  font-weight: 500;
  font-size: 0.9rem;
  cursor: pointer;
  transition: background 0.2s;
}

.btn-secondary:hover {
  background: rgba(0,0,0,0.1);
}

.btn-primary {
  background: #1F73F1; /* Chatwoot blue */
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  color: white;
  font-weight: 500;
  font-size: 0.9rem;
  cursor: pointer;
  transition: background 0.2s;
}

.btn-primary:hover {
  background: #155ECC;
}

@media (max-width: 480px) {
  .filter-popover {
    position: fixed;
    top: auto;
    bottom: 0;
    left: 0;
    right: 0;
    width: auto;
    margin-top: 0;
    border-radius: 12px 12px 0 0;
    max-height: 80vh;
    overflow-y: auto;
  }

  .filter-row {
    flex-wrap: wrap;
  }

  .popover-actions-bottom {
    flex-direction: column;
    gap: 0.75rem;
    align-items: stretch;
  }

  .right-actions {
    flex-direction: column;
  }
}
</style>
