<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Filter, Plus, MapPin, Grid, BedDouble, Car, Edit2, Trash2, Map, Zap } from '@lucide/vue'
import api from '../api'
import { usePropertiesStore } from '../store/properties'
import { storeToRefs } from 'pinia'

const router = useRouter()
const propertiesStore = usePropertiesStore()
const { properties, isLoading } = storeToRefs(propertiesStore)

const fetchProperties = () => {
  propertiesStore.fetchProperties()
}

onMounted(() => {
  fetchProperties()
})

const selectedProperties = ref([])

const NO_PHOTO = `data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='150' height='150' viewBox='0 0 150 150'><rect width='150' height='150' fill='%23f1f5f9'/><text x='75' y='68' text-anchor='middle' font-family='sans-serif' font-size='32'>🏠</text><text x='75' y='95' text-anchor='middle' font-family='sans-serif' font-size='11' fill='%2394a3b8'>Sem Foto</text></svg>`

const getCoverImage = (property) => {
  if (property.photo_urls && property.photo_urls.length > 0) {
    return property.photo_urls[0]
  }
  return NO_PHOTO
}

const openMap = (property) => {
  const address = `${property.street || ''}, ${property.number || ''} ${property.neighborhood || ''} ${property.city || ''} ${property.state || ''}`
  window.open(`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`, '_blank')
}

const deleteProperty = async (id) => {
  import('sweetalert2').then(async ({ default: Swal }) => {
    const result = await Swal.fire({
      title: 'Tem certeza?',
      text: "Você não poderá reverter isso!",
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#d33',
      cancelButtonColor: '#3085d6',
      confirmButtonText: 'Sim, excluir!'
    })

    if (result.isConfirmed) {
      try {
        await api.delete(`/properties/${id}`)
        properties.value = properties.value.filter(p => p.id !== id)
        Swal.fire('Excluído!', 'O imóvel foi excluído.', 'success')
      } catch (error) {
        Swal.fire('Erro', 'Não foi possível excluir.', 'error')
      }
    }
  })
}

const triggerMatch = async (propertyId) => {
  try {
    await api.post(`/properties/${propertyId}/trigger_match`)
    import('sweetalert2').then(({ default: Swal }) => {
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Matching iniciado!', text: 'Aguarde a notificação com o resultado.', showConfirmButton: false, timer: 4000 })
    })
  } catch {
    import('sweetalert2').then(({ default: Swal }) => {
      Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao iniciar matching.', showConfirmButton: false, timer: 3000 })
    })
  }
}

