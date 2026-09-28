<script setup>
import { ref, computed, onMounted } from 'vue'
import { Plus, Edit2, Trash2, X, Save, Paperclip, FileText } from 'lucide-vue-next'
import api from '../../api'
import Swal from 'sweetalert2'

const templates = ref([])
const isLoading = ref(false)
const showModal = ref(false)
const isEditing = ref(false)

const form = ref({
  id: null,
  nome: '',
  categoria: '',
  mensagem: '',
  attachment_url: null,
  attachment_type: null
})
// Arquivo novo escolhido nesta edição (ainda não salvo) -- diferente de
// form.attachment_url, que é o anexo que já está salvo no modelo.
const newAttachmentFile = ref(null)
const removeAttachment = ref(false)
const attachmentInput = ref(null)

const fetchTemplates = async () => {
  isLoading.value = true
  try {
    const response = await api.get('/message_templates')
    templates.value = response.data
  } catch (error) {
    console.error('Erro ao buscar modelos de mensagem:', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  fetchTemplates()
})

const openModal = (template = null) => {
  newAttachmentFile.value = null
  removeAttachment.value = false
  if (template) {
    isEditing.value = true
    form.value = { ...template }
  } else {
    isEditing.value = false
    form.value = { id: null, nome: '', categoria: '', mensagem: '', attachment_url: null, attachment_type: null }
  }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
}

const triggerAttachmentInput = () => {
  attachmentInput.value?.click()
}

const handleAttachmentChange = (event) => {
  const file = event.target.files[0]
  if (file) {
    newAttachmentFile.value = file
    removeAttachment.value = false
  }
}

const clearAttachment = () => {
  newAttachmentFile.value = null
  removeAttachment.value = true
  if (attachmentInput.value) attachmentInput.value.value = ''
}

// Modelo pode ser só anexo (áudio, imagem, PDF, vídeo...), sem texto nenhum
// (pedido 2026-09-28) -- só exige mensagem escrita quando não tem anexo
// nenhum (novo ou já salvo).
const hasAnyAttachment = () => (newAttachmentFile.value || (form.value.attachment_url && !removeAttachment.value))

const newAttachmentPreviewUrl = computed(() => newAttachmentFile.value ? URL.createObjectURL(newAttachmentFile.value) : null)

const previewKind = (file, type) => {
  const t = file?.type || type || ''
  if (t.startsWith('image/')) return 'image'
  if (t.startsWith('audio/')) return 'audio'
  if (t.startsWith('video/')) return 'video'
  return 'file'
}

const saveTemplate = async () => {
  if (!form.value.nome.trim()) return
  if (!form.value.mensagem.trim() && !hasAnyAttachment()) return

  try {
    const formData = new FormData()
    formData.append('message_template[nome]', form.value.nome)
    formData.append('message_template[categoria]', form.value.categoria || '')
    formData.append('message_template[mensagem]', form.value.mensagem || '')
    if (newAttachmentFile.value) formData.append('message_template[attachment]', newAttachmentFile.value)
    if (removeAttachment.value) formData.append('message_template[remove_attachment]', 'true')

    const config = { headers: { 'Content-Type': undefined } }
    if (isEditing.value) {
      await api.put(`/message_templates/${form.value.id}`, formData, config)
    } else {
      await api.post('/message_templates', formData, config)
    }
    closeModal()
    fetchTemplates()
  } catch (error) {
    console.error('Erro ao salvar modelo de mensagem:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao salvar o modelo.', showConfirmButton: false, timer: 3500 })
  }
}

