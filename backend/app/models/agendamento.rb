# Evento da agenda/calendário (compromisso, reunião, lembrete) — cada usuário
# vê e gerencia só os próprios; gerente/diretoria (full_portfolio) enxergam e
# gerenciam a agenda de todo mundo, com filtro por responsável no calendário.
class Agendamento < ApplicationRecord
  belongs_to :account
  belongs_to :user
  # Revendedora vinculada (opcional) — dá contexto ao compromisso (ex: entrega
  # de maleta ou acerto de uma revendedora específica) sem duplicar dado
  # financeiro real, que continua só em Pedido (fonte oficial, sincronizada
  # do Jueri). `valor` aqui é só o valor combinado/estimado do compromisso.
  belongs_to :contact, optional: true

  TIPOS = %w[reuniao entrega_maleta acerto outro].freeze

  validates :titulo, presence: true
  validates :inicio_em, presence: true
  validates :tipo, inclusion: { in: TIPOS }
  validate :fim_nao_pode_ser_antes_do_inicio
  validate :contact_pertence_a_mesma_conta

  # Overlap com o período [de, ate]: cobre tanto evento com duração quanto
  # evento pontual (fim_em nulo, trata como instantâneo no inicio_em).
  scope :no_periodo, ->(de, ate) { where('inicio_em <= ? AND COALESCE(fim_em, inicio_em) >= ?', ate, de) }

  private

  def fim_nao_pode_ser_antes_do_inicio
    return if fim_em.blank? || inicio_em.blank?
    errors.add(:fim_em, 'não pode ser antes do início') if fim_em < inicio_em
  end

  def contact_pertence_a_mesma_conta
    return if contact_id.blank?
    errors.add(:contact_id, 'não pertence a esta conta') if contact&.account_id != account_id
  end
end
