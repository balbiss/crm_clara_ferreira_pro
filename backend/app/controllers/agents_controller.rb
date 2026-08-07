class AgentsController < ApplicationController
  # FALHA CRÍTICA CORRIGIDA (2026-08-07): nenhuma action aqui exigia login —
  # index/show usavam `current_user&.account || Account.first`, então uma
  # chamada SEM autenticação nenhuma caía no fallback e devolvia nome/email/
  # telefone/cargo de todos os agentes da primeira conta do banco. Confirmado
  # exploitable ao vivo (GET /agents sem token devolvia os 4 agentes reais).
  before_action :authenticate_user!
  before_action :set_agent, only: %i[ show update destroy block unblock toggle_roundrobin ]
  # Leitura liberada pra qualquer usuário logado (corretores precisam ver a
  # equipe para atribuição). Escrita restrita ao dono: criar, editar, remover,
  # bloquear, configurar rodízio.
  before_action :require_owner!, only: %i[ create update destroy block unblock toggle_roundrobin ]

  # GET /agents
  def index
    # authenticate_user! já garante current_user presente — não usar mais
    # Account.first como fallback (isso é o que causava o vazamento acima).
    account = current_user.account
    @agents = account.users.order(created_at: :desc)
    
    render json: @agents.as_json(except: [:encrypted_password, :jti],
                                  methods: [:available_for_roundrobin, :queue_position, :avatar_url])
  end

  # GET /agents/1
  def show
    render json: @agent.as_json(except: [:encrypted_password, :jti],
                                 methods: [:available_for_roundrobin, :queue_position, :avatar_url])
  end

  # POST /agents
  def create
    account = current_user.account
    @agent = account.users.build(agent_params.except(:role))
    @agent.role = agent_params[:role].presence || :consultor
    plain_password = agent_params[:password]

    if @agent.save
      WelcomeMailer.welcome(@agent, plain_password).deliver_later if @agent.email.present?
      render json: @agent.as_json(except: [:encrypted_password, :jti]), status: :created
    else
      render json: @agent.errors, status: :unprocessable_entity
    end
  rescue ArgumentError
    render json: { error: "Perfil inválido. Use: #{User.roles.keys.join(', ')}." }, status: :unprocessable_entity
  end

  # PATCH/PUT /agents/1
  def update
    prms = agent_params
    # If password is blank, don't update it
    prms.delete(:password) if prms[:password].blank?
    prms.delete(:role) if prms[:role].blank?

    if @agent.update(prms)
      render json: @agent.as_json(except: [:encrypted_password, :jti])
    else
      render json: @agent.errors, status: :unprocessable_entity
    end
  rescue ArgumentError
    render json: { error: "Perfil inválido. Use: #{User.roles.keys.join(', ')}." }, status: :unprocessable_entity
  end

  # PATCH /agents/1/block
  def block
    if @agent.update(status: 'blocked')
      render json: { message: 'Agent blocked' }
    else
      render json: @agent.errors, status: :unprocessable_entity
    end
  end

  # PATCH /agents/1/unblock
  def unblock
    if @agent.update(status: 'active')
      render json: { message: 'Agent unblocked' }
    else
      render json: @agent.errors, status: :unprocessable_entity
    end
  end

  # GET /agents/queue
  def queue
    account = current_user.account
    agents = account.users
      .where(status: 'active', available_for_roundrobin: true)
      .order(Arel.sql('queue_position ASC NULLS FIRST, id ASC'))
    render json: agents.as_json(only: [:id, :first_name, :last_name, :queue_position])
  end

  # PATCH /agents/1/toggle_roundrobin
  def toggle_roundrobin
    account = current_user.account

    if @agent.available_for_roundrobin?
      @agent.update!(available_for_roundrobin: false, queue_position: nil)
    else
      max_pos = account.users.where(available_for_roundrobin: true).maximum(:queue_position) || 0
      @agent.update!(available_for_roundrobin: true, queue_position: max_pos + 1)
    end

    render json: @agent.as_json(except: [:encrypted_password, :jti])
  end

  # DELETE /agents/1
  def destroy
    if @agent.destroy
      head :no_content
    else
      render json: { error: @agent.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private
    def set_agent
      account = current_user.account
      @agent = account.users.find(params[:id])
    end

    def agent_params
      params.require(:agent).permit(:first_name, :last_name, :email, :phone, :password, :status, :department, :role, :round_robin_group_id, :jueri_gerente_id, permissions: {})
    end
end
