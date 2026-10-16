<script setup>
import { ref, onMounted } from 'vue'
import { Plus, Trash2, X } from 'lucide-vue-next'
import api from '../../api'
import Swal from 'sweetalert2'
import { useContactFields, FIELD_TYPES, fieldTypeLabel } from '../../composables/useContactFields'

const { customFields, allFields, labelOf: fieldLabel, reloadCustomFields } = useContactFields()

const groups = ref([])
const isLoading = ref(false)
// Select de "adicionar campo" fica um por grupo (chave = group.id)
const pickerValue = ref({})

const fetchGroups = async () => {
  isLoading.value = true
  try {
    const { data } = await api.get('/contact_field_groups')
    groups.value = data
  } catch (error) {
    console.error('Erro ao buscar grupos de campos:', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(fetchGroups)

// Campos que ainda não estão em NENHUM grupo (pra saber que existe algo
// escondido em "Outros" na tela de conversa, e pra oferecer no seletor).
const unassignedKeys = () => {
  const assigned = new Set(groups.value.flatMap(g => g.field_keys || []))
  return allFields.value.map(f => f.key).filter(k => !assigned.has(k))
}

const groupOwning = (key) => groups.value.find(g => (g.field_keys || []).includes(key))

const addGroup = async () => {
  try {
    const { data } = await api.post('/contact_field_groups', { contact_field_group: { name: 'Novo grupo', field_keys: [] } })
    groups.value.push(data)
  } catch (error) {
    console.error('Erro ao criar grupo:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao criar grupo.', showConfirmButton: false, timer: 3500 })
  }
}

const renameGroup = async (group, newName) => {
  const name = newName.trim()
  if (!name || name === group.name) return
  try {
    await api.put(`/contact_field_groups/${group.id}`, { contact_field_group: { name } })
    group.name = name
  } catch (error) {
    console.error('Erro ao renomear grupo:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao renomear grupo.', showConfirmButton: false, timer: 3500 })
  }
}

const deleteGroup = async (group) => {
  if (!confirm(`Apagar o grupo "${group.name}"? Os campos dele voltam pra "Outros" na tela de conversa, sem perder nenhum dado.`)) return
  try {
    await api.delete(`/contact_field_groups/${group.id}`)
    groups.value = groups.value.filter(g => g.id !== group.id)
  } catch (error) {
    console.error('Erro ao apagar grupo:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao apagar grupo.', showConfirmButton: false, timer: 3500 })
  }
}

const removeFieldFromGroup = async (group, key) => {
  const newKeys = (group.field_keys || []).filter(k => k !== key)
  try {
    await api.put(`/contact_field_groups/${group.id}`, { contact_field_group: { field_keys: newKeys } })
    group.field_keys = newKeys
  } catch (error) {
    console.error('Erro ao remover campo do grupo:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao remover campo.', showConfirmButton: false, timer: 3500 })
  }
}

// Move um campo pra este grupo -- se ele já estava em outro grupo, tira de
// lá primeiro (senão o mesmo campo apareceria duplicado em 2 lugares na
// tela de conversa).
const addFieldToGroup = async (group, key) => {
  if (!key || (group.field_keys || []).includes(key)) return

  const sourceGroup = groupOwning(key)
  try {
    if (sourceGroup && sourceGroup.id !== group.id) {
      const sourceKeys = sourceGroup.field_keys.filter(k => k !== key)
      await api.put(`/contact_field_groups/${sourceGroup.id}`, { contact_field_group: { field_keys: sourceKeys } })
      sourceGroup.field_keys = sourceKeys
    }
    const newKeys = [...(group.field_keys || []), key]
    await api.put(`/contact_field_groups/${group.id}`, { contact_field_group: { field_keys: newKeys } })
    group.field_keys = newKeys
  } catch (error) {
    console.error('Erro ao adicionar campo ao grupo:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao mover campo.', showConfirmButton: false, timer: 3500 })
  } finally {
    pickerValue.value[group.id] = ''
  }
}

// Campo novo/edição (ex: "Mais vende", "Precisa ter na maleta") — com tipo
// (texto curto, texto longo, seleção múltipla com as opções), igual Kommo
// (Clara, 2026-10-16). Depois de criado aparece no "+ Adicionar campo..." de
// qualquer grupo.
const fieldModal = ref(null) // { key|null, label, type, options: [] }
const novaOpcao = ref('')
const isSavingField = ref(false)

