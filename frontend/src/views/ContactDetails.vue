<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Activity, AtSign, Phone, Plus, X, Edit2, ExternalLink } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'
import EditContactModal from '../components/EditContactModal.vue'
import { useConversationsStore } from '../store/conversations'
import { statusLabel } from '../constants/regua'
import { relativeTimeBR } from '../utils/relativeTime'

const route = useRoute()
const router = useRouter()
const convStore = useConversationsStore()
const contact = ref(null)
const isLoading = ref(true)

// Notas/Biografia é a área principal dessa tela (pedido explícito do
// cliente) — fica como primeira aba, aberta por padrão.
const activeTab = ref('Notas')
const tabs = ['Notas', 'Cadastro', 'Informações', 'Histórico', 'Mesclar']
const isEditModalOpen = ref(false)
const closeEditModal = () => {
  isEditModalOpen.value = false
  fetchContact()
}

// Telefone sem "+55" — o link "abrir no Jueri" já deixa claro que é um
// cadastro brasileiro, redundante repetir o DDI aqui.
const formatPhoneDisplay = (phone) => {
  if (!phone) return null
  return phone.replace(/^\+?55/, '').trim() || phone
}

// URL do próprio Jueri (cadastro de revendedor). Dados sincronizados do
// Jueri não são mais editáveis por aqui — quem precisar mudar algo faz
// direto no Jueri, e esse link abre o cadastro certo numa aba nova.
const jueriCadastroUrl = computed(() => {
  const id = contact.value?.id_jueri
  return id ? `https://claraferreira.jueri.com.br/sis/cadastro/revendedor/${id}` : null
})

// Histórico de transferência de responsável e mudança de status (briefing
// seção 22) — vem pronto em contact.contact_audit_events (Contact model
// registra sozinho via callback, ver backend). from/to de "responsavel" são
// ids de User em string — resolve nome pela lista de agentes da conta.
const agentsById = computed(() => {
  const map = {}
  ;(convStore.agents || []).forEach(a => { map[a.id] = `${a.first_name || ''} ${a.last_name || ''}`.trim() })
  return map
})
const agentName = (id) => id ? (agentsById.value[id] || `Usuário #${id}`) : 'Ninguém'

const auditEvents = computed(() => {
  return [...(contact.value?.contact_audit_events || [])].sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
})

const auditEventLabel = (e) => {
  if (e.event_type === 'status') {
    const from = e.from_value ? statusLabel(e.from_value) : 'Nenhum'
    const to = e.to_value ? statusLabel(e.to_value) : 'Nenhum'
    return `Status alterado de "${from}" para "${to}"`
  }
  return `Responsável alterado de "${agentName(e.from_value)}" para "${agentName(e.to_value)}"`
}

const auditEventAuthor = (e) => e.changed_by ? `${e.changed_by.first_name || ''} ${e.changed_by.last_name || ''}`.trim() : 'Sistema (sincronização automática)'

// Fetch Contact
const fetchContact = async () => {
  isLoading.value = true
  try {
    const response = await api.get(`/contacts/${route.params.id}`)
    contact.value = response.data
    bioDraft.value = contact.value.bio || ''
  } catch (error) {
    console.error('Error fetching contact:', error)
    Swal.fire({ icon: 'error', title: 'Erro', text: 'Contato não encontrado.' })
    router.push('/contatos')
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  fetchContact()
  if (!convStore.agents.length) convStore.fetchAgents()
})

// Biografia — junto com Notas, é a área principal da tela (pedido do
// cliente). Salva sozinha, sem precisar do resto do formulário de edição
// (que foi removido — dados sincronizados do Jueri não são mais editáveis
// por aqui, ver jueriCadastroUrl acima).
const bioDraft = ref('')
const isSavingBio = ref(false)
const saveBio = async () => {
  if (!contact.value) return
  isSavingBio.value = true
  try {
    await api.put(`/contacts/${contact.value.id}`, { contact: { bio: bioDraft.value } })
    contact.value.bio = bioDraft.value
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Biografia salva!', showConfirmButton: false, timer: 2000 })
  } catch (error) {
    console.error('Erro ao salvar biografia:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao salvar biografia.', showConfirmButton: false, timer: 3000 })
  } finally {
    isSavingBio.value = false
  }
}

