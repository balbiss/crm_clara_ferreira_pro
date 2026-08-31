<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { X, Plus, Zap, GripVertical, MessageCircle } from 'lucide-vue-next'
import Swal from 'sweetalert2'
import { usePipelinesStore } from '../store/pipelines'
import { useAgentsStore } from '../store/agents'
import { useInboxesStore } from '../store/inboxes'

// Tela dedicada de automação por pipeline — espelha o botão "Automatize" (Digital
// Pipeline) do Kommo: sai do board normal, mostra as etapas como colunas de
// configuração (sem cards) + painel lateral de fontes de lead.
const route = useRoute()
const router = useRouter()
const pipelinesStore = usePipelinesStore()
const agentsStore = useAgentsStore()
const inboxesStore = useInboxesStore()

const pipeline = computed(() => pipelinesStore.findBySlug(route.params.slug))

onMounted(async () => {
  if (!pipelinesStore.isLoadedOnce) await pipelinesStore.fetchPipelines()
  if (!agentsStore.isLoadedOnce) await agentsStore.fetchAgents()
  if (!inboxesStore.isLoadedOnce) await inboxesStore.fetchInboxes()
})

const goBack = () => router.push(`/pipelines/${route.params.slug}`)

// Só as ações que dá pra executar de verdade com a infra que já existe no CRM — sem
// integrações de anúncio (Meta/TikTok/Google Ads) que o Kommo tem, porque a empresa
// não tem conta de anúncio ligada aqui, seria automação decorativa.
const ACTION_TYPES = [
  { value: 'move_stage', label: 'Mudar etapa do lead' },
  { value: 'change_owner', label: 'Alterar responsável' },
  { value: 'create_note', label: 'Adicionar nota' },
  { value: 'ai_start', label: 'Ligar agente de IA' },
  { value: 'ai_stop', label: 'Pausar agente de IA' },
  { value: 'send_webhook', label: 'Enviar webhook' }
]
const actionLabel = (type) => ACTION_TYPES.find(a => a.value === type)?.label || type

const triggerSummary = (trigger) => {
  if (trigger.action_type === 'move_stage') {
    const target = pipeline.value.pipeline_stages.find(s => s.id === trigger.config.target_stage_id)
    return `${actionLabel(trigger.action_type)} → ${target?.name || '?'}`
  }
  if (trigger.action_type === 'change_owner') {
    const agent = agentsStore.agents.find(a => a.id === trigger.config.user_id)
    return `${actionLabel(trigger.action_type)} → ${agent ? `${agent.first_name} ${agent.last_name}` : '?'}`
  }
  return actionLabel(trigger.action_type)
}

const showTriggerModal = ref(false)
const triggerStageId = ref(null)
const newTrigger = ref({ action_type: '', target_stage_id: null, user_id: null, content: '', url: '' })

const openTriggerModal = (stageId) => {
  triggerStageId.value = stageId
  newTrigger.value = { action_type: '', target_stage_id: null, user_id: null, content: '', url: '' }
  showTriggerModal.value = true
}

const saveTrigger = async () => {
  const t = newTrigger.value
  if (!t.action_type) {
    Swal.fire({ icon: 'warning', title: 'Atenção', text: 'Escolha uma ação.' })
    return
  }
  let config = {}
  if (t.action_type === 'move_stage') {
    if (!t.target_stage_id) return Swal.fire({ icon: 'warning', title: 'Atenção', text: 'Escolha a etapa de destino.' })
    config = { target_stage_id: t.target_stage_id }
  } else if (t.action_type === 'change_owner') {
    if (!t.user_id) return Swal.fire({ icon: 'warning', title: 'Atenção', text: 'Escolha o responsável.' })
    config = { user_id: t.user_id }
  } else if (t.action_type === 'create_note') {
    if (!t.content.trim()) return Swal.fire({ icon: 'warning', title: 'Atenção', text: 'Escreva o texto da nota.' })
    config = { content: t.content.trim() }
  } else if (t.action_type === 'send_webhook') {
    if (!t.url.trim()) return Swal.fire({ icon: 'warning', title: 'Atenção', text: 'Informe a URL do webhook.' })
    config = { url: t.url.trim() }
  }

  try {
    await pipelinesStore.createTrigger(triggerStageId.value, { action_type: t.action_type, config })
    showTriggerModal.value = false
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'Erro', text: e.response?.data?.errors?.join(', ') || 'Não foi possível criar o gatilho.' })
  }
}

