# Evento da agenda/calendário (compromisso, reunião, lembrete) — cada usuário
# vê e gerencia só os próprios; gerente/diretoria (full_portfolio) enxergam e
# gerenciam a agenda de todo mundo, com filtro por responsável no calendário.
class Agendamento < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :titulo, presence: true
  validates :inicio_em, presence: true
  validate :fim_nao_pode_ser_antes_do_inicio

  # Overlap com o período [de, ate]: cobre tanto evento com duração quanto
  # evento pontual (fim_em nulo, trata como instantâneo no inicio_em).
  scope :no_periodo, ->(de, ate) { where('inicio_em <= ? AND COALESCE(fim_em, inicio_em) >= ?', ate, de) }

  private

  def fim_nao_pode_ser_antes_do_inicio
    return if fim_em.blank? || inicio_em.blank?
    errors.add(:fim_em, 'não pode ser antes do início') if fim_em < inicio_em
  end
end