const bulkDelete = async () => {
  if (selectedProperties.value.length === 0) return
  
  import('sweetalert2').then(async ({ default: Swal }) => {
    const result = await Swal.fire({
      title: 'Excluir em massa?',
      text: `Você vai excluir ${selectedProperties.value.length} imóveis.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#d33',
      cancelButtonColor: '#3085d6',
      confirmButtonText: 'Sim, excluir!'
    })

    if (result.isConfirmed) {
      try {
        for (const id of selectedProperties.value) {
          await api.delete(`/properties/${id}`)
        }
        properties.value = properties.value.filter(p => !selectedProperties.value.includes(p.id))
        selectedProperties.value = []
        Swal.fire('Excluídos!', 'Imóveis excluídos com sucesso.', 'success')
      } catch (error) {
        Swal.fire('Erro', 'Ocorreu um erro ao excluir.', 'error')
      }
    }
  })
}
</script>

<template>
  <div class="page-container">
    <div class="filter-card">
      <div class="search-row">
        <input type="text" class="main-search" placeholder="Filtro geral">
      </div>
      <div class="actions-row">
        <div class="left-actions">
          <button class="btn-filter"><Filter class="icon-sm" /> Filtrar</button>
          <span class="total-text">Total de Imóveis: {{ properties.length }}</span>
          <button v-if="selectedProperties.length > 0" class="btn-danger" @click="bulkDelete">Excluir Selecionados ({{ selectedProperties.length }})</button>
        </div>
        <div class="right-actions">
          <button class="btn-outline">Limpar</button>
          <button class="btn-primary">Buscar</button>
        </div>
      </div>
      <div class="active-filters">
        <span class="filter-tag">Status: Ativo <button>×</button></span>
        <span class="filter-tag">Negociação <button>×</button></span>
      </div>
    </div>

    <div class="new-btn-container">
      <button class="btn-primary new-property-btn" @click="router.push('/imoveis/novo')">
        <Plus class="icon-sm" /> Novo Imóvel
      </button>
    </div>

    <div class="properties-list">
      <div v-if="isLoading" class="skeleton-list">
        <div class="skeleton-property-card" v-for="i in 3" :key="'skel'+i">
          <div class="skeleton-image"></div>
          <div class="skeleton-content">
            <div class="skeleton-line title"></div>
            <div class="skeleton-line address"></div>
            <div class="skeleton-features">
              <div class="skeleton-feature"></div>
              <div class="skeleton-feature"></div>
              <div class="skeleton-feature"></div>
            </div>
          </div>
        </div>
      </div>

      <template v-else>
        <div class="property-card" v-for="property in properties" :key="property.id">
        <div class="checkbox-col">
          <input type="checkbox" :value="property.id" v-model="selectedProperties">
        </div>
        
        <div class="image-col">
          <div class="image-wrapper">
            <span class="status-badge"><span class="dot green"></span> {{ property.code || 'S/N' }}</span>
            <img :src="getCoverImage(property)" alt="Imóvel" class="property-img">
          </div>
        </div>

        <div class="details-col">
          <h3 class="property-title">
            {{ property.property_type || 'Imóvel' }} 
            <span class="title-separator" v-if="property.neighborhood">|</span> 
            <span class="neighborhood-name">{{ property.neighborhood }}</span>
          </h3>
          
          <div class="property-address">
            <MapPin class="icon-xs" />
            <p>{{ property.street || 'Endereço não informado' }}, {{ property.number }} - {{ property.neighborhood }} - {{ property.city }}/{{ property.state }}, {{ property.cep }}</p>
          </div>

          <div class="property-features">
            <div class="feature"><Grid class="icon-sm" /> <div><strong>Área Construída</strong><br>{{ property.built_area || 0 }} m²</div></div>
            <div class="feature"><Grid class="icon-sm" /> <div><strong>Área Terreno</strong><br>{{ property.total_area || 0 }} m²</div></div>
            <div class="feature"><BedDouble class="icon-sm" /> <div><strong>Quartos</strong><br>{{ property.bedrooms || 0 }} ({{ property.suites || 0 }} suíte)</div></div>
            <div class="feature"><Car class="icon-sm" /> <div><strong>Vagas</strong><br>{{ property.parking_spots || 0 }}</div></div>
          </div>
        </div>

        <div class="pricing-col">
          <div class="pricing-top">
            <span class="last-updated">Última alteração: {{ new Date(property.updated_at).toLocaleDateString() }}</span>
            <button class="edit-btn" @click="router.push(`/imoveis/${property.id}/editar`)"><Edit2 class="icon-sm" /></button>
          </div>
          
          <div class="pricing-middle">
            <span class="listing-type">{{ property.listing_type || 'Venda' }}</span>
            <h2 class="price">R$ {{ Number(property.price).toLocaleString('pt-BR', {minimumFractionDigits: 2}) }}</h2>
          </div>
          
          <div class="pricing-bottom">
            <span class="agent-name">Captador: {{ property.agent_name || 'Nenhum' }}</span>
            <div class="action-buttons">
              <button class="circle-btn bg-danger" @click="deleteProperty(property.id)" title="Excluir"><Trash2 class="icon-sm" /></button>
              <button class="circle-btn" @click="openMap(property)" title="Ver no Mapa"><Map class="icon-sm" /></button>
              <button class="circle-btn bg-match" @click="triggerMatch(property.id)" title="Executar Matching de Leads"><Zap class="icon-sm" /></button>
            </div>
          </div>
        </div>
        
        <div class="card-indicator"></div>
      </div>
      </template>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  padding: 2rem;
  background: var(--bg-primary);
  height: 100%;
  overflow-y: auto;
}

.filter-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1.5rem;
  margin-bottom: 1rem;

  .search-row {
    margin-bottom: 1rem;
    .main-search {
      width: 100%;
      padding: 0.75rem 1rem;
      border: 1px solid var(--border-color);
      border-radius: 6px;
      background: var(--bg-primary);
      color: var(--text-main);
      font-size: 0.95rem;
      outline: none;
      &:focus { border-color: var(--primary); }
    }
  }

  .actions-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;

    .left-actions, .right-actions {
      display: flex;
      align-items: center;
      gap: 1rem;
    }

    .btn-filter {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      background: var(--bg-primary);
      border: 1px solid var(--border-color);
      padding: 0.5rem 1rem;
      border-radius: 6px;
      font-weight: 600;
      color: var(--text-main);
      cursor: pointer;
    }

    .total-text {
      color: #4338ca;
      font-weight: 600;
      font-size: 0.9rem;
    }

    .btn-danger {
      background: #ef4444;
      border: none;
      color: white;
      padding: 0.5rem 1rem;
      border-radius: 6px;
      cursor: pointer;
      font-weight: 500;
      font-size: 0.85rem;
    }

    .btn-outline {
      background: transparent;
      border: 1px solid var(--border-color);
      padding: 0.5rem 1.5rem;
      border-radius: 20px;
      color: var(--text-main);
      cursor: pointer;
      font-weight: 500;
    }

    .btn-primary {
      background: var(--primary);
      border: none;
      color: white;
      padding: 0.5rem 1.5rem;
      border-radius: 20px;
      cursor: pointer;
      font-weight: 500;
    }
  }

  .active-filters {
    display: flex;
    gap: 0.5rem;
    
    .filter-tag {
      background: var(--bg-primary);
      border: 1px solid var(--border-color);
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
      font-size: 0.8rem;
      color: #4338ca;
      font-weight: 500;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      
      button {
        background: transparent;
        border: none;
        color: #4338ca;
        cursor: pointer;
        font-weight: bold;
      }
    }
  }
}

.new-btn-container {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 1.5rem;
  
  .new-property-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background: var(--primary);
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    font-weight: 500;
    cursor: pointer;
  }
}

.properties-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.property-card {
  display: flex;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1rem;
  position: relative;
  gap: 1.5rem;

  .checkbox-col {
    display: flex;
    align-items: center;
    justify-content: center;
    input { width: 18px; height: 18px; }
  }

  .image-col {
    .image-wrapper {
      position: relative;
      width: 160px;
      height: 120px;
      border-radius: 8px;
      overflow: hidden;
      
      .status-badge {
        position: absolute;
        top: 8px;
        left: 8px;
        background: rgba(0,0,0,0.7);
        color: white;
        padding: 0.2rem 0.5rem;
        border-radius: 4px;
        font-size: 0.75rem;
        display: flex;
        align-items: center;
        gap: 0.4rem;
        
        .dot.green {
          width: 8px; height: 8px;
          background: #22c55e;
          border-radius: 50%;
        }
      }
      
      .property-img {
        width: 100%;
        height: 100%;
        object-fit: cover;
      }
    }
  }

  .details-col {
    flex: 1;
    display: flex;
    flex-direction: column;
    justify-content: space-between;

    .property-title {
      font-size: 1.1rem;
      color: var(--text-main);
      font-weight: 500;
      margin: 0;
      
      .title-separator { color: var(--text-muted); margin: 0 0.5rem; }
      .neighborhood-name { color: var(--text-muted); }
    }

    .property-address {
      display: flex;
      align-items: flex-start;
      gap: 0.5rem;
      color: var(--text-muted);
      font-size: 0.85rem;
      margin-top: 0.5rem;
      p { margin: 0; }
    }

    .property-features {
      display: flex;
      gap: 2rem;
      margin-top: 1rem;
      
      .feature {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        font-size: 0.8rem;
        color: var(--text-main);
        
        strong { color: var(--text-muted); font-weight: 500; }
      }
    }
  }

  .pricing-col {
    width: 280px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    text-align: right;

    .pricing-top {
      display: flex;
      justify-content: flex-end;
      align-items: center;
      gap: 1rem;
      
      .last-updated { font-size: 0.75rem; color: var(--text-muted); }
      .edit-btn { background: none; border: none; color: var(--text-muted); cursor: pointer; }
    }

    .pricing-middle {
      .listing-type { font-size: 0.85rem; color: var(--text-muted); }
      .price { font-size: 1.25rem; font-weight: 700; color: var(--text-main); margin: 0; }
    }

    .pricing-bottom {
      display: flex;
      justify-content: flex-end;
      align-items: center;
      gap: 1rem;
      
      .agent-name { font-size: 0.8rem; color: var(--text-muted); }
      
      .action-buttons {
        display: flex;
        gap: 0.5rem;
        
        .circle-btn {
          width: 32px; height: 32px;
          border-radius: 50%;
          background: #4338ca;
          color: white;
          border: none;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          
          &.bg-danger { background: #ef4444; }
          &.bg-match  { background: #f59e0b; }
        }
      }
    }
  }

  .card-indicator {
    position: absolute;
    right: 0;
    top: 10px;
    bottom: 10px;
    width: 4px;
    background: #4338ca;
    border-radius: 4px 0 0 4px;
  }
}

.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 14px; height: 14px; }

@media (max-width: 768px) {
  .page-container {
    padding: 1rem;
  }

  .filter-card {
    padding: 1rem;
  }

  .actions-row {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;

    .left-actions, .right-actions {
      width: 100%;
      flex-wrap: wrap;
    }
  }

  .property-card {
    flex-direction: column;
    gap: 0.75rem;

    .image-col .image-wrapper {
      width: 100%;
      height: 180px;
    }

    .checkbox-col {
      display: none;
    }
  }

  .card-actions {
    flex-wrap: wrap;
    gap: 0.4rem;
  }
}
</style>
