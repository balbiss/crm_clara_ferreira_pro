require 'test_helper'

# A API que as telas "Automatize" e "Tarefas" usam (2026-10-16): criar gatilho
# com evento/aÃƒÂ§ÃƒÂ£o nova, listar funis com o atraso, criar tarefa manual.
class PipelineTriggersApiTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  self.use_transactional_tests = true

  setup do
    @account = Account.create!(name: 'Clara API')
    @diretora = User.create!(account: @account, first_name: 'Bel', last_name: 'D', email: "d#{SecureRandom.hex(3)}@teste.local", password: 'senha-teste-123', role: 'diretoria')
    @consultora = User.create!(account: @account, first_name: 'Ana', last_name: 'C', email: "c#{SecureRandom.hex(3)}@teste.local", password: 'senha-teste-123', role: 'consultor')
    @pipeline = Pipeline.create!(account: @account, name: 'Funil API')
    @primeiro = @pipeline.pipeline_stages.create!(name: 'Primeiro Contato', position: 0)
    @atendimento = @pipeline.pipeline_stages.create!(name: 'Em atendimento', position: 1)
    @contact = Contact.create!(account: @account, name: 'Revendedora API', phone: "+55149#{rand(10_000_000..99_999_999)}")
  end

  test 'diretoria cria gatilho "cliente respondeu" que muda de etapa' do
    sign_in @diretora
    post pipeline_stage_pipeline_triggers_url(@primeiro), as: :json, params: {
      pipeline_trigger: { action_type: 'move_stage', event: 'client_reply', delay_minutes: 0, config: { target_stage_id: @atendimento.id } }
    }
    assert_response :created
    trigger = PipelineTrigger.last
    assert_equal 'client_reply', trigger.event
    assert_equal @atendimento.id, trigger.config['target_stage_id']
  end

  test 'gatilho sem evento informado continua sendo "ao entrar"' do
    sign_in @diretora
    post pipeline_stage_pipeline_triggers_url(@primeiro), as: :json, params: {
      pipeline_trigger: { action_type: 'create_note', config: { content: 'oi' } }
    }
    assert_response :created
    assert_equal 'enter', PipelineTrigger.last.event
  end

  test 'criar tarefa pelo gatilho exige titulo' do
    sign_in @diretora
    post pipeline_stage_pipeline_triggers_url(@primeiro), as: :json, params: {
      pipeline_trigger: { action_type: 'create_task', event: 'enter', config: {} }
    }
    assert_response :unprocessable_entity
  end

  test 'evento invalido e recusado' do
    sign_in @diretora
    post pipeline_stage_pipeline_triggers_url(@primeiro), as: :json, params: {
      pipeline_trigger: { action_type: 'create_note', event: 'hackeado', config: { content: 'x' } }
    }
    assert_response :unprocessable_entity
  end

  test 'consultora nao cria gatilho' do
    sign_in @consultora
    post pipeline_stage_pipeline_triggers_url(@primeiro), as: :json, params: {
      pipeline_trigger: { action_type: 'create_note', config: { content: 'x' } }
    }
    assert_response :forbidden
  end

  test 'listagem de funis devolve evento e atraso do gatilho (antes o atraso sumia ao recarregar)' do
    @primeiro.pipeline_triggers.create!(action_type: 'create_note', event: 'client_reply', delay_minutes: 90, config: { 'content' => 'x' })
    sign_in @diretora

    get pipelines_url, as: :json
    assert_response :success

    gatilho = response.parsed_body.find { |p| p['id'] == @pipeline.id }['pipeline_stages'].find { |s| s['id'] == @primeiro.id }['pipeline_triggers'].first
    assert_equal 90, gatilho['delay_minutes']
    assert_equal 'client_reply', gatilho['event']
  end

  test 'diretoria cria tarefa manual pela tela de Tarefas' do
    sign_in @diretora
    post tarefas_url, as: :json, params: {
      tarefa: { contact_id: @contact.id, tipo: 'manual_ligar', titulo: 'Ligar pra combinar acerto', prioridade: 'alta',
                user_id: @consultora.id, vencimento_em: 2.days.from_now.iso8601 }
    }
    assert_response :created
    tarefa = Tarefa.find_by!(contact_id: @contact.id)
    assert_equal 'Ligar pra combinar acerto', tarefa.titulo
    assert_equal @consultora.id, tarefa.user_id
    assert_equal 'alta', tarefa.prioridade
  end

  test 'consultora nao cria tarefa manual' do
    sign_in @consultora
    post tarefas_url, as: :json, params: { tarefa: { contact_id: @contact.id, tipo: 'manual_ligar', titulo: 'x' } }
    assert_response :forbidden
  end

  test 'tarefa criada por gatilho aparece na listagem de Tarefas da diretoria' do
    TriggerTaskCreator.call(contact: @contact, config: { 'titulo' => 'Acompanhar', 'tipo' => 'manual_acompanhamento' })
    sign_in @diretora

    get tarefas_url(status: 'pendente'), as: :json
    assert_response :success
    assert_includes response.parsed_body.map { |t| t['titulo'] }, 'Acompanhar'
  end
end
