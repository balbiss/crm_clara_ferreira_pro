<script setup>
import { ref, reactive, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { VueFlow, useVueFlow, Position } from '@vue-flow/core'
import { Background } from '@vue-flow/background'
import '@vue-flow/core/dist/style.css'
import '@vue-flow/core/dist/theme-default.css'
import {
  ArrowLeft, Undo2, Redo2, Save, ZoomIn, ZoomOut, Maximize, X,
  Zap, MessageCircle, HelpCircle, Image, Video, Mic, FileText,
  MousePointerClick, LayoutList, GitFork, Clock, OctagonX,
  Tag, TagIcon, UserCheck, Variable, Webhook, Plus, Trash2
} from '@lucide/vue'
import api from '../api'
import TriggerNode from '../components/flow-nodes/TriggerNode.vue'
import MessageNode from '../components/flow-nodes/MessageNode.vue'
import QuestionNode from '../components/flow-nodes/QuestionNode.vue'
import MediaNode from '../components/flow-nodes/MediaNode.vue'
import OptionsNode from '../components/flow-nodes/OptionsNode.vue'
import ConditionNode from '../components/flow-nodes/ConditionNode.vue'
import WaitNode from '../components/flow-nodes/WaitNode.vue'
import ActionNode from '../components/flow-nodes/ActionNode.vue'
import EndNode from '../components/flow-nodes/EndNode.vue'

// Flow Builder (MVP) — canvas via Vue Flow (@vue-flow/core, equivalente Vue
// do React Flow). Nós identificados por `key` (UUID gerado aqui, não o id
// do Rails) — ver backend/app/models/flow_node.rb pro motivo.
const route = useRoute()
const router = useRouter()
const flowId = route.params.id

const { project, addEdges, findNode, fitView, zoomIn, zoomOut, onConnect, onNodeClick, onPaneReady, onNodesChange, onEdgesChange } = useVueFlow()

const nodeTypes = {
  trigger: TriggerNode,
  send_message: MessageNode,
  ask_question: QuestionNode,
  send_media: MediaNode,
  options: OptionsNode,
  condition: ConditionNode,
  wait: WaitNode,
  action: ActionNode,
  end: EndNode
}

const isLoading = ref(true)
const flow = reactive({ id: null, name: '', description: '', channel: '', active: true })
const nodes = ref([])
const edges = ref([])
const selectedNode = ref(null)
const saveStatus = ref('') // '' | 'saving' | 'saved'
const nameEditing = ref(false)
const agents = ref([])
const tags = ref([])

// Alguns itens da paleta compartilham node_type e só mudam o "preset"
// inicial (ex: os 4 tipos de mídia são todos `send_media` com media_type
// diferente) — evita inflar node_type/componente por bullet do prompt
// quando a diferença é só um campo de config.
const PALETTE = [
  { category: 'Gatilhos', items: [
    { node_type: 'trigger', label: 'Gatilho', icon: Zap }
  ] },
  { category: 'Mensagens', items: [
    { node_type: 'send_message', label: 'Enviar mensagem', icon: MessageCircle },
    { node_type: 'ask_question', label: 'Perguntar', icon: HelpCircle },
    { node_type: 'send_media', label: 'Enviar imagem', icon: Image, preset: { media_type: 'image' } },
    { node_type: 'send_media', label: 'Enviar vídeo', icon: Video, preset: { media_type: 'video' } },
    { node_type: 'send_media', label: 'Enviar áudio', icon: Mic, preset: { media_type: 'audio' } },
    { node_type: 'send_media', label: 'Enviar documento', icon: FileText, preset: { media_type: 'document' } },
    { node_type: 'options', label: 'Botões', icon: MousePointerClick, preset: { mode: 'buttons' } },
    { node_type: 'options', label: 'Lista de opções', icon: LayoutList, preset: { mode: 'list' } }
  ] },
  { category: 'Condições', items: [
    { node_type: 'condition', label: 'Condição', icon: GitFork }
  ] },
  { category: 'Ações', items: [
    { node_type: 'action', label: 'Adicionar etiqueta', icon: Tag, preset: { action_type: 'add_tag' } },
    { node_type: 'action', label: 'Remover etiqueta', icon: TagIcon, preset: { action_type: 'remove_tag' } },
    { node_type: 'action', label: 'Atribuir atendente', icon: UserCheck, preset: { action_type: 'assign_agent' } },
    { node_type: 'action', label: 'Atualizar variável', icon: Variable, preset: { action_type: 'update_variable' } },
    { node_type: 'action', label: 'Enviar webhook', icon: Webhook, preset: { action_type: 'send_webhook' } },
    { node_type: 'wait', label: 'Aguardar', icon: Clock },
    { node_type: 'end', label: 'Encerrar fluxo', icon: OctagonX }
  ] }
]

const defaultDataFor = (type) => ({
  trigger: { trigger_type: 'manual', keyword: '' },
  send_message: { message: '' },
  ask_question: { question: '', variable: '' },
  send_media: { media_type: 'image', url: '', caption: '' },
  options: { mode: 'buttons', title: '', options: [] },
  condition: { check_type: 'variavel', variable: '', operator: 'igual', value: '' },
  wait: { duration: 30, unit: 'minutos' },
  action: { action_type: 'add_tag', tag_name: '', agent_id: null, variable: '', value: '', url: '' },
  end: {}
}[type] || {})

// ---- Carregar fluxo ----
const backendToVueFlow = (data) => {
  flow.id = data.id
  flow.name = data.name
  flow.description = data.description
  flow.channel = data.channel
  flow.active = data.active

  nodes.value = (data.nodes || []).map(n => ({
    id: n.key,
    type: n.node_type,
    position: n.position && n.position.x !== undefined ? n.position : { x: 100, y: 100 },
    data: n.data || {}
  }))

  edges.value = (data.edges || []).map(e => ({
    id: `${e.source_key}-${e.target_key}-${e.source_handle || ''}`,
    source: e.source_key,
    target: e.target_key,
    sourceHandle: e.source_handle || undefined,
    targetHandle: e.target_handle || undefined
  }))
}

const fetchFlow = async () => {
  isLoading.value = true
  try {
    const { data } = await api.get(`/flows/${flowId}`)
    backendToVueFlow(data)
    await nextTick()
    fitView()
  } catch (e) {
    console.error('Erro ao carregar fluxo:', e)
  } finally {
    isLoading.value = false
  }
}

// ---- Drag and drop da paleta pro canvas ----
const onPaletteDragStart = (event, item) => {
  event.dataTransfer.setData('application/flow-node-type', item.node_type)
  event.dataTransfer.setData('application/flow-node-preset', JSON.stringify(item.preset || {}))
  event.dataTransfer.effectAllowed = 'move'
}

const canvasWrapper = ref(null)
const onCanvasDrop = (event) => {
  const nodeType = event.dataTransfer.getData('application/flow-node-type')
  if (!nodeType) return
  let preset = {}
  try { preset = JSON.parse(event.dataTransfer.getData('application/flow-node-preset') || '{}') } catch (e) { preset = {} }
  const bounds = canvasWrapper.value.getBoundingClientRect()
  const position = project({ x: event.clientX - bounds.left, y: event.clientY - bounds.top })
  const key = crypto.randomUUID()
  nodes.value = [...nodes.value, { id: key, type: nodeType, position, data: { ...defaultDataFor(nodeType), ...preset } }]
  pushHistory()
}

// ---- Conexões ----
onConnect((connection) => {
  addEdges([connection])
  pushHistory()
})

// ---- Seleção / painel de configuração ----
onNodeClick(({ node }) => { selectedNode.value = node })
const closePanel = () => { selectedNode.value = null }

const updateSelectedData = (patch) => {
  if (!selectedNode.value) return
  const node = findNode(selectedNode.value.id)
  if (!node) return
  node.data = { ...node.data, ...patch }
}

// ---- Opções do nó "Botões"/"Lista" — cada opção vira uma saída nomeada
// (mesma ideia do Condição, só que em quantidade variável) ----
const addOption = () => {
  if (!selectedNode.value) return
  const node = findNode(selectedNode.value.id)
  if (!node) return
  const options = [...(node.data.options || []), { id: crypto.randomUUID(), label: '' }]
  node.data = { ...node.data, options }
}

const updateOptionLabel = (optionId, label) => {
  if (!selectedNode.value) return
  const node = findNode(selectedNode.value.id)
  if (!node) return
  const options = (node.data.options || []).map(o => o.id === optionId ? { ...o, label } : o)
  node.data = { ...node.data, options }
}

const removeOption = (optionId) => {
  if (!selectedNode.value) return
  const node = findNode(selectedNode.value.id)
  if (!node) return
  node.data = { ...node.data, options: (node.data.options || []).filter(o => o.id !== optionId) }
  // Sem isso a conexão que saía dessa opção fica órfã, apontando pra uma
  // saída que não existe mais.
  edges.value = edges.value.filter(e => !(e.source === selectedNode.value.id && e.sourceHandle === optionId))
  pushHistory()
}

onNodesChange(() => { scheduleAutosave() })
onEdgesChange(() => { scheduleAutosave() })

// ---- Histórico (desfazer/refazer) ----
const history = ref([])
const historyIndex = ref(-1)
const applyingHistory = ref(false)

const snapshot = () => JSON.parse(JSON.stringify({ nodes: nodes.value, edges: edges.value }))

const pushHistory = () => {
  if (applyingHistory.value) return
  history.value = history.value.slice(0, historyIndex.value + 1)
  history.value.push(snapshot())
  if (history.value.length > 50) history.value.shift()
  historyIndex.value = history.value.length - 1
}

const undo = () => {
  if (historyIndex.value <= 0) return
  historyIndex.value -= 1
  applyingHistory.value = true
  const snap = history.value[historyIndex.value]
  nodes.value = JSON.parse(JSON.stringify(snap.nodes))
  edges.value = JSON.parse(JSON.stringify(snap.edges))
  nextTick(() => { applyingHistory.value = false })
}

const redo = () => {
  if (historyIndex.value >= history.value.length - 1) return
  historyIndex.value += 1
  applyingHistory.value = true
  const snap = history.value[historyIndex.value]
  nodes.value = JSON.parse(JSON.stringify(snap.nodes))
  edges.value = JSON.parse(JSON.stringify(snap.edges))
  nextTick(() => { applyingHistory.value = false })
}

// ---- Autosave ----
let autosaveTimer = null
const scheduleAutosave = () => {
  if (isLoading.value) return
  saveStatus.value = 'saving'
  if (autosaveTimer) clearTimeout(autosaveTimer)
  autosaveTimer = setTimeout(saveGraph, 1500)
}

const saveGraph = async () => {
  if (!flow.id) return
  saveStatus.value = 'saving'
  try {
    await api.put(`/flows/${flow.id}/graph`, {
      nodes: nodes.value.map(n => ({ key: n.id, node_type: n.type, position: n.position, data: n.data })),
      edges: edges.value.map(e => ({ source_key: e.source, target_key: e.target, source_handle: e.sourceHandle || null, target_handle: e.targetHandle || null }))
    })
    saveStatus.value = 'saved'
  } catch (e) {
    console.error('Erro ao salvar fluxo:', e)
    saveStatus.value = ''
  }
}

const saveNow = () => {
  if (autosaveTimer) clearTimeout(autosaveTimer)
  saveGraph()
}

// Nome/descrição do fluxo (topo) — salva à parte via PATCH /flows/:id
let nameDebounce = null
watch(() => flow.name, () => {
  if (isLoading.value) return
  if (nameDebounce) clearTimeout(nameDebounce)
  nameDebounce = setTimeout(async () => {
    try { await api.patch(`/flows/${flow.id}`, { flow: { name: flow.name } }) } catch (e) { console.error(e) }
  }, 1000)
})

// Watch profundo em data dos nodes (edição no painel direito) pra disparar autosave
watch(nodes, () => { scheduleAutosave() }, { deep: true })

// ---- Atalhos de teclado ----
const onKeydown = (e) => {
  const meta = e.ctrlKey || e.metaKey
  if (meta && e.key.toLowerCase() === 'z' && e.shiftKey) { e.preventDefault(); redo() }
  else if (meta && e.key.toLowerCase() === 'z') { e.preventDefault(); undo() }
  else if (meta && e.key.toLowerCase() === 's') { e.preventDefault(); saveNow() }
}

const fetchAgentsAndTags = async () => {
  try {
    const [agentsRes, tagsRes] = await Promise.all([api.get('/agents'), api.get('/tags')])
    agents.value = agentsRes.data
    tags.value = tagsRes.data
  } catch (e) {
    console.error('Erro ao buscar agentes/etiquetas:', e)
  }
}

onMounted(async () => {
  await fetchFlow()
  fetchAgentsAndTags()
  history.value = [snapshot()]
  historyIndex.value = 0
  window.addEventListener('keydown', onKeydown)
})

onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown)
  if (autosaveTimer) clearTimeout(autosaveTimer)
})