// "Enviar mensagem"/"Bloquear contato" no topo da página — existiam sem
// nenhum @click, não faziam nada (reclamação real). Mesmo padrão de
// RevendedorasAtivas.vue/TarefasView.vue pro primeiro; block/unblock já
// tinha rota no backend, só faltava usar aqui.
const isStartingConversation = ref(false)
const startConversation = async () => {
  if (!contact.value) return
  isStartingConversation.value = true
  try {
    const conv = await convStore.startConversation(contact.value.id)
    router.push(`/conversas?abrir=${conv.id}`)
  } catch (e) {
    console.error('Erro ao iniciar conversa:', e)
    const msg = e.response?.data?.message || 'Erro ao iniciar conversa.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 3500 })
  } finally {
    isStartingConversation.value = false
  }
}

const isTogglingBlock = ref(false)
const toggleBlockContact = async () => {
  if (!contact.value) return
  const bloqueando = contact.value.status !== 'blocked'
  const result = await Swal.fire({
    title: bloqueando ? 'Bloquear contato?' : 'Desbloquear contato?',
    text: bloqueando ? 'Mensagens desse contato vão parar de gerar resposta automática.' : 'O contato volta a poder ser atendido normalmente.',
    icon: 'warning',
    showCancelButton: true,
    confirmButtonText: bloqueando ? 'Sim, bloquear' : 'Sim, desbloquear',
    cancelButtonText: 'Cancelar'
  })
  if (!result.isConfirmed) return

  isTogglingBlock.value = true
  try {
    await api.patch(`/contacts/${contact.value.id}/${bloqueando ? 'block' : 'unblock'}`)
    contact.value.status = bloqueando ? 'blocked' : 'active'
  } catch (e) {
    console.error('Erro ao bloquear/desbloquear contato:', e)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Não foi possível atualizar o bloqueio.', showConfirmButton: false, timer: 3500 })
  } finally {
    isTogglingBlock.value = false
  }
}

const criadoAtividadeTexto = computed(() => {
  if (!contact.value) return ''
  const criado = relativeTimeBR(contact.value.created_at) || 'data desconhecida'
  const atividade = relativeTimeBR(contact.value.ultima_interacao_em)
  return atividade ? `Criado ${criado} • Última atividade ${atividade}` : `Criado ${criado} • Sem atividade ainda`
})

// Avatar Logic
const getInitials = (name) => {
  if (!name) return '?'
  return name.substring(0, 2).toUpperCase()
}

const colors = [
  { bg: '#dbeafe', color: '#1e40af' }, // Blue
  { bg: '#d1fae5', color: '#065f46' }, // Green
  { bg: '#fee2e2', color: '#991b1b' }, // Red
  { bg: '#fef3c7', color: '#92400e' }, // Yellow
  { bg: '#f3e8ff', color: '#6b21a8' }  // Purple
]

const getAvatarStyle = (name) => {
  if (!name) return { backgroundColor: '#e5e7eb', color: '#4b5563' }
  const index = name.charCodeAt(0) % colors.length
  return {
    backgroundColor: colors[index].bg,
    color: colors[index].color
  }
}

