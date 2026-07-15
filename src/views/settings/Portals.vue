<script setup>
import { ref, onMounted } from 'vue'
import { Copy, Check, ChevronRight } from 'lucide-vue-next'
import api from '../../api'

const webhookUrls = ref({})
const copiedKey   = ref(null)
const isLoading   = ref(true)

onMounted(async () => {
  try {
    const res = await api.get('/account')
    webhookUrls.value = res.data.webhook_urls || {}
  } catch (e) {
    console.error(e)
  } finally {
    isLoading.value = false
  }
})

const copy = async (key, url) => {
  await navigator.clipboard.writeText(url)
  copiedKey.value = key
  setTimeout(() => { copiedKey.value = null }, 2500)
}

const portals = [
  {
    key:        'canal_pro',
    name:       'Canal Pro',
    logo:       '/logos/canal-pro.svg',
    color:      '#7B2FA2',
    colorLight: '#F3E8FF',
    border:     '#D8B4FE',
    description:'Cole a URL abaixo em Configurações → Leads → Receber leads no CRM',
    howto: [
      'Acesse seu painel do Canal Pro',
      'Vá em Configurações → Leads → Receber leads no CRM',
      'No campo "Nome do CRM" escreva: VisitaIA CRM',
      'Cole a URL abaixo no campo "URL de integração"',
      'Clique em Salvar alterações',
    ]
  },
  {
    key:        'zap',
    name:       'ZAP Imóveis',
    logo:       '/logos/zap.svg',
    color:      '#FF5A00',
    colorLight: '#FFF0E8',
    border:     '#FED7AA',
    description:'Cole a URL abaixo no painel do Programa de Parceiros ZAP',
    howto: [
      'Acesse o Programa de Parceiros do ZAP Imóveis',
      'Vá em Integrações → Webhook de Leads',
      'Cole a URL no campo de endpoint',
      'Salve e clique em Enviar lead de teste',
    ]
  },
  {
    key:        'viva_real',
    name:       'Viva Real',
    logo:       '/logos/viva-real.svg',
    color:      '#0062CC',
    colorLight: '#EFF6FF',
    border:     '#BFDBFE',
    description:'Cole a URL abaixo no painel de integrações do Viva Real',
    howto: [
      'Acesse o painel do Viva Real (mesmo login do ZAP)',
      'Vá em Integrações → Webhook de Leads',
      'Cole a URL no campo de endpoint',
      'Salve e clique em Enviar lead de teste',
    ]
  }
]
</script>

