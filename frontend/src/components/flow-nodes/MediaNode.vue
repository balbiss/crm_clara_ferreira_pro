<script setup>
import { computed } from 'vue'
import { Handle, Position } from '@vue-flow/core'
import { Image, Video, Mic, FileText } from '@lucide/vue'

const props = defineProps({ data: { type: Object, default: () => ({}) }, selected: { type: Boolean, default: false } })

const ICONS = { image: Image, video: Video, audio: Mic, document: FileText }
const LABELS = { image: 'Enviar imagem', video: 'Enviar vídeo', audio: 'Enviar áudio', document: 'Enviar documento' }
const icon = computed(() => ICONS[props.data.media_type] || Image)
const label = computed(() => LABELS[props.data.media_type] || 'Enviar mídia')
</script>

<template>
  <div class="flow-node media-node" :class="{ selected }">
    <Handle type="target" :position="Position.Top" />
    <div class="node-header">
      <div class="node-icon"><component :is="icon" class="icon-xs" /></div>
      <span>{{ label }}</span>
    </div>
    <div class="node-body">
      <img v-if="data.media_type === 'image' && data.media_url" :src="data.media_url" class="node-thumb" alt="preview" />
      <p v-else-if="data.media_url">Arquivo enviado ✓</p>
      <p v-else-if="data.url">{{ data.url }}</p>
      <p v-else class="node-empty">Clique pra definir o arquivo...</p>
      <p v-if="data.caption" class="node-sub">"{{ data.caption }}"</p>
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
  background: #fce7f3;
  color: #9d174d;
}

.icon-xs { width: 13px; height: 13px; }

.node-body {
  padding: 0.65rem 0.75rem;
  font-size: 0.8rem;
  color: var(--text-main);
  word-break: break-word;

  p { margin: 0; }
  .node-empty { color: var(--text-muted); font-style: italic; }
  .node-sub { color: var(--text-muted); font-size: 0.75rem; margin-top: 0.35rem; }
  .node-thumb { width: 100%; max-height: 100px; object-fit: cover; border-radius: 6px; }
}
</style>
