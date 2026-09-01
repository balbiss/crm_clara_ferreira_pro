# Agendamento em config/recurring.yml (Solid Queue) — não se auto-reagenda mais
# (ver JueriSyncJob pro histórico do incidente de duplicação em cada boot).
class CheckSnoozedConversationsJob < ApplicationJob
  queue_as :default

  def perform
    Conversation.where(status: :snoozed).where('snoozed_until <= ?', Time.current).find_each do |conv|
      conv.update!(status: :open, snoozed_until: nil)

      ActionCable.server.broadcast("conversations_channel_#{conv.account_id}", {
        event: 'snooze_expired',
        conversation_id: conv.id,
        contact_name: conv.contact&.name.presence || conv.contact&.phone || 'Lead'
      })

      ActionCable.server.broadcast("conversations_channel_#{conv.account_id}", {
        event: 'conversation_updated',
        conversation: { id: conv.id, status: 'open', snoozed_until: nil }
      })
    end
  end
end
