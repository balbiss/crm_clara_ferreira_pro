require 'test_helper'

# "Histórico completo" (2026-10-16): a mesma pessoa tem uma conversa por
# caixa/número; cada conversa mostrava só as próprias mensagens e parecia que
# o histórico tinha sumido. GET /conversations/:id/other_history junta o resto.
class OtherHistoryApiTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  self.use_transactional_tests = true

  setup do
    @account = Account.create!(name: 'Clara Histórico')
    @diretora = User.create!(account: @account, first_name: 'Bel', last_name: 'D', email: "d#{SecureRandom.hex(3)}@teste.local", password: 'senha-teste-123', role: 'diretoria')
    @consultora = User.create!(account: @account, first_name: 'Ana', last_name: 'C', email: "c#{SecureRandom.hex(3)}@teste.local", password: 'senha-teste-123', role: 'consultor')
    @expansao = Inbox.create!(account: @account, name: 'Gerência-Expansão', provider: 'waha', phone_number: "+55149#{rand(10_000_000..99_999_999)}")
    @comercial = Inbox.create!(account: @account, name: 'Gerência Comercial', provider: 'waha', phone_number: "+55149#{rand(10_000_000..99_999_999)}")
    @contact = Contact.create!(account: @account, name: 'Emili Teste', phone: "+55149#{rand(10_000_000..99_999_999)}")
    @conv_expansao = Conversation.create!(account: @account, contact: @contact, inbox: @expansao, status: :open, user: @consultora)
    @conv_comercial = Conversation.create!(account: @account, contact: @contact, inbox: @comercial, status: :open)
  end

  def msg(conv, text, from: 'Contact', at: Time.current, private: false)
    Message.create!(account: @account, conversation: conv, sender_type: from, sender_id: from == 'Contact' ? @contact.id : @diretora.id,
                    text: text, is_private: private, status: :delivered, created_at: at)
  end

  test 'resumo lista as outras caixas com a contagem' do
    msg(@conv_expansao, 'oi pela expansão')
    3.times { |i| msg(@conv_comercial, "mensagem #{i} pelo comercial", at: (10 - i).days.ago) }
    sign_in @diretora

    get other_history_conversation_url(@conv_expansao), as: :json

    assert_response :success
    resumo = response.parsed_body['conversations']
    assert_equal 1, resumo.size
    assert_equal 'Gerência Comercial', resumo.first['inbox_name']
    assert_equal 3, resumo.first['messages_count']
    assert_empty response.parsed_body['messages'], 'sem with_messages vem só o resumo'
  end

  test 'com with_messages devolve as mensagens das outras caixas em ordem, marcadas com a caixa' do
    msg(@conv_expansao, 'só da expansão')
    msg(@conv_comercial, 'segunda', at: 8.days.ago)
    msg(@conv_comercial, 'primeira', at: 9.days.ago)
    msg(@conv_comercial, 'terceira', at: 7.days.ago, from: 'User')
    sign_in @diretora

    get other_history_conversation_url(@conv_expansao, with_messages: true), as: :json

    mensagens = response.parsed_body['messages']
    assert_equal %w[primeira segunda terceira], mensagens.map { |m| m['text'] }
    assert(mensagens.all? { |m| m['inboxName'] == 'Gerência Comercial' })
    assert(mensagens.all? { |m| m['conversationId'] == @conv_comercial.id })
    assert_equal 'agent', mensagens.last['senderType']
  end

  test 'nota privada de outra caixa nao aparece' do
    msg(@conv_comercial, 'pública')
    msg(@conv_comercial, 'nota interna', private: true)
    sign_in @diretora

    get other_history_conversation_url(@conv_expansao, with_messages: true), as: :json

    assert_equal ['pública'], response.parsed_body['messages'].map { |m| m['text'] }
  end

  test 'quem so enxerga a propria conversa nao recebe mensagens de caixa que nao pode ver' do
    msg(@conv_expansao, 'minha conversa')
    msg(@conv_comercial, 'de outra caixa, que a consultora nao enxerga')
    sign_in @consultora

    get other_history_conversation_url(@conv_expansao, with_messages: true), as: :json

    assert_response :success
    assert_empty response.parsed_body['conversations']
    assert_empty response.parsed_body['messages']
  end

  test 'conversa que a pessoa nao pode ver devolve 404' do
    sign_in @consultora

    get other_history_conversation_url(@conv_comercial), as: :json

    assert_response :not_found
  end

  test 'quem tem acesso as duas caixas ve o historico junto' do
    msg(@conv_comercial, 'do comercial')
    @conv_comercial.update!(user: @consultora) # agora ela também é atendente da outra conversa
    sign_in @consultora

    get other_history_conversation_url(@conv_expansao, with_messages: true), as: :json

    assert_equal ['do comercial'], response.parsed_body['messages'].map { |m| m['text'] }
  end

  test 'pessoa com uma conversa so volta vazio' do
    sozinha = Contact.create!(account: @account, name: 'Sozinha', phone: "+55149#{rand(10_000_000..99_999_999)}")
    conv = Conversation.create!(account: @account, contact: sozinha, inbox: @expansao, status: :open)
    sign_in @diretora

    get other_history_conversation_url(conv, with_messages: true), as: :json

    assert_empty response.parsed_body['conversations']
    assert_empty response.parsed_body['messages']
  end

  test 'a conversa normal continua devolvendo as mensagens no mesmo formato (refatoracao)' do
    msg(@conv_expansao, 'oi')
    sign_in @diretora

    get conversation_url(@conv_expansao), as: :json

    assert_response :success
    primeira = response.parsed_body['messages'].first
    assert_equal 'oi', primeira['text']
    assert_equal 'contact', primeira['senderType']
    assert primeira.key?('transcription')
    assert primeira.key?('attachmentUrl')
  end
end