const statusLabel = computed(() => ({ '': '', saving: 'Salvando...', saved: 'Salvo' }[saveStatus.value]))
// Montado no script pra nunca ter "{{"/"}}" literais dentro de uma
// interpolação do template (o parser do Vue quebra nisso — a primeira "}}"
// que aparece, mesmo dentro de uma string, fecha a interpolação errado).
const varHintLabels = computed(() => ['nome', 'telefone', 'email'].map(v => `{{${v}}}`))
</script>

<template>
  <div class="builder-page">
    <div class="builder-topbar">
      <router-link to="/fluxos" class="back-link"><ArrowLeft class="icon-sm" /> Fluxos</router-link>

      <input v-if="nameEditing" v-model="flow.name" class="name-input" @blur="nameEditing = false" @keyup.enter="nameEditing = false" />
      <h1 v-else class="flow-title" @click="nameEditing = true">{{ flow.name || 'Fluxo sem nome' }}</h1>

      <span class="status-badge" :class="{ connected: flow.active, disconnected: !flow.active }">
        <span class="dot"></span>{{ flow.active ? 'Ativo' : 'Inativo' }}
      </span>

      <div class="topbar-spacer"></div>

      <span class="save-indicator" :class="saveStatus">{{ statusLabel }}</span>

      <div class="toolbar-group">
        <button class="icon-btn" title="Diminuir zoom" @click="zoomOut()"><ZoomOut class="icon-sm" /></button>
        <button class="icon-btn" title="Aumentar zoom" @click="zoomIn()"><ZoomIn class="icon-sm" /></button>
        <button class="icon-btn" title="Ajustar à tela" @click="fitView({ padding: 0.2 })"><Maximize class="icon-sm" /></button>
      </div>

      <div class="toolbar-group">
        <button class="icon-btn" title="Desfazer" :disabled="historyIndex <= 0" @click="undo"><Undo2 class="icon-sm" /></button>
        <button class="icon-btn" title="Refazer" :disabled="historyIndex >= history.length - 1" @click="redo"><Redo2 class="icon-sm" /></button>
      </div>

      <button class="btn-primary" @click="saveNow"><Save class="icon-sm" /> Salvar</button>
    </div>

    <div class="builder-body">
      <div class="palette">
        <h2>Elementos</h2>
        <div v-for="group in PALETTE" :key="group.category" class="palette-group">
          <h3>{{ group.category }}</h3>
          <div
            v-for="item in group.items"
            :key="item.label"
            class="palette-item"
            draggable="true"
            @dragstart="onPaletteDragStart($event, item)"
          >
            <component :is="item.icon" class="icon-sm" />
            <span>{{ item.label }}</span>
          </div>
        </div>
      </div>

      <div ref="canvasWrapper" class="canvas-wrapper" @dragover.prevent @drop="onCanvasDrop">
        <VueFlow v-if="!isLoading" v-model:nodes="nodes" v-model:edges="edges" :node-types="nodeTypes" :delete-key-code="['Delete', 'Backspace']" fit-view-on-init @pane-ready="onPaneReady">
          <Background :gap="18" />
        </VueFlow>
        <div v-else class="canvas-loading">Carregando fluxo...</div>
      </div>

      <div v-if="selectedNode" class="config-panel">
        <div class="config-header">
          <h2>Configuração</h2>
          <button class="icon-btn" @click="closePanel"><X class="icon-sm" /></button>
        </div>

        <template v-if="selectedNode.type === 'trigger'">
          <div class="form-group">
            <label>Tipo de gatilho</label>
            <select :value="selectedNode.data.trigger_type" class="form-input" @change="updateSelectedData({ trigger_type: $event.target.value })">
              <option value="novo_contato">Novo contato</option>
              <option value="palavra_chave">Palavra-chave</option>
              <option value="mensagem_recebida">Mensagem recebida</option>
              <option value="evento">Evento</option>
              <option value="webhook">Webhook</option>
              <option value="manual">Manual</option>
            </select>
          </div>
          <div v-if="selectedNode.data.trigger_type === 'palavra_chave'" class="form-group">
            <label>Palavra-chave</label>
            <input class="form-input" :value="selectedNode.data.keyword" placeholder="ex: promoção" @input="updateSelectedData({ keyword: $event.target.value })" />
          </div>
          <p v-if="['evento', 'webhook'].includes(selectedNode.data.trigger_type)" class="hint">Editor pronto pra esse gatilho — a execução ao vivo ainda só cobre Palavra-chave (ver FlowRunnerService).</p>
        </template>

        <template v-else-if="selectedNode.type === 'send_message'">
          <div class="form-group">
            <label>Mensagem</label>
            <textarea class="form-input" rows="6" :value="selectedNode.data.message" placeholder="Olá {{nome}}, tudo bem?" @input="updateSelectedData({ message: $event.target.value })"></textarea>
            <p class="hint">Variáveis disponíveis: <code v-for="v in varHintLabels" :key="v">{{ v }}</code></p>
          </div>
        </template>

        <template v-else-if="selectedNode.type === 'ask_question'">
          <div class="form-group">
            <label>Pergunta</label>
            <textarea class="form-input" rows="3" :value="selectedNode.data.question" placeholder="Qual seu nome?" @input="updateSelectedData({ question: $event.target.value })"></textarea>
          </div>
          <div class="form-group">
            <label>Guardar resposta na variável</label>
            <input class="form-input" :value="selectedNode.data.variable" placeholder="ex: nome_cliente" @input="updateSelectedData({ variable: $event.target.value })" />
          </div>
        </template>

        <template v-else-if="selectedNode.type === 'send_media'">
          <div class="form-group">
            <label>Tipo</label>
            <select :value="selectedNode.data.media_type" class="form-input" @change="updateSelectedData({ media_type: $event.target.value })">
              <option value="image">Imagem</option>
              <option value="video">Vídeo</option>
              <option value="audio">Áudio</option>
              <option value="document">Documento</option>
            </select>
          </div>
          <div class="form-group">
            <label>URL do arquivo</label>
            <input class="form-input" :value="selectedNode.data.url" placeholder="https://..." @input="updateSelectedData({ url: $event.target.value })" />
          </div>
          <div class="form-group">
            <label>Legenda (opcional)</label>
            <input class="form-input" :value="selectedNode.data.caption" @input="updateSelectedData({ caption: $event.target.value })" />
          </div>
        </template>

        <template v-else-if="selectedNode.type === 'options'">
          <div class="form-group">
            <label>{{ selectedNode.data.mode === 'list' ? 'Título da lista' : 'Mensagem antes dos botões' }}</label>
            <textarea class="form-input" rows="2" :value="selectedNode.data.title" @input="updateSelectedData({ title: $event.target.value })"></textarea>
          </div>
          <div class="form-group">
            <label>Opções</label>
            <div v-for="opt in (selectedNode.data.options || [])" :key="opt.id" class="option-edit-row">
              <input class="form-input" :value="opt.label" placeholder="Texto da opção" @input="updateOptionLabel(opt.id, $event.target.value)" />
              <button class="icon-btn" title="Remover" @click="removeOption(opt.id)"><Trash2 class="icon-sm" /></button>
            </div>
            <button class="btn-add-option" @click="addOption"><Plus class="icon-xs" /> Adicionar opção</button>
          </div>
        </template>

        <template v-else-if="selectedNode.type === 'condition'">
          <div class="form-group">
            <label>Verificar</label>
            <select :value="selectedNode.data.check_type" class="form-input" @change="updateSelectedData({ check_type: $event.target.value })">
              <option value="variavel">Variável</option>
              <option value="resposta">Resposta</option>
              <option value="horario">Horário</option>
              <option value="dia">Dia</option>
              <option value="etiqueta">Etiqueta</option>
              <option value="status">Status</option>
            </select>
          </div>
          <div class="form-group">
            <label>Nome da variável</label>
            <input class="form-input" :value="selectedNode.data.variable" placeholder="ex: nome" @input="updateSelectedData({ variable: $event.target.value })" />
          </div>
          <div class="form-group">
            <label>Operador</label>
            <select :value="selectedNode.data.operator" class="form-input" @change="updateSelectedData({ operator: $event.target.value })">
              <option value="igual">é igual a</option>
              <option value="diferente">é diferente de</option>
              <option value="contem">contém</option>
            </select>
          </div>
          <div class="form-group">
            <label>Valor</label>
            <input class="form-input" :value="selectedNode.data.value" @input="updateSelectedData({ value: $event.target.value })" />
          </div>
        </template>

        <template v-else-if="selectedNode.type === 'action'">
          <div class="form-group">
            <label>Ação</label>
            <select :value="selectedNode.data.action_type" class="form-input" @change="updateSelectedData({ action_type: $event.target.value })">
              <option value="add_tag">Adicionar etiqueta</option>
              <option value="remove_tag">Remover etiqueta</option>
              <option value="assign_agent">Atribuir atendente</option>
              <option value="update_variable">Atualizar variável</option>
              <option value="send_webhook">Enviar webhook</option>
            </select>
          </div>

          <div v-if="['add_tag', 'remove_tag'].includes(selectedNode.data.action_type)" class="form-group">
            <label>Etiqueta</label>
            <select :value="selectedNode.data.tag_name" class="form-input" @change="updateSelectedData({ tag_name: $event.target.value })">
              <option value="">Selecione...</option>
              <option v-for="t in tags" :key="t.id" :value="t.name">{{ t.name }}</option>
            </select>
          </div>

          <div v-else-if="selectedNode.data.action_type === 'assign_agent'" class="form-group">
            <label>Atendente</label>
            <select :value="selectedNode.data.agent_id" class="form-input" @change="updateSelectedData({ agent_id: $event.target.value })">
              <option value="">Selecione...</option>
              <option v-for="a in agents" :key="a.id" :value="a.id">{{ a.name }}</option>
            </select>
          </div>

          <template v-else-if="selectedNode.data.action_type === 'update_variable'">
            <div class="form-group">
              <label>Variável</label>
              <input class="form-input" :value="selectedNode.data.variable" placeholder="ex: interesse" @input="updateSelectedData({ variable: $event.target.value })" />
            </div>
            <div class="form-group">
              <label>Novo valor</label>
              <input class="form-input" :value="selectedNode.data.value" @input="updateSelectedData({ value: $event.target.value })" />
            </div>
          </template>

          <div v-else-if="selectedNode.data.action_type === 'send_webhook'" class="form-group">
            <label>URL</label>
            <input class="form-input" :value="selectedNode.data.url" placeholder="https://..." @input="updateSelectedData({ url: $event.target.value })" />
          </div>
        </template>

        <template v-else-if="selectedNode.type === 'wait'">
          <div class="form-group">
            <label>Duração</label>
            <input type="number" min="1" class="form-input" :value="selectedNode.data.duration" @input="updateSelectedData({ duration: Number($event.target.value) })" />
          </div>
          <div class="form-group">
            <label>Unidade</label>
            <select :value="selectedNode.data.unit" class="form-input" @change="updateSelectedData({ unit: $event.target.value })">
              <option value="segundos">Segundos</option>
              <option value="minutos">Minutos</option>
              <option value="horas">Horas</option>
              <option value="dias">Dias</option>
            </select>
          </div>
        </template>

        <template v-else-if="selectedNode.type === 'end'">
          <p class="hint">Esse bloco encerra o fluxo — não precisa de configuração.</p>
        </template>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.builder-page {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--bg-primary);
}

