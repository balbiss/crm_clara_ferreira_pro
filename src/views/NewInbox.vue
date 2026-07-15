<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ChevronLeft, Check, X } from '@lucide/vue'
import { useConversationsStore } from '../store/conversations'

import api from '../api'
import Swal from 'sweetalert2'
import { brand } from '../config/brand'

const router = useRouter()
const route = useRoute()
const conversationsStore = useConversationsStore()

const steps = ref([
  { id: 1, title: 'Escolha o Canal', desc: `Escolha o provedor que você deseja integrar com o ${brand.name}.`, active: true, completed: false },
  { id: 2, title: 'Criar Caixa de Entrada', desc: 'Autenticar sua conta e criar uma caixa de entrada.', active: false, completed: false },
  { id: 3, title: 'Adicionar Agentes', desc: 'Adicionar agentes à caixa de entrada criada.', active: false, completed: false },
  { id: 4, title: 'Então!', desc: 'Está tudo pronto para começar!', active: false, completed: false },
])

const currentStep = ref(1)
const selectedChannel = ref(null)
const selectedProviderId = ref(null)

const showQrModal = ref(false)
const newInbox = ref({
  name: '',
  phone_number: ''
})

const channels = [
  { id: 'site',      name: 'Site',      desc: 'Criar um widget de chat ao vivo',    coming_soon: true,  svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="#3B82F6"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>' },
  { id: 'facebook',  name: 'Facebook',  desc: 'Conectar sua página do Facebook',   coming_soon: true,  svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="#1877F2"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.469h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.469h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>' },
  { id: 'whatsapp',  name: 'WhatsApp',  desc: 'Atenda seus clientes no WhatsApp',  coming_soon: false, svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="#25D366"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 0 0-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"/></svg>' },
  { id: 'sms',       name: 'SMS',       desc: 'Integrar o canal SMS',               coming_soon: true,  svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="#8B5CF6"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>' },
  { id: 'email',     name: 'E-Mail',    desc: 'Conectar com provedores',            coming_soon: true,  svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="#EF4444"><path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"/></svg>' },
  { id: 'api',       name: 'API',       desc: 'Crie um canal personalizado',        coming_soon: true,  svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#F59E0B" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>' },
  { id: 'telegram',  name: 'Telegram',  desc: 'Conectar via Telegram',              coming_soon: true,  svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="#229ED9"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.888-.662 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>' },
  { id: 'line',      name: 'Line',      desc: 'Conectar via Line',                  coming_soon: true,  svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="#00C300"><path d="M24 10.304c0-5.369-5.383-9.738-12-9.738-6.616 0-12 4.369-12 9.738 0 4.814 4.269 8.846 10.036 9.608.391.084.922.258 1.057.592.122.302.079.769.038 1.08l-.164 1.02c-.053.303-.243 1.186 1.04.647 1.281-.54 6.91-4.069 9.428-6.967 1.739-1.906 2.565-3.923 2.565-5.98zm-15.111 2.215h-2.585v-3.791c0-.285.231-.515.515-.515.285 0 .515.23.515.515v3.276h1.555c.285 0 .515.23.515.515 0 .285-.23.515-.515.515zm2.842 0h-1.031c-.285 0-.515-.23-.515-.515v-3.791c0-.285.23-.515.515-.515h1.031c.285 0 .515.23.515.515v3.791c0 .285-.23.515-.515.515zm4.07 0h-1.031c-.285 0-.515-.23-.515-.515v-1.89l-1.428 1.954c-.035.048-.078.087-.126.118-.088.055-.189.083-.292.083h-.158c-.285 0-.515-.23-.515-.515v-3.791c0-.285.231-.515.515-.515s.515.23.515.515v1.892l1.428-1.956c.036-.048.079-.087.127-.118.088-.055.188-.083.292-.083h.158c.285 0 .515.23.515.515v3.791c0 .285-.23.515-.515.515zm4.186-2.76h-1.555v-.515h1.555c.285 0 .515-.23.515-.515s-.23-.515-.515-.515h-1.555v-.515h1.555c.285 0 .515-.231.515-.516 0-.285-.23-.515-.515-.515h-2.07c-.285 0-.515.23-.515.515v3.791c0 .285.23.515.515.515h2.07c.285 0 .515-.23.515-.515 0-.285-.23-.515-.515-.515z"/></svg>' },
  { id: 'instagram', name: 'Instagram', desc: 'Conectar com Instagram',             coming_soon: false, svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="url(#ig-grad)"><defs><linearGradient id="ig-grad" x1="0" x2="1" y1="1" y2="0"><stop offset="0%" stop-color="#f09433"/><stop offset="25%" stop-color="#e6683c"/><stop offset="50%" stop-color="#dc2743"/><stop offset="75%" stop-color="#cc2366"/><stop offset="100%" stop-color="#bc1888"/></linearGradient></defs><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm6.406-11.845a1.44 1.44 0 1 0 0 2.881 1.44 1.44 0 0 0 0-2.881z"/></svg>' },
]

const whatsappProviders = [
  { id: 'baileys', name: 'Baileys', desc: 'Conectar via API', svg: '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="#25D366"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 0 0-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"/></svg>' }
]

const instagramLoading = ref(false)
const instagramError = ref(null)

const startInstagramOAuth = async () => {
  instagramLoading.value = true
  instagramError.value = null
  try {
    const res = await api.get('/instagram_oauth/authorize_url')
    window.location.href = res.data.url
  } catch (e) {
    instagramLoading.value = false
    Swal.fire('Erro', 'Não foi possível iniciar a conexão com o Instagram.', 'error')
  }
}

const selectChannel = (channel) => {
  if (channel.coming_soon) return
  if (channel.id === 'whatsapp') {
    selectedChannel.value = 'whatsapp'
  } else if (channel.id === 'instagram') {
    selectedChannel.value = 'instagram'
    startInstagramOAuth()
  } else {
    selectedChannel.value = channel.id
    selectedProviderId.value = 'none'
    goToStep(2)
  }
}

const selectProvider = (providerId) => {
  selectedProviderId.value = providerId
  goToStep(2)
}

const goToStep = (stepNumber) => {
  currentStep.value = stepNumber
  steps.value.forEach(s => {
    s.active = s.id === stepNumber
    s.completed = s.id < stepNumber
  })
}

const createdInboxId = ref(null)
const qrCodeData = ref(null)
const qrLoading = ref(false)
const qrConnected = ref(false)
let qrPollInterval = null

const createInbox = async () => {
  if (selectedProviderId.value === 'baileys') {
    try {
      const res = await api.post('/inboxes', { 
        inbox: {
          name: newInbox.value.name,
          phone_number: newInbox.value.phone_number,
          provider: 'baileys'
        }
      })
      createdInboxId.value = res.data.id
      goToStep(3)
    } catch (e) {
      Swal.fire('Erro', 'Não foi possível salvar a caixa de entrada.', 'error')
    }
  } else {
    goToStep(3)
  }
}

const openQrModal = async () => {
  showQrModal.value = true
  qrCodeData.value = null
  qrConnected.value = false
  qrLoading.value = true

  // Abre conexão do WS se ainda não estiver aberta
  conversationsStore.setupWebSocket()

  const fetchQr = async () => {
    try {
      const res = await api.get(`/inboxes/${createdInboxId.value}/qr_code`)
      if (res.data.qr_code) {
        qrCodeData.value = res.data.qr_code
        qrLoading.value = false
      }
    } catch (e) {
      console.warn('Erro ao buscar QR Code:', e.message)
    }
  }

  try {
    await fetchQr()
  } catch (e) {
    console.warn('Baileys API não acessível:', e.message)
  }

  qrPollInterval = setInterval(async () => {
    try {
      const statusRes = await api.get(`/inboxes/${createdInboxId.value}/status`)
      if (statusRes.data.connected) {
        qrConnected.value = true
        qrCodeData.value = null
        if (qrPollInterval) {
          clearInterval(qrPollInterval)
          qrPollInterval = null
        }
        return
      }

      await fetchQr()
    } catch (_) {}
  }, 4000)
}

const closeQrModal = () => {
  showQrModal.value = false
  if (qrPollInterval) {
    clearInterval(qrPollInterval)
    qrPollInterval = null
  }
}

const handleInboxUpdated = (e) => {
  const data = e.detail
  if (data.inbox_id === createdInboxId.value) {
    if (data.connection_status === 'open') {
      qrConnected.value = true
      qrCodeData.value = null
      if (qrPollInterval) {
        clearInterval(qrPollInterval)
        qrPollInterval = null
      }
    } else {
      qrConnected.value = false
      if (data.qr_code) {
        qrCodeData.value = data.qr_code
        qrLoading.value = false
      }
    }
  }
}

onMounted(() => {
  window.addEventListener('inbox-updated', handleInboxUpdated)
  conversationsStore.setupWebSocket()

  if (route.query.instagram_inbox_id) {
    selectedChannel.value = 'instagram'
    createdInboxId.value = Number(route.query.instagram_inbox_id)
    goToStep(4)
  } else if (route.query.instagram_error) {
    Swal.fire('Erro ao conectar Instagram', route.query.instagram_error, 'error')
  }
})

onUnmounted(() => {
  window.removeEventListener('inbox-updated', handleInboxUpdated)
  if (qrPollInterval) {
    clearInterval(qrPollInterval)
    qrPollInterval = null
  }
})

const goBack = () => {
  if (currentStep.value === 1 && selectedChannel.value === 'whatsapp') {
    selectedChannel.value = null
  } else if (currentStep.value > 1) {
    goToStep(currentStep.value - 1)
  } else {
    router.push('/settings/inboxes')
  }
}
</script>

<template>
  <div class="page-container">
    <div class="top-nav">
      <button class="back-btn" @click="goBack">
        <ChevronLeft class="icon-sm" />
        Anterior
      </button>
      <h2>Caixas de Entrada</h2>
    </div>

    <div class="wizard-container">
      <div class="stepper-sidebar">
        <div class="step-item" v-for="step in steps" :key="step.id" :class="{ 'active': step.active, 'completed': step.completed }">
          <div class="step-indicator">
            <div class="circle" v-if="!step.completed">{{ step.id }}</div>
            <div class="circle check" v-else><Check class="icon-xs" /></div>
            <div class="line" v-if="step.id !== 4"></div>
          </div>
          <div class="step-content">
            <h4 class="step-title">{{ step.title }}</h4>
            <p class="step-desc" v-if="step.active">{{ step.desc }}</p>
          </div>
        </div>
      </div>

      <div class="wizard-content">
        <!-- Passo 1: Escolha Geral -->
        <div class="step-pane" v-if="currentStep === 1 && selectedChannel !== 'whatsapp'">
          <div class="channel-grid">
            <div
              class="channel-card"
              v-for="channel in channels"
              :key="channel.id"
              :class="{ 'channel-card--disabled': channel.coming_soon }"
              @click="selectChannel(channel)"
            >
              <span v-if="channel.coming_soon" class="coming-soon-badge">Em Breve</span>
              <div class="icon-circle" v-html="channel.svg"></div>
              <h3 class="channel-name">{{ channel.name }}</h3>
              <p class="channel-desc">{{ channel.desc }}</p>
            </div>
          </div>
        </div>

        <!-- Passo 1.1: Escolha do WhatsApp -->
        <div class="step-pane" v-if="currentStep === 1 && selectedChannel === 'whatsapp'">
          <div class="provider-header">
            <h3>Selecione seu provedor de API</h3>
            <p>Conecte seu WhatsApp via API Baileys para começar a receber e enviar mensagens.</p>
          </div>
          <div class="channel-grid provider-grid">
            <div class="channel-card" v-for="provider in whatsappProviders" :key="provider.id" @click="selectProvider(provider.id)">
              <div class="icon-circle" v-html="provider.svg"></div>
              <h3 class="channel-name">{{ provider.name }}</h3>
              <p class="channel-desc">{{ provider.desc }}</p>
            </div>
          </div>
        </div>

        <!-- Passo 2: Criar Caixa de Entrada -->
        <div class="step-pane" v-if="currentStep === 2">
          <div class="form-mockup">
            <template v-if="selectedProviderId === 'baileys'">
              <div class="input-group">
                <label>Nome da Caixa de Entrada</label>
                <input type="text" v-model="newInbox.name" placeholder="Por favor, digite um nome para caixa de entrada" />
              </div>
              <div class="input-group" style="margin-top: 1rem;">
                <label>Número de telefone</label>
                <input type="text" v-model="newInbox.phone_number" placeholder="Por favor, insira o número de telefone do qual a mensagem será enviada" />
              </div>
              
              <button class="btn-primary" style="margin-top: 1.5rem;" @click="createInbox">Criar canal do WhatsApp</button>
            </template>
            <template v-else>
              <h3>Configurar Canal</h3>
              <p class="mockup-desc">Preencha os detalhes para configurar sua nova caixa de entrada.</p>
              <div class="input-group">
                <label>Nome do Canal</label>
                <input type="text" placeholder="Ex: Suporte Vendas" />
              </div>
              <button class="btn-primary" style="margin-top: 1rem;" @click="goToStep(3)">Criar Caixa de Entrada</button>
            </template>
          </div>
        </div>

        <!-- Passo 3: Adicionar Agentes -->
        <div class="step-pane" v-if="currentStep === 3">
          <div class="form-mockup step-agents">
            <h3>Agentes</h3>
            <p class="mockup-desc" style="line-height: 1.5;">Aqui você pode adicionar agentes para gerenciar sua caixa de entrada recém-criada. Somente esses agentes selecionados terão acesso à sua caixa de entrada. Os agentes que não fazem parte desta caixa de entrada não poderão ver ou responder a mensagens nessa caixa de entrada quando fizerem login.<br><br>PS: Como administrador, se você precisar acessar todas as caixas de entrada, adicione-se como agente a todas as caixas de entrada criadas.</p>
            <div class="input-group">
              <label>Agentes</label>
              <input type="text" placeholder="Escolha agentes para a caixa de entrada" />
            </div>
            <button class="btn-primary" style="margin-top: 1.5rem;" @click="goToStep(4)">Adicionar agentes</button>
          </div>
        </div>

        <!-- Passo 4: Fim -->
        <div class="step-pane" v-if="currentStep === 4">
          <div class="form-mockup success-pane">
            <h3>Sua caixa de entrada está pronta!</h3>
            <p class="mockup-desc" style="line-height: 1.5;" v-if="selectedChannel === 'instagram'">
              Sua conta do Instagram foi conectada com sucesso! As mensagens diretas já vão cair automaticamente nas conversas do CRM.
            </p>
            <p class="mockup-desc" style="line-height: 1.5;" v-else>Agora você já pode oferecer uma excelente experiência no atendimento de seus clientes através do seu novo Canal. Clique abaixo para configurar o canal do WhatsApp.</p>
            <div class="actions-row">
              <button class="btn-primary" v-if="selectedChannel === 'whatsapp'" @click="openQrModal">Conectar dispositivo</button>
              <div class="secondary-actions">
                <button class="btn-cancel">Mais configurações</button>
                <button class="btn-green" @click="router.push('/settings/inboxes')">Leva-me lá</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de Conexão (QR Code) -->
    <div v-if="showQrModal" class="modal-backdrop" @click.self="closeQrModal">
      <div class="qr-modal">
        <button class="close-btn" @click="closeQrModal"><X class="icon-sm" /></button>
        <div class="qr-content">
          <h3>Conecte o seu dispositivo</h3>
          <p class="qr-desc">Escaneie o QR code para conectar seu dispositivo. Certifique-se de que o número de telefone esteja correto antes de escanear.</p>
          
          <div class="phone-status">
            <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="#6b7280" class="whatsapp-icon"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 0 0-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"/></svg>
            <span class="phone-name">{{ newInbox.name }}</span>
            <span class="phone-number">{{ newInbox.phone_number }}</span>
            <div class="status-dot" :class="{ connected: qrConnected }"></div>
          </div>

          <!-- Conectado com sucesso -->
          <div v-if="qrConnected" class="connected-state">
            <div class="success-check">✓</div>
            <p>WhatsApp conectado com sucesso!</p>
          </div>

          <!-- Carregando QR -->
          <div v-else-if="qrLoading" class="qr-loading">
            <div class="spinner"></div>
            <p>Aguardando QR Code da API...</p>
          </div>

          <!-- QR Code real da API Baileys -->
          <div v-else-if="qrCodeData" class="qr-code-box">
            <img :src="qrCodeData" alt="QR Code WhatsApp" class="qr-image" />
          </div>

          <!-- API não configurada ou offline -->
          <div v-else class="qr-unavailable">
            <p>⚠️ A API Baileys não está acessível neste momento.</p>
            <p class="small-text">Verifique se a API está rodando e se a URL está correta nas configurações da caixa de entrada.</p>
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
  background: var(--bg-primary);
}

.top-nav {
  display: flex;
  align-items: center;
  padding: 1.5rem 2rem;
  background: var(--bg-secondary);
  border-bottom: 1px solid var(--border-color);

  .back-btn {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 0.9rem;
    font-weight: 500;
    cursor: pointer;
    margin-right: 1rem;

    &:hover {
      color: var(--text-main);
    }
  }

  h2 {
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--text-main);
  }
}

.wizard-container {
  display: flex;
  flex: 1;
  overflow: hidden;
  margin: 1.5rem 2rem;
  background: var(--bg-secondary);
  border-radius: 8px;
  border: 1px solid var(--border-color);
}

.stepper-sidebar {
  width: 280px;
  border-right: 1px solid var(--border-color);
  padding: 2rem 1.5rem;
  background: var(--bg-tertiary);
}

.step-item {
  display: flex;
  gap: 1rem;
  position: relative;
  min-height: 80px;

  &.active {
    .circle {
      background: var(--input-focus);
      border-color: var(--primary);
      color: var(--primary);
      font-weight: 600;
    }
    .step-title {
      color: var(--primary);
    }
  }

  &.completed {
    .circle {
      background: var(--bg-hover);
      border-color: var(--border-color);
      color: var(--text-muted);
      &.check {
        color: #10b981;
      }
    }
    .step-title {
      color: var(--text-main);
    }
  }

  .step-indicator {
    display: flex;
    flex-direction: column;
    align-items: center;
    
    .circle {
      width: 28px;
      height: 28px;
      border-radius: 50%;
      border: 1px solid var(--border-color);
      background: var(--bg-secondary);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.8rem;
      color: var(--text-muted);
      z-index: 2;
    }

    .line {
      flex: 1;
      width: 1px;
      background: var(--border-color);
      margin: 0.25rem 0;
    }
  }

  .step-content {
    flex: 1;
    padding-bottom: 2rem;

    .step-title {
      font-size: 0.9rem;
      font-weight: 600;
      color: var(--text-muted);
      margin-bottom: 0.25rem;
      padding-top: 4px;
    }

    .step-desc {
      font-size: 0.8rem;
      color: var(--text-muted);
      line-height: 1.4;
    }
  }
}

.wizard-content {
  flex: 1;
  padding: 2rem;
  overflow-y: auto;
}

.channel-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 1rem;
}

.provider-grid {
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
}

.provider-header {
  margin-bottom: 2rem;
  
  h3 {
    font-size: 1.2rem;
    color: var(--text-main);
    margin-bottom: 0.5rem;
  }
  
  p {
    color: var(--text-muted);
    font-size: 0.95rem;
    line-height: 1.5;
  }
}

.channel-card {
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1.5rem;
  cursor: pointer;
  transition: all 0.2s ease;
  background: var(--bg-secondary);
  position: relative;
  overflow: hidden;

  &:hover:not(.channel-card--disabled) {
    border-color: var(--primary);
    box-shadow: 0 4px 6px -1px var(--shadow-color);
    transform: translateY(-2px);
  }

  &--disabled {
    cursor: not-allowed;
    opacity: 0.6;
  }

  .coming-soon-badge {
    position: absolute;
    top: 10px;
    right: -22px;
    background: #f59e0b;
    color: white;
    font-size: 0.65rem;
    font-weight: 700;
    padding: 2px 28px;
    transform: rotate(35deg);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    pointer-events: none;
  }

  .icon-circle {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: var(--bg-hover);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-muted);
    margin-bottom: 1rem;
  }

  .channel-name {
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--text-main);
    margin-bottom: 0.5rem;
  }

  .channel-desc {
    font-size: 0.85rem;
    color: var(--text-muted);
    line-height: 1.4;
  }
}

.form-mockup {
  max-width: 500px;
  
  h3 { margin-bottom: 0.5rem; font-size: 1.25rem; color: var(--text-main); }
  .mockup-desc { color: var(--text-muted); font-size: 0.9rem; margin-bottom: 1.5rem; }
  
  .input-group {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    
    label { font-size: 0.85rem; font-weight: 500; color: var(--text-main); }
    input {
      padding: 0.6rem 1rem;
      border: 1px solid var(--border-color);
      border-radius: 6px;
      background: var(--bg-tertiary);
      color: var(--text-main);
      outline: none;
      &:focus { border-color: var(--primary); }
    }
  }

  .agent-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    
    .agent-item {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      font-size: 0.9rem;
      color: var(--text-main);
    }
  }

  &.success-pane {
    text-align: center;
    margin: 4rem auto;
    
    .success-icon {
      width: 64px;
      height: 64px;
      background: var(--input-focus);
      color: var(--primary);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 1.5rem auto;
      
      svg { width: 32px; height: 32px; }
    }
  }
}

.btn-primary {
  background: var(--primary);
  color: var(--text-inverse);
  padding: 0.6rem 1.25rem;
  border-radius: 6px;
  border: none;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;

  &:hover { background: var(--primary-hover); }
}



.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 12px; height: 12px; }

.actions-row {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 1.5rem;
  margin-top: 1.5rem;
  
  .secondary-actions {
    display: flex;
    gap: 1rem;
    align-items: center;
  }
}

.btn-green {
  background: #10b981;
  color: white;
  padding: 0.6rem 1.25rem;
  border-radius: 6px;
  border: none;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
  
  &:hover { background: #059669; }
}

.btn-cancel {
  background: white;
  color: #4b5563;
  padding: 0.6rem 1.25rem;
  border-radius: 6px;
  border: 1px solid #d1d5db;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  
  &:hover { background: #f3f4f6; }
}

/* Modal do QR Code */
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0,0,0,0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.qr-modal {
  background: white;
  border-radius: 12px;
  padding: 1.75rem;
  width: 380px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.15);
  position: relative;
  text-align: center;
  
  .close-btn {
    position: absolute;
    top: 0.75rem;
    right: 0.75rem;
    background: transparent;
    border: none;
    color: #9ca3af;
    cursor: pointer;
    
    &:hover { color: #4b5563; }
  }
  
  h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1.15rem;
    color: #111827;
  }
  
  .qr-desc {
    color: #6b7280;
    font-size: 0.85rem;
    margin-bottom: 1rem;
    line-height: 1.4;
  }
  
  .phone-status {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    margin-bottom: 1.25rem;
    color: #374151;
    font-size: 0.85rem;
    
    .whatsapp-icon { color: #6b7280; }
    
    .status-dot {
      width: 10px;
      height: 10px;
      background: #9ca3af;
      border-radius: 50%;
      margin-left: 0.25rem;
      transition: background 0.3s;
      
      &.connected {
        background: #10b981;
      }
    }
  }
  
  .qr-code-box {
    display: flex;
    justify-content: center;
    align-items: center;
    margin-bottom: 0.5rem;
    
    .qr-image {
      width: 180px;
      height: 180px;
      border-radius: 8px;
      border: 1px solid #e5e7eb;
      padding: 6px;
      background: white;
    }
  }

  .qr-loading {
    padding: 1.5rem 0;
    color: #6b7280;
    
    .spinner {
      width: 32px;
      height: 32px;
      border: 3px solid #e5e7eb;
      border-top-color: #3b82f6;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin: 0 auto 0.75rem;
    }
    
    p { font-size: 0.85rem; }
  }

  .connected-state {
    padding: 1.5rem 0;
    color: #059669;
    
    .success-check {
      width: 48px;
      height: 48px;
      background: #d1fae5;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.5rem;
      margin: 0 auto 0.75rem;
    }
    
    p { font-size: 0.95rem; font-weight: 500; }
  }

  .qr-unavailable {
    padding: 1.5rem 1rem;
    color: #6b7280;
    
    p { font-size: 0.85rem; margin-bottom: 0.5rem; }
    .small-text { font-size: 0.75rem; color: #9ca3af; }
  }
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 768px) {
  .wizard-container {
    flex-direction: column;
    margin: 1rem;
  }

  .stepper-sidebar {
    width: 100%;
    border-right: none;
    border-bottom: 1px solid var(--border-color);
    padding: 1.25rem 1rem;
  }

  .step-item {
    min-height: auto;
  }

  .wizard-content {
    padding: 1.25rem 1rem;
  }

  .qr-modal {
    width: calc(100vw - 2rem);
  }
}
</style>
