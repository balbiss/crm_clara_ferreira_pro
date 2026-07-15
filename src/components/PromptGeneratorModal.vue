<script setup>
import { ref } from 'vue'
import { X, Sparkles, Loader2 } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const props = defineProps({
  inboxId: { type: [Number, String], required: true },
  isOpen: Boolean
})

const emit = defineEmits(['close', 'generated'])

const isGenerating = ref(false)

const form = ref({
  identity: '',
  institutional: '',
  faq: '',
  greeting_message: '',
  ai_role: 'sdr_and_sales', // 'sdr_only', 'sdr_and_sales'
  allow_scheduling: true,
  use_whatsapp_name: true,
  emoji_usage: 'moderate',
  sdr_rules: '',
  routing_rules: '',
  prohibited_actions: ''
})

const generatePrompt = async () => {
  if (!form.value.identity || !form.value.institutional) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'Por favor, preencha pelo menos a Identidade e Institucional.', showConfirmButton: false, timer: 4000 })
    return
  }

  isGenerating.value = true
  try {
    const response = await api.post(`/inboxes/${props.inboxId}/generate_prompt`, {
      prompt_data: form.value
    })
    
    emit('generated', response.data.prompt)
    closeModal()
  } catch (error) {
    console.error('Failed to generate prompt:', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao gerar o prompt. Tente novamente.', showConfirmButton: false, timer: 3500 })
  } finally {
    isGenerating.value = false
  }
}

const closeModal = () => {
  emit('close')
}
</script>

<template>
  <div v-if="isOpen" class="modal-overlay" @click="closeModal">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <div class="header-title">
          <Sparkles class="icon-sparkle" />
          <h3>Gerador de Prompt com IA</h3>
        </div>
        <button class="btn-close" @click="closeModal"><X class="icon-sm" /></button>
      </div>

      <div class="modal-body scrollable">
        <p class="modal-desc">
          Preencha os detalhes da sua imobiliária abaixo. A nossa inteligência artificial vai escrever um prompt de comportamento <strong>perfeito</strong> e à prova de falhas para sua secretária virtual.
        </p>

        <div class="form-group">
          <label>1. Identidade e Tom de Voz</label>
          <textarea v-model="form.identity" placeholder="Ex: Somos a Imobiliária Alpha. A IA deve se chamar Ana, ter um tom amigável, prestativo e persuasivo, focado em fechar negócios."></textarea>
        </div>

        <div class="form-group">
          <label>2. Institucional (Regras e Diferenciais)</label>
          <textarea v-model="form.institutional" placeholder="Ex: Nosso horário é seg a sex das 9h às 18h. Nosso grande diferencial é aprovar financiamento em 24h. Trabalhamos apenas com imóveis de luxo e não fazemos locação."></textarea>
        </div>

        <div class="form-group">
          <label>3. FAQ (Perguntas Frequentes)</label>
          <textarea v-model="form.faq" placeholder="Ex: - Aceita pet? Sim.&#10;- Aceita fiador? Não, apenas seguro fiança.&#10;- Faz minha casa minha vida? Não."></textarea>
        </div>

        <div class="form-group">
          <label>4. Mensagem de Saudação (Primeiro Contato)</label>
          <textarea v-model="form.greeting_message" placeholder="Ex: Olá! 👋 Bem-vindo à Imobiliária Alpha! Sou a Ana, sua assistente virtual. Estou aqui para te ajudar a encontrar o imóvel dos seus sonhos. Como posso te ajudar hoje?"></textarea>
          <small class="help-hint">Esta é a mensagem exata que a IA enviará quando um novo cliente entrar em contato pela primeira vez. Se não preencher, a IA criará uma saudação natural com base na identidade definida.</small>
        </div>

        <div class="form-row-split">
          <div class="form-group">
            <label>5. Modo de Atuação da IA</label>
            <select v-model="form.ai_role" class="form-select">
              <option value="sdr_and_sales">Completo (Qualifica, Oferta Imóveis e Agenda)</option>
              <option value="sdr_only">Apenas Pré-venda/SDR (Coleta dados e transfere)</option>
            </select>
          </div>

          <div class="form-group toggle-group">
            <label class="toggle-label">
              <input type="checkbox" v-model="form.allow_scheduling" class="toggle-checkbox">
              <span class="toggle-text">IA pode fazer o Agendamento Automático?</span>
            </label>
            <span class="help-text" v-if="!form.allow_scheduling">O agendamento será feito apenas pelo corretor humano após a transferência.</span>
            <span class="help-text" v-else>A IA verificará datas e marcará no sistema.</span>
          </div>
        </div>

        <div class="form-row-split" style="margin-top: -0.5rem;">
          <div class="form-group toggle-group">
            <label class="toggle-label">
              <input type="checkbox" v-model="form.use_whatsapp_name" class="toggle-checkbox">
              <span class="toggle-text">Chamar pelo nome sem perguntar?</span>
            </label>
            <span class="help-text" v-if="form.use_whatsapp_name">A IA já inicia o atendimento chamando pelo nome e NUNCA pedirá o número de contato.</span>
            <span class="help-text" v-else>A IA perguntará qual o nome do cliente. NUNCA pedirá o número de contato.</span>
          </div>
          
          <div class="form-group">
            <label>Uso de Emojis</label>
            <select v-model="form.emoji_usage" class="form-select">
              <option value="none">Nenhum (Formal e Sério)</option>
              <option value="moderate">Moderado (Profissional e Amigável)</option>
              <option value="lots">Bastante (Descontraído e Jovem)</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label>6. Regras de SDR (Pré-venda)</label>
          <textarea v-model="form.sdr_rules" placeholder="Ex: Obrigatório coletar o Nome, Telefone, Bairro de interesse e se o cliente já tem aprovação na Caixa Econômica antes de enviar qualquer imóvel."></textarea>
        </div>

        <div class="form-group">
          <label>7. Gatilhos de Transferência (Quando chamar um humano)</label>
          <textarea v-model="form.routing_rules" placeholder="Ex: Transferir imediatamente se o cliente pedir para falar com humano, ligar, ou fizer perguntas complexas de financiamento."></textarea>
        </div>

        <div class="form-group">
          <label>8. Restrições e Proibições (O que a IA NUNCA deve fazer)</label>
          <textarea v-model="form.prohibited_actions" placeholder="Ex: Nunca prometer descontos. Nunca dizer que não sabemos de algo, diga que vai consultar o corretor. Nunca passar endereço exato sem agendar."></textarea>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn-outline" @click="closeModal" :disabled="isGenerating">Cancelar</button>
        <button class="btn-magic" @click="generatePrompt" :disabled="isGenerating">
          <Loader2 v-if="isGenerating" class="icon-sm spin" />
          <Sparkles v-else class="icon-sm" />
          {{ isGenerating ? 'Processando (pode levar 10s)...' : 'Gerar Prompt Mágico' }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(2px);
}

