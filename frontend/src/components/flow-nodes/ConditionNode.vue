<script setup>
import { computed } from 'vue'
import { Handle, Position } from '@vue-flow/core'
import { GitFork } from '@lucide/vue'

const props = defineProps({ data: { type: Object, default: () => ({}) }, selected: { type: Boolean, default: false } })

const OPERATOR_LABELS = { igual: 'é igual a', diferente: 'é diferente de', contem: 'contém' }
const CHECK_TYPE_LABELS = {
  variavel: 'Variável',
  resposta: 'Resposta',
  horario: 'Horário',
  dia: 'Dia',
  etiqueta: 'Etiqueta',
  status: 'Status'
}
const checkLabel = computed(() => CHECK_TYPE_LABELS[props.data.check_type] || CHECK_TYPE_LABELS.variavel)
const preview = computed(() => {
  if (!props.data.variable) return null
  return `${checkLabel.value} {{${props.data.variable}}} ${OPERATOR_LABELS[props.data.operator] || ''} "${props.data.value || ''}"`
})
</script>

<template>
  <div class="flow-node condition-node" :class="{ selected }">
    <Handle type="target" :position="Position.Top" />
    <div class="node-header">
      <div class="node-icon"><GitFork class="icon-xs" /></div>
      <span>Condição</span>
    </div>
    <div class="node-body">
      <p v-if="preview">{{ preview }}</p>
      <p v-else class="node-empty">Clique pra configurar a condição...</p>
    </div>
    <div class="node-outputs">
      <span class="output-label yes">Sim</span>
      <span class="output-label no">Não</span>
    </div>
    <Handle id="sim" type="source" :position="Position.Bottom" style="left: 30%" />
    <Handle id="nao" type="source" :position="Position.Bottom" style="left: 70%" />
  </div>
</template>

<style lang="scss" scoped>
.flow-node {
  min-width: 220px;
  background: var(--bg-secondary);
  border: 2px solid var(--border-color);
  border-radius: 10px;
  box-shadow: 0 2px 6px rgba(0,0,0,0.08);
  overflow: hidden;

  &.selected { border-color: var(--primary, #ff007f); }
}

.node-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.55rem 0.75rem;
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--text-main);
  background: var(--bg-tertiary);
  border-bottom: 1px solid var(--border-color);
}

.node-icon {
  width: 22px;
  height: 22px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.condition-node .node-icon { background: #ede9fe; color: #5b21b6; }

.icon-xs { width: 13px; height: 13px; }

.node-body {
  padding: 0.65rem 0.75rem;
  font-size: 0.8rem;
  color: var(--text-main);
  word-break: break-word;

  p { margin: 0; }
  .node-empty { color: var(--text-muted); font-style: italic; }
}

.node-outputs {
  display: flex;
  justify-content: space-between;
  padding: 0 0.75rem 0.5rem;
  font-size: 0.68rem;
  font-weight: 700;

  .yes { color: #059669; }
  .no { color: #dc2626; }
}
</style>
