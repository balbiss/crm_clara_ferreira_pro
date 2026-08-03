# Engine de Time Travel (revendedoras-ativas-criterios.md) — reconstrói o
# snapshot de "quem está Ativa" em qualquer data D, passada ou presente.
#
# Duas estratégias, escolhidas pra bater o requisito de <200ms:
#   - D == hoje: lê as colunas de snapshot já pré-calculadas pelo Worker de
#     sync (pecas_abertas_atual) — nenhuma query em `pedidos`, é literalmente
#     um SELECT indexado em `contacts`.
#   - D no passado: não dá pra usar o snapshot (ele só reflete HOJE) — precisa
#     reconstruir via `pedidos.open_at(D)`, agregado em UMA query SQL (SUM +
#     GROUP BY direto no banco, usando os índices compostos/parciais da tabela
#     pedidos), não carregando registro por registro pro Ruby.
#
# Overrides manuais (Resgate/Negativado/Descadastrada e blacklist) SEMPRE
# excluem a revendedora do resultado, mesmo que o cálculo de pedidos desse
# "ativa" — é uma decisão operacional permanente, não uma característica de
# uma data específica (seção 19/29.9 do briefing, confirmado pelo Tech Lead).
class AtivasSnapshotService
  # contacts_scope: já deve vir filtrado por RBAC (ver ContactsController)
  def initialize(contacts_scope:, min_pecas_ativa:, data: nil)
    @contacts_scope = contacts_scope
    @min_pecas_ativa = min_pecas_ativa
    @data = (data || Date.current).to_date
  end

  def call
    hoje? ? ativas_de_hoje : ativas_em_data_passada
  end

  def hoje?
    @data == Date.current
  end

  private

  def elegiveis
    @contacts_scope.not_blacklisted.where.not(status: Contact::STATUS_OVERRIDE_PERMANENTE)
  end

  def ativas_de_hoje
    elegiveis
      .where('pecas_abertas_atual > ?', @min_pecas_ativa)
      .order(pecas_abertas_atual: :desc)
      .map { |c| montar_linha(c, c.pecas_abertas_atual, c.pedidos_abertos_count) }
  end

  def ativas_em_data_passada
    agregados = Pedido.joins(:contact)
      .merge(elegiveis)
      .open_at(@data)
      .group(:contact_id)
      .having("SUM(#{Pedido::QUANTIDADE_EFETIVA_SQL}) > ?", @min_pecas_ativa)
      .pluck(:contact_id, Arel.sql("SUM(#{Pedido::QUANTIDADE_EFETIVA_SQL})::integer"), Arel.sql('COUNT(*)'))

    return [] if agregados.empty?

    pecas_por_id  = agregados.to_h { |id, pecas, _| [id, pecas] }
    contagem_por_id = agregados.to_h { |id, _, count| [id, count] }

    Contact.where(id: agregados.map(&:first))
      .sort_by { |c| -pecas_por_id[c.id] }
      .map { |c| montar_linha(c, pecas_por_id[c.id], contagem_por_id[c.id]) }
  end

  def montar_linha(contact, pecas_abertas, pedidos_abertos_count)
    {
      id: contact.id,
      name: contact.name,
      phone: contact.phone,
      status: contact.status,
      user_id: contact.user_id,
      pecas_abertas: pecas_abertas,
      pedidos_abertos_count: pedidos_abertos_count,
      data_referencia: @data
    }
  end
end
