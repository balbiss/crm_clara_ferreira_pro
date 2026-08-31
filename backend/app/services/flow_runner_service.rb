# Execução ao vivo de um Fluxo (MVP) — só o suficiente pra testar o gatilho
# de Palavra-chave de ponta a ponta. Percorre nó por nó via FlowEdge, mesmo
# padrão de PipelineTriggerRunnerService (guarda de loop com MAX_STEPS).
#
# "wait" segura de verdade (enfileira FlowContinueJob com `.set(wait: ...)`
# e para a execução síncrona ali — confirmado num teste real que sem isso a
# mensagem de depois do Aguardar chegava junto com a de antes, instantâneo).
# "condition" segue sempre pelo caminho "não" (não existe nó de Pergunta
# ainda pra popular a variável de verdade). Os outros gatilhos (novo
# contato, mensagem recebida, manual) e os tipos de nó de Pergunta/Mídia/
# Opções/Ação ainda não são executados — só a palavra-chave, que é testável
# direto por uma mensagem de WhatsApp.
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
      seconds = wait_seconds(node.data)
      if seconds.positive?
        FlowContinueJob.set(wait: seconds.seconds).perform_later(@flow.id, @conversation.id, @contact.id, node.key)
      else
        call(node.key, steps: steps + 1)
      end
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

    # Corrida confirmada ao vivo em teste real: o eco da própria mensagem
    # (fromMe: true) às vezes chega no webhook ANTES da gente terminar de
    # gravar o Message com o source_id certo — o webhook então não acha
    # nada com esse source_id e trata como intervenção humana, duplicando.
    # Mesma guarda de cache que a IA já usa (ai_is_replying_#{inbox}_#{chat}),
    # só que ela só era checada quando inbox.ai_enabled — Fluxo roda mesmo
    # com IA desligada, então também precisa dessa guarda.
    Rails.cache.write("ai_is_replying_#{@conversation.inbox_id}_#{recipient}", true, expires_in: 20.seconds)

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

  def wait_seconds(data)
    duration = data['duration'].to_i
    return 0 if duration <= 0

    multiplier = { 'segundos' => 1, 'minutos' => 60, 'horas' => 3600, 'dias' => 86_400 }[data['unit']] || 1
    duration * multiplier
  end
end
