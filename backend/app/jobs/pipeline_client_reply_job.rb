# Roda os gatilhos "quando o cliente responder" (PipelineTrigger event
# 'client_reply') de todas as etapas em que o contato está. Enfileirado por
# Message quando chega mensagem do cliente — em job pra nunca atrasar nem
# derrubar o recebimento da mensagem.
class PipelineClientReplyJob < ApplicationJob
  queue_as :default

  def perform(contact_id)
    PipelineCard.where(contact_id: contact_id).includes(:pipeline_stage).find_each do |card|
      PipelineTriggerRunnerService.new(card).call_for_client_reply
    rescue StandardError => e
      Rails.logger.error("PipelineClientReplyJob: card #{card.id} falhou: #{e.class} #{e.message}")
    end
  end
end
