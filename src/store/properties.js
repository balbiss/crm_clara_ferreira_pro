import { defineStore } from 'pinia'
import api from '../api'

export const usePropertiesStore = defineStore('properties', {
  state: () => ({
    properties: [],
    isLoading: false,
    isLoadedOnce: false
  }),
  
  actions: {
    async fetchProperties() {
      if (!this.isLoadedOnce) {
        this.isLoading = true
      }
      
      try {
        const response = await api.get('/properties')
        this.properties = response.data
        this.isLoadedOnce = true
      } catch (error) {
        console.error('Failed to fetch properties:', error)
      } finally {
        this.isLoading = false
      }
    },
    
    removeProperty(id) {
      this.properties = this.properties.filter(p => p.id !== id)
    }
  }
})
