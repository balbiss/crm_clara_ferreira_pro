<template>
  <div v-if="isOpen" class="modal-overlay" @click.self="close">
    <div class="modal-sidebar">
      <div class="modal-header">
        <div class="title-section">
          <h2>Editar contato - {{ contact?.name }}</h2>
          <p class="subtitle">Alterar detalhes do contato</p>
        </div>
        <button class="close-btn" @click="close">&times;</button>
      </div>

      <div class="modal-body">
        <form @submit.prevent="save">
          
          <div class="form-section">
            <h3>Dados Pessoais</h3>
            <div class="form-group avatar-group">
              <label>Avatar do Contato</label>
              <div class="avatar-preview">
                <img v-if="contact?.avatar_url" :src="contact.avatar_url" alt="Avatar" />
                <div v-else class="avatar-placeholder">
                  {{ contact?.name?.substring(0, 2).toUpperCase() || 'NA' }}
                </div>
              </div>
            </div>

            <div class="form-group">
              <label>Nome Completo</label>
              <input type="text" v-model="formData.name" placeholder="Nome do contato" required autocomplete="off" />
            </div>

            <div class="form-group" v-if="isFullPortfolio">
              <label>Responsável (consultor)</label>
              <select v-model="formData.user_id">
                <option :value="null">Sem responsável</option>
                <option v-for="agent in store.agents" :key="agent.id" :value="agent.id">
                  {{ agent.first_name }} {{ agent.last_name }}
                </option>
              </select>
            </div>

            <!-- CPF, Data de Nascimento e Instagram saíram daqui: são dado de
                 cadastro sincronizado do Jueri (briefing/PDF Etapa 2 — "não deve
                 trazer campos do Jueri"). O CRM não edita esses valores; eles
                 continuam existindo normalmente, só não aparecem mais neste
                 formulário. Mantido: Nome, Responsável, E-mail e Telefone, que
                 são de fato editáveis/gerenciados aqui. -->

            <div class="form-group">
              <label>Endereço de e-mail</label>
              <input type="email" v-model="formData.email" placeholder="Insira o endereço de e-mail do contato" autocomplete="off" />
            </div>

            <div class="form-group">
              <label>Número de Telefone</label>
              <div class="phone-input-wrapper">
                <select class="country-select">
                  <option value="BR">BR ▾</option>
                </select>
                <input type="text" v-model="formData.phone" placeholder="+5511999999999" autocomplete="off" />
              </div>
            </div>
          </div>

          <!-- Seção "Dados de Cadastro" (ID Jueri, Origem do lead) e "Endereço
               Completo" (CEP/Rua/Número/Bairro/Cidade/Estado/País) removidas
               daqui pelo mesmo motivo: é tudo dado de cadastro do Jueri, não
               editável por aqui. Os valores continuam salvos no contato — só
               pararam de aparecer/serem editáveis neste modal. -->

          <div class="form-section">
            <h3>Telefones Adicionais</h3>
            <p style="font-size: 0.85rem; color: #6b7280; margin-bottom: 12px; margin-top: -10px;">
              Mesma revendedora pode falar por vários números (pessoal, mãe, sócia etc.) — todos ficam vinculados a este cadastro único (briefing seção 7).
            </p>
            <div v-for="(tel, index) in formData.telefonesAdicionais" :key="index" class="form-row" style="margin-bottom: 10px; align-items: flex-end;">
              <div class="form-group" style="flex: 1; margin-bottom: 0;">
                <label v-if="index === 0">Identificação</label>
                <input type="text" v-model="tel.label" placeholder="Ex: Telefone da mãe" autocomplete="off" />
              </div>
              <div class="form-group" style="flex: 1; margin-bottom: 0;">
                <label v-if="index === 0">Número</label>
                <input type="text" v-model="tel.numero" placeholder="+5511999999999" autocomplete="off" />
              </div>
              <button type="button" @click="formData.telefonesAdicionais.splice(index, 1)" class="btn-cancel" style="padding: 10px; height: 38px; border-color: #ef4444; color: #ef4444; display: flex; align-items: center; justify-content: center;" title="Remover">
                Remover
              </button>
            </div>
            <button type="button" @click="formData.telefonesAdicionais.push({label: '', numero: ''})" style="background: none; border: none; color: #ff007f; cursor: pointer; font-weight: 500; font-size: 0.9rem; padding: 0; margin-top: 5px;">
              + Adicionar telefone
            </button>
          </div>

          <div class="form-section">
            <h3>Dados da Revenda</h3>
            <p style="font-size: 0.85rem; color: #6b7280; margin-bottom: 12px; margin-top: -10px;">
              Campos usados na aba Principal e no funil Consignado.
            </p>
            <div class="form-row" v-for="pair in revendaFieldPairs" :key="pair[0].key">
              <div class="form-group half">
                <label>{{ pair[0].label }}</label>
                <input type="text" v-model="formData.revenda[pair[0].key]" autocomplete="off" />
              </div>
              <div class="form-group half" v-if="pair[1]">
                <label>{{ pair[1].label }}</label>
                <input type="text" v-model="formData.revenda[pair[1].key]" autocomplete="off" />
              </div>
            </div>
          </div>

          <div class="form-section">
            <h3>Outras Informações</h3>
            <div class="form-group">
              <label>Descrição</label>
              <textarea v-model="formData.bio" placeholder="Insira a descrição do contato" rows="3"></textarea>
            </div>
          </div>

          <div class="form-section">
            <h3>Atributos Personalizados</h3>
            <p style="font-size: 0.85rem; color: #6b7280; margin-bottom: 12px; margin-top: -10px;">
              Crie campos adicionais livremente (ex: Cor do carro, Hobby, Renda do cônjuge).
            </p>
            <div v-for="(attr, index) in formData.customAttributesArray" :key="index" class="form-row" style="margin-bottom: 10px; align-items: flex-end;">
              <div class="form-group" style="flex: 1; margin-bottom: 0;">
                <label v-if="index === 0">Nome do Campo</label>
                <input type="text" v-model="attr.key" placeholder="Ex: Possui Pets?" autocomplete="off" />
              </div>
              <div class="form-group" style="flex: 1; margin-bottom: 0;">
                <label v-if="index === 0">Valor</label>
                <input type="text" v-model="attr.value" placeholder="Ex: Sim, 2 cachorros" autocomplete="off" />
              </div>
              <button v-if="canRemoveCustomField" type="button" @click="formData.customAttributesArray.splice(index, 1)" class="btn-cancel" style="padding: 10px; height: 38px; border-color: #ef4444; color: #ef4444; display: flex; align-items: center; justify-content: center;" title="Remover (só diretoria)">
                Remover
              </button>
            </div>
            <button v-if="canAddCustomField" type="button" @click="formData.customAttributesArray.push({key: '', value: ''})" style="background: none; border: none; color: #ff007f; cursor: pointer; font-weight: 500; font-size: 0.9rem; padding: 0; margin-top: 5px;">
              + Adicionar novo atributo
            </button>
            <p v-else style="font-size: 0.8rem; color: #9ca3af; margin: 4px 0 0;">Só gerente ou superior pode criar campos novos — você pode editar os valores acima.</p>
          </div>

        </form>
      </div>

      <div class="modal-footer">
        <button type="button" class="btn-cancel" @click="close">Cancelar</button>
        <button type="button" class="btn-primary" @click="save" :disabled="loading">
          {{ loading ? 'Salvando...' : 'Salvar Alterações' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useConversationsStore } from '../store/conversations'
import { isFullPortfolio as isFullPortfolioRole, isCriticalConfig } from '../config/roles'
import Swal from 'sweetalert2'

const props = defineProps({
  isOpen: Boolean,
  contact: Object
})

const emit = defineEmits(['close'])
const store = useConversationsStore()

// Transferência de responsável (briefing seção 22/30: "gerente transfere
// revendedoras entre responsáveis") — só quem enxerga a carteira toda pode
// reatribuir. O backend (ContactsController#contact_params) já ignora esse
// campo se quem enviar não for full_portfolio, isso aqui é só a UI.
const currentUser = JSON.parse(localStorage.getItem('user') || '{}')
const isFullPortfolio = computed(() => isFullPortfolioRole(currentUser))

// Atributos personalizados: qualquer usuário atualiza o VALOR de um campo já
// existente, mas só gerente+ pode criar campo novo, e só diretoria (admin)
// pode excluir — regra pedida explicitamente pra essa área não virar bagunça.
const canAddCustomField = computed(() => isFullPortfolioRole(currentUser))
const canRemoveCustomField = computed(() => isCriticalConfig(currentUser))

onMounted(() => {
  if (isFullPortfolio.value && !store.agents.length) store.fetchAgents()
})

// Campos da régua/revenda — espelham a aba Principal em Conversas.vue.
// Ficam em custom_attributes (jsonb) pra não depender de migration nova.
const REVENDA_FIELDS = [
  { key: 'venda', label: 'Venda' },
  { key: 'proximo_agendamento', label: 'Próximo agendamento' },
  { key: 'limite_inicial', label: 'Limite Inicial' },
  { key: 'dia_fechamento', label: 'Dia Fechamento' },
  { key: 'data_agendamento', label: 'Data de Agendamento' },
  { key: 'obs_fechamento', label: 'Obs Fechamento' },
  { key: 'dia_pf_fechamento', label: 'Dia p/ Fechamento' },
  { key: 'horario_fechamento', label: 'Horário de Fechamento' },
  { key: 'atraso', label: 'Atraso' },
  { key: 'observacao_mes', label: 'Observação do mês' },
  { key: 'meta', label: 'Meta' },
  { key: 'desafio_combinado', label: 'Desafio combinado para o mês' },
  { key: 'como_chegar_meta', label: 'Como chegar na Meta' },
]
const revendaFieldPairs = []
for (let i = 0; i < REVENDA_FIELDS.length; i += 2) {
  revendaFieldPairs.push([REVENDA_FIELDS[i], REVENDA_FIELDS[i + 1]])
}

const CADASTRO_KEYS = ['instagram', 'id_jueri', 'origem']
// Campos sincronizados automaticamente do Jueri (JueriSyncService) — têm
// exibição própria na aba "Dados"/"Atributos", não devem aparecer duplicados
// nem editáveis/removíveis na lista livre de "Atributos Personalizados"
// (senão o gerente apaga sem querer e eles só voltam no próximo sync).
const JUERI_CADASTRO_KEYS = [
  'gerente_jueri_id', 'gerente_jueri_nome', 'supervisor_nome',
  'rg', 'profissao', 'razao_social', 'nome_fantasia', 'cnpj',
  'observacao_jueri', 'observacao_interna_jueri', 'data_inativacao_jueri',
]
const RESERVED_KEYS = [...REVENDA_FIELDS.map(f => f.key), ...CADASTRO_KEYS, ...JUERI_CADASTRO_KEYS, 'pedidos', 'telefones_adicionais']

const formData = ref({
  name: '',
  user_id: null,
  email: '',
  phone: '',
  bio: '',
  company_name: '',
  country: '',
  city: '',
  cpf: '',
  birth_date: '',
  cep: '',
  street: '',
  neighborhood: '',
  state: '',
  address_number: '',
  address_complement: '',
  revenda: {},
  cadastro: {},
  telefonesAdicionais: [],
  customAttributesArray: [],
  _originalCustomAttributes: {}
})
const loading = ref(false)
// buscarCep/loadingCep/cepError removidos junto com o campo CEP (seção
// "Endereço Completo" tirada do form — endereço é dado sincronizado do
// Jueri). formData.cep/street/... continuam existindo abaixo só pra
// carregar/reenviar o valor já salvo sem alteração (round-trip seguro,
// sem risco de apagar endereço real do Jueri).

watch(() => props.contact, (newContact) => {
  if (newContact) {
    const custom = newContact.custom_attributes || {}
    const revenda = {}
    REVENDA_FIELDS.forEach(f => { revenda[f.key] = custom[f.key] || '' })
    const cadastro = {}
    CADASTRO_KEYS.forEach(k => { cadastro[k] = custom[k] || '' })

    formData.value = {
      name: newContact.name || '',
      user_id: newContact.user_id ?? null,
      email: newContact.email || '',
      phone: newContact.phone || '',
      bio: newContact.bio || '',
      company_name: newContact.company_name || '',
      country: newContact.country || '',
      city: newContact.city || '',
      cpf: newContact.cpf || '',
      birth_date: newContact.birth_date || '',
      cep: newContact.cep || '',
      street: newContact.street || '',
      neighborhood: newContact.neighborhood || '',
      state: newContact.state || '',
      address_number: newContact.address_number || '',
      address_complement: newContact.address_complement || '',
      revenda,
      cadastro,
      // Fonte de verdade agora é a tabela reseller_phones (não mais o jsonb
      // custom_attributes.telefones_adicionais, que o backend intercepta e
      // some do payload salvo — ver Contact#extrair_telefones_adicionais_do_jsonb).
      telefonesAdicionais: Array.isArray(newContact.reseller_phones)
        ? newContact.reseller_phones.map(rp => ({ label: rp.label || '', numero: rp.phone }))
        : (Array.isArray(custom.telefones_adicionais) ? custom.telefones_adicionais.map(t => ({ ...t })) : []),
      customAttributesArray: Object.keys(custom)
        .filter(k => !RESERVED_KEYS.includes(k))
        .map(k => ({ key: k, value: custom[k] })),
      _originalCustomAttributes: custom
    }
  }
}, { immediate: true })

const close = () => {
  emit('close')
}

const save = async () => {
  if (!props.contact) return
  loading.value = true

  const dataToSave = { ...formData.value }

  // Preserva chaves não gerenciadas por este modal (ex: "pedidos" do Financeiro)
  // e sobrescreve só o que o modal edita.
  const custom_attributes = { ...(dataToSave._originalCustomAttributes || {}) }
  Object.keys(custom_attributes).forEach(k => {
    if (!RESERVED_KEYS.includes(k)) delete custom_attributes[k]
  })
  REVENDA_FIELDS.forEach(f => {
    if (dataToSave.revenda[f.key]) custom_attributes[f.key] = dataToSave.revenda[f.key]
    else delete custom_attributes[f.key]
  })
  CADASTRO_KEYS.forEach(k => {
    if (dataToSave.cadastro[k]) custom_attributes[k] = dataToSave.cadastro[k]
    else delete custom_attributes[k]
  })
  const validPhones = dataToSave.telefonesAdicionais.filter(t => t.numero && t.numero.trim())
  if (validPhones.length) custom_attributes.telefones_adicionais = validPhones
  else delete custom_attributes.telefones_adicionais
  dataToSave.customAttributesArray.forEach(attr => {
    if (attr.key && attr.key.trim()) {
      custom_attributes[attr.key.trim()] = attr.value
    }
  })
  dataToSave.custom_attributes = custom_attributes
  delete dataToSave.customAttributesArray
  delete dataToSave.revenda
  delete dataToSave.cadastro
  delete dataToSave.telefonesAdicionais
  delete dataToSave._originalCustomAttributes

  try {
    await store.updateContact(props.contact.id, dataToSave)
    close()
  } catch (error) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao salvar contato.', showConfirmButton: false, timer: 3500 })
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.4);
  display: flex;
  justify-content: flex-end;
  z-index: 1000;
}

.modal-sidebar {
  background: #f8f9fa;
  width: 450px;
  max-width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  box-shadow: -4px 0 15px rgba(0,0,0,0.1);
  animation: slideInRight 0.3s ease-out;
}

@keyframes slideInRight {
  from { transform: translateX(100%); }
  to { transform: translateX(0); }
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 24px;
  background: white;
  border-bottom: 1px solid #e9ecef;
}

.title-section h2 {
  margin: 0 0 4px 0;
  font-size: 1.15rem;
  color: #1f2937;
  font-weight: 600;
}

.title-section .subtitle {
  margin: 0;
  font-size: 0.85rem;
  color: #6b7280;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #6b7280;
  padding: 0;
  line-height: 1;
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
  background: #f8f9fa;
}

.form-section {
  background: white;
  padding: 20px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  margin-bottom: 24px;
}

.form-section h3 {
  margin: 0 0 16px 0;
  font-size: 0.95rem;
  color: #1f2937;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 1px solid #f3f4f6;
  padding-bottom: 8px;
}

.form-row {
  display: flex;
  gap: 16px;
  margin-bottom: 20px;
}

.form-group {
  margin-bottom: 20px;
}

.form-row .form-group {
  margin-bottom: 0;
  flex: 1;
}

.form-group.half {
  flex: 1;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-size: 0.85rem;
  color: #374151;
  font-weight: 500;
}

.form-group input, .form-group textarea, .form-group select {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  font-size: 0.95rem;
  background: #f3f4f6;
  color: #1f2937;
  transition: all 0.2s;
}

.form-group input:focus, .form-group textarea:focus, .form-group select:focus {
  outline: none;
  border-color: #ff007f;
  background: white;
  box-shadow: 0 0 0 3px rgba(255, 0, 127, 0.1);
}

.qualification-checklists {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 16px;
  background: #f9fafb;
  padding: 16px;
  border-radius: 8px;
  border: 1px solid #f3f4f6;
}

.checklist-item {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-bottom: 12px;
  border-bottom: 1px dashed #e5e7eb;
}

.checklist-item:last-child {
  border-bottom: none;
  padding-bottom: 0;
}

.checklist-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.question-text {
  font-size: 0.9rem;
  color: #374151;
  font-weight: 500;
}

.yes-no-group {
  display: flex;
  background: #e5e7eb;
  border-radius: 6px;
  padding: 2px;
}

.yes-no-btn {
  padding: 4px 12px;
  font-size: 0.85rem;
  color: #6b7280;
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.2s;
  user-select: none;
}

.yes-no-btn input {
  display: none;
}

.yes-no-btn.active {
  background: white;
  color: #1f2937;
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(43,0,22,0.06), 0 6px 16px rgba(43,0,22,0.09);
}

.conditional-input {
  animation: slideDown 0.2s ease-out;
}

@keyframes slideDown {
  from { opacity: 0; transform: translateY(-5px); }
  to { opacity: 1; transform: translateY(0); }
}

.conditional-input input {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  font-size: 0.95rem;
  background: white;
  transition: all 0.2s;
}

.conditional-input input:focus {
  outline: none;
  border-color: #ff007f;
  box-shadow: 0 0 0 3px rgba(255, 0, 127, 0.1);
}

.phone-input-wrapper {
  display: flex;
  gap: 8px;
}

.country-select {
  padding: 8px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background: white;
  color: #374151;
  font-size: 0.9rem;
}

.avatar-preview {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  overflow: hidden;
  background: #e5e7eb;
  display: flex;
  align-items: center;
  justify-content: center;
}

.avatar-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-placeholder {
  color: #6b7280;
  font-weight: 600;
  font-size: 1.2rem;
}

.modal-footer {
  padding: 16px 24px;
  background: white;
  border-top: 1px solid #e9ecef;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.btn-cancel {
  background: transparent;
  border: 1px solid #d1d5db;
  padding: 8px 16px;
  border-radius: 6px;
  cursor: pointer;
  color: #374151;
  font-weight: 500;
  font-size: 0.9rem;
}

.btn-cancel:hover {
  background: #f3f4f6;
}

.btn-primary {
  background: var(--primary, #ff007f);
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
  font-size: 0.9rem;
}

.btn-primary:hover {
  background: var(--primary-dark, #cc0066);
}

.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

@media (max-width: 600px) {
  .modal-header, .modal-body, .modal-footer {
    padding: 16px;
  }

  .form-row {
    flex-direction: column;
    gap: 20px;
  }

  .form-row .form-group {
    margin-bottom: 0;
  }
}
</style>
