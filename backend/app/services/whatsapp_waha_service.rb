require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require 'base64'
require 'tempfile'
require 'open3'

# Mesma interface pública do WhatsappBaileysService (create_connection,
# send_message, send_presence_update, fetch_profile_picture_url,
# fetch_qr_code, connected?, send_raw_document, send_raw_image,
# delete_connection, resolve_jid) para que Inbox#messaging_service possa
# alternar entre os dois provedores sem o resto do app saber a diferença.
#
# Engine WEBJS (whatsapp-web.js dentro do WAHA) usa chatId no formato
# "{digits}@c.us" — diferente do "@s.whatsapp.net" do Baileys.
class WhatsappWahaService
  def initialize(inbox)
    @inbox = inbox
    @api_url = inbox.api_url.presence || ENV['WAHA_API_URL'].presence || 'https://waha-clara.inoovaweb.com.br'
    @api_key = inbox.api_key.presence || ENV['WAHA_API_KEY'].presence || ''
    @session = "waha_#{inbox.phone_number.to_s.gsub(/\D/, '')}"
  end

  attr_reader :session

  def create_connection(webhook_url)
    Rails.cache.delete("inbox:#{@inbox.id}:status")

    body = {
      'name' => @session,
      'start' => true,
      'config' => {
        'webhooks' => [{ 'url' => webhook_url, 'events' => %w[message.any session.status] }]
      }
    }

    res = request(:post, '/api/sessions', body)

    if res.code.to_i == 422
      # Sessão já existe (reconexão) — PUT atualiza config e reconcilia o
      # estado desejado (reinicia sozinha se estava parada).
      request(:put, "/api/sessions/#{@session}", body.except('name'))
      request(:post, "/api/sessions/#{@session}/start", {})
      return true
    end

    res.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error("Waha create_connection error: #{e.message}")
    false
  end

  def resolve_jid(phone)
    digits = phone.gsub(/\D/, '')
    digits = "55#{digits}" unless digits.start_with?('55')

    res = request(:get, "/api/contacts/check-exists?session=#{@session}&phone=#{digits}")
    return nil unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body) rescue {}
    return nil unless data['numberExists']

    data['chatId']
  rescue => e
    Rails.logger.error("Waha resolve_jid error: #{e.message}")
    nil
  end

  def send_message(recipient_phone, text, attachment = nil)
    chat_id = normalize_jid(recipient_phone)

    if attachment.present?
      content_type = attachment.content_type.to_s
      file_data = attachment.download
      filename = attachment.filename.to_s

      # WhatsApp recusa nota de voz que não seja ogg/opus -- o MediaRecorder
      # do navegador grava em webm/opus (Conversas.vue), que o WhatsApp
      # aceita como upload mas nunca entrega pro destinatário (confirmado
      # testando direto na API, 2026-09-25: dono gravava, o CRM mostrava
      # "enviado", mas nunca chegava no WhatsApp do cliente). Converte com
      # ffmpeg antes de mandar -- o arquivo original (webm) continua intacto
      # no ActiveStorage, só a cópia enviada pra WAHA é convertida.
      if content_type.start_with?('audio/') && !content_type.include?('ogg')
        converted = convert_to_ogg_opus(file_data)
        if converted
          file_data = converted
          content_type = 'audio/ogg; codecs=opus'
          filename = filename.sub(/\.\w+\z/, '') + '.ogg'
        end
      end

      file = {
        'mimetype' => content_type,
        'filename' => filename,
        'data' => Base64.strict_encode64(file_data)
      }
      payload = { 'session' => @session, 'chatId' => chat_id, 'file' => file }
      payload['caption'] = text if text.present?

      endpoint = if content_type.start_with?('image/')
                   '/api/sendImage'
                 elsif content_type.start_with?('audio/')
                   payload['ptt'] = true
                   payload.delete('caption') # áudio (ptt) não suporta legenda
                   '/api/sendVoice'
                 elsif content_type.start_with?('video/')
                   '/api/sendVideo'
                 else
                   '/api/sendFile'
                 end

      res = request(:post, endpoint, payload, timeout: 40)
    else
      res = request(:post, '/api/sendText', { 'session' => @session, 'chatId' => chat_id, 'text' => text })
    end

    Rails.logger.info("Waha send_message response code: #{res.code}, body: #{res.body}")
    return nil unless res.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(res.body) rescue {}
    # "id" vem como objeto aninhado ({fromMe, remote, id, _serialized, ...}),
    # não como string — precisa do "_serialized" pra bater com o formato que
    # o webhook manda de volta no eco (payload[:id], usado como source_id).
    # Pegar o Hash inteiro aqui quebrava silenciosamente a deduplicação do
    # eco: toda mensagem enviada pelo CRM virava duplicada quando o
    # WhatsApp ecoava ela de volta (fromMe: true sem source_id correspondente).
    parsed.dig('id', '_serialized') || parsed.dig('_data', 'id', '_serialized')
  rescue => e
    Rails.logger.error("Waha send_message error: #{e.message}")
    nil
  end

  # Usado pelo nó "Enviar mídia" do Fluxos — a WAHA baixa o arquivo sozinha
  # a partir da URL (não precisa a gente baixar e reenviar em base64, como
  # `send_message` faz pra anexo já hospedado no nosso ActiveStorage).
  def send_media_by_url(recipient_phone, url, media_type, caption = nil)
    chat_id = normalize_jid(recipient_phone)
    filename = File.basename(URI.parse(url).path.presence || 'arquivo')

    endpoint = { 'image' => '/api/sendImage', 'video' => '/api/sendVideo', 'audio' => '/api/sendVoice', 'document' => '/api/sendFile' }[media_type] || '/api/sendFile'

    payload = { 'session' => @session, 'chatId' => chat_id, 'file' => { 'url' => url, 'filename' => filename } }
    payload['caption'] = caption if caption.present? && media_type != 'audio'
    payload['ptt'] = true if media_type == 'audio'

    res = request(:post, endpoint, payload, timeout: 40)
    Rails.logger.info("Waha send_media_by_url response code: #{res.code}, body: #{res.body}")
    return nil unless res.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(res.body) rescue {}
    parsed.dig('id', '_serialized') || parsed.dig('_data', 'id', '_serialized')
  rescue => e
    Rails.logger.error("Waha send_media_by_url error: #{e.message}")
    nil
  end

  # Nome do grupo (subject) -- usado só na criação do Contact que representa
  # o grupo (ver waha_controller.rb), nunca em toda mensagem (o endpoint de
  # listagem de todos os grupos é pesado, esse aqui devolve só 1). Endpoint
  # usa sessão no path (padrão diferente de contacts/*, que usa ?session=).
  def fetch_group_name(group_jid)
    res = request(:get, "/api/#{@session}/groups/#{CGI.escape(group_jid)}")
    return nil unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body) rescue {}
    data.dig('groupMetadata', 'subject').presence
  rescue => e
    Rails.logger.error("Waha fetch_group_name error: #{e.message}")
    nil
  end

  def send_presence_update(recipient_phone, presence = 'composing')
    chat_id = normalize_jid(recipient_phone)
    endpoint = presence == 'composing' ? '/api/startTyping' : '/api/stopTyping'
    res = request(:post, endpoint, { 'session' => @session, 'chatId' => chat_id })
    res.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error("Waha send_presence_update error: #{e.message}")
    false
  end

  # Resolve um "@lid" (identificador de privacidade do WhatsApp, que substitui
  # o número de telefone em algumas conversas) pro contato real por trás dele
  # — devolve {id: "5591...@c.us", number:, name:, pushname:, ...} ou nil.
  # Sem isso o número/nome que sobra no CRM é literalmente os dígitos do lid,
  # que não têm relação nenhuma com o telefone de verdade da pessoa.
  def resolve_contact(contact_id)
    res = request(:get, "/api/contacts?session=#{@session}&contactId=#{CGI.escape(contact_id)}")
    return nil unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  rescue => e
    Rails.logger.error("Waha resolve_contact error: #{e.message}")
    nil
  end

  def fetch_profile_picture_url(contact_id)
    contact_id = normalize_jid(contact_id)
    res = request(:get, "/api/contacts/profile-picture?session=#{@session}&contactId=#{CGI.escape(contact_id)}")
    return nil unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body) rescue {}
    data['profilePictureURL'] || data['profilePictureUrl'] || data['url']
  rescue => e
    Rails.logger.error("Waha fetch_profile_picture_url error: #{e.message}")
    nil
  end

  # Diferente do Baileys (que lê de um cache alimentado por webhook), aqui
  # busca o QR ao vivo direto na API — a WAHA já devolve o PNG pronto.
  def fetch_qr_code
    res = request(:get, "/api/#{@session}/auth/qr")
    return nil unless res.is_a?(Net::HTTPSuccess)

    "data:#{res.content_type.presence || 'image/png'};base64,#{Base64.strict_encode64(res.body)}"
  rescue => e
    Rails.logger.error("Waha fetch_qr_code error: #{e.message}")
    nil
  end

  def connected?
    res = request(:get, "/api/sessions/#{@session}")
    return false unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body) rescue {}
    data['status'] == 'WORKING'
  rescue => e
    Rails.logger.error("Waha connected? error: #{e.message}")
    false
  end

  def send_raw_document(jid, filename:, mimetype:, data:, caption: nil)
    chat_id = normalize_jid(jid)
    file = { 'mimetype' => mimetype, 'filename' => filename, 'data' => Base64.strict_encode64(data) }
    payload = { 'session' => @session, 'chatId' => chat_id, 'file' => file }
    payload['caption'] = caption if caption.present?

    res = request(:post, '/api/sendFile', payload, timeout: 40)
    res.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error("Waha send_raw_document error: #{e.message}")
    false
  end

  def send_raw_image(jid, data:, caption: nil)
    chat_id = normalize_jid(jid)
    file = { 'mimetype' => 'image/png', 'filename' => 'image.png', 'data' => Base64.strict_encode64(data) }
    payload = { 'session' => @session, 'chatId' => chat_id, 'file' => file }
    payload['caption'] = caption if caption.present?

    res = request(:post, '/api/sendImage', payload, timeout: 40)
    res.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error("Waha send_raw_image error: #{e.message}")
    false
  end

  # Some equivalente ao "sair" do WhatsApp — apaga a sessão inteira na WAHA
  # (mesmo comportamento do Baileys: reconectar depois sempre pede QR novo).
  def delete_connection
    Rails.cache.delete("inbox:#{@inbox.id}:status")
    res = request(:delete, "/api/sessions/#{@session}")
    res.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error("Waha delete_connection error: #{e.message}")
    false
  end

  private

  # Retorna os bytes convertidos pra ogg/opus, ou nil se o ffmpeg falhar
  # (nesse caso send_message segue com o arquivo original, mesmo
  # comportamento de antes desse fix — não trava o envio, só não corrige).
  def convert_to_ogg_opus(input_bytes)
    input = Tempfile.new(['waha_audio_in', '.webm'], binmode: true)
    input.write(input_bytes)
    input.flush
    output_path = "#{input.path}.ogg"

    _out, status = Open3.capture2e('ffmpeg', '-y', '-i', input.path, '-c:a', 'libopus', output_path)
    return nil unless status.success? && File.exist?(output_path)

    File.binread(output_path)
  rescue => e
    Rails.logger.error("Waha audio conversion (ffmpeg) failed: #{e.message}")
    nil
  ensure
    input&.close
    input&.unlink
    File.delete(output_path) if output_path && File.exist?(output_path)
  end

  def normalize_jid(phone_or_id)
    return phone_or_id if phone_or_id.to_s.include?('@')

    digits = phone_or_id.to_s.gsub(/\D/, '')
    digits = "55#{digits}" unless digits.start_with?('55')
    "#{digits}@c.us"
  end

  def request(method, path, body = nil, timeout: 15)
    uri = URI.parse("#{@api_url}#{path}")
    req_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put, delete: Net::HTTP::Delete }.fetch(method)
    req = req_class.new(uri)
    req['X-Api-Key'] = @api_key

    if body
      req.content_type = 'application/json'
      req.body = JSON.dump(body)
    end

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: timeout) do |http|
      http.request(req)
    end
  end
end
