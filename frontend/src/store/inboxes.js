import { defineStore } from 'pinia'
import api from '../api'

let pollTimer = null

export const useInboxesStore = defineStore('inboxes', {
  state: () => ({
    inboxes: [],
    isLoading: false,
    isLoadedOnce: false
  }),

  getters: {
    disconnectedInboxes: (state) =>
      state.inboxes.filter(i => ['baileys', 'waha', 'instagram'].includes(i.provider) && i.connected === false)
  },

  actions: {
    async fetchInboxes() {
      // Se for a primeira vez, mostramos o loading (skeleton)
      if (!this.isLoadedOnce) {
        this.isLoading = true
      }

      try {
        const response = await api.get('/inboxes')

        // Atualiza a lista mesclando os status já existentes para não piscar
        this.inboxes = response.data.map(newInbox => {
          const oldInbox = this.inboxes.find(i => i.id === newInbox.id)
          return {
            ...newInbox,
            connected: oldInbox && oldInbox.connected !== undefined ? oldInbox.connected : (['baileys', 'waha', 'instagram'].includes(newInbox.provider) ? undefined : null)
          }
        })

        this.isLoadedOnce = true

        // Busca os status do Baileys/Instagram em background
        this.inboxes.forEach(inbox => {
          if (['baileys', 'waha', 'instagram'].includes(inbox.provider)) {
            this.checkStatus(inbox.id)
          }
        })
      } catch (error) {
        console.error('Failed to fetch inboxes:', error)
      } finally {
        this.isLoading = false
      }
    },

    async checkStatus(id) {
      try {
        const response = await api.get(`/inboxes/${id}/status`)
        const inbox = this.inboxes.find(i => i.id === id)
        if (inbox) {
          inbox.connected = response.data.connected
        }
      } catch (error) {
        const inbox = this.inboxes.find(i => i.id === id)
        if (inbox) {
          inbox.connected = false
        }
      }
    },

    // Reconsulta periodicamente os canais conectáveis (Baileys/Instagram) pra
    // detectar queda de conexão mesmo com o usuário navegando fora de Config.
    startStatusPolling() {
      if (pollTimer) return
      pollTimer = setInterval(() => {
        this.inboxes.forEach(inbox => {
          if (['baileys', 'waha', 'instagram'].includes(inbox.provider)) {
            this.checkStatus(inbox.id)
          }
        })
      }, 60000)
    },

    stopStatusPolling() {
      if (pollTimer) {
        clearInterval(pollTimer)
        pollTimer = null
      }
    },

    removeInbox(id) {
      this.inboxes = this.inboxes.filter(i => i.id !== id)
    }
  }
})
