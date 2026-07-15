<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ChevronLeft, Sparkles } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'
import PromptGeneratorModal from '../components/PromptGeneratorModal.vue'

const route = useRoute()
const router = useRouter()
const inbox = ref(null)
const isLoading = ref(true)

const allTabs = [
  { id: 'settings', name: 'Configurações' },
  { id: 'agents', name: 'Agentes' },
  { id: 'hours', name: 'Horário de funcionamento' },
  { id: 'bot', name: 'Secretária Virtual' },
  { id: 'followup', name: 'Resgate (Follow-up)' }
]
// Follow-up não é permitido no Instagram (janela de 24h da Meta)
const tabs = computed(() => allTabs.filter(t => t.id !== 'followup' || inbox.value?.provider !== 'instagram'))
const activeTab = ref('settings')
const agents = ref([])
const isLoadingAgents = ref(false)
const isPromptModalOpen = ref(false)
const groups = ref([])

const handlePromptGenerated = (generatedPrompt) => {
  inbox.value.ai_prompt = generatedPrompt
}

const defaultWorkingHours = [
  { day: 1, name: 'Segunda-feira', open: true, start: '09:00', end: '18:00' },
  { day: 2, name: 'Terça-feira', open: true, start: '09:00', end: '18:00' },
  { day: 3, name: 'Quarta-feira', open: true, start: '09:00', end: '18:00' },
  { day: 4, name: 'Quinta-feira', open: true, start: '09:00', end: '18:00' },
  { day: 5, name: 'Sexta-feira', open: true, start: '09:00', end: '18:00' },
  { day: 6, name: 'Sábado', open: false, start: '09:00', end: '13:00' },
  { day: 0, name: 'Domingo', open: false, start: '09:00', end: '13:00' }
]

const fetchInbox = async () => {
  try {
    const response = await api.get(`/inboxes/${route.params.id}`)
    inbox.value = response.data
    
    // Initialize working hours if empty
    if (!inbox.value.working_hours || inbox.value.working_hours.length === 0) {
      inbox.value.working_hours = JSON.parse(JSON.stringify(defaultWorkingHours))
    } else {
      // Map names if they are missing
      inbox.value.working_hours = inbox.value.working_hours.map(wh => {
        const defaultWh = defaultWorkingHours.find(d => d.day === wh.day)
        return { ...wh, name: defaultWh ? defaultWh.name : '' }
      })
    }
  } catch (error) {
    console.error('Failed to fetch inbox details:', error)
    router.push('/settings/inboxes')
  } finally {
    isLoading.value = false
  }
}

const fetchAgents = async () => {
  isLoadingAgents.value = true
  try {
    const response = await api.get(`/inboxes/${route.params.id}/members`)
    agents.value = response.data
  } catch (error) {
    console.error('Failed to fetch agents:', error)
  } finally {
    isLoadingAgents.value = false
  }
}

const toggleAgent = async (agent) => {
  try {
    if (agent.is_member) {
      await api.delete(`/inboxes/${route.params.id}/members/${agent.id}`)
      agent.is_member = false
    } else {
      await api.post(`/inboxes/${route.params.id}/members`, { user_id: agent.id })
      agent.is_member = true
    }
  } catch (error) {
    console.error('Failed to toggle agent:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao atualizar permissão do agente.', showConfirmButton: false, timer: 3500 })
  }
}

const fetchGroups = async () => {
  try {
    const response = await api.get('/round_robin_groups')
    groups.value = response.data
  } catch (error) {
    console.error('Failed to fetch round robin groups:', error)
  }
}

onMounted(() => {
  fetchInbox()
  fetchAgents()
  fetchGroups()
})

const goBack = () => {
  router.push('/settings/inboxes')
}

