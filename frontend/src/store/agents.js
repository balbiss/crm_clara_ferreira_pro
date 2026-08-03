import { defineStore } from 'pinia'
import api from '../api'

export const useAgentsStore = defineStore('agents', {
  state: () => ({
    agents: [],
    isLoading: false,
    isLoadedOnce: false
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
