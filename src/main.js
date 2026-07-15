import { createApp } from 'vue'
import { createPinia } from 'pinia'
import './style.scss'
import App from './App.vue'
import router from './router'

const app = createApp(App)
const pinia = createPinia()

// Diretiva global para fechar dropdowns ao clicar fora
app.directive('click-outside', {
  beforeMount(el, binding) {
    el._clickOutsideHandler = (event) => {
      if (!el.contains(event.target)) binding.value(event)
    }
    document.addEventListener('mousedown', el._clickOutsideHandler)
  },
  unmounted(el) {
    document.removeEventListener('mousedown', el._clickOutsideHandler)
  }
})

app.use(pinia)
app.use(router)

app.mount('#app')

// Garante que, assim que um Service Worker novo assumir o controle
// (nova versao do app publicada), a pagina recarregue uma vez para
// buscar o JS/CSS mais recente - sem isso o app instalado (PWA) podia
// ficar rodando uma versao antiga por muito tempo sem o usuario perceber.
if ('serviceWorker' in navigator) {
  let reloading = false
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (reloading) return
    reloading = true
    window.location.reload()
  })
}
