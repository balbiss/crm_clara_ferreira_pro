<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeft, Save, Plus, Trash2, MapPin, ImagePlus, X } from '@lucide/vue'
import api from '../api'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const isEditing = ref(false)
const isLoading = ref(false)
const isSubmitting = ref(false)

const activeTab = ref('empreendimento') // empreendimento, fotos, documentos
const deletedPhotoIds = ref([])
const newPhotos = ref([])

// Form State
const form = ref({
  name: '',
  status: '',
  land_area: '',
  built_area: '',
  on_site_sales: 'Não',
  construction_progress: '',
  construction_year: '',
  builder: '',
  developer: '',
  administrator: '',
  architecture: '',
  min_price: '',
  max_price: '',
  tags: '',
  condominium_types: '',
  
  // Address
  cep: '',
  street: '',
  number: '',
  neighborhood: '',
  country: 'Brasil',
  state: '',
  city: '',
  reference_point: '',
  latitude: '',
  longitude: '',
  
  // Checks
  government_plan: false,
  
  // Arrays/Text
  security_features: [],
  services: [],
  social_features: [],
  commercial_features: [],
  infrastructure: [],
  allotment_infrastructure: [],
  leisure_features: []
})

const photos = ref([])

// Checkbox lists based on user screenshots
const securityOptions = [
  'Cabine primária', 'Catraca eletrônica', 'Cerca elétrica', 'Circuito interno de TV',
  'Guarita blindada', 'Guarita de segurança', 'Portão eletrônico', 'Portaria 24h',
  'Segurança 24h', 'Segurança interna', 'Segurança patrimonial', 'Sistema de incêndio',
  'Sistema de segurança', 'Vigia externo', 'Vigilância 24 horas (automóvel)'
]

const servicesOptions = [
  'Central de limpeza e governança', 'Escritório Virtual', 'Massagista', 'Personal Training',
  'Restaurante', 'Sala de massagem', 'TV a cabo', 'Wi-Fi'
]

const socialOptions = [
  'Coworking', 'Estacionamento rotativo', 'Lavanderia coletiva', 'Praça convivência', 'Vagas para visita'
]

const commercialOptions = [
  'Centro de convenções', 'Docas', 'Entradas p/ caminhões', 'Entrada de serviço independente',
  'Escritórios', 'Esteira rolante', 'Forro rebaixado', 'Hall com pé direito duplo',
  'Lava-rápido', 'Pé direito', 'Piso de alta resistência', 'Piso elevado',
  'Refeitório', 'Shaft de telecomunicações', 'Tensão (KVA)'
]

const infraOptions = [
  'Acessibilidade Universal', 'Acesso PcD', 'Água', 'Aquecimento de água c/ energia solar',
  'Aquecimento Elétrico', 'Aquecimento Gás', 'Central Telefônica', 'Elevador', 'Condomínio fechado',
  'Elevadores de Serviço', 'Elevadores Privativos', 'Elevadores Sociais', 'Entradas de energia elétrica',
  'Entradas de linha telefônica', 'Entrada lateral', 'Escada rolante', 'Gás encanado', 'Gás individual',
  'Gerador emergência', 'Heliponto', 'Lan House', 'Manobrista', 'Medição de água individualizada',
  'Pista pouso', 'Poço artesiano', 'Reservatórios de água', 'Rio', 'Salas de reunião', 'Vestiários'
]

const allotmentOptions = [
  'Esgoto', 'Galeria de águas pluviais', 'Guias e sarjetas', 'Iluminação pública', 'Jardim', 'Rua asfaltada'
]

