# Gatilho de automação preso a um status da régua consignada (equivalente do
# PipelineTrigger, só que pra Contact#status em vez de PipelineStage — o Consignado usa
# um sistema de dados separado, não os pipelines genéricos). Dispara quando a
# revendedora entra nesse status: ReguaTriggerRunnerService é quem executa de verdade.
class ReguaTrigger < ApplicationRecord
  belongs_to :account

  ACTION_TYPES = %w[
    change_status
    change_owner
    create_note
    ai_start
    ai_stop
    send_webhook
    start_flow
  ].freeze

  ACTION_LABELS = {
    'change_status' => 'Mudar status da revendedora',
    'change_owner'  => 'Alterar responsável',
    'create_note'   => 'Adicionar nota',
    'ai_start'      => 'Ligar agente de IA',
    'ai_stop'       => 'Pausar agente de IA',
    'send_webhook'  => 'Enviar webhook',
    'start_flow'    => 'Iniciar fluxo'
  }.freeze

  validates :status, presence: true
  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validates :delay_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :config_has_required_fields

  def label
    ACTION_LABELS[action_type] || action_type
  end

  private

  def config_has_required_fields
    case action_type
    when 'change_status'
      errors.add(:config, 'precisa de um status de destino') if config['target_status'].blank?
    when 'change_owner'
      errors.add(:config, 'precisa de um responsável') if config['user_id'].blank?
    when 'create_note'
      errors.add(:config, 'precisa de um texto de nota') if config['content'].blank?
    when 'send_webhook'
      errors.add(:config, 'precisa de uma URL') if config['url'].blank?
    when 'start_flow'
      errors.add(:config, 'precisa de um fluxo escolhido') if config['flow_id'].blank?
    end
  end
end
