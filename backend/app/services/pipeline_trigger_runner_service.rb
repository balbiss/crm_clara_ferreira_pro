# Executa os gatilhos (PipelineTrigger) configurados na etapa de destino de um
# PipelineCard, disparado quando o card entra/Ã© criado nela â€” espelha o comportamento
# do "Automatize" (Digital Pipeline) do Kommo.
#
# Guarda de loop: "move_stage" pode encadear gatilhos (etapa A move pra B, que tem
# gatilho movendo pra C...). MAX_CHAIN evita loop infinito se alguÃ©m configurar um
# ciclo por engano.
class PipelineTriggerRunnerService
  MAX_CHAIN = 5

  def initialize(pipeline_card)
    @card = pipeline_card
  end

  # Gatilhos "quando o lead ENTRAR na etapa".
  def call(chain_depth: 0)
    return if chain_depth >= MAX_CHAIN

    @card.pipeline_stage.pipeline_triggers.where(active: true, event: 'enter').order(:position).each do |trigger|
      dispatch(trigger, chain_depth)
    end
  end

  # Gatilhos "quando o CLIENTE RESPONDER" (chamado por PipelineClientReplyJob a
  # cada mensagem do cliente). Roda UMA vez por permanÃªncia do card na etapa:
  # a primeira resposta marca reply_triggered_at (atÃ´mico no banco, entÃ£o 2
  # mensagens quase simultÃ¢neas nÃ£o disparam em duplicado) e a marca sÃ³ zera
  # quando o card muda de etapa (PipelineCard). Sem isso, aÃ§Ãµes como "Adicionar
  # nota" ou "Criar tarefa" repetiriam a cada mensagem.
  def call_for_client_reply(chain_depth: 0)
    return if chain_depth >= MAX_CHAIN

    triggers = @card.pipeline_stage.pipeline_triggers.where(active: true, event: 'client_reply').order(:position).to_a
    return if triggers.empty?

    claimed = PipelineCard.where(id: @card.id, reply_triggered_at: nil).update_all(reply_triggered_at: Time.current)
    return unless claimed == 1

    # update_all nÃ£o atualiza o objeto em memÃ³ria â€” sem recarregar, quando o
    # gatilho move o card o "zerar a marca" do PipelineCard nÃ£o enxergaria
    # mudanÃ§a nenhuma e a marca ficaria presa na etapa nova.
    @card.reload
    triggers.each { |trigger| dispatch(trigger, chain_depth) }
  end

  # Ponto de entrada usado pelo PipelineTriggerFireJob pra rodar 1 gatilho
  # isolado depois do atraso â€” precisa ser pÃºblico, o resto do fluxo (call)
  # continua privado.
  def run_single_trigger(trigger, chain_depth:)
    run_trigger(trigger, chain_depth)
  end

  private

  def dispatch(trigger, chain_depth)
    if trigger.delay_minutes.to_i.positive?
      # CondiÃ§Ã£o de tempo (PDF Etapa 2, pÃ¡gina 11 â€” "X horas apÃ³s o lead
      # entrar nessa etapa"): agenda em vez de rodar na hora. O job
      # confere de novo se o card ainda tÃ¡ na mesma etapa antes de
      # executar â€” se jÃ¡ saiu, a aÃ§Ã£o nÃ£o roda (mesmo comportamento do
      # Kommo mostrado no exemplo).
      PipelineTriggerFireJob.set(wait: trigger.delay_minutes.minutes).perform_later(trigger.id, @card.id, chain_depth)
    else
      run_trigger(trigger, chain_depth)
    end
  end

  def run_trigger(trigger, chain_depth)
    case trigger.action_type
    when 'move_stage'
      move_stage(trigger, chain_depth)
    when 'change_owner'
      change_owner(trigger)
    when 'create_note'
      create_note(trigger)
    when 'create_task'
      TriggerTaskCreator.call(contact: @card.contact, config: trigger.config)
    when 'ai_start'
      set_ai_paused(false)
    when 'ai_stop'
      set_ai_paused(true)
    when 'send_webhook'
      send_webhook(trigger)
    when 'start_flow'
      start_flow(trigger)
    end
  rescue StandardError => e
    Rails.logger.error("PipelineTrigger##{trigger.id} (#{trigger.action_type}) falhou pro card #{@card.id}: #{e.message}")
  end

  def start_flow(trigger)
    flow = Flow.find_by(id: trigger.config['flow_id'], account_id: @card.pipeline.account_id)
    FlowRunnerService.start_for_contact(flow, @card.contact) if flow
  end

  def move_stage(trigger, chain_depth)
    target = PipelineStage.find_by(id: trigger.config['target_stage_id'], pipeline_id: @card.pipeline_id)
    return unless target && target.id != @card.pipeline_stage_id

    @card.update!(pipeline_stage: target)
    PipelineTriggerRunnerService.new(@card).call(chain_depth: chain_depth + 1)
  end

  def change_owner(trigger)
    user = User.find_by(id: trigger.config['user_id'], account_id: @card.pipeline.account_id)
    @card.contact.update!(user_id: user.id) if user
  end

  def create_note(trigger)
    Note.create!(
      account_id: @card.pipeline.account_id,
      contact_id: @card.contact_id,
      user_id: nil,
      content: trigger.config['content']
    )
  end

  def set_ai_paused(paused)
    contact = @card.contact
    jid = contact.channel_identifier
    return if jid.blank?

    contact.conversations.where.not(inbox_id: nil).distinct.pluck(:inbox_id).each do |inbox_id|
      key = "ai_paused_#{inbox_id}_#{jid}"
      paused ? Rails.cache.write(key, Time.current.to_i) : Rails.cache.delete(key)
    end
  end

  def send_webhook(trigger)
    uri = URI.parse(trigger.config['url'])
    return unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    contact = @card.contact
    payload = {
      event: 'pipeline_trigger',
      pipeline_id: @card.pipeline_id,
      pipeline_stage_id: @card.pipeline_stage_id,
      contact: { id: contact.id, name: contact.name, phone: contact.phone }
    }

    Thread.new do
      begin
        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req.body = payload.to_json
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 5) do |http|
          http.request(req)
        end
      rescue StandardError => e
        Rails.logger.error("Webhook de PipelineTrigger falhou: #{e.message}")
      end
    end
  end
end
