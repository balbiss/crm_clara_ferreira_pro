import { ref, onMounted, onUnmounted } from 'vue'

const deferredPrompt = ref(null)
const isInstalled = ref(false)

const isStandalone = () =>
  window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true

const isIOS = () => /iPhone|iPad|iPod/.test(navigator.userAgent)

export function useInstallPrompt() {
  const canInstall = ref(false)

  const handleBeforeInstallPrompt = (event) => {
    event.preventDefault()
    deferredPrompt.value = event
    canInstall.value = true
  }

  const handleAppInstalled = () => {
    isInstalled.value = true
    canInstall.value = false
    deferredPrompt.value = null
  }

  onMounted(() => {
    isInstalled.value = isStandalone()
    canInstall.value = !!deferredPrompt.value

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.addEventListener('appinstalled', handleAppInstalled)
  })

  onUnmounted(() => {
    window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.removeEventListener('appinstalled', handleAppInstalled)
  })

  const promptInstall = async () => {
    if (!deferredPrompt.value) return
    deferredPrompt.value.prompt()
    await deferredPrompt.value.userChoice
    deferredPrompt.value = null
    canInstall.value = false
  }

  return {
    canInstall,
    isInstalled,
    isIOS: isIOS(),
    isStandalone: isStandalone(),
    promptInstall
  }
}
