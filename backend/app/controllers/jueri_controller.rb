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

  # POST /jueri/sync-now — dispara a sincronização já (mesmo caminho usado pelo
  # webhook: account_id presente = disparo pontual, não mexe no loop recorrente
  # de 30min). Assíncrono de propósito: o histórico completo de pedidos pode ter
  # milhares de registros e não cabe no timeout de uma request HTTP. Resultado
  # sai no log do worker ("[JueriSyncJob] account=... criados=... erros=...").
  def sync_now
    unless JueriApiService.configured?
      return render json: { error: 'not_configured', message: 'JUERI_API_TOKEN/JUERI_CLIENTE_SISTEMA não configurados.' }, status: :unprocessable_entity
    end

    JueriSyncJob.perform_later(current_user.account.id)
    render json: { message: 'Sincronização disparada. Acompanhe pelo log do worker ou confira /contacts em alguns instantes.' }, status: :accepted
  end

  # GET /jueri/debug_schema — diagnóstico pontual: confirma se a coluna
  # contacts.user_id tem algum DEFAULT gravado direto no Postgres (não
  # apareceria no schema.rb se alguém alterou via SQL fora de uma migration).
  def debug_schema
    col = Contact.columns_hash['user_id']
    render json: {
      contacts_user_id_default: col&.default,
      contacts_user_id_sql_type: col&.sql_type,
      novo_contact_user_id_em_memoria: Contact.new.user_id
    }
  end
end
