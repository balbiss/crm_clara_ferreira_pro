# Execução ao vivo de um Fluxo (MVP) — só o suficiente pra testar o gatilho
# de Palavra-chave de ponta a ponta. Percorre nó por nó via FlowEdge, mesmo
# padrão de PipelineTriggerRunnerService (guarda de loop com MAX_STEPS).
#
# Cobertura deliberadamente mínima: "wait" não segura de verdade a resposta
# do webhook (passa direto — dá pra virar job assíncrono depois) e
# "condition" segue sempre pelo caminho "não" (não existe nó de Pergunta
# ainda pra popular a variável). Os outros gatilhos (novo contato, mensagem
# recebida, manual) e os tipos de nó de Ação ainda não são executados — só a
# palavra-chave, que é testável direto por uma mensagem de WhatsApp.
class FlowRunnerService
  MAX_STEPS = 20

  # Acionado pelo webhook (Waha/Baileys) a cada mensagem recebida. Devolve
  # true se algum fluxo ativo do canal bateu com a palavra-chave e foi
  # executado (o chamador deve pular a IA nesse caso).
  def self.trigger_by_keyword(inbox, conversation, contact, text)
    return false if text.blank?

    flow = inbox.account.flows.includes(:flow_nodes).where(active: true).find do |f|
      trigger = f.flow_nodes.find { |n| n.node_type == 'trigger' }
      trigger && trigger.data['trigger_type'] == 'palavra_chave' &&
        trigger.data['keyword'].to_s.strip.present? &&
        text.downcase.include?(trigger.data['keyword'].to_s.strip.downcase)
    end
    return false unless flow

    trigger_node = flow.flow_nodes.find { |n| n.node_type == 'trigger' }
    new(flow, conversation, contact).call(trigger_node.key)
    true
  rescue StandardError => e
    Rails.logger.error("FlowRunnerService (palavra-chave) falhou: #{e.message}")
    false
  end

  def initialize(flow, conversation, contact)
    @flow = flow
    @conversation = conversation
    @contact = contact
  end

  def call(from_key, handle: nil, steps: 0)
    return if steps >= MAX_STEPS

    edge = @flow.flow_edges.find_by(source_key: from_key, source_handle: handle)
    return unless edge

    node = @flow.flow_nodes.find_by(key: edge.target_key)
    return unless node

    case node.node_type
    when 'send_message'
      send_message(node)
      call(node.key, steps: steps + 1)
    when 'wait'
      call(node.key, steps: steps + 1)
    when 'condition'
      call(node.key, handle: 'nao', steps: steps + 1)
    when 'end'
      nil
    end
  end

  private

  def send_message(node)
    text = interpolate(node.data['message'].to_s)
    return if text.blank?

    recipient = @contact.channel_identifier
    external_id = @conversation.inbox.messaging_service.send_message(recipient, text)

    msg = Message.create!(
      account_id: @conversation.account_id,
      conversation: @conversation,
      text: text,
      sender_type: 'User',
      sender_id: nil,
      source_id: external_id.presence || "flow_#{@flow.id}_#{SecureRandom.hex(8)}",
      status: :sent
    )
    msg.rebroadcast
  end

  def interpolate(text)
    text.to_s
      .gsub('{{nome}}', @contact.name.to_s)
      .gsub('{{telefone}}', @contact.phone.to_s)
      .gsub('{{email}}', @contact.email.to_s)
  end
end
