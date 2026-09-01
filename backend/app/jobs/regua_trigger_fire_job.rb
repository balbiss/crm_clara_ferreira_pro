# Executa 1 ReguaTrigger com atraso configurado (delay_minutes), agendado por
# ReguaTriggerRunnerService#call. Confere de novo se a revendedora ainda está
# no mesmo status que originou o agendamento antes de rodar — mesma guarda de
# PipelineTriggerFireJob, só que pra Contact#status em vez de PipelineStage.
class ReguaTriggerFireJob < ApplicationJob
  queue_as :default

  def perform(trigger_id, contact_id, chain_depth = 0)
    trigger = ReguaTrigger.find_by(id: trigger_id)
    contact = Contact.find_by(id: contact_id)
    return unless trigger && contact
    return unless contact.status == trigger.status

    ReguaTriggerRunnerService.new(contact).run_single_trigger(trigger, chain_depth: chain_depth)
  end
end