const saveSettings = async () => {
  try {
    if (inbox.value.followup_enabled && inbox.value.followup_wait_time_minutes < 10) {
      Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'O tempo mínimo do follow-up é 10 minutos.', showConfirmButton: false, timer: 4000 })
      return;
    }

    await api.put(`/inboxes/${inbox.value.id}`, { 
      inbox: {
        name: inbox.value.name,
        bot_prompt: inbox.value.bot_prompt,
        ai_enabled: inbox.value.ai_enabled,
        ai_name: inbox.value.ai_name,
        ai_prompt: inbox.value.ai_prompt,
        working_hours_enabled: inbox.value.working_hours_enabled,
        out_of_office_message: inbox.value.out_of_office_message,
        working_hours: inbox.value.working_hours,
        followup_enabled: inbox.value.followup_enabled,
        followup_max_attempts: inbox.value.followup_max_attempts,
        followup_wait_time_minutes: inbox.value.followup_wait_time_minutes,
        followup_send_closing_message: inbox.value.followup_send_closing_message,
        followup_closing_message: inbox.value.followup_closing_message,
        round_robin_group_id: inbox.value.round_robin_group_id
      }
    })
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Configurações salvas!', showConfirmButton: false, timer: 3000 })
  } catch (error) {
    console.error('Error saving settings:', error)
  }
}
</script>

