require 'openai'

class AiAssistantService
  def initialize(inbox, conversation, extra_context: nil)
    @inbox = inbox
    @conversation = conversation
    @extra_context = extra_context
    api_key = GlobalSetting.fetch('openai_api_key').presence || ENV['OPENAI_API_KEY']
    @client = OpenAI::Client.new(access_token: api_key)
  end

  def self.transcribe_audio(media_data, filename, inbox)
    api_key = GlobalSetting.fetch('openai_api_key').presence || ENV['OPENAI_API_KEY']
    client = OpenAI::Client.new(access_token: api_key)

    # Precisamos criar um arquivo temporário para enviar pro multipart faraday da OpenAI
    tempfile = Tempfile.new([filename.split('.').first, ".#{filename.split('.').last}"])
    tempfile.binmode
    tempfile.write(media_data)
    tempfile.rewind

    response = client.audio.transcribe(
      parameters: {
        model: "whisper-1",
        file: File.open(tempfile.path, "rb")
      }
    )

    tempfile.close
    tempfile.unlink

    response["text"]
  end

  def process_message
    # 1. Recuperar histórico da conversa
    messages = build_message_history

    # 2. Definir o comportamento da IA (System Prompt)
    system_prompt = {
      role: "system",
      content: build_system_prompt
    }

    # 3. Enviar para a OpenAI com Tools
    response = @client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [system_prompt] + messages,
        temperature: @inbox.ai_temperature || 0.7,
        tools: defined_tools,
        tool_choice: "auto"
      }
    )

    text = handle_response(response, messages)
    text.present? ? split_into_messages(text) : []
  end

  private

  def split_into_messages(text)
    return [text] if text.length < 80 # Não divide mensagens curtas

    prompt = <<~PROMPT
      Você é um agente que simula o comportamento humano ao enviar mensagens no WhatsApp.
      Seu objetivo é pegar uma mensagem longa recebida como entrada e dividi-la em múltiplas mensagens menores — sem alterar as palavras do conteúdo original — apenas separando em partes naturais, como um humano faria ao digitar e enviar aos poucos.

      REGRAS:
      - Não reescreva o conteúdo. Apenas separe em mensagens menores respeitando a pontuação e pausas naturais.
      - As divisões devem parecer naturais.
      - Sempre retorne como um JSON com o campo "mensagens" que é um array de strings.
      - Remova vírgulas e pontos finais no final das mensagens, quando soar mais natural para o chat.
      - Tente manter cada mensagem entre 1 a 4 frases no máximo.
      - NUNCA QUEBRE A MENSAGEM EM MAIS DE 5 PARTES.
      - Mantenha itens de lista na mesma mensagem. NUNCA quebre listas em múltiplas mensagens.
    PROMPT

    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: prompt },
          { role: "user", content: text }
        ],
        temperature: 0.3
      }
    )

    json_str = response.dig("choices", 0, "message", "content")
    JSON.parse(json_str)["mensagens"] || [text]
  rescue => e
    Rails.logger.error("Erro ao dividir mensagem em blocos: #{e.message}")
    [text]
  end

  def build_message_history
    recent_messages = @conversation.messages.order(created_at: :asc).last(100)

    recent_messages.map do |msg|
      role = msg.sender_type == 'Contact' ? 'user' : 'assistant'
      { role: role, content: msg.text || "📎 [Mídia/Anexo]" }
    end
  end

  # Régua consignada (briefing seção 12) — usada pra dar contexto de fase à IA,
  # já que o status do contato agora é a etapa do ciclo, não um funil de vendas.
  def build_system_prompt
    base_prompt = @inbox.ai_prompt.presence || "Você é uma assistente virtual prestativa."

    current_time = Time.current.in_time_zone('America/Sao_Paulo')
    dias_semana = %w[Domingo Segunda-feira Terça-feira Quarta-feira Quinta-feira Sexta-feira Sábado]
    dia_semana = dias_semana[current_time.wday]
    date_info = "Hoje é #{dia_semana}, #{current_time.strftime('%d/%m/%Y')}. O horário atual é #{current_time.strftime('%H:%M')}."

    contact_name = @conversation.contact.name.presence || "Revendedora (nome desconhecido)"
    contact_phone = @conversation.contact.phone.presence || "Telefone desconhecido"
    contact_info = "Você está conversando com: #{contact_name}. Número do WhatsApp: #{contact_phone}."

    labels_instruction = "\n[ETIQUETAS]: Use 'apply_label' sempre que tiver certeza da situação da revendedora. [OBRIGATÓRIO] Use 'com_atendente' SEMPRE que você disser à revendedora, de qualquer forma, que vai encaminhar/transferir/passar o atendimento para um consultor humano — mesmo que essa instrução esteja em outra parte do seu prompt e não use essas palavras exatas. Chame 'apply_label' com 'com_atendente' NA MESMA resposta em que disser isso — nunca prometa a transferência sem chamar a ferramenta."
    routing_instruction = "\n[ROTEAMENTO DE DEPARTAMENTO]: Se a revendedora mencionar assuntos fora do relacionamento de venda — cobranças, boletos, segunda via de recibo, problemas com pedido — use imediatamente a ferramenta 'route_to_department': 'financeiro' = cobranças, boletos, pendências; 'suporte' = dúvidas gerais fora do escopo comercial. Avise que está transferindo."

    prompt = "#{base_prompt}\nSeu nome é #{@inbox.ai_name || 'Assistente'}. Você atende revendedoras de uma revenda consignada de joias e semijoias. Seja muito humana, empática e natural.\n[CONTEXTO TEMPORAL]: #{date_info} (Sempre use essa data e hora reais como base).\n[DADOS DA REVENDEDORA]: #{contact_info}#{labels_instruction}#{routing_instruction}"

    # Contexto extra injetado por integrações (webhooks) — sem exigir config manual
    if @extra_context.present?
      prompt += "\n\n[CONTEXTO DA INTEGRAÇÃO]: #{@extra_context}"
    end

    status = @conversation.contact.status.presence || 'revendedor_ativo'

    case status
    when 'revendedor_ativo'
      prompt += "\n[INÍCIO DE CICLO]: A revendedora acabou de pegar a maleta. Foco em acolher, tirar dúvidas iniciais e incentivar o começo das vendas."
    when 'terceiro_dia'
      prompt += "\n[3º DIA DO CICLO]: Mande uma mensagem de incentivo, pergunte se ela já conseguiu ver o catálogo e oriente a compartilhar fotos das peças."
    when 'decimo_dia'
      prompt += "\n[10º DIA DO CICLO]: Pergunte como estão as vendas, lembre do prazo do acerto e tente identificar se ela está com alguma dificuldade comercial."
    when 'vigesimo_dia'
      prompt += "\n[20º DIA DO CICLO]: Fase mais estratégica — ajude a verificar o resultado parcial, incentive vender até o fim, pergunte se quer fazer encomenda pro próximo mês e comece a tratar do agendamento do acerto."
    when 'agendado'
      prompt += "\n[ACERTO AGENDADO]: Confirme data e horário do acerto e lembre a revendedora do compromisso."
    when 'reagendar'
      prompt += "\n[REAGENDAR]: A revendedora não compareceu ou cancelou o acerto anterior — ajude a remarcar uma nova data."
    when 'atrasada', 'suspensa_atraso'
      prompt += "\n[ATRASO]: A revendedora está com o ciclo atrasado. Seja gentil mas direta ao perguntar sobre o andamento das vendas e a possibilidade de agendar o acerto."
    else
      prompt += "\n[ATENDIMENTO GERAL]: Ajude com o que for perguntado e, se identificar necessidade de atenção humana, use 'route_to_department' ou aplique a etiqueta 'com_atendente'."
    end

    prompt
  end

  def defined_tools
    kanban_tool = {
      type: "function",
      function: {
        name: "move_kanban_card",
        description: "Atualiza a etapa da revendedora no ciclo consignado (régua de acompanhamento).",
        parameters: {
          type: "object",
          properties: {
            stage: {
              type: "string",
              enum: %w[revendedor_ativo terceiro_dia decimo_dia vigesimo_dia agendado reagendar atrasada],
              description: "Nova etapa da revendedora no ciclo consignado."
            }
          },
          required: ["stage"]
        }
      }
    }

    route_tool = {
      type: "function",
      function: {
        name: "route_to_department",
        description: "Encaminha a conversa para um agente do departamento correto (suporte, financeiro, manutencao). Use quando o assunto foge do relacionamento comercial com a revendedora.",
        parameters: {
          type: "object",
          properties: {
            department: { type: "string", enum: ["suporte", "financeiro", "manutencao"], description: "Departamento de destino" },
            reason:     { type: "string", description: "Motivo do encaminhamento (ex: 'revendedora pergunta sobre cobrança')" }
          },
          required: ["department"]
        }
      }
    }

    label_tool = {
      type: "function",
      function: {
        name: "apply_label",
        description: "Aplica uma etiqueta na conversa para identificar a situação da revendedora. Use SEMPRE que identificar claramente a situação. 'com_atendente' = a revendedora pede para falar com um humano ou a situação exige atendimento especializado (ex: negociação de acerto, reclamação). Não use 'agente_off' — ela é aplicada automaticamente.",
        parameters: {
          type: "object",
          properties: {
            label: {
              type: "string",
              enum: ["revendedora_engajada", "revendedora_dificuldade", "desqualificado", "com_atendente"],
              description: "Etiqueta a aplicar na conversa."
            },
            reason: {
              type: "string",
              description: "Motivo breve pelo qual está aplicando esta etiqueta."
            }
          },
          required: ["label"]
        }
      }
    }

    [kanban_tool, label_tool, route_tool]
  end

  def handle_response(response, messages)
    max_rounds = 4
    current_response = response

    max_rounds.times do
      choice = current_response.dig("choices", 0, "message")

      unless choice["tool_calls"]
        return choice["content"]
      end

      # Processa todos os tool_calls desta rodada — a IA às vezes chama a
      # mesma ferramenta com os mesmos argumentos duas vezes na mesma resposta
      # (comportamento do próprio modelo, não do nosso código); como algumas
      # ferramentas têm efeito colateral real, a segunda chamada idêntica não
      # é executada de novo.
      seen_calls = Set.new
      all_tool_results = choice["tool_calls"].map do |tool_call|
        function_name = tool_call.dig("function", "name")
        raw_arguments = tool_call.dig("function", "arguments")
        arguments = JSON.parse(raw_arguments)
        dedup_key = [function_name, raw_arguments]

        if seen_calls.include?(dedup_key)
          { tool_call: tool_call, name: function_name, result: "Ação já realizada nesta mesma resposta, não repetida." }
        else
          seen_calls << dedup_key
          result = execute_tool(function_name, arguments)
          { tool_call: tool_call, name: function_name, result: result.to_s }
        end
      end

      # Adiciona a chamada do assistente e todos os resultados ao histórico
      messages << { role: "assistant", content: nil, tool_calls: choice["tool_calls"] }
      all_tool_results.each do |tr|
        messages << { role: "tool", tool_call_id: tr[:tool_call]["id"], name: tr[:name], content: tr[:result] }
      end

      # Nova chamada com tools disponíveis (para permitir encadeamento)
      current_response = @client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [{ role: "system", content: build_system_prompt }] + messages,
          tools: defined_tools,
          tool_choice: "auto",
          temperature: @inbox.ai_temperature || 0.7
        }
      )
    end

    # Fallback: última resposta se atingiu o limite de rodadas
    current_response.dig("choices", 0, "message", "content")
  end

  def execute_tool(name, args)
    account_id = @conversation.account_id
    contact = @conversation.contact

    case name
    when "apply_label"
      label_name = args['label'].to_s.strip.downcase
      colors = { 'revendedora_engajada' => '#10b981', 'revendedora_dificuldade' => '#f59e0b', 'desqualificado' => '#6b7280', 'com_atendente' => '#8b5cf6' }
      color = colors[label_name] || '#6b7280'

      tag = @conversation.account.tags.find_or_create_by!(name: label_name) { |t| t.color = color }
      @conversation.tags << tag unless @conversation.tags.include?(tag)

      ActionCable.server.broadcast("conversations_channel_#{@conversation.account_id}", {
        event: 'conversation_tags_updated',
        conversation_id: @conversation.id,
        tags: @conversation.reload.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
      })

      # Pausa IA permanentemente para labels que encerram o ciclo de IA
      if %w[com_atendente desqualificado].include?(label_name)
        pause_ai_permanently
        RoundRobinAssignmentService.assign_next(@conversation.reload) if label_name == 'com_atendente'
      end

      "Etiqueta '#{label_name}' aplicada na conversa. #{args['reason']}"

    when "route_to_department"
      dept = args['department'].to_s
      agent = nil

      ApplicationRecord.transaction do
        agent = User.where(account_id: account_id, status: 'active', department: dept)
                    .order(Arel.sql('queue_position ASC NULLS FIRST, id ASC'))
                    .lock
                    .first

        if agent&.available_for_roundrobin
          max_pos = User.where(account_id: account_id, available_for_roundrobin: true).maximum(:queue_position) || 0
          agent.update_columns(queue_position: max_pos + 1)
        end
      end

      if agent
        @conversation.update!(user_id: agent.id)
        ActionCable.server.broadcast("conversations_channel_#{@conversation.account_id}", {
          event: 'lead_atribuido',
          assigned_to_user_id: agent.id,
          conversation_id: @conversation.id,
          contact_name: contact.name.presence || contact.phone,
          assigned_by: 'ia_routing'
        })
        AgentNotificationService.notify_assignment(
          agent: agent, conversation: @conversation, assigned_by: 'ia'
        ) rescue nil
        pause_ai_permanently
        dept_label = { 'suporte' => 'Suporte', 'financeiro' => 'Financeiro', 'manutencao' => 'Manutenção' }[dept] || dept
        "Conversa encaminhada para #{agent.first_name} (#{dept_label}). IA pausada."
      else
        "Nenhum agente disponível no departamento #{dept} no momento."
      end

    when "move_kanban_card"
      contact.update!(status: args['stage'])
      "A etapa da revendedora foi atualizada para #{args['stage']} no CRM."

    else
      "Erro: Ferramenta não implementada."
    end
  rescue => e
    "Erro ao executar a ferramenta: #{e.message}"
  end

  def pause_ai_permanently
    jid = @conversation.contact.channel_identifier
    return unless jid

    # Pausa sem expiração — só é retomada pelo botão "Retomar IA"
    Rails.cache.write("ai_paused_#{@inbox.id}_#{jid}", Time.current.to_i)

    # Aplica tag agente_off para indicar visualmente que a IA está desligada
    tag = @conversation.account.tags.find_or_create_by!(name: 'agente_off') { |t| t.color = '#f97316' }
    @conversation.tags << tag unless @conversation.tags.include?(tag)

    ActionCable.server.broadcast("conversations_channel_#{@conversation.account_id}", {
      event: 'conversation_tags_updated',
      conversation_id: @conversation.id,
      tags: @conversation.reload.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
    })
  rescue => e
    Rails.logger.error("Erro ao pausar IA: #{e.message}")
  end
end