const leisureOptions = [
  'Academia', 'Aceita pets', 'Auditório', 'Bicicletário', 'Bosque', 'Brinquedoteca', 'Campo de futebol',
  'Campo Golfe', 'Carregador para carro elétrico', 'Churrasqueira', 'Ciclovia', 'Clube', 'Deck molhado',
  'Espaço buteco', 'Espaço kids', 'Espaço zen', 'Forno a lenha', 'Forno de pizza/pão', 'Gourmet', 'Hall de entrada',
  'Terraço coberto', 'Terraço descoberto', 'Hidromassagem', 'Home theater', 'Lareira', 'Fireplace', 'Lago',
  'Mini market', 'Ofurô', 'Pet place', 'Pet space', 'Piano-Bar', 'Sport bar', 'Piscina', 'Piscina aquecida',
  'Piscina climatizada', 'Piscina com prainha', 'Piscina para adulto', 'Piscina infantil', 'Pista de bicicross',
  'Pista de cooper', 'Pista de Skate', 'Playground', 'Porte-cochère', 'Quadra de squash', 'Quadra de tênis',
  'Quadra de beach tênis', 'Quadra de grama', 'Quadra poliesportiva', 'Mini quadra poliesportiva', 'Sala de estudos',
  'Sala de jogos infantil', 'Sala fitness', 'Sala de ginástica', 'Salão de festas', 'Salão de festas infantil',
  'Salão de jogos', 'Salão de vídeo ou cinema', 'Sauna Seca', 'Sauna úmida', 'Sky lounge', 'Smart locker',
  'Solarium', 'Spa'
]

