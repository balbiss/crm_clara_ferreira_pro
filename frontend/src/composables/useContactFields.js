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

export function useContactFields() {
  carregar()
  const allFields = computed(() => [...ASSIGNABLE_FIELDS, ...customFields.value])
  const labelOf = (key) => allFields.value.find(f => f.key === key)?.label || key
  return { customFields, allFields, labelOf, reloadCustomFields: () => carregar(true) }
}