const openNewField = () => {
  fieldModal.value = { key: null, label: '', type: 'texto_curto', options: [] }
  novaOpcao.value = ''
}
const openEditField = (f) => {
  fieldModal.value = { key: f.key, label: f.label, type: f.type || 'texto_curto', options: [...(f.options || [])] }
  novaOpcao.value = ''
}
const addOpcao = () => {
  // Aceita várias de uma vez separadas por vírgula ("Brinco, Colar, Anel").
  const novas = novaOpcao.value.split(',').map(o => o.trim()).filter(Boolean)
  novas.forEach(o => { if (!fieldModal.value.options.includes(o)) fieldModal.value.options.push(o) })
  novaOpcao.value = ''
}
const removeOpcao = (o) => {
  fieldModal.value.options = fieldModal.value.options.filter(x => x !== o)
}

const saveField = async () => {
  const f = fieldModal.value
  if (!f || isSavingField.value) return
  if (novaOpcao.value.trim()) addOpcao()
  const label = f.label.trim()
  if (!label) return
  if (f.type === 'selecao_multipla' && f.options.length === 0) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'Adicione pelo menos uma opção.', showConfirmButton: false, timer: 3000 })
    return
  }
  isSavingField.value = true
  try {
    const payload = { label, type: f.type, options: f.type === 'selecao_multipla' ? f.options : [] }
    if (f.key) await api.patch(`/contact_custom_fields/${f.key}`, payload)
    else await api.post('/contact_custom_fields', payload)
    await reloadCustomFields()
    fieldModal.value = null
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: f.key ? 'Campo atualizado.' : `Campo "${label}" criado. Agora coloque ele num grupo.`, showConfirmButton: false, timer: 3500 })
  } catch (error) {
    console.error('Erro ao salvar campo:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: error.response?.data?.message || 'Erro ao salvar campo.', showConfirmButton: false, timer: 3500 })
  } finally {
    isSavingField.value = false
  }
}

const deleteField = async (field) => {
  if (!confirm(`Apagar o campo "${field.label}"? Ele some da tela, mas o que já foi preenchido nas revendedoras não é apagado.`)) return
  try {
    await api.delete(`/contact_custom_fields/${field.key}`)
    await reloadCustomFields()
    groups.value.forEach(g => { g.field_keys = (g.field_keys || []).filter(k => k !== field.key) })
  } catch (error) {
    console.error('Erro ao apagar campo:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao apagar campo.', showConfirmButton: false, timer: 3500 })
  }
}

