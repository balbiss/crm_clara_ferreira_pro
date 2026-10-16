# Ação "Criar tarefa" dos gatilhos (PipelineTrigger e ReguaTrigger) — igual ao
# "Adicionar uma tarefa" do Kommo. config:
#   titulo      (obrigatório) texto da tarefa
#   descricao   (opcional)
#   tipo        (opcional) um de Tarefa::MANUAL_TIPOS — padrão manual_acompanhamento
#   prazo_horas (opcional) vence daqui a X horas — padrão 0 (vence agora/hoje)
#   prioridade  (opcional) normal | alta | urgente
#   user_id     (opcional) responsável — padrão: o responsável da revendedora
#
# Existe no máximo UMA tarefa pendente de cada tipo por revendedora (índice
# único do banco): se já há uma pendente do mesmo tipo, não cria outra.
class TriggerTaskCreator
  MAX_PRAZO_HORAS = 24 * 90

  def self.call(contact:, config:)
    config = (config || {}).to_h.stringify_keys
    tipo = Tarefa::MANUAL_TIPOS.include?(config['tipo']) ? config['tipo'] : 'manual_acompanhamento'
    prioridade = Tarefa::PRIORIDADES.include?(config['prioridade']) ? config['prioridade'] : 'normal'
    prazo = config['prazo_horas'].to_i.clamp(0, MAX_PRAZO_HORAS)
    responsavel = config['user_id'].present? ? User.where(id: config['user_id'], account_id: contact.account_id).pick(:id) : nil

    Tarefa.create!(
      account_id: contact.account_id,
      contact_id: contact.id,
      user_id: responsavel || contact.user_id,
      tipo: tipo,
      titulo: config['titulo'].to_s.strip.first(120),
      descricao: config['descricao'].presence,
      prioridade: prioridade,
      vencimento_em: Time.current + prazo.hours
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
