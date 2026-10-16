require 'test_helper'

# Login da API (2026-10-16): o motivo da falha tem que chegar na tela. Antes,
# com o header `Accept: ... */*` do navegador, qualquer falha voltava 422 com
# {"message":"Login bem-sucedido."} e a tela só dizia "e-mail ou senha incorretos".
class LoginApiTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  self.use_transactional_tests = true

  # Mesmos headers que o axios do navegador manda.
  BROWSER_HEADERS = { 'Accept' => 'application/json, text/plain, */*' }.freeze

  setup do
    @account = Account.create!(name: 'Clara Login')
    @user = User.create!(account: @account, first_name: 'Ana', last_name: 'Teste', email: 'ana@teste.local',
                         password: 'senha-certa-123', role: 'consultor')
  end

  def login(email, password)
    post user_session_url, params: { user: { email: email, password: password } }, as: :json, headers: BROWSER_HEADERS
  end

  test 'login certo devolve 200 e o token' do
    login('ana@teste.local', 'senha-certa-123')

    assert_response :ok
    assert_equal 'ana@teste.local', response.parsed_body.dig('user', 'email')
    assert response.headers['Authorization'].present?
  end

  test 'email com maiuscula e espaco ainda entra' do
    login('  ANA@Teste.Local ', 'senha-certa-123')

    assert_response :ok
  end

  test 'senha errada devolve 401 com motivo (nao 422 dizendo login bem-sucedido)' do
    login('ana@teste.local', 'senha-errada')

    assert_response :unauthorized
    assert_equal 'E-mail ou senha inválidos.', response.parsed_body['error']
    assert_nil response.parsed_body['message']
  end

  test 'email que nao existe devolve o mesmo 401' do
    login('naoexiste@teste.local', 'qualquer-coisa')

    assert_response :unauthorized
    assert_equal 'E-mail ou senha inválidos.', response.parsed_body['error']
  end

  test 'usuario bloqueado com a senha certa recebe aviso de bloqueio' do
    @user.update!(status: 'blocked')

    login('ana@teste.local', 'senha-certa-123')

    assert_response :unauthorized
    assert_match(/bloqueado/i, response.parsed_body['error'])
  end

  test 'rota protegida sem login devolve 401 (antes 500 quando o Accept nao era json)' do
    get conversations_url, headers: { 'Accept' => '*/*' }

    assert_response :unauthorized
  end
end
