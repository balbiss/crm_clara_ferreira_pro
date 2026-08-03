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
        // A carteira já passa de 300 revendedoras — o endpoint pagina por padrão
        // (50 por página), então uma chamada só nunca traz todo mundo. As telas
        // "Ativas"/"Inativas" filtram no cliente por status, e precisam do conjunto
        // completo pra não sumir com revendedoras que não estão entre as criadas
        // mais recentemente (ordem padrão é created_at desc).
        const perPage = 200
        let page = 1
        let all = []
        while (true) {
          const response = await api.get('/contacts', { params: { page, per_page: perPage } })
          all = all.concat(response.data)
          if (response.data.length < perPage) break
          page += 1
        }
        this.contacts = all
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
