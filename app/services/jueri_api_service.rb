require 'net/http'
require 'uri'
require 'json'

# Cliente da API do Jueri (ERP da Clara Ferreira — briefing seção 25/35).
# Documentação: https://jueri.com.br/sis/docs/
#
# Credenciais (ENV, ainda não configuradas — ver JueriApiService.configured?):
#   JUERI_API_TOKEN      — Bearer token gerado em Configurações > API dentro do próprio Jueri
#   JUERI_CLIENTE_SISTEMA — ID da empresa no Jueri (parâmetro {cliente_sistema} da URL)
#   JUERI_API_URL         — opcional, default https://jueri.com.br/sis
#
# Jueri é a fonte oficial pra cadastro/CPF/pedidos/financeiro (briefing seção 5) — este
# service só LÊ e faz upsert de cadastro, nunca duplica lógica de negócio que pertence
# ao ERP (baixa de pedido é feita na tela do Jueri, não por aqui).
class JueriApiService
  class ApiError < StandardError; end
  class NotConfiguredError < StandardError; end

  def self.configured?
    ENV['JUERI_API_TOKEN'].present? && ENV['JUERI_CLIENTE_SISTEMA'].present?
  end

  def initialize
    @api_url = ENV['JUERI_API_URL'].presence || 'https://jueri.com.br/sis'
    @token = ENV['JUERI_API_TOKEN']
    @cliente_sistema = ENV['JUERI_CLIENTE_SISTEMA']
    raise NotConfiguredError, 'JUERI_API_TOKEN e JUERI_CLIENTE_SISTEMA precisam estar configurados' unless self.class.configured?
  end

  # ---- Revendedor -----------------------------------------------------

  def revendedores(params = {})
    get("/revendedor", params)
  end

  def find_revendedor(id)
    get("/revendedor/#{id}")
  end

  # Upsert por CPF/CNPJ (PUT sem :id na doc do Jueri) — idempotente, seguro pra rodar
  # em rotina periódica sem duplicar cadastro.
  def upsert_revendedor(attrs)
    put("/revendedor", attrs)
  end

  # ---- Pedido -----------------------------------------------------------

  def pedidos(params = {})
    get("/pedido", params)
  end

  def find_pedido(id)
    get("/pedido/#{id}")
  end

  # ---- Cliente (cliente final de um revendedor, recurso separado) -------

  def clientes(params = {})
    get("/cliente", params)
  end

  # ---- Webhook ------------------------------------------------------------

  def webhooks
    get("/webhook")
  end

  def create_webhook(attrs)
    post("/webhook", attrs)
  end

  private

  def get(path, params = {})
    uri = build_uri(path, params)
    request(Net::HTTP::Get.new(uri))
  end

  def post(path, body)
    uri = build_uri(path)
    req = Net::HTTP::Post.new(uri)
    req.body = JSON.dump(body)
    request(req)
  end

  def put(path, body)
    uri = build_uri(path)
    req = Net::HTTP::Put.new(uri)
    req.body = JSON.dump(body)
    request(req)
  end

  def build_uri(path, params = {})
    uri = URI.parse("#{@api_url}/api/v1/#{@cliente_sistema}#{path}")
    uri.query = URI.encode_www_form(params) if params.present?
    uri
  end

  def request(req)
    req['Authorization'] = "Bearer #{@token}"
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'application/json'

    response = Net::HTTP.start(req.uri.hostname, req.uri.port, use_ssl: req.uri.scheme == 'https', read_timeout: 15) do |http|
      http.request(req)
    end

    body = response.body.present? ? JSON.parse(response.body) : nil

    unless response.is_a?(Net::HTTPSuccess)
      message = body.is_a?(Hash) ? (body['message'] || body['error']) : response.message
      raise ApiError, "Jueri API #{response.code}: #{message}"
    end

    body
  rescue JSON::ParserError
    raise ApiError, "Jueri API retornou resposta inválida (status #{response&.code})"
  end
end
