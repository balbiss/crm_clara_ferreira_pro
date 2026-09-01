# Executa 1 PipelineTrigger com atraso configurado (delay_minutes), agendado
# por PipelineTriggerRunnerService#call. Confere de novo se o card ainda está
# na mesma etapa que originou o agendamento antes de rodar — se o lead já
# saiu dali nesse meio tempo, a ação não deve acontecer (mesmo comportamento
# do "Automatize" do Kommo, PDF Etapa 2 página 11).
class PipelineTriggerFireJob < ApplicationJob
  queue_as :default

  def perform(trigger_id, card_id, chain_depth = 0)
    trigger = PipelineTrigger.find_by(id: trigger_id)
    card = PipelineCard.find_by(id: card_id)
    return unless trigger && card
    return unless card.pipeline_stage_id == trigger.pipeline_stage_id

    PipelineTriggerRunnerService.new(card).run_single_trigger(trigger, chain_depth: chain_depth)
  end
end
