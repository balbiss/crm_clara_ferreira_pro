<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { X, Plus, Zap, GripVertical, MessageCircle } from 'lucide-vue-next'
import Swal from 'sweetalert2'
import api from '../api'
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

const flows = ref([])
const fetchFlows = async () => {
  try {
    const { data } = await api.get('/flows')
    flows.value = (data || []).filter(f => f.active)
  } catch (e) {
    console.error('Erro ao buscar fluxos:', e)
  }
}

onMounted(async () => {
  if (!pipelinesStore.isLoadedOnce) await pipelinesStore.fetchPipelines()
  if (!agentsStore.isLoadedOnce) await agentsStore.fetchAgents()
  if (!inboxesStore.isLoadedOnce) await inboxesStore.fetchInboxes()
  fetchFlows()
})

const goBack = () => router.push(`/pipelines/${route.params.slug}`)

// Só as ações que dá pra executar de verdade com a infra que já existe no CRM — sem
// integrações de anúncio (Meta/TikTok/Google Ads) que o Kommo tem, porque a empresa
// não tem conta de anúncio ligada aqui, seria automação decorativa.
const ACTION_TYPES = [
  { value: 'move_stage', label: 'Mudar etapa do lead' },
  { value: 'change_owner', label: 'Alterar responsável' },
  { value: 'create_note', label: 'Adicionar nota' },
  { value: 'create_task', label: 'Criar tarefa' },
  { value: 'ai_start', label: 'Ligar agente de IA' },
  { value: 'ai_stop', label: 'Pausar agente de IA' },
  { value: 'send_webhook', label: 'Enviar webhook' },
  { value: 'start_flow', label: 'Iniciar fluxo' }
]
const actionLabel = (type) => ACTION_TYPES.find(a => a.value === type)?.label || type

// Quando o gatilho dispara: o lead entra na etapa (padrão, o único modo até
// 2026-10-16) ou o cliente responde estando na etapa.
const EVENT_OPTIONS = [
  { value: 'enter', label: 'Quando o lead entrar na etapa', short: 'Ao entrar' },
  { value: 'client_reply', label: 'Quando o cliente responder (estando nesta etapa)', short: 'Quando o cliente responder' }
]
const eventShort = (trigger) => EVENT_OPTIONS.find(e => e.value === (trigger.event || 'enter'))?.short || ''

const TASK_TIPOS = [
  { value: 'manual_acompanhamento', label: 'Acompanhamento' },
  { value: 'manual_ligar', label: 'Ligar' },
  { value: 'manual_mensagem', label: 'Enviar mensagem' },
  { value: 'manual_agendamento', label: 'Agendar acerto' },
  { value: 'manual_cobranca', label: 'Cobrança' },
  { value: 'manual_outro', label: 'Outro' }
]
const TASK_PRIORIDADES = [
  { value: 'normal', label: 'Normal' },
  { value: 'alta', label: 'Alta' },
  { value: 'urgente', label: 'Urgente' }
]

const delaySummary = (trigger) => {
  const m = trigger.delay_minutes || 0
  if (!m) return 'Imediatamente'
  const h = Math.floor(m / 60)
  const min = m % 60
  return `Depois de ${h ? `${h}h` : ''}${h && min ? ' ' : ''}${min ? `${min}min` : ''}`
}

const triggerSummary = (trigger) => {
  if (trigger.action_type === 'create_task') {
    const prazo = trigger.config.prazo_horas ? ` (vence em ${trigger.config.prazo_horas}h)` : ''
    return `${actionLabel(trigger.action_type)}: "${trigger.config.titulo || '?'}"${prazo}`
  }
  if (trigger.action_type === 'move_stage') {
    const target = pipeline.value.pipeline_stages.find(s => s.id === trigger.config.target_stage_id)
    return `${actionLabel(trigger.action_type)} → ${target?.name || '?'}`
  }
  if (trigger.action_type === 'change_owner') {
    const agent = agentsStore.agents.find(a => a.id === trigger.config.user_id)
    return `${actionLabel(trigger.action_type)} → ${agent ? `${agent.first_name} ${agent.last_name}` : '?'}`
  }
  if (trigger.action_type === 'start_flow') {
    const flow = flows.value.find(f => f.id === trigger.config.flow_id)
    return `${actionLabel(trigger.action_type)} → ${flow ? flow.name : '?'}`
  }
  return actionLabel(trigger.action_type)
}

