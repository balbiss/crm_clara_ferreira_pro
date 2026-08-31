<script setup>
import { computed } from 'vue'
import { Handle, Position } from '@vue-flow/core'
import { Zap } from '@lucide/vue'

const props = defineProps({ data: { type: Object, default: () => ({}) }, selected: { type: Boolean, default: false } })

const TRIGGER_LABELS = {
  novo_contato: 'Novo contato',
  palavra_chave: 'Palavra-chave',
  mensagem_recebida: 'Mensagem recebida',
  evento: 'Evento',
  webhook: 'Webhook',
  manual: 'Manual'
}

const label = computed(() => TRIGGER_LABELS[props.data.trigger_type] || 'Selecione o gatilho')
const preview = computed(() => props.data.trigger_type === 'palavra_chave' && props.data.keyword ? `"${props.data.keyword}"` : null)
</script>

<template>
  <div class="flow-node trigger-node" :class="{ selected }">
    <div class="node-header">
      <div class="node-icon"><Zap class="icon-xs" /></div>
      <span>Gatilho</span>
    </div>
    <div class="node-body">
      <p>{{ label }}</p>
      <p v-if="preview" class="node-sub">{{ preview }}</p>
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

.trigger-node .node-icon { background: #fef3c7; color: #92400e; }

.icon-xs { width: 13px; height: 13px; }

.node-body {
  padding: 0.65rem 0.75rem;
  font-size: 0.8rem;
  color: var(--text-main);

  p { margin: 0; }
  .node-sub { color: var(--text-muted); font-size: 0.75rem; margin-top: 0.2rem; }
}
</style>
