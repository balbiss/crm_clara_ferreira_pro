class ContactFieldGroup < ApplicationRecord
  belongs_to :account

  validates :name, presence: true

  # Campos comerciais (aba Principal do painel de contato) que podem ser
  # organizados em grupo -- "Dados do Jueri (sincronizado)" fica de fora de
  # propósito (dado sincronizado do ERP, não pode virar editável/reagrupável
  # pelo dono, pedido explícito 2026-09-28).
  ASSIGNABLE_FIELD_KEYS = %w[
    venda proximo_agendamento limite_inicial dia_fechamento data_agendamento
    obs_fechamento dia_pf_fechamento horario_fechamento atraso
    observacao_mes meta desafio_combinado como_chegar_meta
  ].freeze

  # Sem nenhum grupo configurado ainda, a conta usa esse grupo padrão (tudo
  # junto, igual o comportamento de antes da dona poder personalizar).
  DEFAULT_GROUP_NAME = 'Principal'.freeze

  scope :ordered, -> { order(:position, :id) }

  def self.seed_default_for(account)
    return if account.contact_field_groups.exists?
    account.contact_field_groups.create!(
      name: DEFAULT_GROUP_NAME,
      position: 0,
      field_keys: ASSIGNABLE_FIELD_KEYS
    )
  end
end