<template>
  <div class="portals-page">
    <div class="page-header">
      <h2>Portais Imobiliários</h2>
      <p>Receba leads do Canal Pro, ZAP e Viva Real diretamente no CRM. Quando um lead chega, a IA responde no WhatsApp automaticamente.</p>
    </div>

    <div v-if="isLoading" class="loading">
      <div class="spinner"></div>
    </div>

    <div v-else class="portals-list">
      <div v-for="portal in portals" :key="portal.key" class="portal-card" :style="{ '--color': portal.color, '--light': portal.colorLight, '--border': portal.border }">

        <!-- Header -->
        <div class="card-header">
          <div class="logo-wrap">
            <img :src="portal.logo" :alt="portal.name" class="portal-logo" />
          </div>
          <div class="header-text">
            <p class="card-desc">{{ portal.description }}</p>
          </div>
          <div class="badge-active">
            <span class="pulse-dot"></span>
            Ativo
          </div>
        </div>

        <!-- Webhook URL -->
        <div class="webhook-row">
          <div class="url-box" @click="copy(portal.key, webhookUrls[portal.key])">
            <span class="url-text">{{ webhookUrls[portal.key] || '...' }}</span>
          </div>
          <button
            class="btn-copy"
            :class="{ done: copiedKey === portal.key }"
            @click="copy(portal.key, webhookUrls[portal.key])"
          >
            <Check v-if="copiedKey === portal.key" :size="14" />
            <Copy v-else :size="14" />
            {{ copiedKey === portal.key ? 'Copiado!' : 'Copiar URL' }}
          </button>
        </div>

        <!-- Body: steps + flow -->
        <div class="card-body">
          <div class="steps-col">
            <p class="col-title">Como configurar</p>
            <div class="steps">
              <div v-for="(step, i) in portal.howto" :key="i" class="step">
                <span class="step-num">{{ i + 1 }}</span>
                <span class="step-text">{{ step }}</span>
              </div>
            </div>
          </div>

          <div class="flow-col">
            <p class="col-title">O que acontece</p>
            <div class="flow">
              <div class="flow-node">
                <div class="flow-icon-wrap">
                  <img :src="portal.logo" class="flow-logo" :alt="portal.name" />
                </div>
                <span>Lead no portal</span>
              </div>
              <ChevronRight :size="14" class="chevron" />
              <div class="flow-node">
                <div class="flow-icon-wrap neutral">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                    <circle cx="12" cy="8" r="4" fill="#6b7280"/>
                    <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" stroke="#6b7280" stroke-width="2" stroke-linecap="round"/>
                  </svg>
                </div>
                <span>Contato criado</span>
              </div>
              <ChevronRight :size="14" class="chevron" />
              <div class="flow-node">
                <div class="flow-icon-wrap green">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                    <path d="M20.52 3.48C18.24 1.2 15.12 0 12 0 5.4 0 0 5.4 0 12c0 2.1.54 4.14 1.56 5.94L0 24l6.24-1.56C8.04 23.46 10.02 24 12 24c6.6 0 12-5.4 12-12 0-3.12-1.2-6.24-3.48-8.52zM12 22c-1.8 0-3.54-.48-5.1-1.38l-.36-.24-3.72.96.96-3.66-.24-.36C2.52 15.66 2 13.86 2 12 2 6.48 6.48 2 12 2c2.64 0 5.16 1.02 7.02 2.88C20.88 6.78 22 9.36 22 12c0 5.52-4.48 10-10 10z" fill="#22c55e"/>
                    <path d="M17.46 14.34c-.3-.15-1.74-.84-2.01-.93-.27-.12-.48-.15-.66.15-.18.3-.75.93-.9 1.11-.18.18-.33.21-.63.06-.3-.15-1.29-.48-2.43-1.53-.9-.81-1.5-1.8-1.68-2.1-.18-.3-.03-.48.12-.63.15-.12.3-.33.45-.51.15-.15.21-.3.3-.48.09-.18.06-.33-.03-.48-.09-.15-.66-1.59-.9-2.19-.24-.57-.48-.51-.66-.51-.18-.03-.36-.03-.54-.03-.18 0-.48.06-.75.33-.27.27-1.02.99-1.02 2.43 0 1.44 1.05 2.82 1.2 3.03.15.18 2.07 3.15 5.01 4.41.69.3 1.23.48 1.65.6.69.21 1.32.18 1.83.12.57-.09 1.74-.72 1.98-1.38.27-.69.27-1.26.21-1.38-.09-.12-.27-.18-.57-.33z" fill="#22c55e"/>
                  </svg>
                </div>
                <span>IA responde no WhatsApp</span>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>

    <div class="info-tip">
      <strong>Atenção:</strong> A resposta automática no WhatsApp só ocorre se o lead informar o telefone no portal.
      ZAP e Viva Real às vezes ocultam o número — nesses casos o lead aparece no CRM para follow-up manual.
    </div>
  </div>
</template>

<style scoped>
.portals-page {
  padding: 1.75rem 2rem;
}

.page-header {
  margin-bottom: 1.75rem;
}
.page-header h2 {
  font-size: 1.3rem;
  font-weight: 700;
  color: #111827;
  margin: 0 0 0.35rem;
}
.page-header p {
  color: #6b7280;
  font-size: 0.88rem;
  margin: 0;
  line-height: 1.6;
}

