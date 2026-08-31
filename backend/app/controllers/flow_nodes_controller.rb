# Upload de mídia pro nó "Enviar mídia" — separado do bulk /flows/:id/graph
# porque esse é multipart (arquivo), não dá pra ir junto do autosave em
# JSON. Identificado por flow_id + key (não o id do Rails, que o frontend
# não conhece — só a key gerada por ele, ver FlowNode).
class FlowNodesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner!

  # POST /flows/:flow_id/nodes/:key/media
  def upload_media
    flow = current_user.account.flows.find(params[:flow_id])
    node = flow.flow_nodes.find_by!(key: params[:key])

    if params[:file].blank?
      return render json: { error: 'Nenhum arquivo enviado.' }, status: :unprocessable_entity
    end

    node.media.attach(params[:file])
    render json: { media_url: media_url_for(node), content_type: node.media.content_type }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Fluxo ou nó não encontrado.' }, status: :not_found
  end

  private

  def media_url_for(node)
    return nil unless node.media.attached?

    Rails.application.routes.url_helpers.rails_storage_proxy_url(node.media, host: ENV['API_HOST'] || 'http://localhost:3000')
  end
end