// Cadastro completo vindo do Jueri (mesmos campos exibidos na aba "Dados" de
// Conversas.vue) — mostrado só leitura na aba "Cadastro" (edição de dado
// sincronizado do Jueri não é mais permitida por aqui, ver jueriCadastroUrl).
const dadosFields = [
  { key: 'cpf', label: 'CPF', source: 'contact' },
  { key: 'birth_date', label: 'Data de Nascimento', source: 'contact', format: 'date' },
  { key: 'nivel', label: 'Nível', source: 'contact' },
  { key: 'instagram', label: 'Instagram', source: 'attr' },
  { key: 'id_jueri', label: 'ID Jueri (ERP)', source: 'attr' },
  { key: 'origem', label: 'Origem do lead', source: 'attr' },
  { key: 'gerente_jueri_nome', label: 'Gerente no Jueri', source: 'attr' },
  { key: 'gerente_jueri_id', label: 'ID do Gerente no Jueri', source: 'attr' },
  { key: 'supervisor_nome', label: 'Supervisor no Jueri', source: 'attr' },
  { key: 'rg', label: 'RG', source: 'attr' },
  { key: 'profissao', label: 'Profissão', source: 'attr' },
  { key: 'razao_social', label: 'Razão Social', source: 'attr' },
  { key: 'nome_fantasia', label: 'Nome Fantasia', source: 'attr' },
  { key: 'cnpj', label: 'CNPJ', source: 'attr' },
  { key: 'meta', label: 'Meta Mensal', source: 'attr' },
  { key: 'observacao_jueri', label: 'Observação (Jueri)', source: 'attr' },
  { key: 'observacao_interna_jueri', label: 'Observação Interna (Jueri)', source: 'attr' },
  { key: 'data_inativacao_jueri', label: 'Data de Inativação (Jueri)', source: 'attr', format: 'date' },
]
// "2026-11-01" sem hora é interpretado como meia-noite UTC — em GMT-3 isso
// volta pro dia anterior no toLocaleDateString. Forçando T00:00:00 (sem Z)
// o JS trata como horário local, sem esse deslocamento de 1 dia (era o bug
// da data de nascimento aparecendo 1 dia a menos).
const getDadoValue = (f) => {
  if (!contact.value) return null
  const raw = f.source === 'attr' ? contact.value.custom_attributes?.[f.key] : contact.value[f.key]
  if (!raw) return null
  if (f.format !== 'date') return raw
  const d = new Date(String(raw).includes('T') ? raw : `${raw}T00:00:00`)
  return Number.isNaN(d.getTime()) ? raw : d.toLocaleDateString('pt-BR')
}
const dadosPreenchidos = computed(() => dadosFields.filter(f => getDadoValue(f)))

// "Informações" (antes "Atributos") mostra só campo LIVRE, criado pela
// própria equipe — os campos acima (dadosFields) já são sincronizados do
// Jueri e têm sua própria aba ("Cadastro"), não devem aparecer duplicados
// aqui. Mesma lista de chaves reservadas do EditContactModal.
const RESERVED_CUSTOM_KEYS = [
  'venda', 'proximo_agendamento', 'limite_inicial', 'dia_fechamento', 'data_agendamento',
  'obs_fechamento', 'dia_pf_fechamento', 'horario_fechamento', 'atraso', 'observacao_mes',
  'meta', 'desafio_combinado', 'como_chegar_meta',
  'instagram', 'id_jueri', 'origem',
  'gerente_jueri_id', 'gerente_jueri_nome', 'supervisor_nome',
  'rg', 'profissao', 'razao_social', 'nome_fantasia', 'cnpj',
  'observacao_jueri', 'observacao_interna_jueri', 'data_inativacao_jueri',
  'pedidos', 'telefones_adicionais'
]
const informacoesPersonalizadas = computed(() => {
  const custom = contact.value?.custom_attributes || {}
  return Object.keys(custom)
    .filter(k => !RESERVED_CUSTOM_KEYS.includes(k) && custom[k])
    .map(k => ({ key: k, value: custom[k] }))
})

const newNote = ref('')
const selectedNote = ref(null)
const showNoteModal = ref(false)

const openNote = (note) => {
  selectedNote.value = note
  showNoteModal.value = true
}

const closeNoteModal = () => {
  showNoteModal.value = false
  selectedNote.value = null
}

const saveNote = async () => {
  if (!newNote.value.trim()) return
  try {
    const response = await api.post(`/contacts/${route.params.id}/add_note`, {
      content: newNote.value
    })
    
    if (!contact.value.notes) {
      contact.value.notes = []
    }
    contact.value.notes.unshift(response.data)
    newNote.value = ''
    
    Swal.fire({
      icon: 'success',
      title: 'Nota salva!',
      timer: 1500,
      showConfirmButton: false
    })
  } catch (error) {
    console.error('Erro ao salvar nota', error)
  }
}

// Etiquetas da revendedora (Contact) — separado de conversation_tags (que
// etiqueta uma conversa específica): muita revendedora sincronizada do Jueri
// nunca trocou mensagem, não teria onde pendurar tag se fosse por conversa.
const isTagInputOpen = ref(false)
const newTagName = ref('')
const TAG_COLORS = ['#6b7280', '#ef4444', '#f59e0b', '#10b981', '#3b82f6', '#8b5cf6', '#ec4899']
const newTagColor = ref(TAG_COLORS[0])