const loadCondominium = async (id) => {
  isLoading.value = true
  try {
    const response = await api.get(`/condominiums/${id}`)
    const data = response.data
    form.value = {
      ...data,
      security_features: data.security_features ? JSON.parse(data.security_features) : [],
      services: data.services ? JSON.parse(data.services) : [],
      social_features: data.social_features ? JSON.parse(data.social_features) : [],
      commercial_features: data.commercial_features ? JSON.parse(data.commercial_features) : [],
      infrastructure: data.infrastructure ? JSON.parse(data.infrastructure) : [],
      allotment_infrastructure: data.allotment_infrastructure ? JSON.parse(data.allotment_infrastructure) : [],
      leisure_features: data.leisure_features ? JSON.parse(data.leisure_features) : []
    }
    photos.value = data.photo_data || []
  } catch (error) {
    console.error('Erro ao carregar condomínio', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  if (route.params.id) {
    isEditing.value = true
    loadCondominium(route.params.id)
  }
})

// ViaCEP Integration
const searchCep = async () => {
  const cepNum = form.value.cep.replace(/\D/g, '')
  if (cepNum.length === 8) {
    try {
      const response = await fetch(`https://viacep.com.br/ws/${cepNum}/json/`)
      const data = await response.json()
      if (!data.erro) {
        form.value.street = data.logradouro
        form.value.neighborhood = data.bairro
        form.value.city = data.localidade
        form.value.state = data.uf
      }
    } catch (error) {
      console.error("Erro ao buscar CEP:", error)
    }
  }
}

// Currency Format
const formatCurrency = (val) => {
  if (!val) return 'R$ 0,00'
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
}

const parseCurrency = (val) => {
  if (!val) return null
  return parseFloat(val.toString().replace(/[^\d,-]/g, '').replace(',', '.'))
}

const handleFileChange = (event) => {
  const files = Array.from(event.target.files)
  files.forEach(file => {
    newPhotos.value.push({
      file,
      preview: URL.createObjectURL(file)
    })
  })
}

const removeNewPhoto = (index) => {
  const photo = newPhotos.value[index]
  if (photo.preview) URL.revokeObjectURL(photo.preview)
  newPhotos.value.splice(index, 1)
}

const removeExistingPhoto = (id, index) => {
  deletedPhotoIds.value.push(id)
  photos.value.splice(index, 1)
}

const submitForm = async () => {
  if (isSubmitting.value) return
  isSubmitting.value = true

  try {
    const formData = new FormData()

    // Append standard fields
    Object.keys(form.value).forEach(key => {
      const val = form.value[key]
      if (typeof val === 'object' && val !== null) {
        // Arrays (like checkboxes) need to be JSON stringified
        formData.append(`condominium[${key}]`, JSON.stringify(val))
      } else {
        formData.append(`condominium[${key}]`, val || '')
      }
    })

    // Append new photos
    newPhotos.value.forEach(photo => {
      formData.append('photos[]', photo.file)
    })

    // Append deleted photo IDs
    deletedPhotoIds.value.forEach(id => {
      formData.append('deleted_photo_ids[]', id)
    })

    const config = { headers: { 'Content-Type': 'multipart/form-data' } }

    if (isEditing.value) {
      await api.put(`/condominiums/${route.params.id}`, formData, config)
    } else {
      await api.post('/condominiums', formData, config)
    }
    router.push('/condominios')
  } catch (error) {
    console.error('Erro ao salvar', error)
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao salvar condomínio. Verifique os dados.', showConfirmButton: false, timer: 3500 })
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <button class="btn-back" @click="router.push('/condominios')">
        <ArrowLeft class="icon" /> Voltar
      </button>
      <div class="header-content">
        <h1>{{ isEditing ? 'Editar Condomínio' : 'Novo Condomínio' }}</h1>
        <button class="btn-primary" @click="submitForm" :disabled="isSubmitting">
          <Save class="icon-sm" /> {{ isSubmitting ? 'Salvando...' : 'Salvar Condomínio' }}
        </button>
      </div>
    </div>

    <div class="tabs">
      <button :class="['tab-btn', { active: activeTab === 'empreendimento' }]" @click="activeTab = 'empreendimento'">Empreendimento</button>
      <button :class="['tab-btn', { active: activeTab === 'fotos' }]" @click="activeTab = 'fotos'">Fotos</button>
    </div>

    <div class="form-content" v-if="activeTab === 'empreendimento'">
      
      <!-- Dados Principais -->
      <div class="section-card">
        <h3 class="section-title">Dados Principais</h3>
        
        <div class="grid-form">
          <div class="input-group col-2">
            <label>Nome *</label>
            <input type="text" v-model="form.name" required>
          </div>
          
          <div class="input-group">
            <label>Status Comercial *</label>
            <select v-model="form.status" required>
              <option value="Em Lançamento">Em Lançamento</option>
              <option value="Em Obras">Em Obras</option>
              <option value="Pronto para Morar">Pronto para Morar</option>
              <option value="Esgotado">Esgotado</option>
            </select>
          </div>

          <div class="input-group">
            <label>Área do Terreno do Condomínio (m²)</label>
            <input type="number" v-model="form.land_area">
          </div>

          <div class="input-group">
            <label>Área Construída do Condomínio (m²)</label>
            <input type="number" v-model="form.built_area">
          </div>

          <div class="input-group">
            <label>Plantão no Local</label>
            <select v-model="form.on_site_sales">
              <option value="Não">Não</option>
              <option value="Sim">Sim</option>
            </select>
          </div>

          <div class="input-group">
            <label>Progresso da Obra</label>
            <select v-model="form.construction_progress">
              <option value="100% concluído">100% concluído</option>
              <option value="Em construção">Em construção</option>
              <option value="Lançamento">Lançamento</option>
              <option value="Não iniciado">Não iniciado</option>
            </select>
          </div>

          <div class="input-group">
            <label>Ano de Construção</label>
            <input type="text" v-model="form.construction_year">
          </div>

          <div class="input-group">
            <label>Construtora</label>
            <input type="text" v-model="form.builder">
          </div>

          <div class="input-group">
            <label>Incorporadora</label>
            <input type="text" v-model="form.developer">
          </div>

          <div class="input-group">
            <label>Administradora</label>
            <input type="text" v-model="form.administrator">
          </div>

          <div class="input-group col-2">
            <label>Arquitetura</label>
            <input type="text" v-model="form.architecture">
          </div>

          <div class="input-group">
            <label>Valor Mínimo</label>
            <input type="number" step="0.01" v-model="form.min_price" placeholder="Ex: 500000.00">
          </div>

          <div class="input-group">
            <label>Valor Máximo</label>
            <input type="number" step="0.01" v-model="form.max_price" placeholder="Ex: 1500000.00">
          </div>
          
          <div class="input-group col-2">
            <label>Tags</label>
            <input type="text" v-model="form.tags" placeholder="Ex: Litoral, Alto padrão...">
          </div>
        </div>
      </div>

      <!-- Unidades -->
      <div class="section-card">
        <h3 class="section-title">Unidades de Condomínio</h3>
        <div class="grid-form">
          <div class="input-group col-2">
            <label>Tipos de Condomínio</label>
            <select v-model="form.condominium_types">
              <option value="">Selecione</option>
              <option value="Horizontal">Horizontal</option>
              <option value="Vertical">Vertical</option>
              <option value="Loteamento">Loteamento</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Endereço -->
      <div class="section-card">
        <h3 class="section-title">Endereço</h3>
        <div class="grid-form">
          <div class="input-group">
            <label>CEP *</label>
            <input type="text" v-model="form.cep" @input="searchCep" maxlength="9" placeholder="00000-000">
          </div>
          <div class="input-group col-2">
            <label>Logradouro *</label>
            <input type="text" v-model="form.street">
          </div>
          <div class="input-group">
            <label>Número *</label>
            <input type="text" v-model="form.number">
          </div>
          <div class="input-group">
            <label>Bairro *</label>
            <input type="text" v-model="form.neighborhood">
          </div>
          <div class="input-group">
            <label>País *</label>
            <input type="text" v-model="form.country">
          </div>
          <div class="input-group">
            <label>Estado *</label>
            <input type="text" v-model="form.state">
          </div>
          <div class="input-group">
            <label>Cidade *</label>
            <input type="text" v-model="form.city">
          </div>
          <div class="input-group col-2">
            <label>Ponto de referência</label>
            <input type="text" v-model="form.reference_point">
          </div>
          <div class="input-group">
            <label>Latitude</label>
            <input type="text" v-model="form.latitude">
          </div>
          <div class="input-group">
            <label>Longitude</label>
            <input type="text" v-model="form.longitude">
          </div>
        </div>
      </div>

      <!-- Facilidades / Checkboxes -->
      <div class="section-card">
        <h3 class="section-title">Segurança</h3>
        <div class="checkbox-grid">
          <label class="checkbox-label" v-for="item in securityOptions" :key="item">
            <input type="checkbox" :value="item" v-model="form.security_features">
            <span>{{ item }}</span>
          </label>
        </div>
      </div>

      <div class="section-card">
        <h3 class="section-title">Serviços</h3>
        <div class="checkbox-grid">
          <label class="checkbox-label" v-for="item in servicesOptions" :key="item">
            <input type="checkbox" :value="item" v-model="form.services">
            <span>{{ item }}</span>
          </label>
        </div>
      </div>

      <div class="section-card">
        <h3 class="section-title">Social</h3>
        <div class="checkbox-grid">
          <label class="checkbox-label" v-for="item in socialOptions" :key="item">
            <input type="checkbox" :value="item" v-model="form.social_features">
            <span>{{ item }}</span>
          </label>
        </div>
      </div>

      <div class="section-card">
        <h3 class="section-title">Comercial / Industrial</h3>
        <div class="checkbox-grid">
          <label class="checkbox-label" v-for="item in commercialOptions" :key="item">
            <input type="checkbox" :value="item" v-model="form.commercial_features">
            <span>{{ item }}</span>
          </label>
        </div>
      </div>

      <div class="section-card">
        <h3 class="section-title">Infraestrutura</h3>
        <div class="checkbox-grid">
          <label class="checkbox-label" v-for="item in infraOptions" :key="item">
            <input type="checkbox" :value="item" v-model="form.infrastructure">
            <span>{{ item }}</span>
          </label>
        </div>
      </div>

      <div class="section-card">
        <h3 class="section-title">Infraestrutura de Loteamento</h3>
        <div class="checkbox-grid">
          <label class="checkbox-label" v-for="item in allotmentOptions" :key="item">
            <input type="checkbox" :value="item" v-model="form.allotment_infrastructure">
            <span>{{ item }}</span>
          </label>
        </div>
      </div>

      <div class="section-card">
        <h3 class="section-title">Área de Lazer do Condomínio</h3>
        <div class="checkbox-grid">
          <label class="checkbox-label" v-for="item in leisureOptions" :key="item">
            <input type="checkbox" :value="item" v-model="form.leisure_features">
            <span>{{ item }}</span>
          </label>
        </div>
      </div>

    </div>

    <!-- Fotos Tab -->
    <div class="form-content" v-if="activeTab === 'fotos'">
      <div class="section-card">
        <h3 class="section-title">Fotos do Condomínio</h3>
        
        <div class="photo-upload-area">
          <input type="file" id="photo-upload" multiple accept="image/*" @change="handleFileChange" class="hidden-input">
          <label for="photo-upload" class="upload-label">
            <ImagePlus class="icon-xl" />
            <span>Clique ou arraste imagens aqui para fazer upload</span>
            <span class="text-sm">Formatos suportados: JPG, PNG, WEBP</span>
          </label>
        </div>

        <div class="photo-grid" v-if="photos.length > 0 || newPhotos.length > 0">
          <!-- Existing Photos -->
          <div class="photo-item" v-for="(photo, index) in photos" :key="'ex-' + photo.id">
            <img :src="photo.url" alt="Foto">
            <button class="btn-remove" @click.prevent="removeExistingPhoto(photo.id, index)">
              <Trash2 class="icon-sm" />
            </button>
          </div>
          
          <!-- New Photos Preview -->
          <div class="photo-item new" v-for="(photo, index) in newPhotos" :key="'new-' + index">
            <img :src="photo.preview" alt="Preview">
            <div class="badge-new">Nova</div>
            <button class="btn-remove" @click.prevent="removeNewPhoto(index)">
              <X class="icon-sm" />
            </button>
          </div>
        </div>
      </div>
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

.page-header {
  margin-bottom: 2rem;

  .btn-back {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    background: transparent;
    border: none;
    color: var(--text-muted);
    cursor: pointer;
    margin-bottom: 1rem;
    font-size: 0.9rem;
    
    &:hover { color: var(--primary); }
  }

  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: center;

    h1 {
      font-size: 1.5rem;
      color: var(--text-main);
    }

    .btn-primary {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      background: var(--primary);
      color: white;
      border: none;
      padding: 0.6rem 1.2rem;
      border-radius: 6px;
      font-weight: 500;
      cursor: pointer;
      
      &:disabled {
        opacity: 0.7;
        cursor: not-allowed;
      }
    }
  }
}

.tabs {
  display: flex;
  gap: 1rem;
  margin-bottom: 2rem;
  border-bottom: 1px solid var(--border-color);

  .tab-btn {
    background: transparent;
    border: none;
    padding: 0.75rem 1.5rem;
    font-weight: 500;
    color: var(--text-muted);
    cursor: pointer;
    border-bottom: 2px solid transparent;
    
    &.active {
      color: #4338ca;
      border-bottom-color: #4338ca;
    }
  }
}

.form-content {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.section-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 2rem;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);

  .section-title {
    color: #4338ca;
    font-size: 1rem;
    margin-bottom: 1.5rem;
    font-weight: 600;
  }
}

.grid-form {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;

  .col-2 {
    grid-column: span 2;
  }
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;

  label {
    font-size: 0.85rem;
    color: var(--text-muted);
  }

  input, select, textarea {
    padding: 0.75rem;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    background: var(--bg-primary);
    color: var(--text-main);
    outline: none;
    
    &:focus { border-color: #4338ca; }
  }
}

/* Checkbox Grids */
.checkbox-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--text-main);
  font-size: 0.9rem;
  cursor: pointer;

  input[type="checkbox"] {
    width: 16px;
    height: 16px;
    cursor: pointer;
  }
}