const removeTrigger = async (stageId, triggerId) => {
  const result = await Swal.fire({
    title: 'Remover esse gatilho?', icon: 'warning', showCancelButton: true,
    confirmButtonColor: '#dc2626', confirmButtonText: 'Remover', cancelButtonText: 'Cancelar'
  })
  if (!result.isConfirmed) return
  await pipelinesStore.deleteTrigger(stageId, triggerId)
}
</script>

<template>
  <div class="automation-page" v-if="pipeline">
    <div class="automation-header">
      <h1>{{ pipeline.name.toUpperCase() }}</h1>
      <button class="btn-secondary" @click="goBack">Voltar</button>
    </div>

    <div class="automation-body">
      <aside class="automation-sidebar">
        <h4>Fontes de lead</h4>
        <p class="sidebar-hint">Números de WhatsApp conectados que podem gerar leads pra esse pipeline.</p>

        <div v-for="inbox in inboxesStore.inboxes" :key="inbox.id" class="source-card">
          <div class="source-icon"><MessageCircle class="icon-sm" /></div>
          <div class="source-info">
            <span class="source-name">{{ inbox.phone_number || inbox.name }}</span>
            <span class="source-status" :class="{ online: inbox.connected }">{{ inbox.connected ? 'Conectado' : 'Desconectado' }}</span>
          </div>
        </div>
        <p v-if="!inboxesStore.inboxes.length" class="empty-hint">Nenhuma caixa conectada ainda.</p>
        <router-link to="/settings/inboxes/new" class="btn-link">+ Adicionar fonte</router-link>

        <div class="sidebar-divider"></div>

        <h4>Controle de duplicatas</h4>
        <p class="sidebar-hint">Sempre ativo: se o telefone que mandou mensagem já está cadastrado (mesmo em outro número salvo pra ela), o sistema usa o cadastro existente em vez de criar um lead duplicado.</p>
      </aside>

      <div class="automation-columns">
        <div class="automation-column" v-for="stage in pipeline.pipeline_stages" :key="stage.id">
          <div class="automation-column-header">
            <GripVertical class="icon-xs drag-icon" />
            <h3>{{ stage.name }}</h3>
          </div>

          <div class="trigger-list">
            <div v-for="trigger in stage.pipeline_triggers" :key="trigger.id" class="trigger-chip">
              <Zap class="icon-xs" />
              <span>{{ triggerSummary(trigger) }}</span>
              <button class="trigger-chip-remove" @click="removeTrigger(stage.id, trigger.id)"><X class="icon-xs" /></button>
            </div>
          </div>

          <button class="trigger-add-btn" @click="openTriggerModal(stage.id)"><Plus class="icon-sm" /> Adicionar gatilho</button>
        </div>
      </div>
    </div>

    <!-- Modal Adicionar Gatilho -->
    <div v-if="showTriggerModal" class="modal-backdrop" @click.self="showTriggerModal = false">
      <div class="modal-card">
        <div class="modal-header">
          <h3>Adicionar gatilho</h3>
          <button class="close-btn" @click="showTriggerModal = false"><X class="icon-sm" /></button>
        </div>

        <form @submit.prevent="saveTrigger" class="modal-form">
          <div class="form-group">
            <label>Ação</label>
            <select v-model="newTrigger.action_type">
              <option value="" disabled>Escolha uma ação...</option>
              <option v-for="a in ACTION_TYPES" :key="a.value" :value="a.value">{{ a.label }}</option>
            </select>
          </div>

          <div class="form-group" v-if="newTrigger.action_type === 'move_stage'">
            <label>Mover lead para a etapa</label>
            <select v-model="newTrigger.target_stage_id">
              <option :value="null" disabled>Escolha a etapa...</option>
              <option v-for="s in pipeline.pipeline_stages.filter(s => s.id !== triggerStageId)" :key="s.id" :value="s.id">{{ s.name }}</option>
            </select>
          </div>

          <div class="form-group" v-if="newTrigger.action_type === 'change_owner'">
            <label>Novo responsável</label>
            <select v-model="newTrigger.user_id">
              <option :value="null" disabled>Escolha a pessoa...</option>
              <option v-for="ag in agentsStore.agents" :key="ag.id" :value="ag.id">{{ ag.first_name }} {{ ag.last_name }}</option>
            </select>
          </div>

          <div class="form-group" v-if="newTrigger.action_type === 'create_note'">
            <label>Texto da nota</label>
            <textarea v-model="newTrigger.content" rows="3" placeholder="Ex: Lead entrou na etapa de negociação"></textarea>
          </div>

          <div class="form-group" v-if="newTrigger.action_type === 'send_webhook'">
            <label>URL do webhook</label>
            <input type="text" v-model="newTrigger.url" placeholder="https://..." />
          </div>

          <p v-if="['ai_start', 'ai_stop'].includes(newTrigger.action_type)" class="empty-hint">
            Sem configuração extra — dispara direto quando o lead entra nessa etapa.
          </p>

          <div class="modal-actions">
            <button type="button" class="btn-cancel" @click="showTriggerModal = false">Cancelar</button>
            <button type="submit" class="btn-submit">Salvar gatilho</button>
          </div>
        </form>
      </div>
    </div>
  </div>
  <div v-else class="loading-state">Carregando pipeline...</div>