const showTriggerModal = ref(false)
const triggerStageId = ref(null)
const emptyTrigger = () => ({
  action_type: '', event: 'enter', target_stage_id: null, user_id: null, content: '', url: '', flow_id: null,
  task_titulo: '', task_descricao: '', task_tipo: 'manual_acompanhamento', task_prazo_horas: 0, task_prioridade: 'normal', task_user_id: null,
  delay_hours: 0, delay_minutes: 0
})
const newTrigger = ref(emptyTrigger())

const openTriggerModal = (stageId) => {
  triggerStageId.value = stageId
  newTrigger.value = emptyTrigger()
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
  } else if (t.action_type === 'create_task') {
    if (!t.task_titulo.trim()) return Swal.fire({ icon: 'warning', title: 'Atenção', text: 'Escreva o título da tarefa.' })
    config = {
      titulo: t.task_titulo.trim(),
      descricao: t.task_descricao.trim(),
      tipo: t.task_tipo,
      prazo_horas: parseInt(t.task_prazo_horas) || 0,
      prioridade: t.task_prioridade
    }
    if (t.task_user_id) config.user_id = t.task_user_id
  } else if (t.action_type === 'send_webhook') {
    if (!t.url.trim()) return Swal.fire({ icon: 'warning', title: 'Atenção', text: 'Informe a URL do webhook.' })
    config = { url: t.url.trim() }
  } else if (t.action_type === 'start_flow') {
    if (!t.flow_id) return Swal.fire({ icon: 'warning', title: 'Atenção', text: 'Escolha o fluxo.' })
    config = { flow_id: t.flow_id }
  }

  const delay_minutes = (parseInt(t.delay_hours) || 0) * 60 + (parseInt(t.delay_minutes) || 0)

  try {
    await pipelinesStore.createTrigger(triggerStageId.value, { action_type: t.action_type, event: t.event, config, delay_minutes })
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
              <span>
                <b class="trigger-event">{{ eventShort(trigger) }}:</b>
                {{ triggerSummary(trigger) }} <em class="trigger-delay">— {{ delaySummary(trigger) }}</em>
              </span>
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

          <template v-if="newTrigger.action_type === 'create_task'">
            <div class="form-group">
              <label>Título da tarefa</label>
              <input type="text" v-model="newTrigger.task_titulo" maxlength="120" placeholder="Ex: Acompanhar — ligar ou chamar no WhatsApp" />
            </div>
            <div class="form-group">
              <label>Tipo</label>
              <select v-model="newTrigger.task_tipo">
                <option v-for="t in TASK_TIPOS" :key="t.value" :value="t.value">{{ t.label }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Detalhes <span class="empty-hint">(opcional)</span></label>
              <textarea v-model="newTrigger.task_descricao" rows="2" placeholder="O que precisa ser feito"></textarea>
            </div>
            <div class="form-group">
              <label>Prazo pra fazer a tarefa</label>
              <div class="delay-row">
                <span>Vence em</span>
                <input type="number" min="0" v-model.number="newTrigger.task_prazo_horas" class="delay-input" />
                <span>horas</span>
              </div>
              <p class="empty-hint">0 = vence na hora que a tarefa for criada.</p>
            </div>
            <div class="form-group">
              <label>Prioridade</label>
              <select v-model="newTrigger.task_prioridade">
                <option v-for="p in TASK_PRIORIDADES" :key="p.value" :value="p.value">{{ p.label }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Responsável pela tarefa</label>
              <select v-model="newTrigger.task_user_id">
                <option :value="null">O responsável pela revendedora/lead</option>
                <option v-for="ag in agentsStore.agents" :key="ag.id" :value="ag.id">{{ ag.first_name }} {{ ag.last_name }}</option>
              </select>
            </div>
          </template>

          <div class="form-group" v-if="newTrigger.action_type === 'send_webhook'">
            <label>URL do webhook</label>
            <input type="text" v-model="newTrigger.url" placeholder="https://..." />
          </div>

          <div class="form-group" v-if="newTrigger.action_type === 'start_flow'">
            <label>Fluxo</label>
            <select v-model="newTrigger.flow_id">
              <option :value="null" disabled>Escolha o fluxo...</option>
              <option v-for="f in flows" :key="f.id" :value="f.id">{{ f.name }}</option>
            </select>
            <p v-if="!flows.length" class="empty-hint">Nenhum fluxo ativo ainda — crie um em "Fluxos" no menu.</p>
          </div>

          <p v-if="['ai_start', 'ai_stop'].includes(newTrigger.action_type)" class="empty-hint">
            Sem configuração extra — dispara direto na hora escolhida abaixo.
          </p>

          <div class="form-group" v-if="newTrigger.action_type">
            <label>Quando disparar</label>
            <select v-model="newTrigger.event">
              <option v-for="e in EVENT_OPTIONS" :key="e.value" :value="e.value">{{ e.label }}</option>
            </select>
            <p v-if="newTrigger.event === 'client_reply'" class="empty-hint">
              Dispara na 1ª mensagem que o cliente mandar enquanto o lead estiver nesta etapa. Roda uma vez só por etapa (se o lead sair e voltar, vale de novo).
            </p>
          </div>

          <div class="form-group" v-if="newTrigger.action_type">
            <label>Executar</label>
            <div class="delay-row">
              <span>Depois de</span>
              <input type="number" min="0" v-model.number="newTrigger.delay_hours" class="delay-input" />
              <span>h</span>
              <input type="number" min="0" max="59" v-model.number="newTrigger.delay_minutes" class="delay-input" />
              <span>min</span>
            </div>
            <p class="empty-hint">
              Deixe 0 e 0 pra executar na hora
              <template v-if="newTrigger.event === 'client_reply'">em que o cliente responder.</template>
              <template v-else>em que o lead entrar nessa etapa.</template>
              Se o lead sair da etapa antes do tempo acabar, a ação não roda.
            </p>
          </div>

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
  // Quebra em várias linhas (antes cortava com "…" e escondia o evento/ação,
  // que agora são mais compridos: "Quando o cliente responder: Mudar etapa...").
  span { flex: 1; min-width: 0; white-space: normal; overflow-wrap: anywhere; line-height: 1.3; }
}
.trigger-chip-remove { background: none; border: none; color: inherit; cursor: pointer; display: flex; opacity: 0.7; &:hover { opacity: 1; } }
.trigger-delay { font-style: normal; opacity: 0.75; font-weight: 500; }
.trigger-event { font-weight: 700; }

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
.delay-row {
  display: flex; align-items: center; gap: 0.4rem;
  span { font-size: 0.85rem; color: var(--text-muted); white-space: nowrap; }
}
.delay-input {
  width: 64px; padding: 0.5rem 0.6rem; border: 1px solid var(--border-color); background: var(--bg-primary);
  color: var(--text-main); border-radius: 6px; font-size: 0.9rem; outline: none;
  &:focus { border-color: var(--primary); }
}
.modal-actions {
  display: flex; justify-content: flex-end; gap: 0.75rem; margin-top: 1rem;
  .btn-cancel { background: var(--bg-tertiary); color: var(--text-main); border: 1px solid var(--border-color); padding: 0.5rem 1rem; border-radius: 6px; font-weight: 500; cursor: pointer; &:hover { background: var(--bg-hover); } }
  .btn-submit { background: var(--primary); color: white; border: none; padding: 0.5rem 1rem; border-radius: 6px; font-weight: 500; cursor: pointer; &:hover { background: var(--primary-hover); } }
}
</style>
