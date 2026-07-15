<script setup>
import { onMounted } from 'vue'
import { Search, Settings2, Trash2, ChevronRight } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'
import { useInboxesStore } from '../store/inboxes'
import { storeToRefs } from 'pinia'

const inboxesStore = useInboxesStore()
const { inboxes, isLoading } = storeToRefs(inboxesStore)

onMounted(() => {
  inboxesStore.fetchInboxes()
})

const deleteInbox = async (id) => {
  const result = await Swal.fire({
    title: 'Deletar?',
    text: 'A caixa de entrada será removida.',
    icon: 'warning',
    showCancelButton: true,
    confirmButtonText: 'Sim, deletar'
  })
  
  if (result.isConfirmed) {
    try {
      await api.delete(`/inboxes/${id}`)
      inboxesStore.removeInbox(id)
    } catch (error) {
      console.error('Failed to delete inbox:', error)
      Swal.fire('Erro', 'Não foi possível deletar a caixa de entrada', 'error')
    }
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-content">
      <div class="header">
        <h1>Caixas de Entrada</h1>
        <p class="description">
          Um canal é o modo de comunicação que seu cliente escolhe para interagir com você. Uma caixa de entrada é onde você gerencia interações para um canal específico. Pode incluir comunicações de várias fontes, como e-mail, chat ao vivo e mídia social.
        </p>
        <a href="#" class="learn-more">Saiba mais sobre as caixas de entrada <ChevronRight class="icon-xs" /></a>
      </div>

      <div class="actions-bar">
        <div class="search-wrapper">
          <Search class="icon-sm search-icon" />
          <input type="text" placeholder="Pesquisar caixas de entrada..." />
        </div>
        
        <div class="actions-right">
          <span class="count-text">{{ inboxes.length }} caixa(s) de entrada</span>
          <router-link to="/settings/inboxes/new" class="btn-primary">
            Adicionar Caixa de Entrada
          </router-link>
        </div>
      </div>

      <div class="inbox-list">
        <div v-if="isLoading" class="skeleton-list">
          <div class="skeleton-card" v-for="i in 3" :key="i">
            <div class="skeleton-avatar"></div>
            <div class="skeleton-text">
              <div class="skeleton-line title"></div>
              <div class="skeleton-line subtitle"></div>
            </div>
            <div class="skeleton-actions">
              <div class="skeleton-circle"></div>
              <div class="skeleton-circle"></div>
            </div>
          </div>
        </div>

        <template v-else>
          <div class="inbox-card" v-for="inbox in inboxes" :key="inbox.id">
            <div class="inbox-info">
              <div class="icon-wrapper" style="background: transparent; border: none; padding: 0;">
                <svg v-if="inbox.provider === 'instagram'" xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" :fill="`url(#ig-grad-${inbox.id})`">
                  <defs><linearGradient :id="`ig-grad-${inbox.id}`" x1="0" x2="1" y1="1" y2="0"><stop offset="0%" stop-color="#f09433"/><stop offset="25%" stop-color="#e6683c"/><stop offset="50%" stop-color="#dc2743"/><stop offset="75%" stop-color="#cc2366"/><stop offset="100%" stop-color="#bc1888"/></linearGradient></defs>
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm6.406-11.845a1.44 1.44 0 1 0 0 2.881 1.44 1.44 0 0 0 0-2.881z"/>
                </svg>
                <svg v-else xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="#25D366">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 0 0-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"/>
                </svg>
              </div>
              <div class="inbox-details">
                <h3>{{ inbox.name }}</h3>
                <div class="provider-row">
                  <span class="provider">{{ inbox.provider === 'instagram' ? 'Instagram' : 'WhatsApp' }} - {{ inbox.provider.charAt(0).toUpperCase() + inbox.provider.slice(1) }}</span>
                  <span v-if="['baileys', 'instagram'].includes(inbox.provider)" class="status-badge" :class="{
                    connected: inbox.connected === true,
                    disconnected: inbox.connected === false,
                    loading: inbox.connected === undefined
                  }">
                    <span class="dot"></span>
                    {{ inbox.connected === true ? 'Conectado' : (inbox.connected === false ? 'Desconectado' : 'Verificando...') }}
                  </span>
                </div>
              </div>
            </div>
            
            <div class="inbox-actions">
              <router-link :to="`/settings/inboxes/${inbox.id}`" class="icon-btn" title="Configurações"><Settings2 class="icon-sm" /></router-link>
              <button class="icon-btn text-danger" @click="deleteInbox(inbox.id)" title="Deletar"><Trash2 class="icon-sm" /></button>
            </div>
          </div>
          
          <div v-if="inboxes.length === 0" class="empty-state">
            Nenhuma caixa de entrada configurada.
          </div>
        </template>
      </div>
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

.page-content {
  max-width: 1000px;
  width: 100%;
  margin: 0;
}

.header {
  margin-bottom: 2.5rem;

  h1 {
    font-size: 1.25rem;
    font-weight: 500;
    color: var(--text-main);
    margin-bottom: 1rem;
  }

  .description {
    color: var(--text-muted);
    font-size: 0.9rem;
    line-height: 1.6;
    margin-bottom: 0.75rem;
    max-width: 800px;
  }
  
  .learn-more {
    color: var(--primary);
    font-size: 0.9rem;
    font-weight: 500;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    
    &:hover {
      text-decoration: underline;
    }
  }
}

.icon-xs { width: 14px; height: 14px; }

.actions-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.search-wrapper {
  position: relative;
  width: 260px;

  .search-icon {
    position: absolute;
    left: 1rem;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-muted);
  }

  input {
    width: 100%;
    padding: 0.55rem 1rem 0.55rem 2.5rem;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    background: var(--bg-tertiary);
    font-size: 0.85rem;
    color: var(--text-main);
    outline: none;
    
    &:focus {
      border-color: var(--primary);
    }
  }
}