<template>
  <div class="page-container">
    <div v-if="isLoading" class="loading-state">Carregando...</div>
    
    <div class="page-content" v-else-if="inbox">
      <!-- Top Navigation -->
      <button class="back-button" @click="goBack">
        <ChevronLeft class="icon-sm" /> Anterior <strong>Caixas de Entrada</strong>
      </button>

      <!-- Header -->
      <div class="header">
        <h1>{{ inbox.name }} ({{ inbox.phone_number }})</h1>
      </div>

      <!-- Tabs -->
      <div class="tabs-container">
        <button 
          v-for="tab in tabs" 
          :key="tab.id"
          class="tab-btn"
          :class="{ active: activeTab === tab.id }"
          @click="activeTab = tab.id"
        >
          {{ tab.name }}
        </button>
      </div>

      <!-- Tab Content: Settings -->
      <div class="tab-content" v-if="activeTab === 'settings'">
        <div class="form-section">
          
          <div class="form-row">
            <div class="label-col">
              <label>Imagem do Canal</label>
            </div>
            <div class="input-col">
              <div class="channel-image" style="background: transparent; border: none;">
                <svg v-if="inbox.provider === 'instagram'" xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 24 24" fill="url(#ig-grad-detail)"><defs><linearGradient id="ig-grad-detail" x1="0" x2="1" y1="1" y2="0"><stop offset="0%" stop-color="#f09433"/><stop offset="50%" stop-color="#dc2743"/><stop offset="100%" stop-color="#bc1888"/></linearGradient></defs><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm6.406-11.845a1.44 1.44 0 1 0 0 2.881 1.44 1.44 0 0 0 0-2.881z"/></svg>
                <svg v-else xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 24 24" fill="#25D366">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 0 0-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"/>
                </svg>
              </div>
            </div>
          </div>

          <div class="form-row">
            <div class="label-col">
              <label>Nome da Caixa de Entrada</label>
            </div>
            <div class="input-col">
              <input type="text" class="form-input" v-model="inbox.name" />
            </div>
          </div>

          <div class="form-row">
            <div class="label-col">
              <label>Provedor de API</label>
            </div>
            <div class="input-col api-provider-row">
              <input type="text" class="form-input disabled-input" :value="inbox.provider.charAt(0).toUpperCase() + inbox.provider.slice(1)" disabled />
              <button class="btn-outline">Converter</button>
            </div>
          </div>

          <div class="form-row" v-if="groups.length > 0">
            <div class="label-col">
              <label>Grupo de Rodízio</label>
              <p style="color: var(--text-muted); font-size: 0.85rem; margin-top: 0.25rem;">Leads que chegarem por este número serão atribuídos apenas aos corretores deste grupo.</p>
            </div>
            <div class="input-col">
              <select class="form-input" v-model="inbox.round_robin_group_id">
                <option :value="null">Sem grupo (rodízio com todos os corretores da conta)</option>
                <option v-for="group in groups" :key="group.id" :value="group.id">{{ group.name }}</option>
              </select>
            </div>
          </div>

          <div class="form-actions">
            <button class="btn-primary" @click="saveSettings">Atualizar</button>
          </div>
          
        </div>
      </div>
      
      <!-- Tab Content: Horário de Funcionamento -->
      <div class="tab-content" v-else-if="activeTab === 'hours'">
        <div class="form-section" style="max-width: 100%">
          
          <div class="enable-hours-toggle">
            <label class="toggle-switch">
              <input type="checkbox" v-model="inbox.working_hours_enabled">
              <span class="slider"></span>
            </label>
            <div>
              <strong style="display: block; color: var(--text-main); font-size: 1rem; margin-bottom: 0.25rem;">Ativar horário de funcionamento</strong>
              <p style="margin: 0; color: var(--text-muted); font-size: 0.85rem;">Se ativado, respostas automáticas fora do expediente serão enviadas.</p>
            </div>
          </div>

          <div class="working-hours-list" v-if="inbox.working_hours_enabled">
            <div class="day-row" v-for="day in inbox.working_hours" :key="day.day">
              <div class="day-checkbox">
                <input type="checkbox" :id="'day-'+day.day" v-model="day.open">
                <label :for="'day-'+day.day">{{ day.name }}</label>
              </div>
              <div class="day-times" v-if="day.open">
                <input type="time" class="time-input" v-model="day.start">
                <span class="time-sep">até</span>
                <input type="time" class="time-input" v-model="day.end">
              </div>
              <div class="day-closed" v-else>
                Fechado
              </div>
            </div>

            <div class="form-row" style="margin-top: 2rem;">
              <div class="label-col" style="width: 100%">
                <label>Mensagem de Ausência (Fora do Expediente)</label>
                <textarea class="form-input" v-model="inbox.out_of_office_message" rows="4" placeholder="Ex: Nosso horário de atendimento é de segunda a sexta, das 09h às 18h. Responderemos em breve."></textarea>
              </div>
            </div>
          </div>

          <div class="form-actions">
            <button class="btn-primary" @click="saveSettings">Salvar Horários</button>
          </div>
        </div>
      </div>

      <!-- Tab Content: Secretária Virtual -->
      <div class="tab-content" v-else-if="activeTab === 'bot'">
        <div class="form-section" style="max-width: 100%">
          
          <div class="enable-hours-toggle" style="margin-bottom: 2rem;">
            <label class="toggle-switch">
              <input type="checkbox" v-model="inbox.ai_enabled">
              <span class="slider"></span>
            </label>
            <div>
              <strong style="display: block; color: var(--text-main); font-size: 1rem; margin-bottom: 0.25rem;">Ativar Secretária Virtual Autônoma</strong>
              <p style="margin: 0; color: var(--text-muted); font-size: 0.85rem;">Se ativado, a inteligência artificial assumirá as conversas desta caixa de entrada.</p>
            </div>
          </div>

          <div v-if="inbox.ai_enabled">
            <div class="form-row">
              <div class="label-col">
                <label>Nome da Secretária</label>
              </div>
              <div class="input-col">
                <input type="text" class="form-input" v-model="inbox.ai_name" placeholder="Ex: Ana, Júlia, Assistente Virtual" />
              </div>
            </div>

            <div class="form-row" style="margin-top: 1rem;">
              <div class="label-col" style="width: 100%">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                  <label>Prompt de Comportamento</label>
                  <button class="btn-magic-sm" @click="isPromptModalOpen = true">
                    ✨ Criar Prompt Perfeito com IA
                  </button>
                </div>
                <p style="color: var(--text-muted); font-size: 0.85rem; margin-top: 0.25rem; margin-bottom: 1rem;">Instrua a IA sobre como ela deve agir, tom de voz, regras de negócio e limites de atendimento.</p>
                <textarea class="form-input" v-model="inbox.ai_prompt" rows="12" placeholder="Ex: Você é a Ana, secretária inteligente da Imobiliária Alpha. Seu objetivo é pré-atender os leads de forma humanizada e amigável..."></textarea>
              </div>
            </div>
          </div>

          <div class="form-actions" style="margin-top: 2rem;">
            <button class="btn-primary" @click="saveSettings">Salvar Configurações da IA</button>
          </div>
        </div>
      </div>

      <!-- Tab Content: Agentes -->
      <div class="tab-content" v-else-if="activeTab === 'agents'">
        <div class="form-section" style="max-width: 100%">
          <div style="margin-bottom: 1.5rem">
            <h3 style="margin: 0 0 0.5rem 0; font-size: 1.1rem; color: var(--text-main)">Gerenciar Acesso</h3>
            <p style="margin: 0; color: var(--text-muted); font-size: 0.9rem;">
              Selecione quais agentes podem visualizar e responder mensagens por esta caixa de entrada.
            </p>
          </div>
          
          <div v-if="isLoadingAgents" class="loading-state">Carregando agentes...</div>
          
          <div class="agents-list" v-else>
            <div class="agent-item" v-for="agent in agents" :key="agent.id">
              <div class="agent-info">
                <div class="agent-avatar">{{ agent.name ? agent.name.charAt(0).toUpperCase() : '?' }}</div>
                <div class="agent-details">
                  <div class="agent-name">{{ agent.name || 'Agente sem nome' }}</div>
                  <div class="agent-email">{{ agent.email }}</div>
                </div>
              </div>
              <button 
                class="btn-toggle" 
                :class="agent.is_member ? 'btn-remove' : 'btn-add'"
                @click="toggleAgent(agent)"
              >
                {{ agent.is_member ? 'Remover' : 'Adicionar' }}
              </button>
            </div>
            
            <div v-if="agents.length === 0" class="empty-state">
              Nenhum agente encontrado nesta conta.
            </div>
          </div>
        </div>
      </div>

      <!-- Tab Content: Resgate Automático -->
      <div class="tab-content" v-else-if="activeTab === 'followup'">
        <div class="form-section" style="max-width: 100%">
          
          <div class="enable-hours-toggle" style="margin-bottom: 2rem;">
            <label class="toggle-switch">
              <input type="checkbox" v-model="inbox.followup_enabled">
              <span class="slider"></span>
            </label>
            <div>
              <strong style="display: block; color: var(--text-main); font-size: 1rem; margin-bottom: 0.25rem;">Ativar Agente de Resgate (Follow-up)</strong>
              <p style="margin: 0; color: var(--text-muted); font-size: 0.85rem;">A IA chamará leads que abandonarem a conversa automaticamente após o tempo determinado.</p>
            </div>
          </div>

          <div v-if="inbox.followup_enabled">
            <div class="form-row">
              <div class="label-col">
                <label>Tempo de Espera no Vácuo (minutos)</label>
                <p style="color: var(--text-muted); font-size: 0.85rem; margin-top: 0.25rem;">Ex: 120 para aguardar 2 horas sem resposta antes de agir.</p>
              </div>
              <div class="input-col">
                <input type="number" class="form-input" v-model="inbox.followup_wait_time_minutes" placeholder="120" min="10" />
              </div>
            </div>

            <div class="form-row" style="margin-top: 1.5rem;">
              <div class="label-col">
                <label>Máximo de Tentativas</label>
                <p style="color: var(--text-muted); font-size: 0.85rem; margin-top: 0.25rem;">Após esse limite o lead será marcado como Frio e o fluxo encerrado.</p>
              </div>
              <div class="input-col">
                <input type="number" class="form-input" v-model="inbox.followup_max_attempts" placeholder="3" min="1" max="10" />
              </div>
            </div>

            <div class="form-row" style="margin-top: 2rem;">
              <div class="label-col">
                <label>Mensagem de Encerramento</label>
                <label class="toggle-switch" style="margin-top: 0.5rem;">
                  <input type="checkbox" v-model="inbox.followup_send_closing_message">
                  <span class="slider"></span>
                </label>
                <p style="color: var(--text-muted); font-size: 0.85rem; margin-top: 0.5rem;">Enviar uma última mensagem avisando que o atendimento será encerrado devido à falta de resposta?</p>
              </div>
              <div class="input-col" v-if="inbox.followup_send_closing_message">
                <textarea class="form-input" v-model="inbox.followup_closing_message" rows="4" placeholder="Ex: Poxa, como não tivemos mais retorno, estou encerrando seu atendimento por aqui para não te incomodar. Se precisar de algo no futuro, é só chamar! 😊"></textarea>
              </div>
            </div>
          </div>

          <div class="form-actions" style="margin-top: 2rem;">
            <button class="btn-primary" @click="saveSettings">Salvar Configurações de Resgate</button>
          </div>
        </div>
      </div>

      <!-- Placeholder for other tabs -->
      <div class="tab-content empty-tab" v-else>
        <p>A configuração da aba "{{ tabs.find(t => t.id === activeTab).name }}" será disponibilizada em breve.</p>
      </div>

    </div>

    <!-- Modals -->
    <PromptGeneratorModal 
      v-if="inbox"
      :inboxId="inbox.id" 
      :isOpen="isPromptModalOpen" 
      @close="isPromptModalOpen = false"
      @generated="handlePromptGenerated"
    />
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 2.5rem 3rem;
  background: var(--bg-primary);
  overflow-y: auto;
}

