# Retoma a execução de um Fluxo depois de um nó "Aguardar" — enfileirado por
# FlowRunnerService com `.set(wait: ...)`, mesmo padrão já usado em
# ReguaAutoAdvanceJob/SendScheduledMessageJob nesse projeto. Sem isso o
# "Aguardar" não segurava de verdade a execução (confirmado num teste real:
# a mensagem de depois do Aguardar chegava junto com a de antes).
class FlowContinueJob < ApplicationJob
  queue_as :default

  def perform(flow_id, conversation_id, contact_id, from_key)
    flow = Flow.find_by(id: flow_id)
    conversation = Conversation.find_by(id: conversation_id)
    contact = Contact.find_by(id: contact_id)
    return unless flow && conversation && contact

    FlowRunnerService.new(flow, conversation, contact).call(from_key)
  end
end
