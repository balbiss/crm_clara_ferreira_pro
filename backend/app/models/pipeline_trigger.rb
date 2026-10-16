# Gatilho de automação preso a uma etapa de pipeline (espelha o "Digital Pipeline" do
# Kommo — botão "Automatize"). Dispara quando um card entra na etapa (event 'enter')
# ou quando o cliente responde estando na etapa (event 'client_reply'):
# PipelineTriggerRunnerService é quem executa de verdade, esse model só guarda a
# configuração.
class PipelineTrigger < ApplicationRecord
  belongs_to :pipeline_stage

  # 'enter' = o lead entra na etapa (único modo até 2026-10-16); 'client_reply' =
  # o cliente manda mensagem enquanto o lead está na etapa (roda 1 vez por
  # permanência na etapa — ver PipelineCard#reply_triggered_at).
  EVENTS = %w[enter client_reply].freeze

  # Só ações que dá pra executar de verdade com a infra que já existe no CRM. Ficaram de
  # fora de propósito integrações de anúncio (Meta/TikTok/Google Ads) que o Kommo tem —
  # a empresa não tem conta de anúncios ligada aqui, seria automação decorativa/fake.
  ACTION_TYPES = %w[
    move_stage
    change_owner
    create_note
    create_task
    ai_start
    ai_stop
    send_webhook
    start_flow
  ].freeze

  ACTION_LABELS = {
    'move_stage'    => 'Mudar etapa do lead',
    'change_owner'  => 'Alterar responsável',
    'create_note'   => 'Adicionar nota',
    'create_task'   => 'Criar tarefa',
    'ai_start'      => 'Ligar agente de IA',
    'ai_stop'       => 'Pausar agente de IA',
    'send_webhook'  => 'Enviar webhook',
    'start_flow'    => 'Iniciar fluxo'
  }.freeze

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validates :event, inclusion: { in: EVENTS }
  validates :delay_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
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
    when 'create_task'
      errors.add(:config, 'precisa de um título pra tarefa') if config['titulo'].blank?
    when 'send_webhook'
      errors.add(:config, 'precisa de uma URL') if config['url'].blank?
    when 'start_flow'
      errors.add(:config, 'precisa de um fluxo escolhido') if config['flow_id'].blank?
    end
  end
end
