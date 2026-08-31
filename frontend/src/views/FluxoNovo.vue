<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft } from '@lucide/vue'
import api from '../api'

const router = useRouter()

const name = ref('')
const description = ref('')
const channel = ref('whatsapp')
const inboxId = ref('')
const active = ref(true)
const isSaving = ref(false)
const errorMsg = ref('')
const inboxes = ref([])

// Sem isso o gatilho por palavra-chave disparava em QUALQUER caixa da
// conta — a pessoa que testou percebeu isso na prática. Filtra pelo canal
// escolhido acima, já que um fluxo de WhatsApp não faz sentido numa caixa
// de Instagram.
const inboxesDoCanal = computed(() => {
  const providersPorCanal = { whatsapp: ['baileys', 'waha'], instagram: ['instagram'] }
  const validos = providersPorCanal[channel.value]
  return validos ? inboxes.value.filter(i => validos.includes(i.provider)) : inboxes.value
})

const fetchInboxes = async () => {
  try {
    const { data } = await api.get('/inboxes')
    inboxes.value = data
  } catch (e) {
    console.error('Erro ao buscar caixas:', e)
  }
}

const criarFluxo = async () => {
  if (!name.value.trim()) {
    errorMsg.value = 'Dê um nome ao fluxo.'
    return
  }
  isSaving.value = true
  errorMsg.value = ''
  try {
    const { data } = await api.post('/flows', {
      flow: { name: name.value.trim(), description: description.value.trim(), channel: channel.value, inbox_id: inboxId.value || null, active: active.value }
    })
    router.push(`/fluxos/${data.id}`)
  } catch (e) {
    console.error('Erro ao criar fluxo:', e)
    errorMsg.value = e.response?.data?.errors?.join(', ') || 'Erro ao criar fluxo.'
  } finally {
    isSaving.value = false
  }
}

onMounted(fetchInboxes)
</script>

<template>
  <div class="page-container">
    <div class="page-content">
      <router-link to="/fluxos" class="back-link"><ArrowLeft class="icon-sm" /> Fluxos</router-link>

      <div class="header">
        <h1>Criar fluxo</h1>
        <p class="description">Comece do zero — depois de criar, o editor visual abre automaticamente.</p>
      </div>

      <form class="form-card" @submit.prevent="criarFluxo">
        <div class="form-group">
          <label>Nome do fluxo</label>
          <input v-model="name" type="text" class="form-input" placeholder="Ex: Atendimento Inicial" />
        </div>

        <div class="form-group">
          <label>Descrição</label>
          <textarea v-model="description" class="form-input" rows="3" placeholder="Pra que serve esse fluxo?"></textarea>
        </div>

        <div class="form-group">
          <label>Canal</label>
          <select v-model="channel" class="form-input" @change="inboxId = ''">
            <option value="whatsapp">WhatsApp</option>
            <option value="instagram">Instagram</option>
            <option value="outro">Outro</option>
          </select>
        </div>

        <div v-if="channel !== 'outro'" class="form-group">
          <label>Caixa</label>
          <select v-model="inboxId" class="form-input">
            <option value="">Selecione a caixa...</option>
            <option v-for="ib in inboxesDoCanal" :key="ib.id" :value="ib.id">{{ ib.name }}</option>
          </select>
          <p class="hint">O gatilho por palavra-chave só escuta essa caixa. Sem escolher, o fluxo não dispara em lugar nenhum.</p>
        </div>

        <div class="form-group">
          <label>Status inicial</label>
          <div class="status-toggle">
            <button type="button" class="toggle-btn" :class="{ active: active }" @click="active = true">Ativo</button>
            <button type="button" class="toggle-btn" :class="{ active: !active }" @click="active = false">Inativo</button>
          </div>
        </div>

        <p v-if="errorMsg" class="error-text">{{ errorMsg }}</p>

        <div class="form-actions">
          <router-link to="/fluxos" class="btn-cancel">Cancelar</router-link>
          <button type="submit" class="btn-primary" :disabled="isSaving">{{ isSaving ? 'Criando...' : 'Criar fluxo' }}</button>
        </div>
      </form>
    </div>
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

.page-content { max-width: 560px; width: 100%; margin: 0; }

.icon-sm { width: 16px; height: 16px; }

.back-link {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  color: var(--text-muted);
  text-decoration: none;
  font-size: 0.85rem;
  margin-bottom: 1.5rem;

  &:hover { color: var(--text-main); }
}

.header {
  margin-bottom: 1.5rem;

  h1 { font-size: 1.25rem; font-weight: 500; color: var(--text-main); margin-bottom: 0.5rem; }
  .description { color: var(--text-muted); font-size: 0.9rem; }
}

.form-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  padding: 1.5rem;
}

.form-group {
  margin-bottom: 1.25rem;

  label { display: block; margin-bottom: 0.5rem; font-size: 0.85rem; color: var(--text-main); font-weight: 500; }

  .form-input {
    width: 100%;
    padding: 0.65rem 0.85rem;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    font-size: 0.9rem;
    background: var(--bg-tertiary);
    color: var(--text-main);
    font-family: inherit;

    &:focus { outline: none; border-color: var(--primary); }
  }
}

.status-toggle { display: flex; gap: 0.5rem; }

.toggle-btn {
  flex: 1;
  padding: 0.6rem;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-tertiary);
  color: var(--text-muted);
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;

  &.active { background: var(--primary, #d49ba7); color: white; border-color: var(--primary, #d49ba7); }
}

.error-text { color: #ef4444; font-size: 0.82rem; margin-bottom: 1rem; }
.hint { font-size: 0.75rem; color: var(--text-muted); margin-top: 0.4rem; }

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  margin-top: 1.5rem;
}

.btn-cancel {
  padding: 0.6rem 1.1rem;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-secondary);
  color: var(--text-main);
  text-decoration: none;
  font-size: 0.85rem;
  display: flex;
  align-items: center;
}

.btn-primary {
  background: var(--primary, #d49ba7);
  color: white;
  padding: 0.6rem 1.25rem;
  border-radius: 6px;
  font-size: 0.85rem;
  font-weight: 600;
  border: none;
  cursor: pointer;

  &:disabled { opacity: 0.6; cursor: not-allowed; }
}
</style>
