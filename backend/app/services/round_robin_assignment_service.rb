class RoundRobinAssignmentService
  # Assigns the next available agent in the round-robin queue to a conversation.
  # Returns the assigned User or nil if no eligible agent exists.
  def self.assign_next(conversation)
    return nil if conversation.user_id.present?

    agent = pick_and_advance(conversation.account, conversation.inbox&.round_robin_group_id)
    return nil unless agent

    conversation.update!(user_id: agent.id)
    broadcast_assignment(conversation, agent)
    AgentNotificationService.notify_assignment(
      agent:       agent,
      conversation: conversation,
      assigned_by: 'rodizio'
    )
    agent
  rescue => e
    Rails.logger.error("RoundRobinAssignmentService error: #{e.message}")
    nil
  end

  # Usado pelo JueriSyncService: revendedora criada direto pela sincronização
  # do ERP (cruzou o limiar de 25 peças) ainda não tem conversa/WhatsApp — só
  # precisa de um consultor responsável, sem broadcast de conversa nenhuma.
  # Reaproveita a MESMA fila (queue_position/available_for_roundrobin) do
  # rodízio de conversas, pra manter justo entre os dois canais de entrada.
  def self.assign_to_contact(contact)
    return nil if contact.user_id.present?

    agent = pick_and_advance(contact.account, nil)
    return nil unless agent

    contact.update_column(:user_id, agent.id)
    agent
  rescue => e
    Rails.logger.error("RoundRobinAssignmentService#assign_to_contact error: #{e.message}")
    nil
  end

  private

  def self.pick_and_advance(account, group_id)
    agent = nil

    ApplicationRecord.transaction do
      account.lock!

      base_scope = User.where(account_id: account.id, status: 'active', department: 'corretor')
      base_scope = base_scope.where(round_robin_group_id: group_id) if group_id.present?

      agent = base_scope
        .where(available_for_roundrobin: true)
        .order(Arel.sql('queue_position ASC NULLS FIRST, id ASC'))
        .lock
        .first

      # Fallback: se ninguém está na fila de rodízio (ex: conta com um único
      # corretor que nunca teve o toggle ativado), ainda assim atribui para
      # algum corretor ativo do grupo (ou da conta, se não houver grupo
      # definido) em vez de deixar o lead/revendedora sem ninguém.
      agent ||= base_scope
        .order(:id)
        .lock
        .first

      if agent&.available_for_roundrobin
        max_pos = User.where(account_id: account.id, available_for_roundrobin: true)
                      .maximum(:queue_position) || 0
        agent.update_columns(queue_position: max_pos + 1)
      end
    end

    agent
  end
  private_class_method :pick_and_advance

  def self.broadcast_assignment(conversation, agent)
    ActionCable.server.broadcast("conversations_channel_#{conversation.account_id}", {
      event: 'conversation_updated',
      conversation: {
        id: conversation.id,
        assignee_id: agent.id,
        assignee: agent.first_name
      }
    })

    ActionCable.server.broadcast("conversations_channel_#{conversation.account_id}", {
      event: 'lead_atribuido',
      assigned_to_user_id: agent.id,
      conversation_id: conversation.id,
      contact_name: conversation.contact.name.presence || conversation.contact.phone,
      assigned_by: 'rodizio'
    })
  end
end
