# Tela "Atividades" (só gerência) — feed cronológico de tudo que a Jueri
# manda pro webhook, ver Webhooks::JueriController#registrar_atividade.
class JueriActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_full_portfolio!

  def index
    page     = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 50).to_i.clamp(1, 200)

    atividades = current_user.account.jueri_activities
      .includes(:contact)
      .order(ocorrido_em: :desc)
      .offset((page - 1) * per_page)
      .limit(per_page)

    render json: atividades.as_json(include: { contact: { only: %i[id name] } })
  end
end