.text-center { text-align: center; }
.py-5 { padding-top: 3rem; padding-bottom: 3rem; }
.icon-sm { width: 16px; height: 16px; }
.icon-xl { width: 48px; height: 48px; color: #4338ca; margin-bottom: 1rem; }
.text-sm { font-size: 0.8rem; color: var(--text-muted); margin-top: 0.5rem; }

/* Photo Upload */
.hidden-input {
  display: none;
}

.photo-upload-area {
  border: 2px dashed var(--border-color);
  border-radius: 8px;
  padding: 3rem;
  text-align: center;
  background: var(--bg-primary);
  transition: all 0.2s;
  margin-bottom: 2rem;

  &:hover {
    border-color: #4338ca;
    background: rgba(67, 56, 202, 0.02);
  }

  .upload-label {
    display: flex;
    flex-direction: column;
    align-items: center;
    cursor: pointer;
    color: var(--text-main);
    font-weight: 500;
  }
}

.photo-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1.5rem;
}

.photo-item {
  position: relative;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid var(--border-color);
  aspect-ratio: 4/3;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .btn-remove {
    position: absolute;
    top: 8px;
    right: 8px;
    background: rgba(239, 68, 68, 0.9);
    color: white;
    border: none;
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: transform 0.2s;

    &:hover {
      transform: scale(1.1);
    }
  }

  &.new {
    border: 2px solid #10b981;
  }

  .badge-new {
    position: absolute;
    top: 8px;
    left: 8px;
    background: #10b981;
    color: white;
    font-size: 0.7rem;
    padding: 2px 8px;
    border-radius: 12px;
    font-weight: bold;
  }
}

@media (max-width: 768px) {
  .page-container {
    padding: 1rem;
  }

  .grid-form {
    grid-template-columns: 1fr;

    .col-2 {
      grid-column: span 1;
    }
  }

  .checkbox-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
