# Executa os gatilhos (PipelineTrigger) configurados na etapa de destino de um
# PipelineCard, disparado quando o card entra/é criado nela — espelha o comportamento
# do "Automatize" (Digital Pipeline) do Kommo.
#
# Guarda de loop: "move_stage" pode encadear gatilhos (etapa A move pra B, que tem
# gatilho movendo pra C...). MAX_CHAIN evita loop infinito se alguém configurar um
# ciclo por engano.
class PipelineTriggerRunnerService
  MAX_CHAIN = 5

  def initialize(pipeline_card)
    @card = pipeline_card
  end

  def call(chain_depth: 0)
    return if chain_depth >= MAX_CHAIN

    @card.pipeline_stage.pipeline_triggers.where(active: true).order(:position).each do |trigger|
      run_trigger(trigger, chain_depth)
    end
  end

  private

  def run_trigger(trigger, chain_depth)
    case trigger.action_type
    when 'move_stage'
      move_stage(trigger, chain_depth)
    when 'change_owner'
      change_owner(trigger)
    when 'create_note'
      create_note(trigger)
    when 'ai_start'
      set_ai_paused(false)
    when 'ai_stop'
      set_ai_paused(true)
    when 'send_webhook'
      send_webhook(trigger)
    end
  rescue StandardError => e
    Rails.logger.error("PipelineTrigger##{trigger.id} (#{trigger.action_type}) falhou pro card #{@card.id}: #{e.message}")
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
