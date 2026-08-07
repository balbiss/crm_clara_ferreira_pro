<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search, Package, MessageCircle } from '@lucide/vue'
import Swal from 'sweetalert2'
import { useContactsStore } from '../store/contacts'
import { useConversationsStore } from '../store/conversations'

// Clientes "Atacado" do Jueri (compra à vista, fora do modelo consignado) —
// são clientes de verdade da empresa, só que fora da régua de revenda
// consignada, por isso ficam numa tela separada em vez de misturar com a
// carteira de revendedoras (ver JueriSyncService#sincronizar_atacado).
const router = useRouter()
const contactsStore = useContactsStore()
const convStore = useConversationsStore()

const isLoading = ref(true)
const searchQuery = ref('')

const atacadoContacts = computed(() => contactsStore.contacts.filter(c => c.status === 'atacado'))

const filteredContacts = computed(() => {
  let list = atacadoContacts.value
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(c =>
      (c.name || `${c.first_name || ''} ${c.last_name || ''}`).toLowerCase().includes(q) ||
      (c.phone || '').includes(q)
    )
  }
  return list
})

const openContact = (contact) => router.push(`/contatos/${contact.id}`)

const isStartingConversation = ref(null)
const startConversation = async (contact) => {
  isStartingConversation.value = contact.id
  try {
    const conv = await convStore.startConversation(contact.id)
    router.push(`/conversas?abrir=${conv.id}`)
  } catch (e) {
    console.error('Erro ao iniciar conversa:', e)
    const msg = e.response?.data?.message || 'Erro ao iniciar conversa.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 3500 })
  } finally {
    isStartingConversation.value = null
  }
}

onMounted(async () => {
  isLoading.value = true
  try {
    if (!contactsStore.isLoadedOnce) await contactsStore.fetchContacts()
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <div class="atacado-page">
    <div class="page-header">
      <div class="title-block">
        <h1>Atacado</h1>
        <p>Clientes de compra à vista, fora do modelo consignado — {{ filteredContacts.length }} cliente{{ filteredContacts.length === 1 ? '' : 's' }}</p>
      </div>
    </div>

    <div class="toolbar">
      <div class="search-box">
        <Search class="icon-sm" />
        <input v-model="searchQuery" type="text" placeholder="Buscar por nome ou telefone..." />
      </div>
    </div>

    <div class="table-wrapper">
      <table v-if="!isLoading && filteredContacts.length > 0" class="atacado-table">
        <thead>
          <tr>
            <th>Cliente</th>
            <th>Telefone</th>
            <th>Cidade</th>
            <th>Ação</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in filteredContacts" :key="c.id" @click="openContact(c)">
            <td class="cell-name">
              <div class="row-avatar"><Package class="icon-xs" /></div>
              <span>{{ c.name || `${c.first_name || ''} ${c.last_name || ''}`.trim() || 'Sem nome' }}</span>
            </td>
            <td>{{ c.phone || '...' }}</td>
            <td>{{ c.city || '...' }}</td>
            <td @click.stop>
              <button
                class="btn-start-conversation"
                :disabled="isStartingConversation === c.id"
                @click="startConversation(c)"
                title="Iniciar conversa no WhatsApp"
              >
                <MessageCircle class="icon-xs" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>

      <div v-else-if="isLoading" class="empty-state">
        <p>Carregando...</p>
      </div>

      <div v-else class="empty-state">
        <div class="empty-icon"><Package :size="28" /></div>
        <h3>Nenhum cliente de atacado encontrado</h3>
        <p>Aparece automaticamente depois da próxima sincronização com o Jueri.</p>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.atacado-page { padding: 1.5rem 2rem; height: 100%; overflow-y: auto; }

.page-header {
  margin-bottom: 1.25rem;
  h1 { font-size: 1.35rem; font-weight: 700; color: var(--text-main); }
  p { font-size: 0.85rem; color: var(--text-muted); margin-top: 0.25rem; }
}

.toolbar { display: flex; gap: 0.75rem; margin-bottom: 1.25rem; }

.search-box {
  display: flex; align-items: center; gap: 0.5rem;
  background: var(--bg-secondary); border: 1px solid var(--border-color);
  border-radius: 8px; padding: 0.5rem 0.75rem; min-width: 260px;

  .icon-sm { width: 16px; height: 16px; color: var(--text-muted); }
  input { border: none; outline: none; background: transparent; color: var(--text-main); font-size: 0.85rem; flex: 1; }
}

.table-wrapper {
  background: var(--bg-secondary); border: 1px solid var(--border-color);
  border-radius: 10px; overflow-x: auto;
}

.atacado-table {
  width: 100%; border-collapse: collapse; font-size: 0.85rem;

  thead th {
    text-align: left; padding: 0.75rem 1rem; font-size: 0.72rem; font-weight: 700;
    text-transform: uppercase; letter-spacing: 0.03em; color: var(--text-muted);
    background: var(--bg-tertiary); border-bottom: 1px solid var(--border-color);
  }

  tbody tr {
    cursor: pointer; transition: background 0.15s; border-bottom: 1px solid var(--border-color);
    &:hover { background: var(--bg-hover); }
    &:last-child { border-bottom: none; }
  }

  td { padding: 0.7rem 1rem; color: var(--text-main); white-space: nowrap; }

  .cell-name { display: flex; align-items: center; gap: 0.6rem; font-weight: 600; }

  .row-avatar {
    width: 30px; height: 30px; border-radius: 50%; background: #f59e0b; color: white;
    display: flex; align-items: center; justify-content: center; flex-shrink: 0;
  }
}

.btn-start-conversation {
  display: flex; align-items: center; justify-content: center; width: 30px; height: 30px;
  border-radius: 6px; border: 1px solid var(--border-color); background: var(--bg-secondary);
  color: var(--primary); cursor: pointer;
  &:hover:not(:disabled) { background: var(--primary); color: white; }
  &:disabled { opacity: 0.5; cursor: not-allowed; }
}

.empty-state {
  padding: 3rem 1.5rem; text-align: center; color: var(--text-muted);
  .empty-icon {
    width: 56px; height: 56px; border-radius: 16px; background: var(--bg-tertiary); color: #f59e0b;
    display: flex; align-items: center; justify-content: center; margin: 0 auto 1rem;
  }
  h3 { font-size: 1rem; font-weight: 700; color: var(--text-main); margin-bottom: 0.4rem; }
  p { font-size: 0.85rem; }
}

.icon-xs { width: 16px; height: 16px; }
</style>
