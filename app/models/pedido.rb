# Pedido consignado importado do Jueri (fonte oficial da verdade). Persistido
# localmente pra viabilizar Time Travel (revendedoras-ativas-criterios.md) —
# sem histórico local não dá pra reconstruir "estava aberto em D?" pra uma
# data no passado, já que a API do Jueri só reflete o estado atual.
class Pedido < ApplicationRecord
  belongs_to :account
  belongs_to :contact

  # status_id do Jueri
  STATUS_ABERTO      = 1
  STATUS_BAIXADO      = 2
  STATUS_CANCELADO    = 3
  STATUS_PERDIDO      = 4
  STATUS_TERMINAIS_EXCLUIDOS = [STATUS_CANCELADO, STATUS_PERDIDO].freeze

  # A partir desta data o Jueri passou a gravar quantidade_antes_baixa de
  # verdade. Pedidos baixados antes disso sem esse campo usam o sentinela.
  CUTOFF_LEGADO = Date.new(2025, 5, 1)
  QUANTIDADE_SENTINELA_LEGADO = 999

  validates :jueri_pedido_id, presence: true, uniqueness: true
  validates :data_criacao, presence: true
  validates :status_id, presence: true

  # Pedido "aberto na data D" (revendedoras-ativas-criterios.md):
  # 1. criado até D
  # 2. não baixado até D (baixa nula OU depois de D)
  # 3. não cancelado até D (cancelamento nulo OU depois de D)
  # 4. status não é terminal (Cancelado/Perdido nunca contam, mesmo com datas em branco)
  scope :open_at, ->(date) {
    where("data_criacao <= ?", date)
      .where("data_baixa IS NULL OR data_baixa > ?", date)
      .where("data_cancelamento IS NULL OR data_cancelamento > ?", date)
      .where.not(status_id: STATUS_TERMINAIS_EXCLUIDOS)
  }

  scope :open_now, -> { open_at(Date.current) }

  # Mesma regra de quantidade_efetiva_para, só que como fragmento SQL puro —
  # necessário pro Time Travel agregar por SUM/GROUP BY direto no banco (uma
  # query só pra milhares de pedidos) em vez de carregar registro por registro
  # pro Ruby e somar em memória (requisito de performance <200ms). As duas
  # implementações (Ruby e SQL) precisam ficar em sincronia — testado no
  # console comparando as duas contra a mesma amostra de dados reais.
  QUANTIDADE_EFETIVA_SQL = <<~SQL.squish.freeze
    CASE
      WHEN quantidade_antes_baixa > 0 THEN quantidade_antes_baixa
      WHEN data_baixa IS NOT NULL AND data_criacao < '#{CUTOFF_LEGADO}' AND COALESCE(quantidade_antes_baixa, 0) = 0 THEN #{QUANTIDADE_SENTINELA_LEGADO}
      ELSE quantidade
    END
  SQL

  # Qtd. a contar pra regra de ativação: Qtd. Inicial (quantidade_antes_baixa)
  # quando disponível, com fallback pra quantidade — e sentinela pra pedidos
  # legados baixados antes do Jueri gravar quantidade_antes_baixa direito.
  def quantidade_efetiva
    self.class.quantidade_efetiva_para(
      data_criacao: data_criacao, data_baixa: data_baixa,
      quantidade: quantidade, quantidade_antes_baixa: quantidade_antes_baixa
    )
  end

  # Mesma regra, mas utilizável direto sobre o hash cru vindo da API do Jueri
  # (JueriSyncService precisa decidir "essa revendedora ativa?" ANTES de
  # persistir o Pedido — não dá pra instanciar o AR sem contact_id ainda).
  def self.quantidade_efetiva_para(data_criacao:, data_baixa:, quantidade:, quantidade_antes_baixa:)
    return quantidade_antes_baixa.to_i if quantidade_antes_baixa.to_i > 0

    baixado_sem_quantidade_inicial_legado = data_baixa.present? &&
      data_criacao.present? && data_criacao.to_date < CUTOFF_LEGADO &&
      quantidade_antes_baixa.to_i.zero?

    return QUANTIDADE_SENTINELA_LEGADO if baixado_sem_quantidade_inicial_legado
    quantidade.to_i
  end
end