const addTag = async () => {
  const name = newTagName.value.trim()
  if (!name || !contact.value) return
  try {
    const { data } = await api.post(`/contacts/${contact.value.id}/tags`, { name, color: newTagColor.value })
    if (!contact.value.tags) contact.value.tags = []
    if (!contact.value.tags.some(t => t.id === data.id)) contact.value.tags.push(data)
    newTagName.value = ''
    newTagColor.value = TAG_COLORS[0]
    isTagInputOpen.value = false
  } catch (error) {
    console.error('Erro ao adicionar etiqueta:', error)
    const msg = error.response?.data?.message || 'Erro ao adicionar etiqueta.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 3500 })
  }
}

const removeTag = async (tagId) => {
  if (!contact.value) return
  try {
    await api.delete(`/contacts/${contact.value.id}/tags/${tagId}`)
    contact.value.tags = (contact.value.tags || []).filter(t => t.id !== tagId)
  } catch (error) {
    console.error('Erro ao remover etiqueta:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao remover etiqueta.', showConfirmButton: false, timer: 3000 })
  }
}

</script>

<template>
  <div class="view-wrapper" style="height: 100%;">
    <div class="page-container" v-if="contact">
    <div class="page-header">
      <div class="header-left">
        <router-link to="/contatos" class="breadcrumb-link">Contatos</router-link>
        <span class="breadcrumb-separator">&gt;</span>
        <span class="breadcrumb-current">{{ contact.name }}</span>
      </div>
      <div class="header-actions">
        <button class="btn-secondary" :disabled="isTogglingBlock" @click="toggleBlockContact">
          {{ contact.status === 'blocked' ? 'Desbloquear contato' : 'Bloquear contato' }}
        </button>
        <button class="btn-primary" :disabled="isStartingConversation" @click="startConversation">
          {{ isStartingConversation ? 'Abrindo...' : 'Enviar mensagem' }}
        </button>
      </div>
    </div>

    <div class="content-grid">
      <!-- Left Pane -->
      <div class="left-pane">
        <div class="profile-header">
          <div class="avatar-large" :style="getAvatarStyle(contact.name)" v-if="!contact.avatar_url">
            {{ getInitials(contact.name) }}
          </div>
          <img :src="contact.avatar_url" alt="Avatar" class="avatar-large" style="object-fit: cover;" v-else />
          <h2 class="profile-name">{{ contact.name }}</h2>
          <div class="profile-meta">
            <div class="meta-item"><Phone class="icon-xs" /> {{ formatPhoneDisplay(contact.phone) || 'Sem telefone' }}</div>
            <div class="meta-item"><AtSign class="icon-xs" /> {{ contact.email || 'Sem e-mail' }}</div>
            <div class="meta-item"><Activity class="icon-xs" /> {{ criadoAtividadeTexto }}</div>
          </div>
          <div class="tags-row">
            <span v-for="tag in contact.tags" :key="tag.id" class="tag-chip" :style="{ background: tag.color }">
              {{ tag.name }}
              <button class="tag-remove" @click="removeTag(tag.id)" title="Remover etiqueta">×</button>
            </span>
            <div class="tag-add-box" v-if="isTagInputOpen">
              <div class="tag-add-inline">
                <input
                  v-model="newTagName"
                  @keyup.enter="addTag"
                  @keyup.esc="isTagInputOpen = false"
                  placeholder="Nova etiqueta..."
                  class="tag-input"
                  autofocus
                />
                <button class="btn-add-tag" @click="addTag" :disabled="!newTagName.trim()">OK</button>
              </div>
              <div class="tag-color-picker">
                <button
                  v-for="c in TAG_COLORS"
                  :key="c"
                  class="tag-color-dot"
                  :class="{ active: newTagColor === c }"
                  :style="{ background: c }"
                  @click="newTagColor = c"
                  :title="c"
                ></button>
              </div>
            </div>
            <button class="btn-tag" v-else @click="isTagInputOpen = true"><Plus class="icon-xs" /> etiqueta</button>
          </div>
        </div>

        <!-- Dados sincronizados do Jueri não são mais editáveis por aqui —
             quem precisar mudar algo faz direto no cadastro do Jueri. -->
        <a v-if="jueriCadastroUrl" :href="jueriCadastroUrl" target="_blank" rel="noopener" class="jueri-link-btn">
          <ExternalLink class="icon-xs" /> Abrir cadastro no Jueri
        </a>
      </div>

      <!-- Right Pane -->
      <div class="right-pane">
        <div class="tabs-header">
          <button 
            v-for="tab in tabs" 
            :key="tab" 
            class="tab-btn" 
            :class="{ active: activeTab === tab }"
            @click="activeTab = tab"
          >
            {{ tab }}
          </button>
        </div>
        <div class="tab-content">
          <!-- Tab Notas: área principal da tela, junto com a Biografia -->
          <div v-show="activeTab === 'Notas'" class="notas-tab">
            <div class="bio-section">
              <h4 class="bio-title">Biografia</h4>
              <textarea v-model="bioDraft" placeholder="Particularidades da revendedora: preferências, histórico, coisas pra lembrar no próximo atendimento..." rows="3"></textarea>
              <button class="btn-primary" style="margin-top: 0.6rem;" @click="saveBio" :disabled="isSavingBio || bioDraft === (contact.bio || '')">
                {{ isSavingBio ? 'Salvando...' : 'Salvar biografia' }}
              </button>
            </div>

            <div class="notes-input-area" style="margin-top: 1.75rem;">
              <textarea v-model="newNote" placeholder="Adicione uma nota sobre este contato..." rows="3"></textarea>
              <button class="btn-primary" @click="saveNote" :disabled="!newNote.trim()">Salvar Nota</button>
            </div>

            <div class="notes-list-compact" v-if="contact.notes && contact.notes.length > 0" style="margin-top: 1.5rem;">
              <div class="note-list-item" v-for="note in contact.notes" :key="note.id" @click="openNote(note)">
                <div class="note-content-row">
                  <span class="note-author">{{ note.user ? (note.user.first_name || note.user.name) : 'Usuário' }}</span>
                  <span class="note-preview-inline">- {{ note.content }}</span>
                </div>
                <span class="note-date">{{ new Date(note.created_at).toLocaleDateString('pt-BR') }}</span>
              </div>
            </div>
            <p class="empty-state-text" v-else style="margin-top: 1rem;">Nenhuma nota encontrada.</p>
          </div>

          <!-- Tab Cadastro: dados sincronizados do Jueri, só leitura -->
          <div v-show="activeTab === 'Cadastro'" class="attrs-tab">
            <div class="attrs-list" v-if="dadosPreenchidos.length > 0">
              <div class="attr-row" v-for="f in dadosPreenchidos" :key="f.key">
                <span class="attr-label">{{ f.label }}</span>
                <span class="attr-value">{{ getDadoValue(f) }}</span>
              </div>
            </div>
            <p class="empty-state-text" v-else>
              Nenhum dado cadastral disponível ainda. Revendedoras sincronizadas do Jueri recebem esses dados automaticamente — se essa revendedora já existia antes da sincronização, aguarde o próximo ciclo automático.
            </p>
            <a v-if="jueriCadastroUrl" :href="jueriCadastroUrl" target="_blank" rel="noopener" class="attrs-edit-btn">
              <ExternalLink class="icon-xs" /> Editar no Jueri
            </a>
          </div>

          <!-- Tab Informações: campos livres, criados pela equipe (não vem do Jueri) -->
          <div v-show="activeTab === 'Informações'" class="attrs-tab">
            <div class="attrs-list" v-if="informacoesPersonalizadas.length > 0">
              <div class="attr-row" v-for="attr in informacoesPersonalizadas" :key="attr.key">
                <span class="attr-label">{{ attr.key }}</span>
                <span class="attr-value">{{ attr.value }}</span>
              </div>
            </div>
            <p class="empty-state-text" v-else>
              Nenhum campo personalizado ainda. Use "Adicionar/editar campos" pra criar informações que não existem no Jueri (ex: hobby, preferência de contato).
            </p>
            <button class="attrs-edit-btn" @click="isEditModalOpen = true"><Edit2 class="icon-xs" /> Adicionar/editar campos</button>
          </div>

          <!-- Tab Histórico -->
          <div v-show="activeTab === 'Histórico'" class="history-tab">
            <div class="history-item">
              <span class="history-date">Data de Criação</span>
              <p>Contato adicionado ao CRM.</p>
            </div>

            <div v-if="auditEvents.length > 0">
              <div class="history-item" v-for="e in auditEvents" :key="'audit-' + e.id">
                <span class="history-date">{{ new Date(e.created_at).toLocaleDateString('pt-BR') }} às {{ new Date(e.created_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) }}</span>
                <p>{{ auditEventLabel(e) }}</p>
                <p style="font-size: 0.78rem; color: var(--text-muted);">Por: {{ auditEventAuthor(e) }}</p>
              </div>
            </div>

            <div v-if="contact.conversations && contact.conversations.length > 0">
              <div class="history-item" v-for="conv in contact.conversations" :key="conv.id">
                <span class="history-date">Conversa #{{ conv.id }} - {{ new Date(conv.created_at).toLocaleDateString() }}</span>
                <p>Status: {{ conv.status === 'open' ? 'Aberta' : (conv.status === 'resolved' ? 'Resolvida' : conv.status) }}</p>
                <p v-if="conv.messages && conv.messages.length > 0">
                  Última mensagem: "{{ conv.messages[conv.messages.length - 1].text }}"
                </p>
                <button class="btn-secondary" style="margin-top: 0.5rem; font-size: 0.8rem; padding: 0.25rem 0.5rem;" @click="$router.push('/conversas')">
                  Ir para a Conversa
                </button>
              </div>
            </div>
            <p v-else class="empty-state-text" style="margin-top: 1rem;">Nenhuma conversa registrada.</p>
          </div>

          <!-- Tab Mesclar -->
          <div v-show="activeTab === 'Mesclar'">
            <p class="empty-state-text">
              Pesquise outro contato para mesclar com este.
            </p>
            <input type="text" class="form-input" placeholder="Pesquisar contatos..." style="width: 100%; max-width: 300px; margin: 1rem auto; display: block;" />
          </div>
        </div>
      </div>
    </div>
  </div>
  <div class="loading-state" v-else-if="isLoading">
    Carregando...
  </div>

  <EditContactModal :isOpen="isEditModalOpen" :contact="contact" @close="closeEditModal" />

  <!-- Note Modal -->
  <div class="modal-overlay" v-show="showNoteModal" @click="closeNoteModal">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <h3>Detalhes da Nota</h3>
        <button class="btn-close" @click="closeNoteModal"><X class="icon-sm" /></button>
      </div>
      <div class="modal-body" v-if="selectedNote">
        <div class="modal-meta">
          <strong>Criado por:</strong> {{ selectedNote.user ? (selectedNote.user.first_name || selectedNote.user.name) : 'Usuário' }} <br />
          <strong>Data:</strong> {{ new Date(selectedNote.created_at).toLocaleDateString('pt-BR') }} às {{ new Date(selectedNote.created_at).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) }}
        </div>
        <div class="modal-text">
          {{ selectedNote.content }}
        </div>
      </div>
    </div>
  </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #ffffff;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 2rem;
  border-bottom: 1px solid #e5e7eb;

  .header-left {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.95rem;

    .breadcrumb-link {
      color: #6b7280;
      text-decoration: none;
      &:hover { color: #1f2937; }
    }
    
    .breadcrumb-separator {
      color: #9ca3af;
    }

    .breadcrumb-current {
      font-weight: 500;
      color: #1f2937;
    }
  }

  .header-actions {
    display: flex;
    gap: 0.75rem;
  }
}

