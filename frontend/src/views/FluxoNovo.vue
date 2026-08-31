<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft } from '@lucide/vue'
import api from '../api'

const router = useRouter()

const name = ref('')
const description = ref('')
const channel = ref('whatsapp')
const active = ref(true)
const isSaving = ref(false)
const errorMsg = ref('')

const criarFluxo = async () => {
  if (!name.value.trim()) {
    errorMsg.value = 'Dê um nome ao fluxo.'
    return
  }
  isSaving.value = true
  errorMsg.value = ''
  try {
    const { data } = await api.post('/flows', {
      flow: { name: name.value.trim(), description: description.value.trim(), channel: channel.value, active: active.value }
    })
    router.push(`/fluxos/${data.id}`)
  } catch (e) {
    console.error('Erro ao criar fluxo:', e)
    errorMsg.value = e.response?.data?.errors?.join(', ') || 'Erro ao criar fluxo.'
  } finally {
    isSaving.value = false
  }
}
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
          <select v-model="channel" class="form-input">
            <option value="whatsapp">WhatsApp</option>
            <option value="instagram">Instagram</option>
            <option value="outro">Outro</option>
          </select>
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