.page-content {
  max-width: 1000px;
  width: 100%;
  margin: 0;
}

.back-button {
  background: transparent;
  border: none;
  color: var(--text-muted);
  font-size: 0.9rem;
  display: flex;
  align-items: center;
  gap: 0.25rem;
  cursor: pointer;
  padding: 0;
  margin-bottom: 2rem;
  
  strong {
    color: var(--text-main);
    font-weight: 500;
  }
  
  &:hover {
    color: var(--text-main);
  }
}

.header {
  margin-bottom: 1.5rem;

  h1 {
    font-size: 1.4rem;
    font-weight: 500;
    color: var(--text-main);
    margin: 0;
  }
}

.tabs-container {
  display: flex;
  border-bottom: 1px solid var(--border-color);
  margin-bottom: 2rem;
  overflow-x: auto;
  
  &::-webkit-scrollbar {
    display: none;
  }
}

.tab-btn {
  background: transparent;
  border: none;
  padding: 0.75rem 1rem;
  font-size: 0.9rem;
  color: var(--text-muted);
  cursor: pointer;
  border-bottom: 2px solid transparent;
  white-space: nowrap;
  font-weight: 500;
  
  &:hover {
    color: var(--text-main);
  }
  
  &.active {
    color: var(--primary);
    border-bottom-color: var(--primary);
  }
}