.loading {
  display: flex;
  justify-content: center;
  padding: 3rem;
}
.spinner {
  width: 26px; height: 26px;
  border: 3px solid #e5e7eb;
  border-top-color: #6366f1;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Cards */
.portals-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1.25rem;
}

.portal-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  overflow: hidden;
  border-top: 3px solid var(--color);
}

/* Header */
.card-header {
  display: flex;
  align-items: center;
  gap: 1.25rem;
  padding: 1rem 1.25rem 0.9rem;
  border-bottom: 1px solid #f3f4f6;
}

.logo-wrap {
  flex-shrink: 0;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 6px 10px;
  display: flex;
  align-items: center;
}

.portal-logo {
  height: 28px;
  width: auto;
  display: block;
}

.header-text {
  flex: 1;
}

.card-desc {
  margin: 0;
  font-size: 0.83rem;
  color: #6b7280;
  line-height: 1.5;
}

.badge-active {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.25rem 0.65rem;
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  color: #15803d;
  white-space: nowrap;
}

.pulse-dot {
  width: 6px; height: 6px;
  background: #22c55e;
  border-radius: 50%;
  animation: pulse 2s infinite;
}
@keyframes pulse { 0%,100% { opacity:1 } 50% { opacity:.35 } }

/* Webhook row */
.webhook-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.25rem;
  background: #fafafa;
  border-bottom: 1px solid #f0f0f0;
}

.url-box {
  flex: 1;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 7px;
  padding: 0.5rem 0.75rem;
  cursor: pointer;
  overflow: hidden;
}

.url-text {
  font-family: 'Courier New', monospace;
  font-size: 0.78rem;
  color: #334155;
  white-space: nowrap;
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
}

.btn-copy {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.5rem 0.9rem;
  background: var(--color);
  color: white;
  border: none;
  border-radius: 7px;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: filter 0.15s;
  flex-shrink: 0;
}
.btn-copy:hover { filter: brightness(0.9); }
.btn-copy.done  { background: #10b981; }

/* Card body */
.card-body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0;
}

.steps-col {
  padding: 1rem 1.25rem;
  border-right: 1px solid #f0f0f0;
}

.flow-col {
  padding: 1rem 1.25rem;
}

.col-title {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.07em;
  color: #9ca3af;
  margin: 0 0 0.65rem;
}

/* Steps */
.steps { display: flex; flex-direction: column; gap: 0.4rem; }

.step {
  display: flex;
  align-items: flex-start;
  gap: 0.55rem;
}

.step-num {
  width: 18px; height: 18px;
  border-radius: 50%;
  background: var(--light);
  color: var(--color);
  font-size: 0.68rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  margin-top: 1px;
}

.step-text {
  font-size: 0.8rem;
  color: #4b5563;
  line-height: 1.45;
}

/* Flow */
.flow {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: nowrap;
}

.flow-node {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.35rem;
  flex: 1;
  min-width: 0;
}

.flow-icon-wrap {
  width: 40px; height: 40px;
  border-radius: 10px;
  background: var(--light);
  border: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.flow-icon-wrap.neutral { background: #f9fafb; border-color: #e5e7eb; }
.flow-icon-wrap.green   { background: #f0fdf4; border-color: #bbf7d0; }

.flow-logo {
  width: 26px; height: 26px;
  object-fit: contain;
}

.flow-node span {
  font-size: 0.68rem;
  color: #6b7280;
  text-align: center;
  font-weight: 500;
  line-height: 1.3;
}

.chevron {
  color: #d1d5db;
  flex-shrink: 0;
  margin-bottom: 18px;
}

/* Tip */
.info-tip {
  background: #fffbeb;
  border: 1px solid #fde68a;
  border-radius: 8px;
  padding: 0.85rem 1.1rem;
  font-size: 0.84rem;
  color: #78350f;
  line-height: 1.6;
}
</style>
