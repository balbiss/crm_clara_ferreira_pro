# Executa os gatilhos (ReguaTrigger) configurados no status de destino de um Contact,
# disparado sempre que o status muda (drag no Kanban, JueriSyncService,
# ReguaAutoAdvanceJob — qualquer caminho, porque o hook fica no model, não num
# controller específico). Espelha PipelineTriggerRunnerService.
class ReguaTriggerRunnerService
  MAX_CHAIN = 5

  def initialize(contact)
    @contact = contact
  end

  def call(chain_depth: 0)
    return if chain_depth >= MAX_CHAIN

    ReguaTrigger.where(account_id: @contact.account_id, status: @contact.status, active: true).order(:position).each do |trigger|
      run_trigger(trigger, chain_depth)
    end
  end

  private

  def run_trigger(trigger, chain_depth)
    case trigger.action_type
    when 'change_status'
      change_status(trigger, chain_depth)
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
    Rails.logger.error("ReguaTrigger##{trigger.id} (#{trigger.action_type}) falhou pro contato #{@contact.id}: #{e.message}")
  end

  def change_status(trigger, chain_depth)
    target = trigger.config['target_status']
    return if target.blank? || target == @contact.status

    @contact.update!(status: target)
    ReguaTriggerRunnerService.new(@contact).call(chain_depth: chain_depth + 1)
  end

  def change_owner(trigger)
    user = User.find_by(id: trigger.config['user_id'], account_id: @contact.account_id)
    @contact.update!(user_id: user.id) if user
  end

  def create_note(trigger)
    Note.create!(
      account_id: @contact.account_id,
      contact_id: @contact.id,
      user_id: nil,
      content: trigger.config['content']
    )
  end

  def set_ai_paused(paused)
    jid = @contact.channel_identifier
    return if jid.blank?

    @contact.conversations.where.not(inbox_id: nil).distinct.pluck(:inbox_id).each do |inbox_id|
      key = "ai_paused_#{inbox_id}_#{jid}"
      paused ? Rails.cache.write(key, Time.current.to_i) : Rails.cache.delete(key)
    end
  end

  def send_webhook(trigger)
    uri = URI.parse(trigger.config['url'])
    return unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    payload = {
      event: 'regua_trigger',
      status: @contact.status,
      contact: { id: @contact.id, name: @contact.name, phone: @contact.phone }
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
        Rails.logger.error("Webhook de ReguaTrigger falhou: #{e.message}")
      end
    end
  end
end