.actions-right {
  display: flex;
  align-items: center;
  gap: 1rem;

  .count-text {
    font-size: 0.85rem;
    color: var(--text-muted);
    border-right: 1px solid var(--border-color);
    padding-right: 1rem;
  }
}

.btn-primary {
  background: #1f93ff;
  color: white;
  padding: 0.55rem 1rem;
  border-radius: 6px;
  text-decoration: none;
  font-size: 0.85rem;
  font-weight: 500;
  border: none;
  cursor: pointer;
  
  &:hover {
    background: #007bf5;
  }
}

.btn-cancel {
  background: transparent;
  color: #666;
  border: 1px solid #ddd;
  padding: 0.55rem 1rem;
  border-radius: 6px;
  cursor: pointer;
  
  &:hover {
    background: #f1f1f1;
  }
}

.inbox-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.empty-state {
  text-align: center;
  padding: 3rem;
  color: #999;
}

.inbox-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-secondary);
}

.inbox-info {
  display: flex;
  align-items: center;
  gap: 1rem;

  .icon-wrapper {
    width: 36px;
    height: 36px;
    border-radius: 8px;
    border: 1px solid var(--border-color);
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-tertiary);
  }

  .inbox-details {
    h3 {
      margin: 0 0 0.25rem 0;
      font-size: 1rem;
      color: var(--text-main);
    }

    .provider-row {
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }

    .provider {
      font-size: 0.85rem;
      color: var(--text-muted);
    }
    
    .status-badge {
      display: flex;
      align-items: center;
      gap: 0.35rem;
      font-size: 0.75rem;
      font-weight: 500;
      padding: 0.15rem 0.5rem;
      border-radius: 12px;
      
      .dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
      }
      
      &.connected {
        background: #d1fae5;
        color: #059669;
        .dot { background: #10b981; }
      }
      
      &.disconnected {
        background: #fee2e2;
        color: #dc2626;
        .dot { background: #ef4444; }
      }
      
      &.loading {
        background: #f3f4f6;
        color: #6b7280;
        .dot { 
          background: #9ca3af; 
          animation: pulse 1.5s infinite;
        }
      }
    }
  }
}

@keyframes pulse {
  0% { opacity: 0.5; }
  50% { opacity: 1; }
  100% { opacity: 0.5; }
}

.skeleton-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.skeleton-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.5rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  animation: pulse-skeleton 1.5s infinite;
  
  .skeleton-avatar {
    width: 48px;
    height: 48px;
    border-radius: 8px;
    background: var(--bg-hover);
    margin-right: 1.5rem;
  }
  
  .skeleton-text {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  
  .skeleton-line {
    height: 12px;
    background: var(--bg-hover);
    border-radius: 4px;
    
    &.title { width: 150px; height: 16px; }
    &.subtitle { width: 100px; }
  }
  
  .skeleton-actions {
    display: flex;
    gap: 0.5rem;
    
    .skeleton-circle {
      width: 32px;
      height: 32px;
      border-radius: 6px;
      background: var(--bg-hover);
    }
  }
}

@keyframes pulse-skeleton {
  0% { opacity: 0.6; }
  50% { opacity: 1; }
  100% { opacity: 0.6; }
}

.inbox-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;

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
    
    &:hover {
      background: #fee2e2;
      color: #ef4444;
      border-color: #fca5a5;
    }
  }
}

.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  border-radius: 12px;
  padding: 2rem;
  width: 450px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.1);
  
  h2 {
    margin: 0 0 1.5rem 0;
    font-size: 1.2rem;
  }
}

.form-group {
  margin-bottom: 1.25rem;
  
  label {
    display: block;
    margin-bottom: 0.5rem;
    font-size: 0.85rem;
    color: #4b5563;
    font-weight: 500;
  }
  
  .form-input {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 0.95rem;
    
    &:focus {
      outline: none;
      border-color: #3b82f6;
      box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
    }
  }
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 2rem;
}
</style>
