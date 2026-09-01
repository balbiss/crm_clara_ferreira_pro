# Execução ao vivo de um Fluxo — percorre nó por nó via FlowEdge, mesmo
# padrão de PipelineTriggerRunnerService (guarda de loop com MAX_STEPS).
# Estado da execução (variáveis capturadas, em que nó parou) mora num
# FlowRun, um por vez por conversa em andamento.
#
# Cobertura:
# - Gatilho: só Palavra-chave dispara (trigger_by_keyword) — os outros
#   (novo contato, mensagem recebida, evento, webhook, manual) ainda não.
# - "send_message"/"send_media": manda de verdade.
# - "ask_question": manda a pergunta e PARA — vira FlowRun#status
#   "waiting_reply", a próxima mensagem da conversa é tratada como resposta
#   (continue_with_reply) e vira a variável configurada, em vez de cair na
#   IA ou virar um novo gatilho.
# - "options" (Botões/Lista): manda a lista numerada e também PARA esperando
#   resposta — casa a resposta por número ou por texto da opção.
# - "wait": segura de verdade (FlowContinueJob com `.set(wait: ...)`).
# - "condition": avalia de verdade contra FlowRun#variables.
# - "action": add_tag/remove_tag/assign_agent/update_variable/send_webhook,
#   mesmo vocabulário de PipelineTrigger#action_type.
class FlowRunnerService
  MAX_STEPS = 20

  # Acionado pelo webhook a cada mensagem recebida. Só considera fluxos
  # ativos DA MESMA CAIXA que recebeu a mensagem (Flow#inbox_id) — um fluxo
  # sem caixa definida não dispara em lugar nenhum, de propósito (evita
  # crer que ativou pra uma caixa e na verdade valer pra todas).
  def self.trigger_by_keyword(inbox, conversation, contact, text)
    return false if text.blank?

    flow = inbox.flows.includes(:flow_nodes).where(active: true).find do |f|
      trigger = f.flow_nodes.find { |n| n.node_type == 'trigger' }
      trigger && trigger.data['trigger_type'] == 'palavra_chave' &&
        trigger.data['keyword'].to_s.strip.present? &&
        text.downcase.include?(trigger.data['keyword'].to_s.strip.downcase)
    end
    return false unless flow

    trigger_node = flow.flow_nodes.find { |n| n.node_type == 'trigger' }
    flow_run = FlowRun.create!(flow: flow, conversation: conversation, contact: contact)
    new(flow_run).call(trigger_node.key)
    true
  rescue StandardError => e
    Rails.logger.error("FlowRunnerService (palavra-chave) falhou: #{e.message}")
    false
  end

  # Início programático de um fluxo — chamado por PipelineTriggerRunnerService/
  # ReguaTriggerRunnerService quando o gatilho configurado é "Iniciar fluxo"
  # (PDF Etapa 2, página 11: fluxos disponíveis como Ação nos gatilhos).
  # Precisa de uma caixa (Flow#inbox) pra saber por onde mandar mensagem —
  # sem isso não tem como abrir/achar a conversa. Não empilha um 2º fluxo
  # rodando na mesma conversa (mesma guarda que trigger_by_keyword ganha de
  # graça por só ter 1 FlowRun em waiting_reply por vez sendo escutado).
  def self.start_for_contact(flow, contact)
    return false unless flow&.active? && flow.inbox.present? && contact.present?

    trigger_node = flow.flow_nodes.find { |n| n.node_type == 'trigger' }
    return false unless trigger_node

    conversation = Conversation.find_or_create_by(contact: contact, inbox: flow.inbox) do |conv|
      conv.account = flow.account
      conv.status = :open
      conv.user_id = contact.user_id
      conv.source = 'whatsapp'
    end

    return false if FlowRun.exists?(conversation: conversation, status: %w[running waiting_reply])

    flow_run = FlowRun.create!(flow: flow, conversation: conversation, contact: contact)
    new(flow_run).call(trigger_node.key)
    true
  rescue StandardError => e
    Rails.logger.error("FlowRunnerService (start_for_contact, flow=#{flow&.id}, contact=#{contact&.id}) falhou: #{e.message}")
    false
  end

  # Chamado ANTES de trigger_by_keyword pra toda mensagem recebida — se essa
  # conversa tem um FlowRun esperando resposta (Perguntar ou Botões/Lista),
  # essa mensagem é a resposta, não um gatilho novo nem algo pra IA.
  def self.continue_with_reply(conversation, text)
    flow_run = FlowRun.where(conversation: conversation, status: 'waiting_reply').order(updated_at: :desc).first
    return false unless flow_run

    node = flow_run.flow.flow_nodes.find_by(key: flow_run.current_node_key)
    return false unless node

    case node.node_type
    when 'ask_question'
      var_name = node.data['variable'].to_s.strip.presence || 'resposta'
      flow_run.update!(variables: flow_run.variables.merge(var_name => text.to_s), status: 'running')
      new(flow_run).call(node.key)
      true
    when 'options'
      handle_id = match_option_handle(node, text)
      if handle_id
        flow_run.update!(status: 'running')
        new(flow_run).call(node.key, handle: handle_id)
      else
        # Achado num teste real: sem esse "senão", uma resposta que não bate
        # com nenhuma opção fazia o call cair num handle inexistente e
        # encerrar o FlowRun silenciosamente — a resposta CERTA mandada
        # logo depois não tinha mais fluxo esperando pra reagir a ela.
        # Continua esperando (status já é waiting_reply, não muda).
        runner = new(flow_run)
        runner.send(:send_message_text, 'Não entendi. Responda com o número da opção ou o texto dela.')
      end
      true
    else
      false
    end
  rescue StandardError => e
    Rails.logger.error("FlowRunnerService (continuar) falhou: #{e.message}")
    false
  end

  def self.match_option_handle(node, text)
    options = node.data['options'] || []
    normalized = text.to_s.strip.downcase
    return nil if options.blank? || normalized.blank?

    by_number = normalized.match?(/\A\d+\z/) ? options[normalized.to_i - 1] : nil
    # Direção certa: o texto da opção CONTÉM o que a pessoa respondeu (ex:
    # respondeu "quero" pra opção "Sim, quero") — checado errado antes (o
    # contrário), confirmado num teste real que "Quero" não batia com nada.
    match = by_number ||
      options.find { |o| o['label'].to_s.strip.downcase == normalized } ||
      options.find { |o| o['label'].to_s.present? && o['label'].to_s.strip.downcase.include?(normalized) }
    match && match['id']
  end

  def initialize(flow_run)
    @flow_run = flow_run
    @flow = flow_run.flow
    @conversation = flow_run.conversation
    @contact = flow_run.contact
  end

  def call(from_key, handle: nil, steps: 0)
    return if steps >= MAX_STEPS

    edge = @flow.flow_edges.find_by(source_key: from_key, source_handle: handle)
    return finish! unless edge

    node = @flow.flow_nodes.find_by(key: edge.target_key)
    return finish! unless node

    case node.node_type
    when 'send_message'
      send_message_text(interpolate(node.data['message'].to_s))
      call(node.key, steps: steps + 1)
    when 'send_media'
      send_media(node)
      call(node.key, steps: steps + 1)
    when 'ask_question'
      send_message_text(interpolate(node.data['question'].to_s))
      @flow_run.update!(current_node_key: node.key, status: 'waiting_reply')
    when 'options'
      send_options(node)
      @flow_run.update!(current_node_key: node.key, status: 'waiting_reply')
    when 'wait'
      seconds = wait_seconds(node.data)
      if seconds.positive?
        @flow_run.update!(current_node_key: node.key)
        FlowContinueJob.set(wait: seconds.seconds).perform_later(@flow_run.id, node.key)
      else
        call(node.key, steps: steps + 1)
      end
    when 'condition'
      call(node.key, handle: (evaluate_condition(node) ? 'sim' : 'nao'), steps: steps + 1)
    when 'action'
      run_action(node)
      call(node.key, steps: steps + 1)
    when 'end'
      finish!
    else
      finish!
    end
  end

  private

  def finish!
    @flow_run.update!(status: 'completed') if @flow_run.status != 'completed'
    nil
  end

  def evaluate_condition(node)
    actual = @flow_run.variables[node.data['variable'].to_s].to_s
    expected = interpolate(node.data['value'].to_s)

    case node.data['operator']
    when 'igual' then actual.casecmp?(expected)
    when 'diferente' then !actual.casecmp?(expected)
    when 'contem' then actual.downcase.include?(expected.downcase)
    else false
    end
  end

  def run_action(node)
    case node.data['action_type']
    when 'add_tag'
      # Na CONVERSA, não na revendedora — é onde a tela de conversa mostra
      # "Adicionar etiqueta" de verdade (achado num teste real: a pessoa
      # não achava a etiqueta porque eu tava aplicando no lugar errado).
      # Mesmo padrão que a tag "agente_off" já usa em Webhooks::WahaController,
      # inclusive o broadcast pra atualizar a tela sem precisar recarregar.
      tag = @conversation.account.tags.find_by(name: node.data['tag_name'])
      if tag && !@conversation.tags.include?(tag)
        @conversation.tags << tag
        broadcast_tags
      end
    when 'remove_tag'
      tag = @conversation.account.tags.find_by(name: node.data['tag_name'])
      if tag && @conversation.tags.include?(tag)
        @conversation.tags.delete(tag)
        broadcast_tags
      end
    when 'assign_agent'
      # Na CONVERSA — mesmo caso da etiqueta (achado num teste real: o
      # atendente não aparecia porque isso tava mudando o responsável da
      # revendedora, um campo separado do atendente da conversa em si).
      user = @conversation.account.users.find_by(id: node.data['agent_id'])
      if user
        @conversation.update!(user_id: user.id)
        ActionCable.server.broadcast("conversations_channel_#{@conversation.account_id}", {
          event: 'conversation_updated',
          conversation: { id: @conversation.id, assignee_id: user.id, assignee: user.first_name }
        })
      end
    when 'update_variable'
      var = node.data['variable'].to_s.strip
      return if var.blank?

      @flow_run.update!(variables: @flow_run.variables.merge(var => interpolate(node.data['value'].to_s)))
    when 'send_webhook'
      send_webhook(node)
    end
  rescue StandardError => e
    Rails.logger.error("FlowRunnerService ação '#{node.data['action_type']}' falhou: #{e.message}")
  end

  def broadcast_tags
    ActionCable.server.broadcast("conversations_channel_#{@conversation.account_id}", {
      event: 'conversation_tags_updated',
      conversation_id: @conversation.id,
      tags: @conversation.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
    })
  end

  # Mesmo padrão de PipelineTriggerRunnerService#send_webhook.
  def send_webhook(node)
    url = node.data['url']
    return if url.blank?

    uri = URI.parse(url)
    return unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    payload = {
      event: 'flow_action',
      flow_id: @flow.id,
      contact: { id: @contact.id, name: @contact.name, phone: @contact.phone },
      variables: @flow_run.variables
    }

    Thread.new do
      begin
        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req.body = payload.to_json
        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 5) do |http|
          http.request(req)
        end
        Rails.logger.info("Webhook de ação de Fluxo (flow=#{@flow.id}) respondeu #{res.code}")
      rescue StandardError => e
        Rails.logger.error("Webhook de ação de Fluxo falhou: #{e.message}")
      end
    end
  end

  def send_message_text(text)
    return if text.blank?

    recipient = @contact.channel_identifier

    # Corrida confirmada ao vivo em teste real: o eco da própria mensagem
    # (fromMe: true) às vezes chega no webhook ANTES da gente terminar de
    # gravar o Message com o source_id certo — o webhook então não acha
    # nada com esse source_id e trata como intervenção humana, duplicando.
    # Mesma guarda de cache que a IA já usa (ai_is_replying_#{inbox}_#{chat}).
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

  def send_media(node)
    caption = interpolate(node.data['caption'].to_s)
    recipient = @contact.channel_identifier
    media_type = node.data['media_type'].presence || 'document'
    url = node.data['url']
    return if !node.media.attached? && url.blank?

    Rails.cache.write("ai_is_replying_#{@conversation.inbox_id}_#{recipient}", true, expires_in: 20.seconds)
    messaging_service = @conversation.inbox.messaging_service

    # Upload direto reaproveita o mesmo caminho que já manda anexo de
    # verdade (Message#attachment) — mais confiável do que URL externa, que
    # deu 500 na WAHA num teste real (nem toda instância baixa por URL).
    external_id = if node.media.attached?
      messaging_service.send_message(recipient, caption, node.media)
    elsif messaging_service.respond_to?(:send_media_by_url)
      messaging_service.send_media_by_url(recipient, url, media_type, caption)
    end

    msg = Message.create!(
      account_id: @conversation.account_id,
      conversation: @conversation,
      text: caption.presence || "[#{media_type}]",
      sender_type: 'User',
      sender_id: nil,
      source_id: external_id.presence || "flow_#{@flow.id}_#{SecureRandom.hex(8)}",
      status: :sent
    )
    msg.attachment.attach(node.media.blob) if node.media.attached?
    msg.rebroadcast
  end

  def send_options(node)
    lines = [interpolate(node.data['title'].to_s)]
    (node.data['options'] || []).each_with_index do |opt, i|
      lines << "#{i + 1}. #{opt['label']}"
    end
    send_message_text(lines.reject(&:blank?).join("\n"))
  end

  def interpolate(text)
    base = text.to_s
      .gsub('{{nome}}', @contact.name.to_s)
      .gsub('{{telefone}}', @contact.phone.to_s)
      .gsub('{{email}}', @contact.email.to_s)

    @flow_run.variables.each { |key, value| base = base.gsub("{{#{key}}}", value.to_s) }
    base
  end

  def wait_seconds(data)
    duration = data['duration'].to_i
    return 0 if duration <= 0

    multiplier = { 'segundos' => 1, 'minutos' => 60, 'horas' => 3600, 'dias' => 86_400 }[data['unit']] || 1
    duration * multiplier
  end
end
