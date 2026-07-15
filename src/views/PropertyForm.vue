<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Eye, Info, ImagePlus } from '@lucide/vue'
import Swal from 'sweetalert2'
import api from '../api'

const router = useRouter()
const route = useRoute()
const isEditMode = computed(() => !!route.params.id)

const form = ref({
  owner_name: '', owner_email: '', owner_phone: '', owner_phone_type: 'Celular',
  usage_type: 'Residencial', property_type: 'Casa', condo_name: '',
  cep: '', street: '', number: '', neighborhood: '', city: '', state: '', country: 'Brasil',
  complement: '', reference_point: '', latitude: '', longitude: '', show_address_mode: 'Completo',
  listing_type: [], description: '',
  iptu_condition: 'Isento', iptu_value: '',
  auth_start_date: '', auth_end_date: '', exclusivity: false,
  built_area: '', total_area: '', suites: '', bedrooms: '', bathrooms: '', parking_spots: '',
  price: '', title: '', status: 'Disponível'
})

const isSubmitting = ref(false)
const photos = ref([])
const existingPhotos = ref([])
const deletedPhotoIds = ref([])

const searchCep = async () => {
  const cep = form.value.cep.replace(/\D/g, '')
  if (cep.length === 8) {
    try {
      const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`)
      const data = await response.json()
      if (!data.erro) {
        form.value.street = data.logradouro
        form.value.neighborhood = data.bairro
        form.value.city = data.localidade
        form.value.state = data.uf
      }
    } catch (error) {
      console.error('Erro ao buscar CEP', error)
    }
  }
}

const handlePhotoUpload = (e) => {
  const files = Array.from(e.target.files)
  photos.value.push(...files)
}

const removeExistingPhoto = (id) => {
  deletedPhotoIds.value.push(id)
  existingPhotos.value = existingPhotos.value.filter(p => p.id !== id)
}

const adQuality = computed(() => {
  let score = 0
  if (form.value.owner_name) score += 5
  if (form.value.owner_phone) score += 5
  if (form.value.cep) score += 10
  if (form.value.street) score += 10
  if (form.value.description.length > 50) score += 20
  if (photos.value.length > 0) score += 20
  if (photos.value.length > 3) score += 10
  if (form.value.price) score += 10
  if (form.value.title) score += 10
  return Math.min(score, 100)
})

const qualityLabel = computed(() => {
  if (adQuality.value < 30) return 'Baixo'
  if (adQuality.value < 60) return 'Normal'
  if (adQuality.value < 80) return 'Bom'
  return 'Ótimo'
})

const loadProperty = async () => {
  if (!isEditMode.value) return
  
  try {
    const response = await api.get(`/properties/${route.params.id}`)
    const property = response.data
    
    Object.keys(form.value).forEach(key => {
      if (property[key] !== undefined && property[key] !== null) {
        form.value[key] = property[key]
      }
    })
    
    // Listing type handling
    if (property.listing_type) {
      form.value.listing_type = property.listing_type.split(',')
    }
    
    // Existing photos
    if (property.photo_data) {
      existingPhotos.value = property.photo_data
    }
    
    // Format price back to string for input
    if (property.price) {
      form.value.price = Number(property.price).toLocaleString('pt-BR', {minimumFractionDigits: 2})
    }
  } catch (error) {
    console.error('Erro ao carregar imóvel', error)
    Swal.fire('Erro', 'Não foi possível carregar os dados do imóvel.', 'error')
  }
}

onMounted(() => {
  loadProperty()
})

const submitForm = async () => {
  if (isSubmitting.value) return
  isSubmitting.value = true
  
  try {
    const formData = new FormData()
    
    // Convert array to string for listing_type if needed
    const dataToSubmit = { ...form.value }
    dataToSubmit.listing_type = dataToSubmit.listing_type.join(',')
    
    // Parse price string (e.g. "500.000,00" to "500000.00")
    if (dataToSubmit.price) {
      let rawPrice = String(dataToSubmit.price).replace(/[R$\s.]/g, '').replace(',', '.')
      dataToSubmit.price = rawPrice
    }
    
    Object.keys(dataToSubmit).forEach(key => {
      formData.append(`property[${key}]`, dataToSubmit[key])
    })
    
    photos.value.forEach(photo => {
      formData.append('photos[]', photo)
    })
    
    deletedPhotoIds.value.forEach(id => {
      formData.append('deleted_photo_ids[]', id)
    })

    if (isEditMode.value) {
      await api.put(`/properties/${route.params.id}`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })
    } else {
      await api.post('/properties', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })
    }

    Swal.fire({
      icon: 'success',
      title: 'Sucesso',
      text: isEditMode.value ? 'Imóvel atualizado!' : 'Imóvel cadastrado com sucesso!',
      confirmButtonColor: '#1f93ff'
    }).then(() => {
      router.push('/imoveis')
    })
  } catch (error) {
    console.error(error)
    Swal.fire({
      icon: 'error',
      title: 'Erro',
      text: 'Não foi possível cadastrar o imóvel.'
    })
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h1>{{ isEditMode ? 'Editar Imóvel' : 'Cadastrar um imóvel' }}</h1>
    </div>

    <div class="form-layout">
      <div class="form-content">
        <form @submit.prevent="submitForm" class="property-form">
          <!-- Título e Preço -->
          <section class="form-section">
            <h3 class="section-title">Informações Principais</h3>
            <div class="form-grid">
              <div class="input-group full-width">
                <label>Título do Anúncio *</label>
                <input type="text" v-model="form.title" placeholder="Ex: Lindo apartamento com varanda gourmet" required>
              </div>
              <div class="input-group">
                <label>Preço de Venda/Locação *</label>
                <input type="text" v-model="form.price" placeholder="R$ 0,00" required>
              </div>
              <div class="input-group">
                <label>Status de Disponibilidade *</label>
                <select v-model="form.status" required>
                  <option value="Disponível">Disponível</option>
                  <option value="Vendido">Vendido</option>
                  <option value="Alugado">Alugado</option>
                  <option value="Suspenso">Suspenso</option>
                  <option value="Em Análise">Em Análise</option>
                </select>
              </div>
            </div>
          </section>

          <!-- Dados do Proprietário -->
          <section class="form-section">
            <h3 class="section-title">Dados do Proprietário</h3>
            <div class="form-grid">
              <div class="input-group">
                <label>Nome do Proprietário</label>
                <input type="text" v-model="form.owner_name">
              </div>
              <div class="input-group">
                <label>E-mail</label>
                <input type="email" v-model="form.owner_email">
              </div>
              <div class="input-group">
                <label>Telefone</label>
                <input type="tel" v-model="form.owner_phone" placeholder="+55">
              </div>
              <div class="input-group">
                <label>Tipo</label>
                <select v-model="form.owner_phone_type">
                  <option value="Celular">Celular</option>
                  <option value="Fixo">Fixo</option>
                  <option value="WhatsApp">WhatsApp</option>
                </select>
              </div>
            </div>
          </section>

          <!-- Estrutura -->
          <section class="form-section">
            <h3 class="section-title">Estrutura</h3>
            <div class="usage-types">
              <label class="radio-btn" :class="{active: form.usage_type === 'Residencial'}">
                <input type="radio" v-model="form.usage_type" value="Residencial"> Residencial
              </label>
              <label class="radio-btn" :class="{active: form.usage_type === 'Comercial'}">
                <input type="radio" v-model="form.usage_type" value="Comercial"> Comercial
              </label>
              <label class="radio-btn" :class="{active: form.usage_type === 'Industrial'}">
                <input type="radio" v-model="form.usage_type" value="Industrial"> Industrial
              </label>
              <label class="radio-btn" :class="{active: form.usage_type === 'Rural'}">
                <input type="radio" v-model="form.usage_type" value="Rural"> Rural
              </label>
            </div>
            <div class="form-grid">
              <div class="input-group">
                <label>Tipo *</label>
                <select v-model="form.property_type" required>
                  <option value="Casa">Casa</option>
                  <option value="Apartamento">Apartamento</option>
                  <option value="Terreno">Terreno</option>
                  <option value="Sala Comercial">Sala Comercial</option>
                </select>
              </div>
              <div class="input-group">
                <label>Condomínio / Empreendimento</label>
                <input type="text" v-model="form.condo_name">
              </div>
            </div>
          </section>

          <!-- Detalhes do Imóvel -->
          <section class="form-section">
            <h3 class="section-title">Detalhes do Imóvel</h3>
            <div class="form-grid">
              <div class="input-group">
                <label>Área Construída (m²)</label>
                <input type="number" v-model="form.built_area">
              </div>
              <div class="input-group">
                <label>Área do Terreno (m²)</label>
                <input type="number" v-model="form.total_area">
              </div>
              <div class="input-group">
                <label>Quartos</label>
                <input type="number" v-model="form.bedrooms">
              </div>
              <div class="input-group">
                <label>Suítes</label>
                <input type="number" v-model="form.suites">
              </div>
              <div class="input-group">
                <label>Banheiros</label>
                <input type="number" v-model="form.bathrooms">
              </div>
              <div class="input-group">
                <label>Vagas de Garagem</label>
                <input type="number" v-model="form.parking_spots">
              </div>
            </div>
          </section>

          <!-- Localização -->
          <section class="form-section">
            <h3 class="section-title">Localização do Imóvel</h3>
            <div class="tabs">
              <button type="button" class="tab active">Endereço</button>
              <button type="button" class="tab">Endereço alternativo</button>
            </div>
            <div class="form-grid">
              <div class="input-group">
                <label>CEP *</label>
                <input type="text" v-model="form.cep" @input="searchCep" @blur="searchCep" required placeholder="Apenas números">
              </div>
              <div class="input-group">
                <label>Logradouro</label>
                <input type="text" v-model="form.street">
              </div>
              <div class="input-group">
                <label>Número</label>
                <input type="text" v-model="form.number">
              </div>
              <div class="input-group">
                <label>Bairro</label>
                <input type="text" v-model="form.neighborhood">
              </div>
              <div class="input-group">
                <label>País *</label>
                <select v-model="form.country"><option>Brasil</option></select>
              </div>
              <div class="input-group">
                <label>Estado *</label>
                <input type="text" v-model="form.state">
              </div>
              <div class="input-group">
                <label>Cidade *</label>
                <input type="text" v-model="form.city">
              </div>
              <div class="input-group full-width">
                <label>Complemento</label>
                <input type="text" v-model="form.complement">
              </div>
            </div>
            <div class="address-display-options mt-3">
              <label>Mostrar endereço *</label>
              <div class="radio-group">
                <label><input type="radio" v-model="form.show_address_mode" value="Completo"> Completo</label>
                <label><input type="radio" v-model="form.show_address_mode" value="Somente rua"> Somente rua</label>
                <label><input type="radio" v-model="form.show_address_mode" value="Somente bairro"> Somente bairro</label>
              </div>
            </div>
          </section>

          <!-- Fotos -->
          <section class="form-section">
            <h3 class="section-title">Fotos do Imóvel</h3>
            
            <div class="existing-photos-gallery" v-if="existingPhotos.length > 0">
              <div v-for="photo in existingPhotos" :key="photo.id" class="photo-thumbnail">
                <img :src="photo.url" alt="Foto atual">
                <button type="button" class="btn-remove-photo" @click="removeExistingPhoto(photo.id)" title="Remover Foto">×</button>
              </div>
            </div>

            <div class="photo-upload-area" :class="{'mt-3': existingPhotos.length > 0}">
              <input type="file" multiple accept="image/*" @change="handlePhotoUpload" class="hidden-input" id="photoUpload">
              <label for="photoUpload" class="upload-box">
                <ImagePlus class="icon-lg" />
                <p>Clique para adicionar imagens do imóvel</p>
                <span>(formatos aceitos: .jpeg, .png, .webp)</span>
              </label>
              <div class="photos-preview" v-if="photos.length > 0">
                <p>{{ photos.length }} arquivo(s) selecionado(s)</p>
              </div>
            </div>
          </section>

          <!-- Pretensão e Descrição -->
          <section class="form-section">
            <h3 class="section-title">Pretensão (Obrigatório no mínimo um tipo)</h3>
            <div class="checkbox-group mb-3">
              <label><input type="checkbox" v-model="form.listing_type" value="Venda"> Venda</label>
              <label><input type="checkbox" v-model="form.listing_type" value="Locação"> Locação</label>
            </div>

            <h3 class="section-title">Descrição do anúncio *</h3>
            <div class="editor-container">
              <div class="editor-toolbar">
                <button type="button">B</button>
                <button type="button">I</button>
                <button type="button">•</button>
              </div>
              <textarea v-model="form.description" rows="6" required></textarea>
            </div>
          </section>

          <div class="form-actions">
            <button type="button" class="btn-cancel" @click="router.push('/imoveis')" :disabled="isSubmitting">Cancelar</button>
            <button type="submit" class="btn-submit" :disabled="isSubmitting">{{ isSubmitting ? 'Salvando...' : 'Salvar Imóvel' }}</button>
          </div>
        </form>
      </div>

      <!-- Right Sidebar -->
      <div class="form-sidebar">
        <div class="preview-card">
          <h4>Pré-visualização do anúncio do imóvel</h4>
          <button class="preview-btn"><Eye class="icon-sm" /></button>
          
          <div class="ad-quality mt-4">
            <div class="quality-header">
              <span>Qualidade do anúncio</span>
              <span>{{ adQuality }}/100</span>
            </div>
            <div class="progress-bar">
              <div class="progress" :style="{width: adQuality + '%'}"></div>
              <div class="markers">
                <span>Baixo</span>
                <span>Normal</span>
                <span>Bom</span>
                <span>Ótimo</span>
              </div>
            </div>
            <div class="quality-footer mt-2">
              <a href="#"><Info class="icon-xs" /> Como aumentar o nível do anúncio.</a>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 2rem;
  background: var(--bg-primary);
  overflow-y: auto;
}

.page-header h1 {
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--text-main);
  margin-bottom: 1.5rem;
}

.form-layout {
  display: grid;
  grid-template-columns: 1fr 320px;
  gap: 2rem;
  align-items: start;
}

.form-section {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1.5rem;
  margin-bottom: 1.5rem;
}

.section-title {
  font-size: 1rem;
  color: #4338ca; // Roxo igual ao da foto
  font-weight: 600;
  margin-bottom: 1rem;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;

  &.full-width {
    grid-column: 1 / -1;
  }

  label {
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text-main);
  }

  input, select {
    padding: 0.65rem;
    border: 1px solid var(--border-color);
    background: var(--bg-primary);
    border-radius: 6px;
    color: var(--text-main);
    font-size: 0.9rem;
    outline: none;
    &:focus { border-color: var(--primary); }
  }
}

.usage-types {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;

  .radio-btn {
    display: flex;
    align-items: center;
    padding: 0.5rem 1rem;
    border: 1px solid var(--border-color);
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.9rem;
    background: var(--bg-primary);
    
    input { display: none; }
    
    &.active {
      background: #4338ca;
      color: white;
      border-color: #4338ca;
    }
  }
}

.tabs {
  display: flex;
  gap: 1rem;
  border-bottom: 1px solid var(--border-color);
  margin-bottom: 1rem;
  
  .tab {
    background: none;
    border: none;
    padding: 0.5rem 1rem;
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

.photo-upload-area {
  .hidden-input { display: none; }
  
  .upload-box {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem 2rem;
    border: 2px dashed var(--border-color);
    border-radius: 8px;
    cursor: pointer;
    color: var(--text-muted);
    background: var(--bg-primary);
    
    &:hover { border-color: var(--primary); color: var(--primary); }
    
    .icon-lg { width: 48px; height: 48px; margin-bottom: 1rem; }
    p { font-size: 1rem; margin-bottom: 0.25rem; color: var(--text-main); }
    span { font-size: 0.8rem; }
  }
}

.existing-photos-gallery {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  
  .photo-thumbnail {
    position: relative;
    width: 120px;
    height: 120px;
    border-radius: 6px;
    overflow: hidden;
    border: 1px solid var(--border-color);
    
    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    
    .btn-remove-photo {
      position: absolute;
      top: 4px;
      right: 4px;
      width: 24px;
      height: 24px;
      background: #ef4444;
      color: white;
      border: none;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      font-weight: bold;
      font-size: 14px;
    }
  }
}

.editor-container {
  border: 1px solid var(--border-color);
  border-radius: 6px;
  overflow: hidden;
  
  .editor-toolbar {
    background: var(--bg-tertiary);
    padding: 0.5rem;
    display: flex;
    gap: 0.5rem;
    border-bottom: 1px solid var(--border-color);
    
    button {
      background: none;
      border: none;
      padding: 0.25rem 0.5rem;
      cursor: pointer;
      font-weight: bold;
      color: var(--text-main);
      &:hover { background: var(--bg-hover); border-radius: 4px; }
    }
  }
  
  textarea {
    width: 100%;
    border: none;
    padding: 1rem;
    resize: vertical;
    background: var(--bg-primary);
    color: var(--text-main);
    outline: none;
  }
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 2rem;
  
  button {
    padding: 0.75rem 1.5rem;
    border-radius: 6px;
    font-weight: 500;
    cursor: pointer;
  }
  
  .btn-cancel {
    background: transparent;
    border: 1px solid var(--border-color);
    color: var(--text-main);
  }
  
  .btn-submit {
    background: var(--primary);
    color: white;
    border: none;
  }
}

/* Sidebar */
.preview-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1.5rem;
  position: sticky;
  top: 2rem;
  
  h4 { font-size: 1rem; margin-bottom: 1rem; color: var(--text-main); }
  
  .preview-btn {
    padding: 0.5rem 1rem;
    border: 1px solid var(--border-color);
    background: var(--bg-primary);
    border-radius: 6px;
    cursor: pointer;
    color: #4338ca;
  }
  
  .quality-header {
    display: flex;
    justify-content: space-between;
    font-size: 0.9rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
  }
  
  .progress-bar {
    height: 12px;
    background: var(--bg-tertiary);
    border-radius: 6px;
    position: relative;
    margin-bottom: 1.5rem;
    
    .progress {
      height: 100%;
      background: #4338ca;
      border-radius: 6px;
      transition: width 0.3s;
    }
    
    .markers {
      position: absolute;
      top: 100%;
      left: 0;
      width: 100%;
      display: flex;
      justify-content: space-between;
      font-size: 0.7rem;
      color: var(--text-muted);
      margin-top: 0.2rem;
    }
  }
  
  .quality-footer a {
    font-size: 0.8rem;
    color: var(--text-muted);
    text-decoration: none;
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }
}

@media (max-width: 768px) {
  .page-container {
    padding: 1rem;
  }

  .form-layout {
    grid-template-columns: 1fr;
  }

  .form-grid {
    grid-template-columns: 1fr;

    .full-width {
      grid-column: 1;
    }
  }

  .form-section {
    padding: 1rem;
  }
}
</style>
