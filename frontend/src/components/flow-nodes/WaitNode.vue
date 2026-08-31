<script setup>
import { computed } from 'vue'
import { Handle, Position } from '@vue-flow/core'
import { Clock } from '@lucide/vue'

const props = defineProps({ data: { type: Object, default: () => ({}) }, selected: { type: Boolean, default: false } })

const UNIT_LABELS = { segundos: 'segundo(s)', minutos: 'minuto(s)', horas: 'hora(s)', dias: 'dia(s)' }
const preview = computed(() => props.data.duration ? `${props.data.duration} ${UNIT_LABELS[props.data.unit] || ''}` : null)
</script>

<template>
  <div class="flow-node wait-node" :class="{ selected }">
    <Handle type="target" :position="Position.Top" />
    <div class="node-header">
      <div class="node-icon"><Clock class="icon-xs" /></div>
      <span>Aguardar</span>
    </div>
    <div class="node-body">
      <p v-if="preview">{{ preview }}</p>
      <p v-else class="node-empty">Clique pra definir o tempo...</p>
    </div>
    <Handle type="source" :position="Position.Bottom" />
  </div>
</template>

<style lang="scss" scoped>
.flow-node {
  min-width: 200px;
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

.wait-node .node-icon { background: #fef9c3; color: #854d0e; }

.icon-xs { width: 13px; height: 13px; }

.node-body {
  padding: 0.65rem 0.75rem;
  font-size: 0.8rem;
  color: var(--text-main);

  p { margin: 0; }
  .node-empty { color: var(--text-muted); font-style: italic; }
}
</style>
