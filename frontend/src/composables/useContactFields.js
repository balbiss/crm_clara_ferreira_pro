import { ref, computed } from 'vue'
import api from '../api'
import { ASSIGNABLE_FIELDS } from '../constants/contactFields'

// Campos do painel de contato = 13 fixos + os que a dona criou em
// Configurações → Campos do Contato (ex: grupo "Produtos", 2026-10-09).
// Estado compartilhado entre telas — busca uma vez só.
const customFields = ref([])
let carregando = null

const carregar = (forcar = false) => {
  if (!carregando || forcar) {
    carregando = api.get('/contact_custom_fields')
      .then(({ data }) => { customFields.value = data || [] })
      .catch(e => { console.error('Erro ao buscar campos personalizados:', e); carregando = null })
  }
  return carregando
}

// Tipos (2026-10-16, igual Kommo): texto curto (padrão, inclusive os 13
// fixos), texto longo e seleção múltipla (valor guardado como lista).
export const FIELD_TYPES = [
  { value: 'texto_curto', label: 'Texto curto' },
  { value: 'texto_longo', label: 'Texto longo' },
  { value: 'selecao_multipla', label: 'Seleção múltipla' }
]
export const fieldTypeLabel = (type) => FIELD_TYPES.find(t => t.value === type)?.label || 'Texto curto'

// Valor pra exibir: lista vira "A, B"; vazio vira ''.
export const formatFieldValue = (value) => {
  if (Array.isArray(value)) return value.filter(Boolean).join(', ')
  return value == null ? '' : String(value)
}

export function useContactFields() {
  carregar()
  const allFields = computed(() => [
    ...ASSIGNABLE_FIELDS.map(f => ({ type: 'texto_curto', ...f })),
    ...customFields.value.map(f => ({ ...f, type: f.type || 'texto_curto' }))
  ])
  const labelOf = (key) => allFields.value.find(f => f.key === key)?.label || key
  const fieldOf = (key) => allFields.value.find(f => f.key === key) || { key, label: key, type: 'texto_curto' }
  return { customFields, allFields, labelOf, fieldOf, reloadCustomFields: () => carregar(true) }
}
