require 'test_helper'

# Gatilhos "quando o cliente responder" + ação "Criar tarefa" (2026-10-16).
# Autocontido: cria os próprios dados (não usa os fixtures antigos da VisitaIA).
class PipelineTriggerClientReplyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = true

  include ActiveJob::TestHelper

  setup do
    @account = Account.create!(name: 'Clara Teste')
    @user = User.create!(account: @account, first_name: 'Bel', last_name: 'Teste', email: "bel#{SecureRandom.hex(3)}@teste.local",
                         password: 'senha-teste-123', role: 'diretoria')
    @inbox = Inbox.create!(account: @account, name: 'Prospecção', provider: 'waha', phone_number: "+55149#{rand(10_000_000..99_999_999)}")
    @pipeline = Pipeline.create!(account: @account, name: 'Prospecção Teste')
    @primeiro = @pipeline.pipeline_stages.create!(name: 'Primeiro Contato', position: 0)
    @atendimento = @pipeline.pipeline_stages.create!(name: 'Em atendimento', position: 1)
    @formulario = @pipeline.pipeline_stages.create!(name: 'Formulário enviado', position: 2)
    @contact = Contact.create!(account: @account, name: 'Lead Teste', phone: "+55149#{rand(10_000_000..99_999_999)}", user: @user)
    @conversation = Conversation.create!(account: @account, contact: @contact, inbox: @inbox, status: :open)
    @card = PipelineCard.create!(pipeline: @pipeline, pipeline_stage: @primeiro, contact: @contact)
  end

  def client_message(text = 'oi, tenho interesse', private: false, historical: false)
    msg = Message.new(account: @account, conversation: @conversation, sender_type: 'Contact', sender_id: @contact.id,
                      text: text, is_private: private, status: :delivered)
    msg.historical_import = true if historical
    msg.save!
    msg
  end

  def reply_trigger(stage, action:, config: {}, delay: 0)
    stage.pipeline_triggers.create!(action_type: action, event: 'client_reply', config: config, delay_minutes: delay)
  end

  # ---- Pedido principal da Clara: cliente respondeu -> move pra "Em atendimento" ----

  test 'cliente responde: card move pra Em atendimento' do
    reply_trigger(@primeiro, action: 'move_stage', config: { 'target_stage_id' => @atendimento.id })

    perform_enqueued_jobs { client_message }

    assert_equal @atendimento.id, @card.reload.pipeline_stage_id
  end

  test 'nao dispara antes de o cliente responder (nem so de entrar na etapa)' do
    reply_trigger(@primeiro, action: 'move_stage', config: { 'target_stage_id' => @atendimento.id })

    PipelineTriggerRunnerService.new(@card).call # simula "entrou na etapa"

    assert_equal @primeiro.id, @card.reload.pipeline_stage_id
  end

  test 'mensagem da equipe (nao do cliente) nao dispara' do
    reply_trigger(@primeiro, action: 'move_stage', config: { 'target_stage_id' => @atendimento.id })

    perform_enqueued_jobs do
      Message.create!(account: @account, conversation: @conversation, sender_type: 'User', sender_id: @user.id, text: 'oi!', status: :sent)
    end

    assert_equal @primeiro.id, @card.reload.pipeline_stage_id
  end

  test 'nota privada e historico importado nao disparam' do
    reply_trigger(@primeiro, action: 'move_stage', config: { 'target_stage_id' => @atendimento.id })

    perform_enqueued_jobs do
      client_message(private: true)
      client_message(historical: true)
    end

    assert_equal @primeiro.id, @card.reload.pipeline_stage_id
  end

  test 'roda uma vez so por permanencia na etapa (segunda mensagem nao repete)' do
    reply_trigger(@primeiro, action: 'create_note', config: { 'content' => 'Cliente respondeu' })

    perform_enqueued_jobs do
      client_message('primeira')
      client_message('segunda')
      client_message('terceira')
    end

    assert_equal 1, Note.where(contact_id: @contact.id, content: 'Cliente respondeu').count
  end

  test 'sair e voltar pra etapa libera o gatilho de novo' do
    reply_trigger(@primeiro, action: 'create_note', config: { 'content' => 'Cliente respondeu' })

    perform_enqueued_jobs { client_message('primeira') }
    assert_equal 1, Note.where(contact_id: @contact.id).count

    @card.reload.update!(pipeline_stage: @formulario)
    assert_nil @card.reload.reply_triggered_at, 'mudar de etapa tem que zerar a marca'
    @card.update!(pipeline_stage: @primeiro)

    perform_enqueued_jobs { client_message('de novo') }
    assert_equal 2, Note.where(contact_id: @contact.id).count
  end

  test 'gatilho que move o card libera o gatilho da etapa nova' do
    reply_trigger(@primeiro, action: 'move_stage', config: { 'target_stage_id' => @atendimento.id })
    reply_trigger(@atendimento, action: 'create_note', config: { 'content' => 'Entrou em atendimento' })

    perform_enqueued_jobs do
      client_message('primeira') # move pra Em atendimento
      client_message('segunda')  # gatilho da etapa nova (nota) roda agora
    end

    assert_equal @atendimento.id, @card.reload.pipeline_stage_id
    assert_equal 1, Note.where(contact_id: @contact.id, content: 'Entrou em atendimento').count
  end

  test 'gatilho com atraso e agendado e nao roda se o card sair da etapa' do
    reply_trigger(@primeiro, action: 'create_note', config: { 'content' => 'Depois de 1h' }, delay: 60)

    client_message
    assert_enqueued_with(job: PipelineClientReplyJob)
    perform_enqueued_jobs(only: PipelineClientReplyJob)
    assert_enqueued_with(job: PipelineTriggerFireJob)
    assert_equal 0, Note.where(contact_id: @contact.id).count, 'com atraso, nao roda na hora'

    # o lead sai da etapa antes de a hora passar -> ao chegar a hora, nao roda
    @card.update!(pipeline_stage: @formulario)
    perform_enqueued_jobs(only: PipelineTriggerFireJob)
    assert_equal 0, Note.where(contact_id: @contact.id).count
  end

  test 'gatilho com atraso roda se o card continuar na etapa' do
    reply_trigger(@primeiro, action: 'create_note', config: { 'content' => 'Depois de 1h' }, delay: 60)

    perform_enqueued_jobs(only: PipelineClientReplyJob) { client_message }
    perform_enqueued_jobs(only: PipelineTriggerFireJob)

    assert_equal 1, Note.where(contact_id: @contact.id, content: 'Depois de 1h').count
  end

  test 'gatilhos "ao entrar" continuam funcionando e nao rodam na resposta' do
    @primeiro.pipeline_triggers.create!(action_type: 'create_note', config: { 'content' => 'Entrou' }) # event padrao = enter

    PipelineTriggerRunnerService.new(@card).call
    assert_equal 1, Note.where(contact_id: @contact.id, content: 'Entrou').count

    perform_enqueued_jobs { client_message }
    assert_equal 1, Note.where(contact_id: @contact.id, content: 'Entrou').count, 'resposta do cliente nao repete o gatilho de entrada'
  end

  test 'gatilho inativo nao roda' do
    t = reply_trigger(@primeiro, action: 'move_stage', config: { 'target_stage_id' => @atendimento.id })
    t.update!(active: false)

    perform_enqueued_jobs { client_message }

    assert_equal @primeiro.id, @card.reload.pipeline_stage_id
  end

  test 'contato sem card em funil nao quebra nada' do
    outro = Contact.create!(account: @account, name: 'Sem funil', phone: "+55149#{rand(10_000_000..99_999_999)}")
    conv = Conversation.create!(account: @account, contact: outro, inbox: @inbox, status: :open)

    assert_nothing_raised do
      perform_enqueued_jobs do
        Message.create!(account: @account, conversation: conv, sender_type: 'Contact', sender_id: outro.id, text: 'oi', status: :delivered)
      end
    end
  end

  # ---- Ação "Criar tarefa" ----

  test 'criar tarefa pelo gatilho: titulo, tipo, prioridade, responsavel e prazo' do
    reply_trigger(@primeiro, action: 'create_task', config: {
      'titulo' => 'Acompanhar lead', 'tipo' => 'manual_ligar', 'prioridade' => 'alta', 'prazo_horas' => 24, 'descricao' => 'Ligar ou chamar no WhatsApp'
    })

    perform_enqueued_jobs { client_message }

    tarefa = Tarefa.find_by!(contact_id: @contact.id)
    assert_equal 'Acompanhar lead', tarefa.titulo
    assert_equal 'manual_ligar', tarefa.tipo
    assert_equal 'alta', tarefa.prioridade
    assert_equal 'pendente', tarefa.status
    assert_equal @user.id, tarefa.user_id, 'sem responsavel na config, usa o responsavel do contato'
    assert_equal 'Ligar ou chamar no WhatsApp', tarefa.descricao
    assert_in_delta 24.hours.from_now.to_f, tarefa.vencimento_em.to_f, 120
  end

  test 'criar tarefa com responsavel escolhido' do
    outra = User.create!(account: @account, first_name: 'Nathalia', last_name: 'Teste', email: "nat#{SecureRandom.hex(3)}@teste.local",
                         password: 'senha-teste-123', role: 'consultor')
    TriggerTaskCreator.call(contact: @contact, config: { 'titulo' => 'X', 'user_id' => outra.id })

    assert_equal outra.id, Tarefa.find_by!(contact_id: @contact.id).user_id
  end

  test 'criar tarefa com tipo/prioridade invalidos usa os padroes' do
    TriggerTaskCreator.call(contact: @contact, config: { 'titulo' => 'X', 'tipo' => 'hackeado', 'prioridade' => 'ultra' })

    tarefa = Tarefa.find_by!(contact_id: @contact.id)
    assert_equal 'manual_acompanhamento', tarefa.tipo
    assert_equal 'normal', tarefa.prioridade
  end

  test 'nao duplica tarefa pendente do mesmo tipo' do
    2.times { TriggerTaskCreator.call(contact: @contact, config: { 'titulo' => 'X', 'tipo' => 'manual_ligar' }) }

    assert_equal 1, Tarefa.where(contact_id: @contact.id).count
  end

  test 'validacao: criar tarefa exige titulo; evento invalido e recusado' do
    sem_titulo = @primeiro.pipeline_triggers.new(action_type: 'create_task', config: {})
    assert_not sem_titulo.valid?

    evento_ruim = @primeiro.pipeline_triggers.new(action_type: 'create_note', config: { 'content' => 'x' }, event: 'qualquer')
    assert_not evento_ruim.valid?
  end

  test 'criar tarefa tambem funciona no gatilho da regua do Consignado' do
    trigger = ReguaTrigger.create!(account: @account, status: 'terceiro_dia', action_type: 'create_task',
                                   config: { 'titulo' => 'Ligar pra combinar o acerto', 'tipo' => 'manual_agendamento' })
    assert trigger.persisted?

    ReguaTriggerRunnerService.new(@contact).run_single_trigger(trigger, chain_depth: 0)

    tarefa = Tarefa.find_by!(contact_id: @contact.id)
    assert_equal 'Ligar pra combinar o acerto', tarefa.titulo
    assert_equal 'manual_agendamento', tarefa.tipo
  end
end