const optionLabelFor = (key) => {
  const owner = groupOwning(key)
  return owner ? `${fieldLabel(key)} (em: ${owner.name})` : fieldLabel(key)
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-content">
        <div>
          <h1>Campos do Contato</h1>
          <p class="subtitle">Organize os campos comerciais do painel de conversa em grupos. "Dados do Jueri (sincronizado)" não entra aqui -- é sincronizado do ERP e fica sempre separado.</p>
        </div>
        <button class="btn-primary" @click="addGroup">
          <Plus class="icon-sm" /> Novo Grupo
        </button>
      </div>
    </div>

    <div class="group-card custom-fields-card">
      <h3 class="custom-fields-title">Campos criados por você</h3>
      <p class="custom-fields-hint">Precisa de uma informação que não está na lista (ex: "Mais vende", "Precisa ter na maleta")? Crie aqui e depois coloque no grupo que quiser.</p>
      <div class="field-chips">
        <span v-if="customFields.length === 0" class="empty-hint">Nenhum campo criado ainda.</span>
        <span v-for="f in customFields" :key="f.key" class="field-chip field-chip-editable" title="Clique pra editar" @click="openEditField(f)">
          {{ f.label }}
          <span class="chip-type">{{ fieldTypeLabel(f.type) }}</span>
          <button class="chip-remove" title="Apagar campo" @click.stop="deleteField(f)"><X class="icon-xxs" /></button>
        </span>
      </div>
      <button class="btn-primary" type="button" @click="openNewField">
        <Plus class="icon-sm" /> Criar campo
      </button>
    </div>

    <!-- Criar/editar campo: nome + tipo (+ opções da seleção múltipla) -->
    <div v-if="fieldModal" class="modal-overlay" @click.self="fieldModal = null">
      <div class="modal-box">
        <div class="modal-head">
          <h3>{{ fieldModal.key ? 'Editar campo' : 'Novo campo' }}</h3>
          <button class="btn-icon" @click="fieldModal = null"><X class="icon-sm" /></button>
        </div>
        <label class="modal-label">Nome do campo</label>
        <input v-model="fieldModal.label" type="text" class="modal-input" maxlength="60" placeholder="Ex: Mais vende" />

        <label class="modal-label">Tipo</label>
        <div class="type-options">
          <label v-for="t in FIELD_TYPES" :key="t.value" :class="['type-option', { active: fieldModal.type === t.value }]">
            <input type="radio" :value="t.value" v-model="fieldModal.type" />
            <span>{{ t.label }}</span>
          </label>
        </div>
        <p class="type-hint">
          <template v-if="fieldModal.type === 'texto_curto'">Uma linha (ex: tamanho do anel, cidade).</template>
          <template v-else-if="fieldModal.type === 'texto_longo'">Várias linhas, pra observações e detalhes.</template>
          <template v-else>Marca uma ou mais opções da lista (ex: Brinco, Colar, Anel).</template>
        </p>

        <template v-if="fieldModal.type === 'selecao_multipla'">
          <label class="modal-label">Opções</label>
          <div class="field-chips">
            <span v-if="fieldModal.options.length === 0" class="empty-hint">Nenhuma opção ainda.</span>
            <span v-for="o in fieldModal.options" :key="o" class="field-chip">
              {{ o }}
              <button class="chip-remove" @click="removeOpcao(o)"><X class="icon-xxs" /></button>
            </span>
          </div>
          <form class="new-field-row" @submit.prevent="addOpcao">
            <input v-model="novaOpcao" type="text" class="modal-input" placeholder="Nova opção (pode separar várias por vírgula)" />
            <button class="btn-secondary" type="submit" :disabled="!novaOpcao.trim()">Adicionar</button>
          </form>
        </template>

        <div class="modal-actions">
          <button class="btn-secondary" @click="fieldModal = null">Cancelar</button>
          <button class="btn-primary" :disabled="!fieldModal.label.trim() || isSavingField" @click="saveField">Salvar</button>
        </div>
      </div>
    </div>

    <div v-if="isLoading" class="empty-state">Carregando...</div>

    <div v-else class="groups-list">
      <div v-for="group in groups" :key="group.id" class="group-card">
        <div class="group-header">
          <input
            type="text"
            class="group-name-input"
            :value="group.name"
            @change="renameGroup(group, $event.target.value)"
          />
          <button class="btn-icon text-danger" title="Apagar grupo" @click="deleteGroup(group)">
            <Trash2 class="icon-sm" />
          </button>
        </div>

        <div class="field-chips">
          <span v-if="(group.field_keys || []).length === 0" class="empty-hint">Nenhum campo neste grupo ainda.</span>
          <span v-for="key in group.field_keys" :key="key" class="field-chip">
            {{ fieldLabel(key) }}
            <button class="chip-remove" @click="removeFieldFromGroup(group, key)"><X class="icon-xxs" /></button>
          </span>
        </div>

        <select
          class="add-field-select"
          v-model="pickerValue[group.id]"
          @change="addFieldToGroup(group, $event.target.value)"
        >
          <option value="" disabled selected>+ Adicionar campo...</option>
          <option v-for="f in allFields" :key="f.key" :value="f.key">{{ optionLabelFor(f.key) }}</option>
        </select>
      </div>

      <div v-if="groups.length === 0" class="empty-state">Nenhum grupo criado ainda.</div>

      <div v-if="unassignedKeys().length > 0" class="unassigned-hint">
        Campos sem grupo (aparecem em "Outros" na tela de conversa): {{ unassignedKeys().map(fieldLabel).join(', ') }}
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 2rem; background: var(--bg-primary); height: 100%; overflow-y: auto; }
.page-header {
  margin-bottom: 2rem;
  .header-content {
    display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem;
    h1 { font-size: 1.2rem; color: var(--text-main); font-weight: 500; margin: 0 0 0.25rem; }
    .subtitle { font-size: 0.85rem; color: var(--text-muted); margin: 0; max-width: 520px; }
  }
}
.btn-primary {
  display: inline-flex; align-items: center; gap: 0.5rem; background: var(--primary);
  color: white; border: none; padding: 0.6rem 1.2rem; border-radius: 6px; font-weight: 500; cursor: pointer;
  white-space: nowrap;
}
.groups-list { display: flex; flex-direction: column; gap: 1rem; max-width: 640px; }
.group-card {
  background: var(--bg-secondary); border: 1px solid var(--border-color);
  border-radius: 8px; padding: 1.25rem;
  box-shadow: 0 1px 2px rgba(43,0,22,0.06);
}
.group-header {
  display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.9rem;
}
.group-name-input {
  flex: 1; font-size: 1rem; font-weight: 600; color: var(--text-main);
  border: 1px solid transparent; background: transparent; padding: 0.35rem 0.5rem; border-radius: 6px;
  &:hover, &:focus { border-color: var(--border-color); background: var(--bg-primary); outline: none; }
}
.btn-icon {
  background: transparent; border: none; cursor: pointer; padding: 0.5rem; border-radius: 4px;
  display: flex; align-items: center; justify-content: center; color: var(--text-muted);
  &:hover { background: rgba(0,0,0,0.05); }
  &.text-danger:hover { color: #ef4444; background: rgba(239, 68, 68, 0.1); }
}
.field-chips {
  display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 0.9rem; min-height: 1.5rem;
}
.field-chip {
  display: inline-flex; align-items: center; gap: 0.35rem;
  background: rgba(255, 0, 127, 0.08); color: var(--primary);
  padding: 0.3rem 0.6rem; border-radius: 14px; font-size: 0.8rem; font-weight: 500;
}
.chip-remove {
  background: none; border: none; cursor: pointer; color: inherit; display: flex; padding: 0;
  opacity: 0.7;
  &:hover { opacity: 1; }
}
.icon-xxs { width: 12px; height: 12px; }
.empty-hint { font-size: 0.82rem; color: var(--text-muted); font-style: italic; }
.add-field-select {
  width: 100%; padding: 0.5rem 0.75rem; border: 1px solid var(--border-color);
  border-radius: 6px; background: var(--bg-primary); color: var(--text-main); font-size: 0.85rem;
  &:focus { outline: none; border-color: var(--primary); }
}
.empty-state { color: var(--text-muted); font-size: 0.9rem; padding: 1rem 0; }
.unassigned-hint {
  font-size: 0.8rem; color: var(--text-muted); background: var(--bg-secondary);
  border: 1px dashed var(--border-color); border-radius: 8px; padding: 0.75rem 1rem;
}
.custom-fields-card { margin-bottom: 1.5rem; }
.field-chip-editable { cursor: pointer; &:hover { background: rgba(255, 0, 127, 0.14); } }
.chip-type {
  font-size: 0.65rem; font-weight: 600; text-transform: uppercase;
  background: rgba(255,255,255,0.7); color: var(--text-muted); border-radius: 8px; padding: 0 0.35rem;
}
.btn-secondary {
  background: transparent; color: var(--text-main); border: 1px solid var(--border-color);
  padding: 0.55rem 1rem; border-radius: 6px; cursor: pointer; white-space: nowrap;
  &:disabled { opacity: 0.5; cursor: not-allowed; }
}
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.modal-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 1000;
  display: flex; align-items: center; justify-content: center; padding: 1rem;
}
.modal-box {
  background: var(--bg-secondary); border-radius: 10px; padding: 1.25rem 1.5rem;
  width: 100%; max-width: 460px; max-height: 90vh; overflow-y: auto;
  box-shadow: 0 10px 25px rgba(0,0,0,0.15);
}
.modal-head {
  display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;
  h3 { margin: 0; font-size: 1.05rem; color: var(--text-main); }
}
.modal-label { display: block; font-size: 0.85rem; font-weight: 600; color: var(--text-main); margin: 0.75rem 0 0.4rem; }
.modal-input {
  width: 100%; padding: 0.55rem 0.75rem; border: 1px solid var(--border-color); border-radius: 6px;
  background: var(--bg-primary); color: var(--text-main); font-size: 0.9rem;
  &:focus { outline: none; border-color: var(--primary); }
}
.type-options { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.type-option {
  display: inline-flex; align-items: center; gap: 0.35rem; padding: 0.45rem 0.75rem;
  border: 1px solid var(--border-color); border-radius: 6px; cursor: pointer; font-size: 0.85rem; color: var(--text-main);
  &.active { border-color: var(--primary); background: rgba(255, 0, 127, 0.05); }
}
.type-hint { font-size: 0.78rem; color: var(--text-muted); margin: 0.4rem 0 0; }
.modal-actions { display: flex; justify-content: flex-end; gap: 0.5rem; margin-top: 1.25rem; }
.custom-fields-title { margin: 0 0 0.25rem; font-size: 1rem; color: var(--text-main); }
.custom-fields-hint { margin: 0 0 0.75rem; font-size: 0.85rem; color: var(--text-muted); }
.new-field-row { display: flex; gap: 0.5rem; margin-top: 0.75rem; align-items: center; }
.new-field-row .group-name-input { flex: 1; }
</style>
