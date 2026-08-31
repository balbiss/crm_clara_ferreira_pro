<script setup>
import { Handle, Position } from '@vue-flow/core'
import { OctagonX } from '@lucide/vue'

defineProps({ selected: { type: Boolean, default: false } })
</script>

<template>
  <div class="flow-node end-node" :class="{ selected }">
    <Handle type="target" :position="Position.Top" />
    <div class="node-header">
      <div class="node-icon"><OctagonX class="icon-xs" /></div>
      <span>Encerrar fluxo</span>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.flow-node {
  min-width: 160px;
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
  padding: 0.6rem 0.75rem;
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--text-main);
}

.node-icon {
  width: 22px;
  height: 22px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: #fee2e2;
  color: #991b1b;
}

.icon-xs { width: 13px; height: 13px; }
</style>
