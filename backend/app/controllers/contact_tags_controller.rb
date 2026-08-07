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
    return render json: { error: 'Nome obrigatório' }, status: :unprocessable_entity if name.blank?

    # RBAC (TagsController): "apenas o dono cria, edita ou remove etiquetas"
    # do catálogo. Qualquer usuário pode ANEXAR uma etiqueta já existente,
    # mas criar um nome de etiqueta novo é reservado à diretoria — senão o
    # find_or_create_by! daqui virava uma porta lateral pra burlar essa regra.
    tag = current_user.account.tags.find_by(name: name)
    if tag.nil?
      unless owner?
        return render json: { error: 'forbidden', message: 'Só a diretoria pode criar etiquetas novas. Escolha uma já existente.' }, status: :forbidden
      end
      tag = current_user.account.tags.create!(name: name, color: params[:color].presence || '#6b7280')
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
