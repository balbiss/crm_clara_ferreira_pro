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

  # GET /jueri/debug_pedido/:id — estado AO VIVO de um pedido específico no
  # Jueri (bypassa o sync local, pra comparar contra o que está salvo aqui).
  def debug_pedido
    service = JueriApiService.new
    render json: service.find_pedido(params[:id])
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

  # GET /jueri/debug_recurso?recurso=contas_receber&per_page=3 — inspeciona
  # a resposta crua de um recurso ainda não modelado no CRM (financeiro,
  # venda, representante), pra descobrir os campos reais antes de desenhar
  # o schema local. Temporário/diagnóstico, mesmo espírito do #debug acima.
  RECURSOS_DEBUG = %w[contas_receber contas_pagar venda representante cliente].freeze

  def debug_recurso
    unless RECURSOS_DEBUG.include?(params[:recurso])
      return render json: { error: 'recurso_invalido', recursos_validos: RECURSOS_DEBUG }, status: :unprocessable_entity
    end

    service = JueriApiService.new
    per_page = (params[:per_page] || 3).to_i.clamp(1, 10)
    extra = params.except(:controller, :action, :recurso, :per_page, :page).permit!.to_h
    filtros = { per_page: per_page, page: 1 }.merge(extra)
    data = case params[:recurso]
           when 'contas_receber' then service.contas_receber(filtros)
           when 'contas_pagar' then service.contas_pagar(filtros)
           when 'venda' then service.vendas(filtros)
           when 'representante' then service.representantes(filtros)
           when 'cliente' then service.clientes(filtros)
           end
    render json: data
  rescue JueriApiService::NotConfiguredError => e
    render json: { error: 'not_configured', message: e.message }, status: :unprocessable_entity
  rescue JueriApiService::ApiError => e
    render json: { error: 'jueri_api_error', message: e.message }, status: :bad_gateway
  end

  # POST /jueri/reconciliar_pedidos/:contact_id — confere ao vivo, pedido por
  # pedido, se os pedidos "Aberto" salvos localmente pra essa revendedora
  # ainda existem de verdade no Jueri. Corrige o bug real encontrado
  # 2026-08-30 (webhook pedido.deleted nunca tratado — pedido excluído no
  # Jueri, ex: por "Unificar Pedidos", ficava Aberto aqui pra sempre,
  # inflando a soma de peças). Um request por pedido aberto — só usar sob
  # demanda pra 1 revendedora específica, nunca em massa pra toda a base
  # (estouraria o rate limit do Jueri, ~300 chamadas em rajada).
  def reconciliar_pedidos
    contact = current_user.account.contacts.find(params[:contact_id])
    service = JueriApiService.new
    sync_service = JueriSyncService.new(account: current_user.account)
    corrigidos = []

    contact.pedidos.where(status_id: Pedido::STATUS_ABERTO).find_each do |pedido|
      begin
        service.find_pedido(pedido.jueri_pedido_id)
      rescue JueriApiService::ApiError => e
        next unless e.message.include?('404')
        sync_service.sync_pedido_excluido({ 'id' => pedido.jueri_pedido_id })
        corrigidos << pedido.jueri_pedido_id
      end
    end

    render json: { contact_id: contact.id, pedidos_corrigidos: corrigidos, pecas_abertas_atual: contact.reload.pecas_abertas_atual }
  rescue JueriApiService::NotConfiguredError => e
    render json: { error: 'not_configured', message: e.message }, status: :unprocessable_entity
  end

  # POST /jueri/reconciliar_pedidos_abertos — varredura completa (assíncrona,
  # background) de TODOS os pedidos "Aberto" da conta contra o Jueri, pra
  # limpar pedidos-fantasma antigos (excluídos no Jueri antes do fix do
  # webhook pedido.deleted). Leva minutos (ritmo lento de propósito, ver
  # JueriReconciliarPedidosAbertosJob) — resultado sai no log do worker.
  def reconciliar_pedidos_abertos
    unless JueriApiService.configured?
      return render json: { error: 'not_configured', message: 'JUERI_API_TOKEN/JUERI_CLIENTE_SISTEMA não configurados.' }, status: :unprocessable_entity
    end

    total_abertos = current_user.account.pedidos.where(status_id: Pedido::STATUS_ABERTO).count
    JueriReconciliarPedidosAbertosJob.perform_later(current_user.account.id)
    render json: { message: "Varredura disparada em background pra #{total_abertos} pedidos abertos. Acompanhe pelo log do worker (leva alguns minutos)." }, status: :accepted
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
