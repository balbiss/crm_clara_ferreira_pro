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
  REVENDEDORES_PER_PAGE = 500

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

  # O endpoint /revendedor mistura revendedora de verdade com outras categorias
  # que usam o mesmo cadastro por falta de campo próprio no Jueri (confirmado
  # pelo cliente por vídeo, 2026-08-07): "Caução" (cadastro de responsável/
  # cônjuge que assina/paga por uma revendedora menor de idade, não é ela
  # mesma) e "Colaborador" (funcionário interno) — nenhum dos dois é cliente,
  # nunca viram Contact nem contam pedido pra ativação. "Atacado" (compra à
  # vista, fora do modelo consignado) É cliente de verdade, só que fora da
  # régua consignada — vira Contact com status próprio ('atacado'), fora das
  # telas de carteira Ativa/Inativa (achado real: 2 "Atacado" e 1
  # "Colaborador" já tinham virado "revendedor_ativo" por engano antes desta
  # correção).
  NIVEIS_EXCLUIR_COMPLETAMENTE = ['Caução', 'Colaborador'].freeze
  NIVEL_ATACADO = 'Atacado'.freeze

  def initialize(account:)
    @account = account
    @service = JueriApiService.new
    @gerente_nome_cache = {}
    # Mapeamento ID do gerente no Jueri -> usuário do CRM (diretoria configura
    # em Agentes, um por um, com o ID que a Clara passa). Carregado 1x por
    # ciclo — é só uma query, não custa nada de rate limit da API do Jueri.
    @gerente_user_map = @account.users.where.not(jueri_gerente_id: [nil, '']).index_by(&:jueri_gerente_id)
  end

  def call
    resultado = { criados: 0, reativados: 0, atualizados: 0, sem_maleta: 0, pedidos_sincronizados: 0, erros: 0 }

    # Busca o cadastro em lote ANTES dos pedidos — precisamos saber quem é
    # gerente/operador (fk_tipo_revendedor_id=1) pra nunca deixar entrar como
    # revendedora (revendedoras-ativas-criterios.md, seção "Exclusões
    # Automáticas": "Gerentes / carteiras são operadores, não revendedoras").
    # Reaproveitado depois no Passo 4, não busca a listagem duas vezes.
    cadastro_por_revendedor = buscar_todo_cadastro_de_revendedores
    operador_ids = cadastro_por_revendedor.select { |_, r| r['fk_tipo_revendedor_id'] == 1 }.keys
    excluir_ids = cadastro_por_revendedor.select { |_, r| NIVEIS_EXCLUIR_COMPLETAMENTE.include?(r['level_revendedor']) }.keys
    atacado_ids = cadastro_por_revendedor.select { |_, r| r['level_revendedor'] == NIVEL_ATACADO }.keys

    # Catálogo dos "times de vendas" (Vendas 1, Vendas 4 etc) — mesmo lote já
    # buscado acima, zero custo extra de API. Usado pela tela de gestão de
    # acesso (SalesTeamsController) e pra expandir a carteira visível de quem
    # tem membership num time (ver visible_contacts_scope).
    sincronizar_times_de_vendas(cadastro_por_revendedor, operador_ids)

    # Atacado é cliente de verdade, só que fora da régua consignada — cadastro
    # simples (sem pedido/régua), status fixo 'atacado', nunca entra no cálculo
    # de ativação abaixo.
    sincronizar_atacado(cadastro_por_revendedor, atacado_ids, resultado)

    pedidos_por_revendedor = buscar_todo_historico_de_pedidos.except(*operador_ids, *excluir_ids, *atacado_ids)
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

    # --- Passo 4: refresca cadastro (nível, RG, profissão, observações etc)
    # de TODAS as revendedoras já existentes — não só das novas. Reaproveita
    # o cadastro já buscado no início do método (não busca de novo).
    atualizar_cadastro_existentes(cadastro_por_revendedor, contatos_existentes, resultado)

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

  # Cadastro completo (nível, RG, profissão, observações etc) em lote — igual
  # à busca de pedidos, sem custo de find_revendedor por revendedora.
  def buscar_todo_cadastro_de_revendedores
    cadastro_por_revendedor = {}

    page = 1
    loop do
      response = @service.revendedores(page: page, per_page: REVENDEDORES_PER_PAGE)
      items = response['data'] || []
      break if items.empty?

      items.each do |revendedor|
        id = revendedor['id']
        next if id.blank?
        cadastro_por_revendedor[id.to_s] = revendedor
      end

      break if response['next_page_url'].blank?
      page += 1
    end

    cadastro_por_revendedor
  end

  # Catalogo dos revendedor-líder (fk_tipo_revendedor_id=1) como SalesTeam, e
  # dá acesso automático ao time pra quem já está mapeado via jueri_gerente_id
  # (o vínculo legado 1:1 continua funcionando, só que agora também conta como
  # membro do time — sem precisar reconfigurar na tela nova de Times de Vendas).
  def sincronizar_times_de_vendas(cadastro_por_revendedor, operador_ids)
    operador_ids.each do |id|
      revendedor = cadastro_por_revendedor[id]
      nome = revendedor['nome'].presence || "Time #{id}"

      team = SalesTeam.find_or_initialize_by(account: @account, jueri_lider_id: id)
      team.nome = nome
      team.save! if team.new_record? || team.changed?

      mapped_user = @gerente_user_map[id]
      next unless mapped_user

      SalesTeamMembership.find_or_create_by!(sales_team: team, user: mapped_user)
    rescue => e
      Rails.logger.error("[JueriSyncService] Falha ao sincronizar time de vendas #{id}: #{e.message}")
    end
  end

  # Atacado (compra à vista, fora do consignado) é cliente de verdade da
  # empresa — vira Contact igual a uma revendedora, só que com status fixo
  # 'atacado' (fora de ACTIVE_STATUSES/INACTIVE_STATUSES, então nunca entra
  # na régua nem nas telas de Carteira Ativa/Inativa — tela própria no
  # frontend). Cadastro simples: sem pedido/snapshot, não precisa de
  # find_revendedor (já veio tudo no lote de buscar_todo_cadastro_de_revendedores).
  def sincronizar_atacado(cadastro_por_revendedor, atacado_ids, resultado)
    atacado_ids.each do |id|
      revendedor = cadastro_por_revendedor[id]
      contact = @account.contacts.find_or_initialize_by(id_jueri: id.to_s)
      is_new = contact.new_record?
      apply_revendedor_attrs(contact, revendedor)
      contact.source = 'Jueri' if contact.source.blank?
      contact.status = 'atacado'
      next unless contact.new_record? || contact.changed?

      contact.save!
      if is_new
        resultado[:criados] += 1
        # Cliente atacado novo cai sozinho no pipeline Atacado, na 1ª etapa —
        # pedido explícito do cliente, senão ninguém sabe que apareceu.
        criar_card_pipeline(contact, pipeline_slug: 'atacado')
      end
    rescue => e
      Rails.logger.error("[JueriSyncService] Falha ao sincronizar Atacado #{id}: #{e.message}")
      resultado[:erros] += 1
    end
  end

  # Cria o card no pipeline manual (Kanban tipo Kommo) só na primeira vez —
  # se o contato já tiver card nesse pipeline, não mexe (a equipe pode já
  # ter movido pra outra etapa, não é pra resetar o progresso dela).
  def criar_card_pipeline(contact, pipeline_slug:, stage_name: nil)
    pipeline = @account.pipelines.find_by(slug: pipeline_slug)
    return unless pipeline

    stage = stage_name.present? ? pipeline.pipeline_stages.find_by(name: stage_name) : pipeline.pipeline_stages.order(:position).first
    return unless stage

    return if PipelineCard.exists?(pipeline_id: pipeline.id, contact_id: contact.id)
    PipelineCard.create!(pipeline: pipeline, contact: contact, pipeline_stage: stage)
  rescue => e
    Rails.logger.error("[JueriSyncService] Falha ao criar card no pipeline '#{pipeline_slug}' pro contato #{contact.id}: #{e.message}")
  end

  def atualizar_cadastro_existentes(cadastro_por_revendedor, contatos_existentes, resultado)
    contatos_existentes.each do |id_jueri, contact|
      revendedor = cadastro_por_revendedor[id_jueri.to_s]
      next unless revendedor

      apply_revendedor_attrs(contact, revendedor)
      contact.save! if contact.changed?
    rescue => e
      Rails.logger.error("[JueriSyncService] Falha ao atualizar cadastro do contato #{contact.id}: #{e.message}")
      resultado[:erros] += 1
    end
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
      # 1ª vez que essa revendedora leva maleta de verdade — cai sozinha no
      # pipeline Onboarding, na etapa "Primeira Maleta" (pedido explícito do
      # cliente pra parar de depender de alguém lembrar de criar o card à
      # mão). Reativação (branch abaixo) não repete isso: ela já teve a
      # primeira maleta antes.
      criar_card_pipeline(contact, pipeline_slug: 'onboarding', stage_name: 'Primeira Maleta')
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
    # "Nível" (Consignado/Colaborador/Caução/Safira/Rubi/Esmeralda/Diamante) —
    # já vem resolvido (texto, não ID) no `level_revendedor` da listagem em
    # lote, sem custo de request extra. Coluna dedicada (não custom_attributes)
    # pra dar pra filtrar/indexar (usado na fila de Acertos do Agendamento).
    contact.nivel = revendedor['level_revendedor'].presence || contact.nivel

    telefone_principal = formatar_telefone(revendedor['telefone_1'])
    contact.phone = telefone_principal if telefone_principal.present? && contact.phone.blank?

    gerente_id = revendedor['gerente'] || revendedor['fk_revendedor_gerente_id']

    # Atribuição por mapeamento real (não é rodízio/sorteio, ver briefing):
    # se a Clara já configurou o ID desse gerente do Jueri num usuário daqui
    # (Agentes > ID do Gerente no Jueri), a revendedora cai direto pra ele.
    # Só se AINDA não tiver responsável — nunca sobrescreve atribuição ou
    # transferência manual de quem já tem user_id setado (isso é decisão do
    # gerente, roda tanto na criação quanto no refresh de cadastro existente).
    mapped_user = @gerente_user_map[gerente_id.to_s] if gerente_id.present?
    contact.user_id = mapped_user.id if mapped_user && contact.user_id.nil?

    custom = contact.custom_attributes || {}
    old = ->(key) { custom[key] }
    contact.custom_attributes = custom.merge(
      'origem' => custom['origem'] || 'Sincronizado do Jueri',
      'id_jueri' => contact.id_jueri,
      'gerente_jueri_id' => gerente_id,
      'gerente_jueri_nome' => resolve_gerente_nome(gerente_id) || old.call('gerente_jueri_nome'),
      'meta' => revendedor['meta_mensal'].present? ? "R$ #{format('%.2f', revendedor['meta_mensal'].to_f).tr('.', ',')}" : old.call('meta'),
      'rg' => revendedor['rg'].presence || old.call('rg'),
      'profissao' => revendedor['profissao'].presence || old.call('profissao'),
      'razao_social' => revendedor['razao_social'].presence || old.call('razao_social'),
      'nome_fantasia' => revendedor['nome_fantasia'].presence || old.call('nome_fantasia'),
      'cnpj' => revendedor['cnpj'].presence || old.call('cnpj'),
      'observacao_jueri' => revendedor['observacao'].presence || old.call('observacao_jueri'),
      'observacao_interna_jueri' => revendedor['observacao_interna'].presence || old.call('observacao_interna_jueri'),
      'supervisor_nome' => revendedor['supervisor_nome'].presence || old.call('supervisor_nome'),
      'data_inativacao_jueri' => revendedor['data_inativacao'].presence || old.call('data_inativacao_jueri'),
      # Resto do cadastro do Jueri que ainda não tinha lugar nenhum aqui —
      # pedido explícito do cliente pra trazer tudo, não só um recorte.
      'local_trabalho' => revendedor['local'].presence || old.call('local_trabalho'),
      'website_jueri' => revendedor['website'].presence || old.call('website_jueri'),
      'referencia_nome' => revendedor['referencia_nome'].presence || old.call('referencia_nome'),
      'referencia_telefone' => (revendedor['referencia_celular'].presence || revendedor['referencia_telefone'].presence) || old.call('referencia_telefone'),
      'status_cadastral_jueri' => resolve_status_cadastral(revendedor['fk_status_id']) || old.call('status_cadastral_jueri'),
      'data_criacao_jueri' => revendedor['data_criacao'].presence || old.call('data_criacao_jueri'),
      'data_ultima_alteracao_jueri' => revendedor['data_ultima_alteracao'].presence || old.call('data_ultima_alteracao_jueri')
    )
  end

  # fk_status_id no Jueri é o status CADASTRAL (1-Ativo/2-Inativo), não tem
  # relação nenhuma com a régua do CRM (Contact#status) — não confundir os
  # dois em lugar nenhum, são conceitos diferentes com o mesmo nome.
  def resolve_status_cadastral(fk_status_id)
    { 1 => 'Ativo', 2 => 'Inativo' }[fk_status_id]
  end

  # Resolve o nome do gerente/hierarquia do Jueri (campo `gerente`/
  # `fk_revendedor_gerente_id` no cadastro do revendedor é só um ID interno,
  # sem nome junto — precisa de outra chamada em find_revendedor pra pegar o
  # nome). Cacheado por execução do sync: várias revendedoras costumam
  # compartilhar o mesmo gerente, então isso não vira 1 chamada extra por
  # revendedora, e sim 1 por gerente único encontrado na rodada.
  def resolve_gerente_nome(gerente_id)
    return nil if gerente_id.blank?
    return @gerente_nome_cache[gerente_id] if @gerente_nome_cache.key?(gerente_id)

    nome = @service.find_revendedor(gerente_id)['nome']
    @gerente_nome_cache[gerente_id] = nome
  rescue JueriApiService::ApiError => e
    Rails.logger.warn("[JueriSyncService] Falha ao resolver nome do gerente #{gerente_id}: #{e.message}")
    @gerente_nome_cache[gerente_id] = nil
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
