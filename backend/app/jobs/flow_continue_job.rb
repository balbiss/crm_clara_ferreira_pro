# Retoma a execução de um Fluxo depois de um nó "Aguardar" — enfileirado por
# FlowRunnerService com `.set(wait: ...)`, mesmo padrão já usado em
# ReguaAutoAdvanceJob/SendScheduledMessageJob nesse projeto. Sem isso o
# "Aguardar" não segurava de verdade a execução (confirmado num teste real:
# a mensagem de depois do Aguardar chegava junto com a de antes).
class FlowContinueJob < ApplicationJob
  queue_as :default

  def perform(flow_run_id, from_key)
    flow_run = FlowRun.find_by(id: flow_run_id)
    return unless flow_run && flow_run.status != 'completed'

    FlowRunnerService.new(flow_run).call(from_key)
  end
end
