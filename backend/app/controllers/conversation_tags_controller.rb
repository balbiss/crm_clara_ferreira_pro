class ConversationTagsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation

  def index
    render json: @conversation.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
  end

  def create
    name = params[:name].to_s.strip.downcase.gsub(/\s+/, '_')
    return render json: { error: 'Nome obrigatório' }, status: :unprocessable_entity if name.blank?

    # RBAC (TagsController): "apenas o dono cria, edita ou remove etiquetas"
    # do catálogo. Qualquer usuário pode ANEXAR uma etiqueta já existente,
    # mas criar um nome de etiqueta novo (que ainda não existe no catálogo
    # da conta) é reservado à diretoria — senão o find_or_create_by! daqui
    # virava uma porta lateral pra burlar essa regra.
    tag = current_user.account.tags.find_by(name: name)
    if tag.nil?
      unless owner?
        return render json: { error: 'forbidden', message: 'Só a diretoria pode criar etiquetas novas. Escolha uma já existente.' }, status: :forbidden
      end
      tag = current_user.account.tags.create!(name: name, color: params[:color].presence || '#6b7280')
    end

    unless @conversation.tags.include?(tag)
      @conversation.tags << tag
      broadcast_update
    end

    render json: { id: tag.id, name: tag.name, color: tag.color }
  end

  def destroy
    tag = @conversation.tags.find_by(id: params[:id])
    if tag
      # Remover a etiqueta 'agente_off' manualmente equivale a clicar "Retomar IA":
      # também limpa a pausa e tira 'com_atendente' junto, já que a IA está retomando.
      # O corretor já atribuído (conversation.user_id) não é alterado aqui.
      if tag.name == 'agente_off'
        contact_jid = @conversation.contact.channel_identifier
        Rails.cache.delete("ai_paused_#{@conversation.inbox_id}_#{contact_jid}")
        com_atendente = @conversation.tags.find { |t| t.name == 'com_atendente' }
        @conversation.tags.delete(com_atendente) if com_atendente
      end

      @conversation.tags.delete(tag)
      broadcast_update
    end
    head :no_content
  end

  private

  def set_conversation
    @conversation = current_user.account.conversations.find(params[:conversation_id])
  end

  def broadcast_update
    ActionCable.server.broadcast("conversations_channel_#{@conversation.account_id}", {
      event: 'conversation_tags_updated',
      conversation_id: @conversation.id,
      tags: @conversation.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
    })
  end
end