const deleteTemplate = async (id) => {
  if (!confirm('Tem certeza que deseja apagar este modelo de mensagem?')) return
  try {
    await api.delete(`/message_templates/${id}`)
    fetchTemplates()
  } catch (error) {
    console.error('Erro ao excluir:', error)
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-content">
        <div>
          <h1>Modelos de Mensagem</h1>
          <p class="subtitle">Digite "/" no campo de mensagem da conversa pra usar um modelo salvo aqui.</p>
        </div>
        <button class="btn-primary" @click="openModal()">
          <Plus class="icon-sm" /> Novo Modelo
        </button>
      </div>
    </div>

    <div class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>Nome</th>
            <th>Categoria</th>
            <th>Mensagem</th>
            <th width="60">Anexo</th>
            <th width="120">Ações</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="isLoading">
            <td colspan="5" class="text-center py-4">Carregando modelos...</td>
          </tr>
          <tr v-else-if="templates.length === 0">
            <td colspan="5" class="text-center py-4 text-muted">Nenhum modelo criado ainda.</td>
          </tr>
          <tr v-for="template in templates" :key="template.id">
            <td class="font-medium">{{ template.nome }}</td>
            <td class="text-muted">{{ template.categoria || '—' }}</td>
            <td class="text-muted preview-cell">{{ template.mensagem || '—' }}</td>
            <td class="text-center"><Paperclip v-if="template.attachment_url" class="icon-sm" style="color: var(--primary);" /></td>
            <td class="actions-cell">
              <button class="btn-icon" @click="openModal(template)" title="Editar">
                <Edit2 class="icon-sm" />
              </button>
              <button class="btn-icon text-danger" @click="deleteTemplate(template.id)" title="Excluir">
                <Trash2 class="icon-sm" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal Form -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content">
        <div class="modal-header">
          <h2>{{ isEditing ? 'Editar Modelo' : 'Novo Modelo' }}</h2>
          <button class="btn-icon" @click="closeModal"><X class="icon-sm" /></button>
        </div>
        <div class="modal-body">
          <div class="input-group">
            <label>Nome (usado na busca pelo "/")</label>
            <input type="text" v-model="form.nome" placeholder="Ex: Boas-vindas, Cobrança..." autofocus />
          </div>
          <div class="input-group">
            <label>Categoria <span class="text-muted text-xs">(opcional)</span></label>
            <input type="text" v-model="form.categoria" placeholder="Ex: Comercial, Financeiro..." />
          </div>
          <div class="input-group">
            <label>Mensagem <span class="text-muted text-xs">(opcional se tiver anexo)</span></label>
            <textarea v-model="form.mensagem" rows="5" placeholder="Texto que será enviado quando escolher esse modelo..."></textarea>
          </div>
          <div class="input-group">
            <label>Anexo <span class="text-muted text-xs">(opcional — imagem, PDF, áudio ou vídeo)</span></label>
            <input ref="attachmentInput" type="file" accept="image/*,application/pdf,audio/*,video/*" hidden @change="handleAttachmentChange" />

            <template v-if="newAttachmentFile">
              <div class="attachment-preview">
                <img v-if="previewKind(newAttachmentFile) === 'image'" :src="newAttachmentPreviewUrl" class="attachment-preview-img" />
                <audio v-else-if="previewKind(newAttachmentFile) === 'audio'" :src="newAttachmentPreviewUrl" controls style="height: 32px; max-width: 220px;"></audio>
                <video v-else-if="previewKind(newAttachmentFile) === 'video'" :src="newAttachmentPreviewUrl" controls style="height: 60px; max-width: 220px;"></video>
                <FileText v-else class="icon-sm" />
                <span>{{ newAttachmentFile.name }}</span>
                <button type="button" class="btn-icon" @click="clearAttachment"><X class="icon-xs" /></button>
              </div>
            </template>
            <template v-else-if="form.attachment_url && !removeAttachment">
              <div class="attachment-preview">
                <img v-if="previewKind(null, form.attachment_type) === 'image'" :src="form.attachment_url" class="attachment-preview-img" />
                <audio v-else-if="previewKind(null, form.attachment_type) === 'audio'" :src="form.attachment_url" controls style="height: 32px; max-width: 220px;"></audio>
                <video v-else-if="previewKind(null, form.attachment_type) === 'video'" :src="form.attachment_url" controls style="height: 60px; max-width: 220px;"></video>
                <a v-else :href="form.attachment_url" target="_blank" class="attachment-preview-link"><FileText class="icon-sm" /> Ver anexo</a>
                <button type="button" class="btn-icon" @click="clearAttachment"><X class="icon-xs" /></button>
              </div>
            </template>
            <button v-else type="button" class="btn-outline-audio" @click="triggerAttachmentInput">
              <Paperclip class="icon-sm" /> Escolher anexo
            </button>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn-cancel" @click="closeModal">Cancelar</button>
          <button class="btn-primary" @click="saveTemplate">
            <Save class="icon-sm" /> Salvar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container { padding: 2rem; background: var(--bg-primary); height: 100%; }
.page-header {
  margin-bottom: 2rem;
  .header-content {
    display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem;
    h1 { font-size: 1.2rem; color: var(--text-main); font-weight: 500; margin: 0 0 0.25rem; }
    .subtitle { font-size: 0.85rem; color: var(--text-muted); margin: 0; }
  }
}
.table-container {
  background: var(--bg-secondary); border: 1px solid var(--border-color);
  border-radius: 8px; overflow: hidden; box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
}
.data-table {
  width: 100%; border-collapse: collapse;
  th, td { padding: 1rem 1.5rem; text-align: left; border-bottom: 1px solid var(--border-color); }
  th { font-weight: 600; color: var(--text-main); font-size: 0.9rem; background: rgba(0,0,0,0.01); }
  td { color: var(--text-muted); font-size: 0.9rem; }
  tr { transition: background-color 0.2s; &:hover { background: rgba(255, 0, 127, 0.02); } }
}
.preview-cell {
  max-width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.font-medium { color: var(--text-main); font-weight: 500; }
.actions-cell { display: flex; gap: 0.5rem; }
.btn-icon {
  background: transparent; border: none; cursor: pointer; padding: 0.5rem; border-radius: 4px;
  display: flex; align-items: center; justify-content: center; color: var(--text-muted);
  &:hover { background: rgba(0,0,0,0.05); }
  &.text-danger:hover { color: #ef4444; background: rgba(239, 68, 68, 0.1); }
}
.btn-primary {
  display: inline-flex; align-items: center; gap: 0.5rem; background: var(--primary);
  color: white; border: none; padding: 0.6rem 1.2rem; border-radius: 6px; font-weight: 500; cursor: pointer;
  white-space: nowrap;
}
.btn-cancel {
  background: transparent; color: var(--text-muted); border: 1px solid var(--border-color);
  padding: 0.6rem 1.2rem; border-radius: 6px; cursor: pointer;
  &:hover { background: var(--bg-primary); color: var(--text-main); }
}

/* Modal */
.modal-overlay {
  position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.modal-content {
  background: var(--bg-secondary); border-radius: 8px; width: 100%; max-width: 480px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.1);
}
.modal-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: 1.5rem; border-bottom: 1px solid var(--border-color);
  h2 { font-size: 1.1rem; color: var(--text-main); margin: 0; }
}
.modal-body { padding: 1.5rem; }
.modal-footer {
  padding: 1.5rem; border-top: 1px solid var(--border-color); display: flex; justify-content: flex-end; gap: 1rem;
}
.input-group {
  margin-bottom: 1.5rem;
  label { display: block; margin-bottom: 0.5rem; color: var(--text-main); font-size: 0.9rem; font-weight: 500; }
  input[type="text"], textarea {
    width: 100%; padding: 0.75rem; background: var(--bg-primary); border: 1px solid var(--border-color);
    border-radius: 6px; color: var(--text-main); font-family: inherit; font-size: 0.9rem;
    &:focus { outline: none; border-color: var(--primary); }
  }
  textarea { resize: vertical; }
}
.attachment-preview {
  display: flex; align-items: center; gap: 0.5rem;
  background: var(--bg-primary); border: 1px solid var(--border-color);
  border-radius: 6px; padding: 0.5rem 0.75rem; color: var(--text-main); font-size: 0.85rem;
}
.attachment-preview-img { max-height: 60px; max-width: 100px; border-radius: 4px; object-fit: cover; }
.attachment-preview-link { display: inline-flex; align-items: center; gap: 0.3rem; color: var(--primary); }
.btn-outline-audio {
  display: inline-flex; align-items: center; gap: 0.4rem;
  background: transparent; border: 1px dashed var(--border-color); color: var(--text-muted);
  padding: 0.5rem 0.9rem; border-radius: 6px; cursor: pointer; font-size: 0.85rem;
  &:hover { border-color: var(--primary); color: var(--primary); }
}
.icon-xs { width: 14px; height: 14px; }
.text-xs { font-size: 0.75rem; }
.text-muted { color: var(--text-muted); }
.icon-sm { width: 16px; height: 16px; }
.text-center { text-align: center; }
.py-4 { padding: 1.5rem 0; }
</style>