.form-section {
  display: flex;
  flex-direction: column;
  gap: 2rem;
  max-width: 800px;
}

.form-row {
  display: flex;
  gap: 2rem;
  align-items: flex-start;
}

.label-col {
  width: 250px;
  flex-shrink: 0;
  
  label {
    font-size: 0.9rem;
    font-weight: 500;
    color: var(--text-main);
  }
}

.input-col {
  flex-grow: 1;
}

.channel-image {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-main);
}

.form-input {
  width: 100%;
  padding: 0.65rem 1rem;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-tertiary);
  font-size: 0.95rem;
  color: var(--text-main);
  
  &:focus {
    outline: none;
    border-color: var(--primary);
  }
}

.disabled-input {
  background: rgba(0,0,0,0.02);
  color: var(--text-muted);
  cursor: not-allowed;
}

.api-provider-row {
  display: flex;
  gap: 1rem;
}

.btn-outline {
  background: transparent;
  border: 1px solid var(--border-color);
  color: var(--text-main);
  padding: 0.65rem 1.5rem;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
  
  &:hover {
    background: var(--bg-secondary);
  }
}

.btn-primary {
  background: #1f93ff;
  color: white;
  padding: 0.65rem 1.5rem;
  border-radius: 6px;
  font-size: 0.9rem;
  font-weight: 500;
  border: none;
  cursor: pointer;
  
  &:hover {
    background: #007bf5;
  }
}

