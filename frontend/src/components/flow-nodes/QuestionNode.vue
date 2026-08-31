<script setup>
import { Handle, Position } from '@vue-flow/core'
import { HelpCircle } from '@lucide/vue'

defineProps({ data: { type: Object, default: () => ({}) }, selected: { type: Boolean, default: false } })
</script>

<template>
  <div class="flow-node question-node" :class="{ selected }">
    <Handle type="target" :position="Position.Top" />
    <div class="node-header">
      <div class="node-icon"><HelpCircle class="icon-xs" /></div>
      <span>Perguntar</span>
    </div>
    <div class="node-body">
      <p v-if="data.question">{{ data.question }}</p>
      <p v-else class="node-empty">Clique pra escrever a pergunta...</p>
      <p v-if="data.variable" class="node-sub">Resposta: {{ data.variable }}</p>
    </div>
    <Handle type="source" :position="Position.Bottom" />
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
  background: #cffafe;
  color: #0e7490;
}

.icon-xs { width: 13px; height: 13px; }

.node-body {
  padding: 0.65rem 0.75rem;
  font-size: 0.8rem;
  color: var(--text-main);
  word-break: break-word;

  p { margin: 0; }
  .node-empty { color: var(--text-muted); font-style: italic; }
  .node-sub { color: var(--text-muted); font-size: 0.72rem; margin-top: 0.35rem; font-family: monospace; }
}
</style>
