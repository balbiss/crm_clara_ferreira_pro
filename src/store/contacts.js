import { defineStore } from 'pinia'
import api from '../api'

export const useContactsStore = defineStore('contacts', {
  state: () => ({
    contacts: [],
    isLoading: false,
    isLoadedOnce: false
  }),
  
  actions: {
    async fetchContacts() {
      if (!this.isLoadedOnce) {
        this.isLoading = true
      }
      
      try {
        const response = await api.get('/contacts')
        this.contacts = response.data
        this.isLoadedOnce = true
      } catch (error) {
        console.error('Failed to fetch contacts:', error)
      } finally {
        this.isLoading = false
      }
    },
    
    removeContact(id) {
      this.contacts = this.contacts.filter(c => c.id !== id)
    }
  }
})
