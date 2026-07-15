import { defineStore } from 'pinia'
import api from '../api'

export const useCondominiumsStore = defineStore('condominiums', {
  state: () => ({
    condominiums: [],
    isLoading: false,
    isLoadedOnce: false
  }),
  
  actions: {
    async fetchCondominiums() {
      if (!this.isLoadedOnce) {
        this.isLoading = true
      }
      
      try {
        const response = await api.get('/condominiums')
        this.condominiums = response.data
        this.isLoadedOnce = true
      } catch (error) {
        console.error('Failed to fetch condominiums:', error)
      } finally {
        this.isLoading = false
      }
    },
    
    removeCondominium(id) {
      this.condominiums = this.condominiums.filter(c => c.id !== id)
    }
  }
})