</template>

<style lang="scss" scoped>
.automation-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 1rem 1.5rem;
}

.automation-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
  flex-shrink: 0;

  h1 { font-size: 1.15rem; font-weight: 700; color: var(--text-main); letter-spacing: 0.02em; }
}

.automation-body {
  display: flex;
  gap: 1.25rem;
  flex: 1;
  overflow: hidden;
}

.automation-sidebar {
  width: 260px;
  flex-shrink: 0;
  overflow-y: auto;
  padding-right: 0.25rem;

  h4 { font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; color: var(--text-muted); margin-bottom: 0.5rem; }
  .sidebar-hint { font-size: 0.78rem; color: var(--text-muted); margin-bottom: 0.75rem; line-height: 1.4; }
  .sidebar-divider { height: 1px; background: var(--border-color); margin: 1.25rem 0; }
}

.source-card {
  display: flex; align-items: center; gap: 0.6rem; padding: 0.6rem 0.7rem;
  background: var(--bg-tertiary); border-radius: 8px; margin-bottom: 0.5rem;

  .source-icon { flex-shrink: 0; display: flex; }
  .source-info { display: flex; flex-direction: column; overflow: hidden; }
  .source-name { font-size: 0.82rem; font-weight: 600; color: var(--text-main); }
  .source-status { font-size: 0.7rem; color: var(--text-muted); &.online { color: #059669; } }
}

.empty-hint { font-size: 0.78rem; color: var(--text-muted); margin-bottom: 0.5rem; }
.btn-link { display: inline-block; margin-top: 0.25rem; background: none; border: none; color: var(--primary); font-size: 0.82rem; font-weight: 600; cursor: pointer; padding: 0; text-decoration: none; &:hover { text-decoration: underline; } }

.automation-columns {
  display: flex;
  gap: 0.75rem;
  overflow-x: auto;
  flex: 1;
  padding-bottom: 1rem;
}

.automation-column {
  width: 260px;
  min-width: 260px;
  background: var(--bg-tertiary, #f4f5f7);
  border-radius: 10px;
  border-top: 3px solid var(--primary);
  padding: 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.automation-column-header {
  display: flex; align-items: center; gap: 0.4rem;
  .drag-icon { color: var(--text-muted); flex-shrink: 0; }
  h3 { font-size: 0.78rem; font-weight: 800; color: var(--text-main); letter-spacing: 0.03em; }
}

.trigger-list { display: flex; flex-direction: column; gap: 0.4rem; min-height: 40px; }

.trigger-chip {
  display: flex; align-items: center; gap: 0.35rem; background: rgba(255, 0, 127, 0.08);
  border: 1px solid rgba(255, 0, 127, 0.25); border-radius: 6px; padding: 0.4rem 0.5rem;
  color: var(--primary); font-size: 0.72rem; font-weight: 600;
  span { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
}
.trigger-chip-remove { background: none; border: none; color: inherit; cursor: pointer; display: flex; opacity: 0.7; &:hover { opacity: 1; } }

.trigger-add-btn {
  display: flex; align-items: center; justify-content: center; gap: 0.35rem; background: none;
  border: 1px dashed var(--border-color); border-radius: 6px; padding: 0.5rem; color: var(--text-muted);
  font-size: 0.75rem; font-weight: 600; cursor: pointer;
  &:hover { border-color: var(--primary); color: var(--primary); }
}

.btn-secondary {
  display: flex; align-items: center; gap: 0.4rem; background: var(--bg-tertiary); color: var(--text-main);
  padding: 0.5rem 0.9rem; border-radius: 6px; border: 1px solid var(--border-color); font-weight: 600; font-size: 0.85rem; cursor: pointer;
  &:hover { background: var(--bg-hover); }
}

.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 12px; height: 12px; }

.loading-state { text-align: center; padding: 5rem; color: var(--text-muted); }

.modal-backdrop { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0, 0, 0, 0.4); display: flex; align-items: center; justify-content: center; z-index: 1000; }
.modal-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; width: 100%; max-width: 480px; max-height: 80vh; box-shadow: 0 20px 25px -5px var(--shadow-color), 0 10px 10px -5px var(--shadow-sm); overflow: hidden; display: flex; flex-direction: column; }
.modal-header {
  display: flex; justify-content: space-between; align-items: center; padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-color); background: var(--bg-tertiary);
  h3 { font-size: 1.1rem; font-weight: 600; color: var(--text-main); }
  .close-btn { background: transparent; border: none; color: var(--text-muted); cursor: pointer; &:hover { color: var(--text-main); } }
}
.modal-form { padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem; overflow-y: auto; }
.form-group {
  display: flex; flex-direction: column; gap: 0.4rem;
  label { font-size: 0.85rem; font-weight: 500; color: var(--text-main); }
  input, select, textarea {
    padding: 0.65rem 0.75rem; border: 1px solid var(--border-color); background: var(--bg-primary);
    color: var(--text-main); border-radius: 6px; font-size: 0.9rem; outline: none; font-family: inherit;
    &:focus { border-color: var(--primary); }
  }
  textarea { resize: vertical; }
}
.modal-actions {
  display: flex; justify-content: flex-end; gap: 0.75rem; margin-top: 1rem;
  .btn-cancel { background: var(--bg-tertiary); color: var(--text-main); border: 1px solid var(--border-color); padding: 0.5rem 1rem; border-radius: 6px; font-weight: 500; cursor: pointer; &:hover { background: var(--bg-hover); } }
  .btn-submit { background: var(--primary); color: white; border: none; padding: 0.5rem 1rem; border-radius: 6px; font-weight: 500; cursor: pointer; &:hover { background: var(--primary-hover); } }
}
</style>
