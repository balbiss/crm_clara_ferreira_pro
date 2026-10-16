# Resposta do Devise/Warden quando a autenticação falha (login errado, usuário
# bloqueado, token ausente/inválido): SEMPRE 401 + {"error": "<motivo>"}, não
# importa o Accept que o cliente mandou.
#
# O navegador/axios manda `Accept: application/json, text/plain, */*`; o Rails
# ignora esse Accept ("browser-like") e trata a requisição como HTML, então o
# Devise devolvia texto puro (ou 422/500, dependendo da rota) e a tela não
# conseguia mostrar o motivo (Clara, 2026-10-16).
class JsonFailureApp < Devise::FailureApp
  def respond
    self.status = 401
    self.content_type = 'application/json; charset=utf-8'
    self.response_body = { error: i18n_message }.to_json
  end
end
