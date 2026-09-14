import { defineStore } from 'pinia'
import api from '../api'

export const useAgentsStore = defineStore('agents', {
  state: () => ({
    agents: [],
    isLoading: false,
    isLoadedOnce: false,
    lastFetchedAt: null
  }),
  
  actions: {
    async fetchAgents() {
      if (!this.isLoadedOnce) {
        this.isLoading = true
      }
      
      try {
        const response = await api.get('/agents')
        this.agents = response.data
        this.isLoadedOnce = true
        this.lastFetchedAt = Date.now()
      } catch (error) {
        console.error('Failed to fetch agents:', error)
      } finally {
        this.isLoading = false
      }
    },
    
    removeAgent(id) {
      this.agents = this.agents.filter(a => a.id !== id)
    }
  }
})
