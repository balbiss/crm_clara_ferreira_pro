# Tarefa real da régua operacional (briefing seção 23) — antes disso existia
# só como derivação em tempo real no frontend (status + dias no ciclo), sem
# persistência: não dava pra marcar "concluída" de verdade nem auditar quem
# fez o quê. Criada automaticamente pelo ReguaAutoAdvanceJob no exato momento
# da transição de status (3º/10º/20º dia, Atrasada).
class Tarefa < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :user, optional: true
  belongs_to :concluida_por, class_name: 'User', optional: true

  # terceiro_dia/decimo_dia/vigesimo_dia/atrasada nascem sozinhos do
  # ReguaAutoAdvanceJob. Os MANUAL_TIPOS são escolhidos por quem cria a
  # tarefa (TarefasController#create) ou por quem conclui uma e já cria o
  # follow-up (#complete) — lista inspirada no Kommo (PDF Etapa 2, página
  # 10: "no Kommo a gente podia criar vários tipos de tarefa").
  MANUAL_TIPOS = %w[manual_ligar manual_mensagem manual_agendamento manual_cobranca manual_acompanhamento manual_outro].freeze
  MANUAL_TIPO_LABELS = {
    'manual_ligar'         => 'Ligar',
    'manual_mensagem'      => 'Enviar mensagem',
    'manual_agendamento'   => 'Agendar acerto',
    'manual_cobranca'      => 'Cobrança',
    'manual_acompanhamento' => 'Acompanhamento',
    'manual_outro'         => 'Outro'
  }.freeze
  TIPOS = (%w[terceiro_dia decimo_dia vigesimo_dia atrasada] + MANUAL_TIPOS).freeze
  STATUSES = %w[pendente concluida ignorada].freeze
  PRIORIDADES = %w[normal alta urgente].freeze

  # Mesmo texto/prioridade já usados em TarefasView.vue (briefing seção 23) —
  # única fonte de verdade agora, o frontend passa a consumir isso da API.
  DEFINICOES = {
    'terceiro_dia' => {
      titulo: '3° Dia — mensagem de incentivo',
      descricao: "Mandar mensagem de incentivo\nPerguntar se conseguiu ver o catálogo\nOrientar a compartilhar fotos",
      prioridade: 'normal'
    },
    'decimo_dia' => {
      titulo: '10° Dia — acompanhar vendas',
      descricao: "Mandar mensagem de incentivo\nPerguntar como estão as vendas\nLembrar do prazo\nIdentificar possíveis dificuldades",
      prioridade: 'normal'
    },
    'vigesimo_dia' => {
      titulo: '20° Dia — agendar acerto',
      descricao: "Agendar acerto\nIncentivar a vender até o último dia\nPegar encomendas para o próximo mês\nVerificar se o mês está fraco",
      prioridade: 'alta'
    },
    'atrasada' => {
      titulo: 'Revendedora atrasada',
      descricao: "Gerar alerta de prioridade\nAcionar consultor\nRegistrar tentativa de contato\nEncaminhar para resgate/suspensão se necessário",
      prioridade: 'urgente'
    }
  }.freeze

  validates :titulo, presence: true
  validates :tipo, inclusion: { in: TIPOS }
  validates :status, inclusion: { in: STATUSES }
  validates :prioridade, inclusion: { in: PRIORIDADES }

  scope :pendentes, -> { where(status: 'pendente') }
  scope :vencidas, -> { pendentes.where('vencimento_em < ?', Time.current) }
  scope :do_dia, -> { pendentes.where(vencimento_em: Time.current.beginning_of_day..Time.current.end_of_day) }

  # Cria (ou ignora se já existe uma pendente do mesmo tipo — índice único no
  # banco garante isso mesmo em corrida) a tarefa correspondente à transição
  # de status que acabou de acontecer.
  def self.criar_para_transicao!(contact, tipo)
    return unless DEFINICOES.key?(tipo)
    def_ = DEFINICOES[tipo]
    create!(
      account_id: contact.account_id,
      contact_id: contact.id,
      user_id: contact.user_id,
      tipo: tipo,
      titulo: def_[:titulo],
      descricao: def_[:descricao],
      prioridade: def_[:prioridade],
      vencimento_em: Time.current
    )
  rescue ActiveRecord::RecordNotUnique
    nil # já existe uma pendente do mesmo tipo pra essa revendedora — não duplica
  end

  def concluir!(por:, resultado: nil)
    update!(status: 'concluida', concluida_em: Time.current, concluida_por: por, resultado: resultado)
  end
end
