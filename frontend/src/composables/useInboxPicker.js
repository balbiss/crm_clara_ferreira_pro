import Swal from 'sweetalert2'
import { useInboxesStore } from '../store/inboxes'

const ULTIMA_CAIXA_KEY = 'ultima_caixa_envio'

// Com 2+ caixas de WhatsApp conectadas, sem perguntar o backend sempre
// mandava pela mais antiga da conta, sem nenhum critério de negócio — dono
// achou confuso quando a conta ganhou uma 2ª linha ("Comercial-
// Consultores", 2026-09-25). Usado em todo botão "iniciar conversa"
// (ContactDetails/RevendedorasAtivas/TarefasView/AtacadoView).
//
// 2026-10-16 (Clara): estando DENTRO de uma caixa no menu, não pergunta —
// usa essa caixa (`preferredInboxId`). Quando precisa perguntar, já vem
// marcada a última caixa escolhida, é só confirmar.
export async function pickWhatsappInbox({ preferredInboxId = null } = {}) {
  const inboxesStore = useInboxesStore()
  if (!inboxesStore.isLoadedOnce) await inboxesStore.fetchInboxes()

  const whatsappInboxes = inboxesStore.inboxes.filter(i => ['baileys', 'waha'].includes(i.provider))

  if (preferredInboxId && whatsappInboxes.some(i => String(i.id) === String(preferredInboxId))) {
    return { inboxId: preferredInboxId, cancelled: false }
  }

  if (whatsappInboxes.length <= 1) {
    return { inboxId: null, cancelled: false }
  }

  let ultima = null
  try { ultima = localStorage.getItem(ULTIMA_CAIXA_KEY) } catch { /* sem storage */ }
  if (!whatsappInboxes.some(i => String(i.id) === String(ultima))) ultima = null

  const inputOptions = Object.fromEntries(whatsappInboxes.map(i => [i.id, `${i.name} (${i.phone_number || 'sem número'})`]))
  const { value: chosenId, isConfirmed } = await Swal.fire({
    title: 'Enviar por qual caixa?',
    input: 'select',
    inputOptions,
    inputValue: ultima || '',
    inputPlaceholder: 'Escolha a caixa de WhatsApp',
    showCancelButton: true,
    confirmButtonText: 'Iniciar conversa',
    cancelButtonText: 'Cancelar',
    confirmButtonColor: '#ff007f',
    inputValidator: (value) => (value ? undefined : 'Escolha uma caixa')
  })

  if (isConfirmed && chosenId) {
    try { localStorage.setItem(ULTIMA_CAIXA_KEY, String(chosenId)) } catch { /* sem storage */ }
  }
  return { inboxId: isConfirmed ? chosenId : null, cancelled: !isConfirmed }
}
