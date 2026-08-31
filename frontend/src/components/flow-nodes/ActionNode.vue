<script setup>
import { computed } from 'vue'
import { Handle, Position } from '@vue-flow/core'
import { Tag, TagIcon, UserCheck, Webhook, Variable } from '@lucide/vue'

const props = defineProps({ data: { type: Object, default: () => ({}) }, selected: { type: Boolean, default: false } })

const ICONS = { add_tag: Tag, remove_tag: TagIcon, assign_agent: UserCheck, update_variable: Variable, send_webhook: Webhook }
const LABELS = {
  add_tag: 'Adicionar etiqueta',
  remove_tag: 'Remover etiqueta',
  assign_agent: 'Atribuir atendente',
  update_variable: 'Atualizar variável',
  send_webhook: 'Enviar webhook'
}
const icon = computed(() => ICONS[props.data.action_type] || Tag)
const label = computed(() => LABELS[props.data.action_type] || 'Ação')

const preview = computed(() => {
  const d = props.data
  switch (d.action_type) {
    case 'add_tag':
    case 'remove_tag':
      return d.tag_name || null
    case 'assign_agent':
      return d.agent_name || null
    case 'update_variable':
      return d.variable ? `${d.variable} = ${d.value || ''}` : null
    case 'send_webhook':
      return d.url || null
    default:
      return null
  }
})
</script>

<template>
  <div class="flow-node action-node" :class="{ selected }">
    <Handle type="target" :position="Position.Top" />
    <div class="node-header">
      <div class="node-icon"><component :is="icon" class="icon-xs" /></div>
      <span>{{ label }}</span>
    </div>
    <div class="node-body">
      <p v-if="preview">{{ preview }}</p>
      <p v-else class="node-empty">Clique pra configurar...</p>
    </div>
    <Handle type="source" :position="Position.Bottom" />
  </div>
</template>

<style lang="scss" scoped>
.flow-node {
  min-width: 210px;
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
  background: #dcfce7;
  color: #166534;
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
</style>