.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 13px; height: 13px; }

.builder-topbar {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  padding: 0.75rem 1.25rem;
  border-bottom: 1px solid var(--border-color);
  background: var(--bg-secondary);
  flex-shrink: 0;
}

.back-link {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  color: var(--text-muted);
  text-decoration: none;
  font-size: 0.82rem;

  &:hover { color: var(--text-main); }
}

.flow-title {
  font-size: 1rem;
  font-weight: 700;
  color: var(--text-main);
  cursor: text;
  margin: 0;
}

.name-input {
  font-size: 1rem;
  font-weight: 700;
  color: var(--text-main);
  background: var(--bg-tertiary);
  border: 1px solid var(--primary);
  border-radius: 6px;
  padding: 0.2rem 0.5rem;
}

.status-badge {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.72rem;
  font-weight: 600;
  padding: 0.15rem 0.55rem;
  border-radius: 12px;

  .dot { width: 6px; height: 6px; border-radius: 50%; }

  &.connected { background: #d1fae5; color: #059669; .dot { background: #10b981; } }
  &.disconnected { background: #f3f4f6; color: #6b7280; .dot { background: #9ca3af; } }
}

.topbar-spacer { flex: 1; }

.save-indicator {
  font-size: 0.78rem;
  color: var(--text-muted);
  min-width: 60px;

  &.saved { color: #059669; }
}

.toolbar-group {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0 0.5rem;
  border-left: 1px solid var(--border-color);
}

.icon-btn {
  width: 32px;
  height: 32px;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
  color: var(--text-muted);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;

  &:hover:not(:disabled) { background: var(--bg-hover); color: var(--text-main); }
  &:disabled { opacity: 0.4; cursor: not-allowed; }
}

.btn-primary {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: var(--primary, #d49ba7);
  color: white;
  padding: 0.5rem 0.9rem;
  border-radius: 6px;
  font-size: 0.82rem;
  font-weight: 600;
  border: none;
  cursor: pointer;
}

.builder-body {
  display: flex;
  flex: 1;
  min-height: 0;
}

.palette {
  width: 220px;
  flex-shrink: 0;
  border-right: 1px solid var(--border-color);
  background: var(--bg-secondary);
  padding: 1rem;
  overflow-y: auto;

  h2 { font-size: 0.85rem; font-weight: 700; color: var(--text-main); margin-bottom: 0.75rem; }
}

.palette-group {
  margin-bottom: 1.25rem;

  h3 { font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; color: var(--text-muted); margin-bottom: 0.5rem; }
}

.palette-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.55rem 0.6rem;
  border-radius: 8px;
  border: 1px solid var(--border-color);
  background: var(--bg-tertiary);
  color: var(--text-main);
  font-size: 0.8rem;
  cursor: grab;
  margin-bottom: 0.4rem;

  &:hover { border-color: var(--primary); }
  &:active { cursor: grabbing; }
}

.canvas-wrapper {
  flex: 1;
  position: relative;
  background: var(--bg-primary);
}

.canvas-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--text-muted);
  font-size: 0.9rem;
}

.config-panel {
  width: 300px;
  flex-shrink: 0;
  border-left: 1px solid var(--border-color);
  background: var(--bg-secondary);
  padding: 1rem;
  overflow-y: auto;
}

.config-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;

  h2 { font-size: 0.9rem; font-weight: 700; color: var(--text-main); }
}

.form-group {
  margin-bottom: 1.1rem;

  label { display: block; margin-bottom: 0.4rem; font-size: 0.8rem; color: var(--text-main); font-weight: 500; }

  .form-input {
    width: 100%;
    padding: 0.55rem 0.7rem;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    font-size: 0.85rem;
    background: var(--bg-tertiary);
    color: var(--text-main);
    font-family: inherit;

    &:focus { outline: none; border-color: var(--primary); }
  }
}

.hint {
  font-size: 0.72rem;
  color: var(--text-muted);
  margin-top: 0.4rem;

  code { background: var(--bg-tertiary); padding: 0.1rem 0.3rem; border-radius: 4px; }
}

.option-edit-row {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  margin-bottom: 0.5rem;

  .form-input { flex: 1; }
  .icon-btn { flex-shrink: 0; }
}

.btn-add-option {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  width: 100%;
  padding: 0.5rem;
  border: 1px dashed var(--border-color);
  border-radius: 6px;
  background: transparent;
  color: var(--text-muted);
  font-size: 0.8rem;
  cursor: pointer;

  &:hover { border-color: var(--primary, #d49ba7); color: var(--primary, #d49ba7); }
}
</style>
