# "Fluxos" (MVP) — construtor visual de automação de conversa. Diferente de
# PipelinesController (board de uso diário, index liberado pra qualquer
# agente), Fluxos é só ferramenta de configuração — TODA ação é restrita a
# diretoria, inclusive listar.
class FlowsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner!
  before_action :set_flow, only: %i[show update destroy duplicate graph]

  def index
    flows = current_user.account.flows.includes(:flow_nodes).order(updated_at: :desc)
    render json: flows.map { |f| serialize_summary(f) }
  end

  def show
    render json: serialize_full(@flow)
  end

  def create
    flow = current_user.account.flows.new(flow_params)
    if flow.save
      render json: serialize_full(flow), status: :created
    else
      render json: { errors: flow.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @flow.update(flow_params)
      render json: serialize_full(@flow)
    else
      render json: { errors: @flow.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @flow.destroy!
    head :no_content
  end

  # POST /flows/:id/duplicate
  def duplicate
    novo = nil
    ActiveRecord::Base.transaction do
      novo = current_user.account.flows.create!(
        name: "#{@flow.name} (cópia)",
        description: @flow.description,
        channel: @flow.channel,
        active: false
      )
      @flow.flow_nodes.each do |n|
        novo.flow_nodes.create!(key: n.key, node_type: n.node_type, position: n.position, data: n.data)
      end
      @flow.flow_edges.each do |e|
        novo.flow_edges.create!(source_key: e.source_key, target_key: e.target_key, source_handle: e.source_handle, target_handle: e.target_handle)
      end
    end
    render json: serialize_full(novo), status: :created
  end

  # PUT /flows/:id/graph — autosave: substitui nodes+edges inteiros de uma
  # vez (upsert por key, apaga o que sumiu). Mais adequado ao canvas do que
  # REST granular por node/edge (evita 1 request por drag).
  def graph
    nodes_params = params.require(:nodes)
    edges_params = params.fetch(:edges, [])

    ActiveRecord::Base.transaction do
      keys_recebidas = nodes_params.map { |n| n[:key] }
      @flow.flow_nodes.where.not(key: keys_recebidas).destroy_all

      nodes_params.each do |n|
        node = @flow.flow_nodes.find_or_initialize_by(key: n[:key])
        node.update!(node_type: n[:node_type], position: n[:position] || {}, data: n[:data] || {})
      end

      @flow.flow_edges.destroy_all
      edges_params.each do |e|
        @flow.flow_edges.create!(
          source_key: e[:source_key], target_key: e[:target_key],
          source_handle: e[:source_handle], target_handle: e[:target_handle]
        )
      end

      @flow.touch
    end

    render json: serialize_full(@flow.reload)
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_flow
    @flow = current_user.account.flows.find(params[:id])
  end

  def flow_params
    params.require(:flow).permit(:name, :description, :channel, :active)
  end

  def serialize_summary(flow)
    {
      id: flow.id,
      name: flow.name,
      description: flow.description,
      channel: flow.channel,
      active: flow.active,
      flow_nodes_count: flow.flow_nodes.size,
      created_at: flow.created_at,
      updated_at: flow.updated_at
    }
  end

  def serialize_full(flow)
    serialize_summary(flow).merge(
      flow_nodes_count: flow.flow_nodes.count,
      nodes: flow.flow_nodes.map { |n| { key: n.key, node_type: n.node_type, position: n.position, data: n.data } },
      edges: flow.flow_edges.map { |e| { source_key: e.source_key, target_key: e.target_key, source_handle: e.source_handle, target_handle: e.target_handle } }
    )
  end
end
