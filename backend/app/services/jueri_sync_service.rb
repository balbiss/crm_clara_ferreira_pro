# Sincroniza revendedoras + histórico de pedidos do Jueri pro CRM (briefing
# seções 11, 25, 29.1-29.2; revendedoras-ativas-criterios.md).
#
# Fase "Worker" — diferente da versão anterior (que só somava pedidos Aberto em
# memória e descartava tudo depois), agora:
#   1. busca TODO o histórico de pedidos (qualquer status), não só os abertos —
#      necessário pra Time Travel funcionar de verdade (uma data no passado só
#      é reconstruível se a gente tiver o data_baixa/data_cancelamento reais);
#   2. persiste cada pedido na tabela `pedidos` (upsert por jueri_pedido_id,
#      idempotente — rodar de novo não duplica nada);
#   3. persiste telefones adicionais direto em `reseller_phones`;
#   4. recalcula o snapshot (pecas_abertas_atual/pedidos_abertos_count) a
#      partir do que ficou salvo, respeitando min_pecas_ativa e overrides
#      manuais (Resgate/Desconsiderado nunca reativam sozinhos);
#   5. registra marcos de ciclo de vida (Iniciada/Churn/Reativação).
#
# Não existe filtro por revendedor nem por status no endpoint /pedido da forma
# que precisaríamos (confirmado testando a API) — a estratégia possível é
# puxar TODOS os pedidos paginados e agrupar por fk_revendedor_id no lado de cá.
#
# IMPORTANTE (rate limit): a chamada cara e limitada é `find_revendedor`
# (detalhe cadastral, 1 request por revendedor). Ela só pode rodar pra um
# conjunto PEQUENO e limitado — quem está cruzando o limiar de ativação AGORA
# (criação nova ou reativação). NUNCA rodar find_revendedor pra toda a base de
# contatos já existente (300+ contatos) a cada ciclo — isso é o que estourava
# o 429 documentado ("depois de ~300 chamadas em rajada"). Persistir pedido e
# recalcular snapshot pra quem JÁ é Contact não precisa de find_revendedor —
# usa só o que já veio na busca em lote de pedidos (zero custo de rate limit).
#
# Não mexe no status de quem já está em ciclo ativo (revendedor_ativo/terceiro_dia/
# etc.) — isso é papel do ReguaAutoAdvanceJob. Aqui só cria revendedora nova,
# reativa quem estava inativa e voltou a ter maleta em aberto, ou desativa quem
# não tem mais pedido acima do limiar (Sem Maleta).
class JueriSyncService
  PEDIDOS_PER_PAGE = 500

  # A API do Jueri devolve o status do pedido como STRING em `status` (não um
  # código numérico em `fk_status_pedido_id` como o briefing original sugeria
  # — confirmado inspecionando a resposta real). Mapeia pro status_id interno
  # que usamos em `Pedido` (1-Aberto/2-Baixado/3-Cancelado/4-Perdido).
  STATUS_LABEL_TO_ID = {
    'Aberto' => Pedido::STATUS_ABERTO,
    'Baixado' => Pedido::STATUS_BAIXADO,
    'Cancelado' => Pedido::STATUS_CANCELADO,
    'Perdido' => Pedido::STATUS_PERDIDO
  }.freeze
  # Jueri limita a taxa de requisições (visto na prática: 429 depois de ~300 chamadas
  # em rajada) — espaça as buscas de cadastro completo pra não estourar o limite.
  PAUSA_ENTRE_CHAMADAS = 0.3

  def initialize(account:)
    @account = account
    @service = JueriApiService.new
  end

  def call
    resultado = { criados: 0, reativados: 0, atualizados: 0, sem_maleta: 0, pedidos_sincronizados: 0, erros: 0 }

    pedidos_por_revendedor = buscar_todo_historico_de_pedidos
    limiar = @account.min_pecas_ativa
    contatos_existentes = @account.contacts.where.not(id_jueri: nil).index_by(&:id_jueri)

    ids_ativos_agora = pedidos_por_revendedor.keys.select do |id_jueri|
      soma_pecas_abertas(pedidos_por_revendedor[id_jueri]) > limiar
    end.map(&:to_s)

    # --- Passo 1: pedidos + snapshot pra quem JÁ é Contact — sem custo de API,
    # só grava o que já veio na busca em lote. Cobre tanto ativos quanto
    # inativos (uma revendedora inativa pode ter um pedido antigo que mudou de
    # status desde a última sincronização).
    pedidos_por_revendedor.each do |id_jueri, pedidos_raw|
      contact = contatos_existentes[id_jueri.to_s]
      next unless contact

      persistir_pedidos(contact, pedidos_raw, resultado)
      recalcular_snapshot(contact)
    rescue => e
      Rails.logger.error("[JueriSyncService] Falha ao persistir pedidos do contato #{contact&.id}: #{e.message}")
      resultado[:erros] += 1
    end

    # --- Passo 2: transição de status (cria/reativa) — só pra quem está
    # cruzando o limiar AGORA. É o único passo que pode chamar find_revendedor,
    # por isso fica num conjunto pequeno e com PAUSA_ENTRE_CHAMADAS.
    ids_ativos_agora.each_with_index do |id_jueri, index|
      sleep(PAUSA_ENTRE_CHAMADAS) if index.positive?
      transicionar_status(id_jueri, pedidos_por_revendedor[id_jueri], contatos_existentes[id_jueri.to_s], resultado)
    rescue JueriApiService::ApiError => e
      Rails.logger.error("[JueriSyncService] Falha ao sincronizar revendedor #{id_jueri}: #{e.message}")
      resultado[:erros] += 1
    end

    # --- Passo 3: quem estava ativa e não está mais na lista de "acima do
    # limiar agora" fez o acerto e não levou nova maleta — vira Sem Maleta.
    marcar_sem_maleta(ids_ativos_agora, resultado)

    resultado
  end

  private

  # ---- Busca (fonte: API do Jueri) ---------------------------------------

  def buscar_todo_historico_de_pedidos
    pedidos_por_revendedor = Hash.new { |h, k| h[k] = [] }

    page = 1
    loop do
      # Sem filtro de status: precisamos do histórico completo (Baixado/
      # Cancelado/Perdido também), não só Aberto — é o que viabiliza Time Travel.
      response = @service.pedidos(page: page, per_page: PEDIDOS_PER_PAGE)
      items = response['data'] || []
      break if items.empty?

      items.each do |pedido|
        rid = pedido['fk_revendedor_id']
        next if rid.blank?
        # Chave sempre string — o Jueri devolve fk_revendedor_id como Integer
        # no JSON, mas id_jueri (Contact) e ids_ativos_agora (.map(&:to_s))
        # são strings. Sem normalizar aqui, o lookup em pedidos_por_revendedor
        # no Passo 2 (linha ~87) batia com o Hash.new autovivificador e
        # devolvia [] silenciosamente pra revendedora recém-criada — pedidos
        # nunca eram persistidos e pecas_abertas_atual/dias com maleta ficavam
        # zerados pra sempre (bug real encontrado testando com dados reais).
        pedidos_por_revendedor[rid.to_s] << pedido
      end

      break if response['next_page_url'].blank?
      page += 1
    end

    pedidos_por_revendedor
  end

  def soma_pecas_abertas(pedidos_raw)
    pedidos_raw.select { |p| status_aberto?(p) }.sum { |p| quantidade_efetiva_raw(p) }
  end

  def status_id_de(p)
    id = STATUS_LABEL_TO_ID[p['status']]
    if id.nil?
      Rails.logger.warn("[JueriSyncService] status de pedido não mapeado: #{p['status'].inspect} (pedido id=#{p['id']}) — tratando como Aberto")
      id = Pedido::STATUS_ABERTO
    end
    id
  end

  def status_aberto?(p)
    status_id_de(p) == Pedido::STATUS_ABERTO
  end

  def quantidade_efetiva_raw(p)
    Pedido.quantidade_efetiva_para(
      data_criacao: parse_date(p['data_criacao']),
      data_baixa: parse_date(p['data_baixa']),
      quantidade: p['quantidade'],
      quantidade_antes_baixa: p['quantidade_antes_baixa']
    )
  end

  # ---- Transição de status (só pro conjunto ativo-agora, com find_revendedor) --

  def transicionar_status(id_jueri, pedidos_raw, contact, resultado)
    if contact.nil?
      revendedor = @service.find_revendedor(id_jueri)
      contact = build_contact(id_jueri, revendedor)
      contact.status = 'revendedor_ativo'
      contact.cycle_started_at = inicio_ciclo(pedidos_raw)
      contact.save!
      persistir_pedidos(contact, pedidos_raw, resultado)
      persistir_telefones(contact, revendedor)
      recalcular_snapshot(contact)
      criar_evento(contact, 'iniciada')
      resultado[:criados] += 1
    elsif contact.desconsiderado? || Contact::STATUS_OVERRIDE_PERMANENTE.include?(contact.status)
      # Blacklist manual, Resgate, Negativado/Jurídico e Descadastrada são
      # overrides permanentes — nunca reativam sozinhos, mesmo com pedido em
      # aberto no Jueri (briefing seção 19/29.9). Cadastro e pedidos já foram
      # atualizados no Passo 1, não precisa de find_revendedor.
      resultado[:atualizados] += 1
    elsif Contact::INACTIVE_STATUSES.include?(contact.status)
      # Marco "reativacao" (lifecycle_events) só é registrado se ela cumpre a
      # definição de verdade (briefing seção 20 / Tech Lead): 60+ dias inativa
      # E sem pendência financeira. Uma revendedora que volta rápido (poucos
      # dias sem maleta) ainda vira Ativa normalmente, só não gera o marco
      # histórico de "Reativação" — captura o status/tempo ANTES de sobrescrever.
      dias_inativa = contact.status_changed_at && (Date.current - contact.status_changed_at.to_date).to_i
      elegivel_marco_reativacao = contact.status != 'inativa_pendencia' &&
        dias_inativa && dias_inativa >= Contact::DIAS_MINIMOS_PARA_REATIVACAO

      contact.status = 'revendedor_ativo'
      contact.cycle_started_at = inicio_ciclo(pedidos_raw)
      contact.save!
      criar_evento(contact, 'reativacao') if elegivel_marco_reativacao
      resultado[:reativados] += 1
    else
      resultado[:atualizados] += 1
    end
  end

  # ---- Pedidos (persistência real, fase Worker) ---------------------------

  # upsert_all em lote em vez de find_or_initialize_by + save! um por um —
  # com histórico completo (23k+ pedidos no total da conta), fazer isso
  # registro a registro seria centenas de milhares de queries por ciclo.
  # upsert_all vira 1 INSERT ... ON CONFLICT por lote de 500, ordens de
  # grandeza mais rápido (requisito de performance da fase).
  def persistir_pedidos(contact, pedidos_raw, resultado)
    agora = Time.current
    rows = pedidos_raw.filter_map do |p|
      jueri_id = p['id'].to_s
      next if jueri_id.blank?
      {
        jueri_pedido_id: jueri_id,
        account_id: @account.id,
        contact_id: contact.id,
        data_criacao: parse_date(p['data_criacao']),
        data_baixa: parse_date(p['data_baixa']),
        data_cancelamento: parse_date(p['data_cancelamento']),
        status_id: status_id_de(p),
        quantidade: (p['quantidade'] || 0).to_i,
        quantidade_antes_baixa: p['quantidade_antes_baixa'].presence&.to_i,
        valor_total: p['valor_total'].presence,
        created_at: agora,
        updated_at: agora
      }
    end
    return if rows.empty?

    rows.each_slice(500) do |slice|
      # updated_at NÃO entra em update_only — o Rails já cuida dela sozinho
      # (record_timestamps), listar de novo aqui gera "multiple assignments to
      # same column updated_at" no Postgres.
      Pedido.upsert_all(slice, unique_by: :jueri_pedido_id, update_only: %i[
        contact_id data_criacao data_baixa data_cancelamento status_id
        quantidade quantidade_antes_baixa valor_total
      ])
    end
    resultado[:pedidos_sincronizados] += rows.size
  end

  # ---- Snapshot pré-calculado (requisito de performance) ------------------

  def recalcular_snapshot(contact)
    abertos = contact.pedidos.open_now.to_a
    contact.update_columns(
      pecas_abertas_atual: abertos.sum(&:quantidade_efetiva),
      pedidos_abertos_count: abertos.size,
      snapshot_calculado_em: Time.current
    )
  end

  # ---- Marcos de ciclo de vida (Iniciada/Churn/Reativação) ----------------

  def criar_evento(contact, tipo)
    return if tipo == 'iniciada' && LifecycleEvent.exists?(contact_id: contact.id, event_type: 'iniciada')
    LifecycleEvent.create!(
      account: @account, contact: contact, event_type: tipo, occurred_at: Time.current,
      metadata: { pecas_abertas: contact.pecas_abertas_atual }
    )
  end

  # Briefing seção 16/29.6: revendedora que estava em ciclo ativo e deixou de ter
  # pedido aberto acima do limiar fez o acerto e não levou nova maleta — vira
  # "Sem Maleta". Não mexe em quem está em status manual (Resgate/Negativado/etc,
  # cobertos por INACTIVE_STATUSES e por isso já fora do filtro abaixo).
  def marcar_sem_maleta(ids_jueri_ativos_agora, resultado)
    @account.contacts
      .where(status: Contact::ACTIVE_STATUSES)
      .where.not(id_jueri: nil)
      .where.not(id_jueri: ids_jueri_ativos_agora)
      .find_each do |contact|
        pecas_antes = contact.pecas_abertas_atual
        contact.update!(status: 'sem_maleta')
        recalcular_snapshot(contact)
        LifecycleEvent.create!(
          account: @account, contact: contact, event_type: 'churn', occurred_at: Time.current,
          metadata: { pecas_antes: pecas_antes, pecas_depois: contact.reload.pecas_abertas_atual }
        )
        resultado[:sem_maleta] += 1
      end
  end

  # ---- Cadastro (dados do Jueri, sem relação com pedidos) -----------------

  def build_contact(id_jueri, revendedor)
    contact = @account.contacts.new(id_jueri: id_jueri.to_s, source: 'Jueri')
    apply_revendedor_attrs(contact, revendedor)
    contact
  end

  def apply_revendedor_attrs(contact, revendedor)
    nome = revendedor['nome'].to_s
    primeiro, *resto = nome.split(' ')

    contact.first_name = primeiro.presence || contact.first_name
    contact.last_name = resto.join(' ').presence || contact.last_name
    contact.name = nome.presence || contact.name
    contact.email = revendedor['email'].presence || contact.email
    contact.cpf = revendedor['cpf'].presence || contact.cpf
    contact.birth_date = parse_date(revendedor['data_nascimento']) || contact.birth_date
    contact.cep = revendedor['cep'].presence || contact.cep
    contact.street = revendedor['logradouro'].presence || contact.street
    contact.address_number = revendedor['numero'].to_s.presence || contact.address_number
    contact.address_complement = revendedor['complemento'].presence || contact.address_complement
    contact.neighborhood = revendedor['bairro'].presence || contact.neighborhood
    contact.city = revendedor['cidade'].presence || contact.city
    contact.state = revendedor['uf'].presence || contact.state
    contact.country = 'Brasil'
    contact.jueri_synced_at = Time.current

    telefone_principal = formatar_telefone(revendedor['telefone_1'])
    contact.phone = telefone_principal if telefone_principal.present? && contact.phone.blank?

    contact.custom_attributes = (contact.custom_attributes || {}).merge(
      'origem' => 'Sincronizado do Jueri',
      'id_jueri' => contact.id_jueri,
      'meta' => revendedor['meta_mensal'].present? ? "R$ #{format('%.2f', revendedor['meta_mensal'].to_f).tr('.', ',')}" : contact.custom_attributes&.dig('meta')
    )
  end

  # Telefones adicionais persistidos DIRETO em reseller_phones (não passa mais
  # pelo jsonb — diferente do que o EditContactModal faz, que ainda manda por
  # custom_attributes.telefones_adicionais e o model intercepta/traduz). Só
  # roda no momento de criação (junto com find_revendedor), não recorrente.
  def persistir_telefones(contact, revendedor)
    [revendedor['telefone_2'], revendedor['telefone_3']].each do |raw|
      numero = formatar_telefone(raw)
      next if numero.blank? || numero == contact.phone
      contact.reseller_phones.find_or_create_by!(phone: numero)
    end
  end

  def inicio_ciclo(pedidos_raw)
    datas = pedidos_raw.select { |p| status_aberto?(p) }.map { |p| parse_datetime(p['data_criacao']) }.compact
    datas.min || Time.current
  end

  def formatar_telefone(raw)
    return nil if raw.blank?
    digitos = raw.to_s.gsub(/\D/, '')
    return nil if digitos.blank?
    digitos = "55#{digitos}" unless digitos.start_with?('55')
    "+#{digitos}"
  end

  def parse_date(str)
    return nil if str.blank?
    Date.parse(str.to_s)
  rescue ArgumentError
    nil
  end

  def parse_datetime(str)
    Time.zone.parse(str.to_s) if str.present?
  rescue ArgumentError
    nil
  end
end