.form-actions {
  margin-top: 1rem;
  display: flex;
  justify-content: flex-end;
}

.empty-tab {
  padding: 3rem;
  text-align: center;
  color: var(--text-muted);
  background: var(--bg-secondary);
  border-radius: 8px;
  border: 1px solid var(--border-color);
}

.agents-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-top: 1rem;
}

.agent-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-secondary);
}

.agent-info {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.agent-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--primary);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 1.1rem;
}

.agent-details {
  display: flex;
  flex-direction: column;
}

.agent-name {
  font-weight: 500;
  color: var(--text-main);
  font-size: 0.95rem;
}

.agent-email {
  font-size: 0.85rem;
  color: var(--text-muted);
}

.btn-toggle {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.85rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid transparent;
  transition: all 0.2s;
}

.btn-add {
  background: var(--primary);
  color: white;
  
  &:hover {
    background: #007bf5;
  }
}

.btn-remove {
  background: transparent;
  color: #ef4444;
  border-color: #fca5a5;
  
  &:hover {
    background: #fee2e2;
  }
}

/* Horário de Funcionamento */
.enable-hours-toggle {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
  padding: 1.5rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  margin-bottom: 2rem;
}

.toggle-switch {
  position: relative;
  display: inline-block;
  width: 44px;
  height: 24px;
  flex-shrink: 0;
  
  input {
    opacity: 0;
    width: 0;
    height: 0;
    
    &:checked + .slider {
      background-color: var(--primary);
    }
    
    &:checked + .slider:before {
      transform: translateX(20px);
    }
  }
  
  .slider {
    position: absolute;
    cursor: pointer;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: #ccc;
    transition: .3s;
    border-radius: 24px;
    
    &:before {
      position: absolute;
      content: "";
      height: 18px;
      width: 18px;
      left: 3px;
      bottom: 3px;
      background-color: white;
      transition: .3s;
      border-radius: 50%;
    }
  }
}

.working-hours-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.day-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.5rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-tertiary);
}

.day-checkbox {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 150px;
  
  input[type="checkbox"] {
    width: 18px;
    height: 18px;
    cursor: pointer;
  }
  
  label {
    font-weight: 500;
    color: var(--text-main);
    cursor: pointer;
  }
}

.day-times {
  display: flex;
  align-items: center;
  gap: 1rem;
  
  .time-input {
    padding: 0.5rem;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    background: var(--bg-primary);
    color: var(--text-main);
    font-family: inherit;
    font-size: 0.9rem;
    outline: none;
    
    &:focus {
      border-color: var(--primary);
    }
  }
  
  .time-sep {
    color: var(--text-muted);
    font-size: 0.85rem;
  }
}

.day-closed {
  color: var(--text-muted);
  font-size: 0.9rem;
  font-style: italic;
  width: 250px;
  text-align: right;
}

.btn-magic-sm {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 1rem;
  background: var(--primary);
  border: none;
  border-radius: 6px;
  color: white;
  cursor: pointer;
  font-weight: 500;
  font-size: 0.85rem;
  transition: opacity 0.2s;
}

.btn-magic-sm:hover {
  opacity: 0.9;
}

@media (max-width: 768px) {
  .page-container {
    padding: 1.25rem 1rem;
  }

  .form-row {
    flex-direction: column;
    gap: 0.5rem;
  }

  .label-col {
    width: 100%;
  }

  .day-row {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .day-checkbox {
    width: 100%;
  }

  .day-closed {
    width: 100%;
    text-align: left;
  }

  .agent-item {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }
}
</style>
