<script setup>
import { computed } from 'vue'
import { Handle, Position } from '@vue-flow/core'
import { LayoutList, MousePointerClick } from '@lucide/vue'

const props = defineProps({ data: { type: Object, default: () => ({}) }, selected: { type: Boolean, default: false } })

const isList = computed(() => props.data.mode === 'list')
const options = computed(() => Array.isArray(props.data.options) ? props.data.options : [])

// Espalha as saídas nomeadas ao longo da base do node, uma por opção —
// mesma ideia do Condição (handles "sim"/"nao"), só que em quantidade
// variável.
const handleLeft = (index) => {
  const total = options.value.length
  if (total <= 1) return '50%'
  return `${(index / (total - 1)) * 80 + 10}%`
}
</script>

<template>
  <div class="flow-node options-node" :class="{ selected }">
    <Handle type="target" :position="Position.Top" />
    <div class="node-header">
      <div class="node-icon">
        <component :is="isList ? LayoutList : MousePointerClick" class="icon-xs" />
      </div>
      <span>{{ isList ? 'Lista de opções' : 'Botões' }}</span>
    </div>
    <div class="node-body">
      <p v-if="data.title">{{ data.title }}</p>
      <p v-else class="node-empty">Clique pra configurar as opções...</p>

      <div v-if="options.length" class="options-list">
        <div v-for="opt in options" :key="opt.id" class="option-row">{{ opt.label || '(sem texto)' }}</div>
      </div>
    </div>
    <div v-if="options.length" class="node-outputs">
      <Handle v-for="(opt, i) in options" :key="opt.id" :id="opt.id" type="source" :position="Position.Bottom" :style="{ left: handleLeft(i) }" />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.flow-node {
  min-width: 220px;
  max-width: 260px;
  background: var(--bg-secondary);
  border: 2px solid var(--border-color);
  border-radius: 10px;
  box-shadow: 0 2px 6px rgba(0,0,0,0.08);
  overflow: hidden;

  &.selected { border-color: var(--primary, #d49ba7); }
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
  background: #e0e7ff;
  color: #3730a3;
}

.icon-xs { width: 13px; height: 13px; }

.node-body {
  padding: 0.65rem 0.75rem;
  font-size: 0.8rem;
  color: var(--text-main);
  word-break: break-word;

  p { margin: 0; }
  .node-empty { color: var(--text-muted); font-style: italic; }
}

.options-list {
  margin-top: 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}

.option-row {
  font-size: 0.74rem;
  padding: 0.3rem 0.5rem;
  border-radius: 6px;
  background: var(--bg-tertiary);
  color: var(--text-main);
}

.node-outputs {
  position: relative;
  height: 0.5rem;
}
</style>
