# Etiquetas na REVENDEDORA (Contact), separado de conversation_tags (que
# etiqueta uma conversa específica) — ver ContactTag/migration pro motivo.
class ContactTagsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contact

  def index
    render json: @contact.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
  end

  def create
    name = params[:name].to_s.strip.downcase.gsub(/\s+/, '_')
    color = params[:color].presence || '#6b7280'
    return render json: { error: 'Nome obrigatório' }, status: :unprocessable_entity if name.blank?

    tag = current_user.account.tags.find_or_create_by!(name: name) do |t|
      t.color = color
    end

    @contact.tags << tag unless @contact.tags.include?(tag)

    render json: { id: tag.id, name: tag.name, color: tag.color }
  end

  def destroy
    tag = @contact.tags.find_by(id: params[:id])
    @contact.tags.delete(tag) if tag
    head :no_content
  end

  private

  def set_contact
    @contact = visible_contacts_scope.find(params[:contact_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found', message: 'Contato não encontrado ou fora da sua carteira.' }, status: :not_found
  end
end