.modal-content {
  background: var(--bg-primary);
  width: 100%;
  max-width: 700px;
  max-height: 90vh;
  border-radius: 12px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
  display: flex;
  flex-direction: column;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid var(--border-color);
}

.header-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.header-title h3 {
  margin: 0;
  font-size: 1.25rem;
  color: var(--text-main);
}

.icon-sparkle {
  color: #8b5cf6;
  width: 20px;
  height: 20px;
}

.btn-close {
  background: transparent;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  padding: 0.25rem;
}

.modal-body {
  padding: 1.5rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.modal-desc {
  margin: 0;
  color: var(--text-muted);
  font-size: 0.95rem;
  line-height: 1.5;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-group label {
  font-weight: 600;
  color: var(--text-main);
  font-size: 0.9rem;
}

.form-group textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-secondary);
  color: var(--text-main);
  resize: vertical;
  min-height: 80px;
  font-size: 0.9rem;
}

.form-group textarea:focus {
  outline: none;
  border-color: #8b5cf6;
}

.modal-footer {
  padding: 1.25rem 1.5rem;
  border-top: 1px solid var(--border-color);
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
}

.btn-outline {
  padding: 0.5rem 1rem;
  background: transparent;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  color: var(--text-main);
  cursor: pointer;
  font-weight: 500;
}

.btn-magic {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1.25rem;
  background: var(--primary);
  border: none;
  border-radius: 6px;
  color: white;
  cursor: pointer;
  font-weight: 600;
  transition: opacity 0.2s;
}

.btn-magic:hover {
  opacity: 0.9;
}

.btn-magic:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.icon-sm {
  width: 16px;
  height: 16px;
}

.form-row-split {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  background: var(--bg-tertiary, #f8fafc);
  padding: 1rem;
  border-radius: 8px;
  border: 1px solid var(--border-color);
}

.form-select {
  width: 100%;
  padding: 0.65rem 1rem;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-secondary);
  color: var(--text-main);
  font-size: 0.9rem;
}

.form-select:focus {
  outline: none;
  border-color: #8b5cf6;
}

.toggle-group {
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.toggle-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-weight: 600;
  color: var(--text-main);
}

.toggle-checkbox {
  width: 18px;
  height: 18px;
  accent-color: #8b5cf6;
}

.help-text {
  font-size: 0.8rem;
  color: var(--text-muted);
  margin-top: 0.25rem;
  margin-left: 1.5rem;
}

.help-hint {
  font-size: 0.78rem;
  color: var(--text-muted);
  margin-top: 0.15rem;
  font-style: italic;
}

@media (max-width: 600px) {
  .modal-overlay {
    padding: 0.75rem;
  }

  .modal-header, .modal-body, .modal-footer {
    padding: 1rem;
  }

  .form-row-split {
    grid-template-columns: 1fr;
  }
}
</style>
