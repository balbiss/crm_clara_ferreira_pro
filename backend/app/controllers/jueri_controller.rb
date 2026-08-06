# Endpoint de diagnóstico pra inspecionar a resposta CRUA da API do Jueri sem
# passar pelo JueriSyncService (que já mapeia os campos pro schema interno).
# Útil pra investigar mudanças no formato da API ou confirmar dado específico
# de um revendedor. Restrito à diretoria — expõe dado cru da API (CPF etc).
class JueriController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner!

  # GET /jueri/debug?per_page=5
  def debug
    service = JueriApiService.new
    per_page = (params[:per_page] || 5).to_i.clamp(1, 20)
    render json: service.revendedores(per_page: per_page, page: 1)
  rescue JueriApiService::NotConfiguredError => e
    render json: { error: 'not_configured', message: e.message }, status: :unprocessable_entity
  rescue JueriApiService::ApiError => e
    render json: { error: 'jueri_api_error', message: e.message }, status: :bad_gateway
  end

  # GET /jueri/debug/:id — cadastro completo de um revendedor específico
  def debug_show
    service = JueriApiService.new
    render json: service.find_revendedor(params[:id])
  rescue JueriApiService::NotConfiguredError => e
    render json: { error: 'not_configured', message: e.message }, status: :unprocessable_entity
  rescue JueriApiService::ApiError => e
    render json: { error: 'jueri_api_error', message: e.message }, status: :bad_gateway
  end
end
