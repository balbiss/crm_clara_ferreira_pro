# Gatilho de automação preso a uma etapa de pipeline (espelha o "Digital Pipeline" do
# Kommo — botão "Automatize"). Dispara quando um card entra na etapa: PipelineTriggerRunnerService
# é quem executa de verdade, esse model só guarda a configuração.
class PipelineTrigger < ApplicationRecord
  belongs_to :pipeline_stage

  # Só ações que dá pra executar de verdade com a infra que já existe no CRM. Ficaram de
  # fora de propósito integrações de anúncio (Meta/TikTok/Google Ads) que o Kommo tem —
  # a empresa não tem conta de anúncios ligada aqui, seria automação decorativa/fake.
  ACTION_TYPES = %w[
    move_stage
    change_owner
    create_note
    ai_start
    ai_stop
    send_webhook
  ].freeze

  ACTION_LABELS = {
    'move_stage'    => 'Mudar etapa do lead',
    'change_owner'  => 'Alterar responsável',
    'create_note'   => 'Adicionar nota',
    'ai_start'      => 'Ligar agente de IA',
    'ai_stop'       => 'Pausar agente de IA',
    'send_webhook'  => 'Enviar webhook'
  }.freeze

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validate :config_has_required_fields

  def label
    ACTION_LABELS[action_type] || action_type
  end

  private

  def config_has_required_fields
    case action_type
    when 'move_stage'
      errors.add(:config, 'precisa de uma etapa de destino') if config['target_stage_id'].blank?
    when 'change_owner'
      errors.add(:config, 'precisa de um responsável') if config['user_id'].blank?
    when 'create_note'
      errors.add(:config, 'precisa de um texto de nota') if config['content'].blank?
    when 'send_webhook'
      errors.add(:config, 'precisa de uma URL') if config['url'].blank?
    end
  end
end
