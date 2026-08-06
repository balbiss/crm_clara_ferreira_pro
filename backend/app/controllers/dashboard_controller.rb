class DashboardController < ApplicationController
  def index
    is_owner   = full_portfolio? || current_user.has_permission?('view_all_contacts')
    account    = current_user.account
    uid        = current_user.id
    today      = Date.current

    # Scopes filtrados por papel
    # Corretor: contatos derivados das conversas atribuídas a ele (não user_id do contato)
    if is_owner
      contacts_scope = account.contacts
      conv_scope     = account.conversations
    else
      my_contact_ids = account.conversations.where(user_id: uid).pluck(:contact_id).uniq
      contacts_scope = account.contacts.where(id: my_contact_ids)
      conv_scope     = account.conversations.where(user_id: uid)
    end

    # Batch contacts: 3 GROUP BY queries instead of 9 individual COUNTs
    total_contacts  = contacts_scope.count
    temp_counts     = contacts_scope.group(:temperature).count
    status_counts   = contacts_scope.group(:status).count
    intention_counts = contacts_scope.group(:intention).count

    quente = %w[quente Quente QUENTE].sum { |t| temp_counts[t] || 0 }
    morno  = %w[morno Morno MORNO].sum   { |t| temp_counts[t] || 0 }
    frio   = %w[frio Frio FRIO].sum      { |t| temp_counts[t] || 0 }

    # Régua consignada (briefing seção 12) — etapas do ciclo ativo
    kanban = {
      revendedor_ativo: status_counts['revendedor_ativo'] || 0,
      terceiro_dia:     status_counts['terceiro_dia']     || 0,
      decimo_dia:       status_counts['decimo_dia']       || 0,
      vigesimo_dia:     status_counts['vigesimo_dia']     || 0,
      agendado:         status_counts['agendado']         || 0,
      reagendar:        status_counts['reagendar']        || 0,
      atrasada:         status_counts['atrasada']         || 0
    }

    # Resumo da carteira operacional (substitui o "Termômetro de Leads" herdado
    # da VisitaIA — não faz sentido pra revendedora consignada, briefing seção 28.5).
    carteira = {
      ativas_total: kanban.values.sum,
      com_maleta:   contacts_scope.where('pecas_abertas_atual > 0').count,
      agendadas:    kanban[:agendado],
      atrasadas:    kanban[:atrasada]
    }

    tarefas_scope = is_owner ? account.tarefas : account.tarefas.where(user_id: uid)
    tarefas_pendentes_por_tipo = tarefas_scope.pendentes.group(:tipo).count
    tarefas_do_dia = {
      terceiro_dia: tarefas_pendentes_por_tipo['terceiro_dia'] || 0,
      decimo_dia:   tarefas_pendentes_por_tipo['decimo_dia']   || 0,
      vigesimo_dia: tarefas_pendentes_por_tipo['vigesimo_dia'] || 0,
      reagendar:    status_counts['reagendar'] || 0
    }

    pretensao_venda = %w[venda Venda VENDA].sum { |i| intention_counts[i] || 0 }

    # Batch conversations: 1 GROUP BY instead of 2 COUNTs
    conv_status   = conv_scope.group(:status).count
    conv_open     = conv_status['open']     || 0
    conv_resolved = conv_status['resolved'] || 0
    conv_today    = conv_scope.where(created_at: today.beginning_of_day..today.end_of_day).count

    com_atendente_tag = account.tags.find_by(name: 'com_atendente')
    with_human = com_atendente_tag ? conv_scope.joins(:conversation_tags)
      .where(conversation_tags: { tag_id: com_atendente_tag.id }).count : 0

    leads_by_source = contacts_scope.where.not(source: [nil, '']).group(:source).count

    # Leads atribuídos hoje — conversas novas atribuídas a este usuário (ou a qualquer um, se dono)
    today_conv_scope = is_owner \
      ? account.conversations.where(created_at: today.beginning_of_day..today.end_of_day) \
      : account.conversations.where(user_id: uid, created_at: today.beginning_of_day..today.end_of_day)

    today_assigned_leads = today_conv_scope
      .includes(:contact)
      .order(created_at: :desc)
      .limit(20)
      .map do |conv|
        c = conv.contact
        next unless c
        {
          conversation_id: conv.id,
          contact_name:    c.name.presence || c.phone || 'Desconhecido',
          contact_phone:   c.phone,
          temperature:     c.temperature,
          kanban_status:   c.status,
          intention:       c.intention&.truncate(80),
          assigned_to:     conv.user_id == uid ? nil : account.users.find_by(id: conv.user_id)&.first_name,
          created_at:      conv.created_at
        }
      end.compact

    render json: {
      is_owner: is_owner,
      kpis: {
        total_contacts:  total_contacts,
        pretensao_venda: pretensao_venda,
        temperature:     { quente: quente, morno: morno, frio: frio },
        kanban:          kanban,
        conversations:   { open: conv_open, resolved: conv_resolved, today: conv_today, with_human: with_human },
        carteira:        carteira,
        tarefas_do_dia:  tarefas_do_dia
      },
      leads_by_source:      leads_by_source,
      today_assigned_leads: today_assigned_leads
    }
  end
end
