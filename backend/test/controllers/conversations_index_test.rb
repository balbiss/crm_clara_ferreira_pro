require 'test_helper'

# Lista de conversas (2026-10-16): antes só vinha a 1ª página (100 mais recentes
# da CONTA toda) e a caixa era filtrada no navegador — numa caixa quieta quase
# nada aparecia. Agora o servidor filtra por caixa, pagina e tem modo "lista".
class ConversationsIndexTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  self.use_transactional_tests = true

  setup do
    @account = Account.create!(name: 'Clara Lista')
    @diretora = User.create!(account: @account, first_name: 'Bel', last_name: 'D', email: "d#{SecureRandom.hex(3)}@teste.local", password: 'senha-teste-123', role: 'diretoria')
    @consultora = User.create!(account: @account, first_name: 'Ana', last_name: 'C', email: "c#{SecureRandom.hex(3)}@teste.local", password: 'senha-teste-123', role: 'consultor')
    @quieta = Inbox.create!(account: @account, name: 'Gerência-Expansão', provider: 'waha', phone_number: "+55149#{rand(10_000_000..99_999_999)}")
    @movimentada = Inbox.create!(account: @account, name: 'Prospecção', provider: 'waha', phone_number: "+55149#{rand(10_000_000..99_999_999)}")
  end

  # GET da lista: autentica a cada chamada (o login de teste vale por requisição)
  # e já confere o status, mostrando o erro do servidor se houver.
  def listar(como: @diretora, **params)
    sign_in como
    get conversations_url(**params), as: :json
    assert_response :success, "status #{response.status}: #{response.body[0, 400]}"
    response.parsed_body
  end

  def conversa(inbox, nome, atividade:, user: nil, mensagens: 3)
    contato = Contact.create!(account: @account, name: nome, phone: "+55149#{rand(10_000_000..99_999_999)}")
    conv = Conversation.create!(account: @account, contact: contato, inbox: inbox, status: :open, user: user)
    mensagens.times do |i|
      Message.create!(account: @account, conversation: conv, sender_type: 'Contact', sender_id: contato.id, text: "#{nome} msg #{i + 1}", status: :delivered,
                      created_at: atividade - (mensagens - i).minutes)
    end
    conv.update_columns(last_activity_at: atividade)
    conv
  end

  test 'caixa quieta some da lista global mas aparece com inbox_id (o bug da Gerência-Expansão)' do
    120.times { |i| conversa(@movimentada, "Movimentada #{i}", atividade: i.minutes.ago, mensagens: 1) }
    antigas = 5.times.map { |i| conversa(@quieta, "Quieta #{i}", atividade: (30 + i).days.ago, mensagens: 1) }

    globais = listar(light: true, per_page: 100)
    assert_equal 100, globais.size
    assert(globais.none? { |c| c.dig('contact', 'name').start_with?('Quieta') }, 'sem o filtro, a caixa quieta fica de fora das 100 mais recentes (era o defeito)')

    da_caixa = listar(light: true, inbox_id: @quieta.id, per_page: 200)
    assert_equal antigas.map(&:id).sort, da_caixa.map { |c| c['id'] }.sort
    assert(da_caixa.all? { |c| c['inbox_id'] == @quieta.id })
  end

  test 'ordem: atividade mais recente primeiro, sem atividade por último' do
    velha = conversa(@quieta, 'Velha', atividade: 5.days.ago)
    nova = conversa(@quieta, 'Nova', atividade: 1.hour.ago)
    sem_atividade = conversa(@quieta, 'Sem atividade', atividade: 1.day.ago)
    sem_atividade.update_columns(last_activity_at: nil)

    lista = listar(light: true, inbox_id: @quieta.id)

    assert_equal [nova.id, velha.id, sem_atividade.id], lista.map { |c| c['id'] }
  end

  test 'páginas não repetem nem pulam conversa (inclusive com atividade empatada)' do
    mesmo_instante = 2.hours.ago
    ids = 7.times.map { |i| conversa(@quieta, "Empate #{i}", atividade: mesmo_instante).id }

    vistos = (1..4).flat_map do |pagina|
      listar(light: true, inbox_id: @quieta.id, per_page: 3, page: pagina).map { |c| c['id'] }
    end

    assert_equal ids.sort, vistos.sort
    assert_equal vistos.uniq.size, vistos.size
  end

  test 'modo lista: só a última mensagem, contato leve e messages_loaded false' do
    conv = conversa(@quieta, 'Maria', atividade: 1.hour.ago, mensagens: 5)

    item = listar(light: true, inbox_id: @quieta.id).first

    assert_equal conv.id, item['id']
    assert_equal ['Maria msg 5'], item['messages'].map { |m| m['text'] }
    assert_equal 'Maria msg 5', item['preview']
    assert_equal false, item['messages_loaded']
    assert_equal [], item.dig('contact', 'pedidos')
    assert_equal [], item.dig('contact', 'notes')
    assert_equal 'Maria', item.dig('contact', 'name')
    %w[inbox_name assignee unread tags last_activity_iso].each { |k| assert item.key?(k), "faltou #{k}" }
  end

  test 'sem light a resposta continua completa como antes' do
    conversa(@quieta, 'Maria', atividade: 1.hour.ago, mensagens: 4)

    item = listar.first

    assert_equal 4, item['messages'].size
    assert_equal true, item['messages_loaded']
  end

  test 'conversa sem mensagem aparece na lista sem quebrar' do
    conversa(@quieta, 'Vazia', atividade: 1.hour.ago, mensagens: 0)

    item = listar(light: true, inbox_id: @quieta.id).first

    assert_equal [], item['messages']
    assert_equal 'Nova Conversa', item['preview']
  end

  test 'consultora não vê conversa de caixa que não é dela nem pedindo pelo inbox_id' do
    propria = conversa(@quieta, 'Minha', atividade: 1.hour.ago, user: @consultora)
    conversa(@movimentada, 'De outra caixa', atividade: 1.hour.ago)

    assert_empty listar(como: @consultora, light: true, inbox_id: @movimentada.id)
    assert_equal [propria.id], listar(como: @consultora, light: true, inbox_id: @quieta.id).map { |c| c['id'] }
  end

  test 'per_page acima do limite é travado e não quebra' do
    conversa(@quieta, 'Uma', atividade: 1.hour.ago)

    assert_equal 1, listar(light: true, per_page: 100_000).size
  end
end
