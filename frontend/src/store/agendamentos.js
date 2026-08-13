import { defineStore } from 'pinia'
import api from '../api'

export const useAgendamentosStore = defineStore('agendamentos', {
  state: () => ({
    agendamentos: [],
    isLoading: false
  }),

  actions: {
    async fetchAgendamentos({ de, ate, userId } = {}) {
      this.isLoading = true
      try {
        const params = {}
        if (de) params.de = de
        if (ate) params.ate = ate
        if (userId) params.user_id = userId

        const { data } = await api.get('/agendamentos', { params })
        this.agendamentos = data
      } finally {
        this.isLoading = false
      }
    },

    async criar(payload) {
      const { data } = await api.post('/agendamentos', { agendamento: payload })
      this.agendamentos.push(data)
      return data
    },

    async atualizar(id, payload) {
      const { data } = await api.patch(`/agendamentos/${id}`, { agendamento: payload })
      const idx = this.agendamentos.findIndex(a => a.id === id)
      if (idx !== -1) this.agendamentos[idx] = data
      return data
    },

    async remover(id) {
      await api.delete(`/agendamentos/${id}`)
      this.agendamentos = this.agendamentos.filter(a => a.id !== id)
    }
  }
})
