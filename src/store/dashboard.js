import { defineStore } from 'pinia'
import api from '../api'

export const useDashboardStore = defineStore('dashboard', {
  state: () => ({
    kpis: {
      total_contacts:  0,
      pretensao_venda: 0,
      temperature:     { quente: 0, morno: 0, frio: 0 },
      kanban:          { lead: 0, visit: 0, proposal: 0, won: 0 },
      conversations:   { open: 0, resolved: 0, today: 0, with_human: 0 },
      appointments:    { total: 0, today: 0, upcoming: 0, done: 0 }
    },
    leadsBySourceData: {
      labels: ['Sem dados'],
      datasets: [{
        data: [1],
        backgroundColor: ['#e5e7eb']
      }]
    },
    todayLeads: [],
    isOwner: false,
    isLoading: false,
    isLoadedOnce: false
  }),

  actions: {
    async fetchDashboard() {
      if (!this.isLoadedOnce) this.isLoading = true
      try {
        const response = await api.get('/dashboard')
        this.kpis       = response.data.kpis
        this.isOwner    = response.data.is_owner
        this.todayLeads = response.data.today_assigned_leads || []

        const sourceData = response.data.leads_by_source || {}
        const labels = Object.keys(sourceData)
        const data   = Object.values(sourceData)

        if (labels.length > 0) {
          this.leadsBySourceData = {
            labels,
            datasets: [{
              data,
              backgroundColor: ['#6366f1','#10b981','#f59e0b','#ef4444','#3b82f6','#ec4899','#0d9488','#8b5cf6']
            }]
          }
        } else {
          this.leadsBySourceData = {
            labels: ['Sem dados'],
            datasets: [{ data: [1], backgroundColor: ['#e5e7eb'] }]
          }
        }

        this.isLoadedOnce = true
      } catch (error) {
        console.error('Error fetching dashboard data', error)
      } finally {
        this.isLoading = false
      }
    }
  }
})
