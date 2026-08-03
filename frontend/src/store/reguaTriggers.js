import { defineStore } from 'pinia'
import api from '../api'

// Gatilhos de automação por status da régua consignada (botão "Automatize" no
// Kanban.vue) — equivalente ao store/pipelines.js, mas pra Contact#status em vez de
// PipelineStage.
export const useReguaTriggersStore = defineStore('reguaTriggers', {
  state: () => ({
    triggers: [],
    isLoading: false,
    isLoadedOnce: false
  }),

  actions: {
    async fetchTriggers() {
      if (!this.isLoadedOnce) this.isLoading = true
      try {
        const response = await api.get('/regua_triggers')
        this.triggers = response.data
        this.isLoadedOnce = true
      } catch (error) {
        console.error('Failed to fetch regua triggers:', error)
      } finally {
        this.isLoading = false
      }
    },

    triggersForStatus(status) {
      return this.triggers.filter(t => t.status === status)
    },

    async createTrigger(status, payload) {
      const response = await api.post('/regua_triggers', { regua_trigger: { status, ...payload } })
      this.triggers.push(response.data)
      return response.data
    },

    async deleteTrigger(triggerId) {
      await api.delete(`/regua_triggers/${triggerId}`)
      this.triggers = this.triggers.filter(t => t.id !== triggerId)
    }
  }
})
