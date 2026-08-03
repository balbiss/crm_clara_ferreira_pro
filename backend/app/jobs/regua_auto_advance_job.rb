# Avança automaticamente o status da revendedora conforme os dias do ciclo consignado
# (briefing seções 12-13). Roda em loop próprio, no mesmo padrão do
# CheckSnoozedConversationsJob — sem depender da API do Jueri, usa cycle_started_at
# (setado pelo Contact#track_regua_status_change sempre que o status entra em
# "revendedor_ativo").
class ReguaAutoAdvanceJob < ApplicationJob
  queue_as :default

  ADVANCEABLE_STATUSES = %w[revendedor_ativo terceiro_dia decimo_dia vigesimo_dia].freeze

  def perform
    Contact.where(status: ADVANCEABLE_STATUSES).find_each { |c| advance(c) }
    Contact.where(status: 'atrasada').find_each { |c| check_virada_de_mes(c) }
  ensure
    self.class.set(wait: 1.hour).perform_later rescue nil
  end

  private

  def advance(contact)
    days = days_in_cycle(contact)
    new_status =
      if days >= 35
        'atrasada'
      elsif days >= 20 && contact.status != 'vigesimo_dia'
        'vigesimo_dia'
      elsif days >= 10 && contact.status == 'terceiro_dia'
        'decimo_dia'
      elsif days >= 3 && contact.status == 'revendedor_ativo'
        'terceiro_dia'
      end

    return unless new_status && new_status != contact.status
    contact.update!(status: new_status)
    Tarefa.criar_para_transicao!(contact, new_status)
  end

  # Regra do briefing (seção 13): se virou o mês sem acerto, evolui pra Suspensa por
  # Atraso (dentro de Inativas), não fica só "Atrasada" indefinidamente.
  def check_virada_de_mes(contact)
    cycle_start = contact.cycle_started_at || contact.created_at
    return unless Time.current.beginning_of_month > cycle_start.beginning_of_month
    contact.update!(status: 'suspensa_atraso')
  end

  def days_in_cycle(contact)
    cycle_start = contact.cycle_started_at || contact.created_at
    ((Time.current - cycle_start) / 1.day).floor
  end
end