.btn-secondary {
  background: transparent;
  color: #374151;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid #d1d5db;
  font-weight: 500;
  font-size: 0.85rem;
  cursor: pointer;
  
  &:hover { background: #f3f4f6; }
}

.btn-primary {
  background: #cc0066;
  color: white;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: none;
  font-weight: 500;
  font-size: 0.85rem;
  cursor: pointer;
  
  &:hover { background: #cc0066; }
}

.content-grid {
  display: grid;
  grid-template-columns: minmax(400px, 1fr) 1fr;
  flex: 1;
  overflow: hidden;
}

/* LEFT PANE */
.left-pane {
  padding: 2rem;
  overflow-y: auto;
  border-right: 1px solid #e5e7eb;
}

.profile-header {
  margin-bottom: 2.5rem;

  .avatar-large {
    width: 64px;
    height: 64px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.5rem;
    font-weight: 500;
    margin-bottom: 1rem;
  }

  .profile-name {
    font-size: 1.25rem;
    font-weight: 600;
    color: #1f2937;
    margin: 0 0 0.5rem 0;
  }

  .profile-meta {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    margin-bottom: 1rem;

    .meta-item {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      font-size: 0.85rem;
      color: #6b7280;
    }
  }

  .btn-tag {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    background: transparent;
    border: 1px dashed #d1d5db;
    color: #4b5563;
    padding: 0.25rem 0.5rem;
    border-radius: 16px;
    font-size: 0.75rem;
    cursor: pointer;

    &:hover { border-color: #9ca3af; }
  }

  .tags-row {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.4rem;
  }

  .tag-chip {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.2rem 0.35rem 0.2rem 0.6rem;
    border-radius: 16px;
    font-size: 0.72rem;
    font-weight: 600;
    color: #ffffff;
  }

  .tag-remove {
    background: rgba(255, 255, 255, 0.25);
    border: none;
    color: #ffffff;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    line-height: 1;
    cursor: pointer;
    font-size: 0.8rem;
    display: flex;
    align-items: center;
    justify-content: center;

    &:hover { background: rgba(255, 255, 255, 0.4); }
  }

  .tag-add-box {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .tag-add-inline {
    display: flex;
    align-items: center;
    gap: 0.35rem;
  }

  .tag-color-picker {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }

  .tag-color-dot {
    width: 18px;
    height: 18px;
    border-radius: 50%;
    border: 2px solid transparent;
    cursor: pointer;
    padding: 0;

    &.active { border-color: #1f2937; }
    &:hover { opacity: 0.85; }
  }

  .tag-input {
    padding: 0.3rem 0.6rem;
    border: 1px solid #d1d5db;
    border-radius: 16px;
    font-size: 0.75rem;
    outline: none;
    width: 140px;

    &:focus { border-color: #cc0066; }
  }

  .btn-add-tag {
    background: #cc0066;
    color: white;
    border: none;
    padding: 0.3rem 0.65rem;
    border-radius: 16px;
    font-size: 0.72rem;
    font-weight: 600;
    cursor: pointer;

    &:disabled { opacity: 0.5; cursor: not-allowed; }
    &:hover:not(:disabled) { opacity: 0.9; }
  }
}

.jueri-link-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin-top: 0.5rem;
  padding: 0.5rem 0.9rem;
  font-size: 0.82rem;
  font-weight: 600;
  color: #cc0066;
  background: rgba(204, 0, 102, 0.07);
  border: 1px solid rgba(204, 0, 102, 0.25);
  border-radius: 6px;
  text-decoration: none;
  width: fit-content;

  &:hover { background: rgba(204, 0, 102, 0.14); }
}

.bio-section {
  .bio-title {
    font-size: 0.95rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 0.75rem;
  }

  textarea {
    width: 100%;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    padding: 0.75rem;
    font-family: inherit;
    resize: vertical;
    outline: none;
    font-size: 0.95rem;
    background: #f9fafb;

    &:focus {
      border-color: #ff007f;
      box-shadow: 0 0 0 2px rgba(255, 0, 127, 0.2);
      background: white;
    }
  }
}

.notas-tab {
  text-align: left;
}

.form-input {
  width: 100%;
  padding: 0.75rem 1rem;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  font-size: 0.85rem;
  color: #1f2937;
  outline: none;

  &::placeholder { color: #9ca3af; }
  &:focus { box-shadow: 0 0 0 2px #ffd9ec; border-color: transparent; }
}


/* RIGHT PANE */
.right-pane {
  background: #ffffff;
  display: flex;
  flex-direction: column;
}

.tabs-header {
  display: flex;
  padding: 1rem 2rem 0;
  border-bottom: 1px solid #e5e7eb;
  gap: 2rem;
}

.tab-btn {
  background: transparent;
  border: none;
  padding: 0.75rem 0;
  font-size: 0.85rem;
  color: #6b7280;
  font-weight: 500;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
  
  &.active {
    color: #cc0066;
    border-bottom-color: #cc0066;
  }
  
  &:hover:not(.active) {
    color: #374151;
  }
}

.tab-content {
  padding: 3rem 2rem;
  text-align: center;
  flex: 1;

  .empty-state-text {
    color: #6b7280;
    font-size: 0.95rem;
    text-align: center;
    line-height: 1.5;
  }

  .attrs-tab {
    text-align: left;
  }

  .attrs-list {
    display: flex;
    flex-direction: column;
  }

  .attr-row {
    display: grid;
    grid-template-columns: 180px 1fr;
    gap: 1rem;
    align-items: baseline;
    padding: 0.55rem 0;
    border-bottom: 1px solid #f3f4f6;
    font-size: 0.85rem;

    &:last-child { border-bottom: none; }

    .attr-label { color: #6b7280; }
    .attr-value { color: #1f2937; font-weight: 500; overflow-wrap: break-word; }
  }

  .attrs-edit-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    margin-top: 1rem;
    padding: 0.5rem 0.75rem;
    font-size: 0.8rem;
    font-weight: 600;
    color: #cc0066;
    background: rgba(204, 0, 102, 0.07);
    border: none;
    border-radius: 6px;
    cursor: pointer;

    &:hover { background: rgba(204, 0, 102, 0.14); }
  }

  .history-item {
    text-align: left;
    padding: 1.25rem;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    background: #ffffff;
    margin-bottom: 1rem;
    box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
    border-left: 4px solid #ff007f;
    
    .history-date {
      font-size: 0.8rem;
      color: #6b7280;
      font-weight: 500;
      margin-bottom: 0.75rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    
    p {
      margin: 0;
      color: #1f2937;
      font-size: 0.95rem;
      line-height: 1.5;
    }
  }

  .notes-input-area {
    display: flex;
    flex-direction: column;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 1rem;
    
    textarea {
      width: 100%;
      border: 1px solid #d1d5db;
      border-radius: 6px;
      padding: 0.75rem;
      font-family: inherit;
      resize: vertical;
      outline: none;
      font-size: 0.95rem;
      
      &:focus {
        border-color: #ff007f;
        box-shadow: 0 0 0 2px rgba(255, 0, 127, 0.2);
      }
    }
    
    .btn-primary {
      align-self: flex-end;
      margin-top: 0.75rem;
      padding: 0.5rem 1.25rem;
      font-size: 0.9rem;
      border-radius: 6px;
    }
  }

  .notes-list-compact {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    text-align: left;
  }

  .note-list-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.85rem 1rem;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    background: #ffffff;
    cursor: pointer;
    transition: all 0.2s;
    
    &:hover {
      border-color: #ff007f;
      box-shadow: 0 2px 4px rgba(255, 0, 127, 0.1);
      background: #f8fafc;
    }

    .note-content-row {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      flex: 1;
      min-width: 0;
    }
    
    .note-author {
      font-weight: 600;
      color: #374151;
      white-space: nowrap;
      font-size: 0.9rem;
    }

    .note-preview-inline {
      color: #6b7280;
      font-size: 0.9rem;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    
    .note-date {
      color: #9ca3af;
      font-size: 0.85rem;
      white-space: nowrap;
      margin-left: 1rem;
      flex-shrink: 0;
    }
  }
}

.empty-state-text {
  font-size: 0.85rem;
  color: #6b7280;
  max-width: 400px;
  margin: 0 auto;
  line-height: 1.5;
}

.icon-xs {
  width: 14px;
  height: 14px;
}

.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #6b7280;
}

/* Modal CSS */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(2px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
}

.modal-content {
  background: white;
  width: 90%;
  max-width: 500px;
  border-radius: 12px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.modal-header {
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  justify-content: space-between;
  align-items: center;

  h3 {
    margin: 0;
    font-size: 1.1rem;
    color: #1f2937;
  }

  .btn-close {
    background: none;
    border: none;
    color: #9ca3af;
    cursor: pointer;
    padding: 0.25rem;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;

    &:hover {
      background: #f3f4f6;
      color: #4b5563;
    }
  }
}

.modal-body {
  padding: 1.5rem;

  .modal-meta {
    background: #f9fafb;
    padding: 1rem;
    border-radius: 6px;
    font-size: 0.9rem;
    color: #4b5563;
    margin-bottom: 1rem;
    line-height: 1.5;
  }

  .modal-text {
    font-size: 0.95rem;
    color: #1f2937;
    line-height: 1.6;
    white-space: pre-wrap;
  }
}

@media (max-width: 900px) {
  .content-grid {
    grid-template-columns: 1fr;
    overflow-y: auto;
  }

  .page-header {
    padding: 1rem;
    flex-wrap: wrap;
    gap: 0.75rem;
  }
}

</style>
