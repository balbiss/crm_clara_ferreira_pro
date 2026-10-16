<script setup>
// Valor de um campo do contato no painel da conversa: mostra e edita com 1
// clique, do jeito certo pra cada tipo (Clara, 2026-10-16, igual Kommo):
// texto curto (input), texto longo (caixa de várias linhas) e seleção
// múltipla (lista de opções pra marcar — salva como lista).
import { ref, computed, nextTick } from 'vue'
import { formatFieldValue } from '../composables/useContactFields'

const props = defineProps({
  field: { type: Object, required: true },
  value: { default: null }
})
const emit = defineEmits(['save'])

const editing = ref(false)
const draft = ref('')
const inputRef = ref(null)

const tipo = computed(() => props.field.type || 'texto_curto')
const exibido = computed(() => formatFieldValue(props.value))

// Seleção múltipla: opções do campo + valores antigos que não estão mais
// nas opções (não some com dado já preenchido).
const selecionados = computed(() => (Array.isArray(props.value) ? props.value : (props.value ? [String(props.value)] : [])))
const opcoes = computed(() => {
  const base = props.field.options || []
  return [...base, ...selecionados.value.filter(v => !base.includes(v))]
})

const abrir = () => {
  if (tipo.value === 'selecao_multipla') { editing.value = true; return }
  draft.value = exibido.value
  editing.value = true
  nextTick(() => inputRef.value?.focus())
}

const salvarTexto = () => {
  if (!editing.value) return
  editing.value = false
  const novo = draft.value.trim()
  if (novo === exibido.value.trim()) return
  emit('save', novo || null)
}

const alternar = (opcao) => {
  const atual = selecionados.value
  const novo = atual.includes(opcao) ? atual.filter(v => v !== opcao) : [...atual, opcao]
  emit('save', novo.length ? novo : null)
}
</script>

<template>
  <div class="cfe">
    <template v-if="editing && tipo === 'texto_curto'">
      <input
        ref="inputRef"
        v-model="draft"
        class="cfe-input"
        @keydown.enter.prevent="salvarTexto"
        @keydown.esc.prevent="editing = false"
        @blur="salvarTexto"
      />
    </template>

    <template v-else-if="editing && tipo === 'texto_longo'">
      <textarea
        ref="inputRef"
        v-model="draft"
        rows="4"
        class="cfe-input cfe-textarea"
        @keydown.ctrl.enter.prevent="salvarTexto"
        @keydown.esc.prevent="editing = false"
        @blur="salvarTexto"
      ></textarea>
      <span class="cfe-hint">Clique fora pra salvar · Esc cancela</span>
    </template>

    <template v-else-if="editing && tipo === 'selecao_multipla'">
      <div class="cfe-options">
        <label v-for="op in opcoes" :key="op" class="cfe-option">
          <input type="checkbox" :checked="selecionados.includes(op)" @change="alternar(op)" />
          <span>{{ op }}</span>
        </label>
        <p v-if="opcoes.length === 0" class="cfe-hint">Esse campo ainda não tem opções. Cadastre em Configurações → Campos do Contato.</p>
        <button type="button" class="cfe-done" @click="editing = false">Pronto</button>
      </div>
    </template>

    <template v-else>
      <span v-if="tipo === 'selecao_multipla' && selecionados.length" class="cfe-value cfe-editable cfe-chips" title="Clique pra editar" @click="abrir">
        <span v-for="v in selecionados" :key="v" class="cfe-chip">{{ v }}</span>
      </span>
      <span
        v-else
        class="cfe-value cfe-editable"
        :class="{ empty: !exibido, longo: tipo === 'texto_longo' }"
        title="Clique pra preencher"
        @click="abrir"
      >{{ exibido || 'Clique pra preencher' }}</span>
    </template>
  </div>
</template>

<style scoped>
.cfe { min-width: 0; }
.cfe-value {
  color: var(--text-main);
  font-weight: 500;
  overflow-wrap: break-word;
}
.cfe-value.empty { color: var(--text-muted); font-weight: 400; font-style: italic; }
.cfe-value.longo { white-space: pre-wrap; }
.cfe-editable {
  display: inline-block;
  cursor: pointer;
  border-radius: 4px;
  padding: 1px 4px;
  margin: -1px -4px;
}
.cfe-editable:hover { background: #fdf2f8; }
.cfe-input {
  width: 100%;
  font-size: 0.78rem;
  padding: 2px 6px;
  border: 1px solid #ff007f;
  border-radius: 4px;
  outline: none;
  min-width: 0;
  font-family: inherit;
}
.cfe-textarea { resize: vertical; padding: 4px 6px; }
.cfe-hint { display: block; font-size: 0.68rem; color: var(--text-muted); margin-top: 2px; }
.cfe-chips { display: inline-flex; flex-wrap: wrap; gap: 4px; }
.cfe-chip {
  background: rgba(255, 0, 127, 0.08);
  color: #cc0066;
  border-radius: 10px;
  padding: 1px 8px;
  font-size: 0.72rem;
  font-weight: 600;
}
.cfe-options {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 6px 8px;
  border: 1px solid #ff007f;
  border-radius: 6px;
  background: var(--bg-secondary, #fff);
}
.cfe-option { display: flex; align-items: center; gap: 6px; font-size: 0.78rem; cursor: pointer; }
.cfe-done {
  align-self: flex-end;
  margin-top: 2px;
  padding: 2px 10px;
  border: none;
  border-radius: 4px;
  background: #ff007f;
  color: #fff;
  font-size: 0.72rem;
  cursor: pointer;
}
</style>
