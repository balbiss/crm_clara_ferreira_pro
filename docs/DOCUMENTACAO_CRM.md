# CRM Clara Ferreira Acessórios — Documentação Geral

> Documento vivo — atualizado a cada mudança relevante de arquitetura ou regra de negócio. Última atualização: 2026-08-30.

## 1. O que é

CRM de relacionamento para revendedoras de joias/semijoias no modelo consignado. Entidade central é a **Revendedora** (model `Contact` no código, nome herdado do fork original), sincronizada automaticamente do ERP **Jueri** do cliente.

## 2. Stack

- **Backend**: Ruby on Rails 8 (API mode), PostgreSQL, Devise + Devise-JWT (auth), ActionCable (tempo real), Solid Queue (jobs em background)
- **Frontend**: Vue 3 (`<script setup>`), Pinia, Vue Router 4, Axios
- **WhatsApp**: dois provedores coexistindo por caixa de entrada — Baileys (não-oficial, self-hosted) e WAHA (não-oficial, self-hosted, WEBJS/whatsapp-web.js) — ver seção 8. API oficial (Meta Cloud API) ainda não implementada
- **Storage de arquivos**: MinIO (S3-compatível, self-hosted) — ver seção 7
- **Deploy**: Coolify (self-host, `2.24.96.245:8000`) — repo monorepo `github.com/balbiss/crm_clara_ferreira_pro`, branch `master`, pastas `backend/` e `frontend/`

## 3. Papéis (roles) e permissões

4 perfis (`User.role`): `consultor`, `gerente`, `diretoria`, `financeiro`.

| Nível | Quem | O que enxerga |
|---|---|---|
| `owner?` | só diretoria | configurações críticas (agentes, inboxes, tags, integrações) |
| `full_portfolio?` | gerente + diretoria | carteira inteira (todas as revendedoras, não só a própria) |
| `finance?` | financeiro + diretoria | dados financeiros/cobrança |
| consultor | — | só a própria carteira (ver seção 6 — carteira própria = atribuição direta OU time de vendas com acesso) |

Helpers em `app/controllers/application_controller.rb` (`owner?`/`full_portfolio?`/`finance?`) e `User#owner_level?`/`#finance_access?`.

## 4. Régua de ciclo (status da revendedora)

Status ativos (`Contact::ACTIVE_STATUSES`): `revendedor_ativo` → `terceiro_dia` → `decimo_dia` → `vigesimo_dia` → `agendado`/`reagendar`/`atrasada`. Avança sozinho via `ReguaAutoAdvanceJob` (roda de hora em hora).

Status inativos (`Contact::INACTIVE_STATUSES`): `sem_maleta`, `inativa_pendencia`, `suspensa_atraso`, `negativado_juridico`, `resgate`, `reativacao`, `descadastrada`. `Resgate`/`Negativado`/`Descadastrada` são **overrides permanentes** — nunca reativam sozinhos mesmo com pedido novo no Jueri, só manual.

Regra de ativação (soma de peças em pedidos "Aberto" acima de `account.min_pecas_ativa`, hoje 25) e desativação ("Sem Maleta" quando some da lista de ativos) — implementadas em `JueriSyncService`.

## 5. Sincronização com o Jueri

`JueriSyncService` (chamado por `JueriSyncJob`, recorrente a cada 30min + reativo via webhook):
1. Busca cadastro completo de revendedores em lote (paginado, ~2.300 registros hoje)
2. Busca histórico completo de pedidos em lote (paginado, ~23k+ registros) — **isso é o que faz o job levar ~2,5-3 minutos por execução**, é normal
3. Persiste pedidos (`Pedido`, upsert em lote), recalcula snapshot (`pecas_abertas_atual`) de quem já é `Contact`
4. Cria/reativa quem cruza o limiar agora (único passo que chama `find_revendedor` individual — rate-limited, só pra esse conjunto pequeno)
5. Marca "Sem Maleta" quem saiu da lista de ativos
6. Atualiza cadastro (nível, endereço etc) de todas as revendedoras existentes
7. Cataloga os "times de vendas" (ver seção 6)

Webhook reativo: `POST /webhooks/jueri/:token` (token único por conta) — qualquer evento (`pedido.*`/`venda.*`/`financeiro.*`) dispara uma sync pontual da conta, com debounce de 30s. **Autenticação real hoje é só o token na URL** — o campo de assinatura (`HTTP_SIGNATURE`) que o Jueri pede ainda não é validado no nosso lado (formato não documentado publicamente).

Endpoint manual: `POST /jueri/sync-now` (só diretoria) força uma sync fora do ciclo.

**Rate limit do Jueri**: ~300 chamadas em rajada antes de 429 — por isso o sync separa "busca em lote" (barato) de `find_revendedor` individual (caro, só pra quem está cruzando o limiar agora).

**Feed "Atividades" (2026-08-31)**: `JueriActivity` registra TODO evento recebido no webhook (revendedor.*/pedido.*/venda.*/financeiro.*), com descrição legível montada por tipo de evento (`Webhooks::JueriController#descricao_para`) — inspirado no painel "Atividades do Dia" da própria Jueri, que mostra bem mais coisa do que o CRM refletia antes. **Sem notificação/push nesse feed** (só o cadastro novo tem aviso, ver abaixo) — pedido aberto muda de valor várias vezes por dia, virar aviso a cada mudança seria barulho demais. Tela nova em `/atividades`, só gerência/diretoria (`GET /jueri_activities`, paginado). `contact_id` fica nulo quando o `fk_revendedor_id` do evento ainda não vira um `Contact` local (ex: cadastro novo sem pedido aberto ainda).

**Aviso de cadastro novo (2026-08-31)**: evento `revendedor.created` do webhook dispara uma notificação (sino + push) só pra dono/gerente (`Notification.audience = 'owner_level'`, ver seção 10.2) com nome da revendedora e quem cadastrou no Jueri. **Atenção**: o nome do campo "quem cadastrou" no payload (`usuario`/`criado_por`) ainda não foi confirmado contra um evento real — foi um chute educado seguindo o padrão do campo `vendedor` já visto no payload de pedido. O payload completo continua logado inteiro (`Rails.logger.info` logo acima no controller) — na próxima vez que um `revendedor.created` real chegar, checar o log e corrigir o nome da chave se `cadastrado_por` sair "não identificado".

**Bug encontrado e corrigido (2026-08-30): correntes duplicadas do `JueriSyncJob`.** `config/initializers/recurring_jobs.rb` agenda `JueriSyncJob.set(wait: 2.minutes).perform_later` a **cada boot** do backend/worker, sem checar se já existe uma corrente recorrente rodando — como o próprio job se reagenda pra sempre (`ensure ... perform_later`), cada deploy empilhava uma corrente nova e independente. Depois de vários deploys seguidos numa mesma sessão, isso fez o job rodar a cada 1-2min (em vez de a cada 30min) e disparar 429 em cascata na API do Jueri — mesma classe do incidente antigo do `JueriReconciliarPedidosAbertosJob`. Corrigido com um lock (`Rails.cache.write(..., unless_exist: true, expires_in: 30.minutes)`) que colapsa todas as correntes duplicadas pra só uma executar de verdade por ciclo.

**`Pedido#data_acerto`** (2026-08-30) — a Jueri manda esse campo já no payload do pedido desde a criação (ex: pedido aberto em 29/08 já vem com `data_acerto` 28/09, o prazo padrão da maleta) — não é preenchido só depois do acerto acontecer de verdade. Persistido em `persistir_pedidos`, exposto em `GET /contacts` como `data_prevista_acerto` por revendedora (mínimo entre os pedidos abertos) e mostrado na coluna "Previsão de acerto" de `RevendedorasAtivas.vue`.

## 6. Times de vendas (hierarquia Jueri) — feature 2026-08-07

No Jueri, todo revendedor tem `fk_tipo_revendedor_id`: `2` = revendedora normal, `1` = **"revendedor líder"** (não é pessoa física — é o registro que representa um time/carteira, ex: "Vendas 1"..."Vendas 6", mas também pode ser o nome de uma pessoa real). Toda revendedora normal aponta pro seu líder via `fk_revendedor_gerente_id` (campo com nome legado — a UI do Jueri já chama de "líder"; existe também um `supervisor` que **não é usado** pra nada, não confundir).

No CRM:
- `SalesTeam` — catálogo dos líderes, sincronizado automaticamente a cada ciclo do `JueriSyncService` (mesmo lote já buscado, zero custo extra de API)
- `SalesTeamMembership` — join table: quais usuários do CRM podem ver a carteira **inteira** de um time (múltiplos operadores por time, igual ao "gerenciar agendas" do próprio Jueri — não é 1:1)
- `User.jueri_gerente_id` — mapeamento legado 1:1 (Agentes > "ID do Gerente no Jueri"), continua funcionando e conta como membro automático do time
- Tela `Configurações > Times de Vendas` (`requiresFullPortfolio` — gerente + diretoria) pra gerenciar quem vê cada time
- `visible_contacts_scope`/`visible_conversations_scope`/`visible_tarefas_scope` (nos controllers) expandidos: consultor vê o que é responsável direto (`Contact#user_id`) **OU** o que pertence a um time que ele tem acesso (`custom_attributes['gerente_jueri_id']` do Contact IN os times do usuário)

### 6.1 Atribuição em massa de carteira (2026-08-30)

"Gerenciar acesso" (seção acima) só controla **visibilidade** — não atribui ninguém como responsável de fato. Pra isso existe uma ação separada:

- `POST /sales_teams/:id/assign_unassigned { user_id }` (`SalesTeamsController#assign_unassigned`) — atribui `Contact#user_id` em massa pro consultor escolhido, usando o mesmo vínculo `custom_attributes['gerente_jueri_id'] == team.jueri_lider_id`.
- **Só preenche quem está com `user_id: nil`** — nunca sobrescreve uma atribuição manual já feita antes. Coerente com a decisão de produto de que atribuição é sempre manual (seção 9), só que em lote em vez de um por um.
- Cada time devolve `unassigned_contacts_count` (contagem ao vivo) — a tela `Configurações > Times de Vendas` mostra esse número no botão "Atribuir carteira (N)" e desabilita quando chega a zero.

## 7. Storage de arquivos (MinIO)

Anexos (fotos, áudio, documentos do WhatsApp e do chat interno) usam `ActiveStorage` com serviço `:minio` (S3-compatível, self-hosted no Coolify) em produção — **nunca `:local`**, porque o disco do container é apagado a cada redeploy.

URLs de anexo usam `rails_storage_proxy_url` (não `rails_blob_url`) em todo lugar — o Rails busca o arquivo do MinIO internamente e entrega pelo domínio público já existente (`crm-api.clarajoias.com.br`), sem precisar expor o MinIO na internet nem depender de DNS novo.

**Broadcast em tempo real de anexo**: mensagens do WhatsApp são criadas (`Message.create!`) ANTES da mídia terminar de baixar — o primeiro broadcast via ActionCable sai sem `attachmentUrl`. `Message#rebroadcast` é chamado explicitamente depois que o anexo termina de processar, e o frontend faz merge (não descarta) mensagens repetidas por id.

## 8. WhatsApp (Baileys + WAHA)

`Inbox#provider` decide qual API usar (`baileys`, `waha`, `instagram`) e `Inbox#messaging_service` despacha pro service certo (`WhatsappBaileysService` / `WhatsappWahaService` / `InstagramMessagingService`) — os três implementam a mesma interface pública (`create_connection`, `send_message`, `send_presence_update`, `fetch_profile_picture_url`, `fetch_qr_code`, `connected?`, `delete_connection`, `resolve_jid`), então nenhum código que envia mensagem deveria falar com um service concreto diretamente — sempre `inbox.messaging_service.*`. **Lição aprendida (2026-08-30)**: 3 lugares hardcoded pra `WhatsappBaileysService` (jobs de follow-up/agendado, notificação de agente) quebravam silenciosamente pra qualquer inbox não-Baileys.

Duas caixas de WhatsApp podem coexistir na mesma conta, cada uma com seu provider — na criação de caixa nova, **WAHA vem marcado como recomendado/padrão**, Baileys continua disponível como opção manual.

### 8.1 Baileys

`WhatsappBaileysService` fala com uma API Baileys self-hosted (Coolify Service, não Application — ver infra). `connected?` confia **só** no cache escrito pelo webhook `connection.update` — nunca inferir conexão por outro meio (já teve bug de falso-positivo).

### 8.2 WAHA

`WhatsappWahaService` fala com uma instância WAHA self-hosted (engine WEBJS/whatsapp-web.js). Diferenças importantes em relação ao Baileys:

- **Formato de JID**: `{digits}@c.us` (WAHA/WEBJS), não `@s.whatsapp.net` (Baileys).
- **Identificação da caixa no webhook**: `POST /webhooks/waha?inbox_id=X` — por query param, não por número de telefone (Baileys usa `?phone=`).
- **QR code buscado ao vivo**: `GET /api/{session}/auth/qr` na hora (devolve PNG, convertido pra data URL base64) — não depende de cache alimentado por webhook como o Baileys. `connected?` também é checagem ao vivo (`GET /api/sessions/{session}`, status `WORKING`).
- **`@lid` (identificador de privacidade do WhatsApp)**: em algumas conversas o `from`/chat id vem como `{numero_fantasma}@lid` em vez do telefone real — sem tratar isso, o contato nasce com nome/telefone errados (os próprios dígitos do lid, que não existem como número). O webhook resolve isso chamando `GET /api/contacts?session=X&contactId={lid}`, que devolve o contato de verdade (`id` no formato `@c.us`, `name`/`pushname`). O `jid` salvo no Contact continua sendo o `@lid` (é o que a WAHA espera pra mandar mensagem de volta pro mesmo chat) — só telefone/nome usam o valor resolvido.
- **Endpoints de mídia confirmados**: `sendText`, `sendImage`, `sendVideo` (dedicado), `sendVoice` (áudio/PTT), `sendFile` (documentos), `startTyping`/`stopTyping`. GIF e figurinha não têm endpoint na tier CORE.
- **Bug confirmado e corrigido (2026-08-31)**: eventos de PROTOCOLO do WhatsApp Business (`_data.type` = `notification_template`, `biz_content_placeholder` etc — negociação de privacidade de conta business, cartão de contato) chegam no webhook `message.any` igual a uma mensagem real, sem texto nem mídia. Antes disso viravam mensagem visível "📎 Arquivo não suportado ou vazio" na tela; agora são ignorados silenciosamente (`WahaController::TIPOS_SISTEMA_SEM_CONTEUDO`) quando não têm conteúdo de verdade. Visto ao vivo: 3-4 desses chegaram em <1s pro mesmo chat e, como `Contact.find_by_any_phone` + `create!` não é atômico, **criaram um Contact duplicado** (race condition) — corrigido com índice único parcial `idx_contacts_account_jid_unique` (`account_id`+`jid`, só onde `jid` não é nulo) + `rescue ActiveRecord::RecordNotUnique` re-buscando o contato em vez de duplicar, aplicado tanto no controller da WAHA quanto no do Baileys (mesmo padrão de find+create lá).

### 8.3 Regra geral: `source_id` é obrigatório em toda mensagem enviada pelo CRM

Sempre que uma mensagem é criada porque o CRM mandou pra fora (resposta do agente, IA, follow-up, mensagem agendada, encerramento), o `id` retornado por `messaging_service.send_message(...)` **precisa** ser salvo como `Message#source_id`. Motivo: o WhatsApp ecoa de volta toda mensagem enviada (evento `fromMe: true` no webhook) — sem o `source_id` batendo, esse eco não encontra a mensagem original e é tratado como "intervenção humana pelo celular", criando uma **segunda mensagem duplicada** (sem `sender_id`, sem foto do agente) e ainda pausando a IA à toa.

Duas armadilhas reais já encontradas nesse fluxo (2026-08-30):
1. `messages_controller#create` (o caminho principal de resposta do agente) nunca salvava `source_id` nenhum — corrigido.
2. Na WAHA, o campo `id` da resposta de `sendText`/`sendImage`/etc vem como **objeto aninhado** (`{fromMe, remote, id, _serialized}`), não como string — pegar o objeto inteiro (em vez de `id._serialized`) também quebra a comparação, mesmo com o `source_id` sendo "salvo".

### 8.4 Gestão de caixa (comum aos dois providers)

Inboxes têm botão **Reconectar** (reabre QR sem apagar a caixa) e **Desconectar** (desloga a sessão sem apagar histórico — `Inbox has_many :conversations, dependent: :nullify`, apagar caixa nunca apaga conversa/mensagem). Banner global no CRM quando um canal cai. `phone_number` é único por conta pra `baileys`/`waha` (validação no model) — duas caixas com o mesmo número disputariam a mesma sessão externa e só uma receberia webhook de verdade.

API oficial do WhatsApp (Meta Cloud API) **ainda não implementada** — arquitetura seguiria o mesmo padrão (novo `provider` em `Inbox`, novo service, novo webhook controller).

## 9. Conversas e mensagens

- **"Apagar conversa" ≠ "Apagar contato"** (dois botões distintos no menu ⋮ do painel de contato, adicionado 2026-08-30). "Apagar conversa" (`DELETE /conversations/:id`) apaga só o histórico de mensagens daquela conversa — o `Contact` (cadastro, notas, pedidos, tags, posição no pipeline) continua intacto. "Apagar contato" (`DELETE /contacts/:id`) apaga o `Contact` inteiro e tudo que depende dele em cascata (`dependent: :destroy` em conversations/notes/pipeline_cards/pedidos/reseller_phones/lifecycle_events/tarefas/contact_tags) — **se a revendedora ainda tiver pedido aberto no Jueri, ela volta na próxima sincronização como um contato novo, sem nada do histórico apagado.**
- Balão de mensagem enviada mostra a **foto de perfil do agente** (`User#avatar_url`) em vez de só a inicial — serializado em três lugares que precisam ficar em sincronia: histórico da conversa (`ConversationsController#format_conversation`), resposta imediata (`MessagesController#create`) e broadcast em tempo real (`Message#broadcast_to_conversation`).
- Menu lateral (Comunicações) lista cada caixa de entrada como subitem, com um ponto de status (verde/vermelho), levando pra `/conversas/inbox/:inboxId` — rota e filtro (`sidebarInboxId` na store) já existiam, só não estavam expostos.
- **Gotcha do filtro de caixa**: ao trocar de filtro/caixa, a conversa ativa (painel da direita) precisa ser reconciliada pro novo filtro (`reconcileActiveConversation` na store) — sem isso, o auto-seleção da conversa mais recente da conta inteira (que roda sempre que não há nenhuma selecionada, ex: depois de um F5) ignorava o filtro e abria uma conversa de outra caixa sem nenhuma mensagem visível ali.

## 10. Decisões de produto importantes (não óbvias pelo código)

- **Atribuição de responsável é manual** (gerente decide quem cuida de quem) — não existe rodízio automático de leads novos. A exceção é o vínculo por time de vendas (seção 6), que reflete a hierarquia real do Jueri, não um sorteio — mesmo a atribuição em massa (seção 6.1) só preenche quem está sem responsável, nunca sobrescreve.
- Deletar uma caixa de entrada (WhatsApp) **nunca** apaga conversas/mensagens — só desvincula. "Apagar conversa" (seção 9) também preserva o cadastro da revendedora — só "Apagar contato" é destrutivo de verdade.
- Status Resgate/Negativado/Descadastrada nunca reativam sozinhos mesmo com pedido novo — só manual.

### 10.1 Histórico de auditoria (`ContactAuditEvent`, 2026-08-30)

Toda mudança de `Contact#status` e `Contact#user_id` (responsável) fica registrada automaticamente via callback `after_update` no model (`Contact#registrar_mudanca_status`/`#registrar_mudanca_responsavel`) — não precisa ser chamado manualmente em cada lugar que muda esses campos. `changed_by` vem de `Current.user` (`ActiveSupport::CurrentAttributes`, setado em `ApplicationController`) — nulo significa mudança feita pelo sistema (sync do Jueri, régua automática), preenchido significa uma pessoa mudou pela tela.

**Gotcha**: `update_all`/`update_columns` NÃO disparam callback de model — `bulk_assign` (ContactsController) e `assign_unassigned` (SalesTeamsController) foram convertidos de `update_all` pra um loop com `#update` justamente por causa disso (senão essas duas telas de atribuição em massa ficariam sem registro no histórico). Qualquer código novo que mude `status`/`user_id` em lote precisa do mesmo cuidado.

Exposto em `GET /contacts/:id` como `contact_audit_events` (com `changed_by` embutido), mostrado na aba "Histórico" de `ContactDetails.vue`.

### 10.2 Notificações com público restrito (`Notification.audience`, 2026-08-31)

`Notification` (sino do topo) era conta inteira (sem `user_id`) e **nunca tinha sido usada de verdade** (0 linhas em produção antes disso). Adicionado `audience`: nulo = todo mundo vê (comportamento antigo preservado), `'owner_level'` = só gerente/diretoria (`User::OWNER_LEVEL_ROLES`) — `Notification.visible_to(user)` faz o filtro, usado em `NotificationsController#index`/`#mark_all_read`/`#mark_as_read`. Primeiro uso real: aviso de `revendedor.created` (seção 5).

## 10.3 Fluxos — construtor visual de automação (2026-08-31)

Menu "Fluxos" (só diretoria, `isCriticalConfig`), inspirado no builder do ManyChat. `Flow` → `FlowNode`/`FlowEdge` (grafo livre, não etapas lineares como `Pipeline`). `FlowNode#key` (UUID gerado no frontend) é o identificador estável que o Vue Flow usa e que `FlowEdge#source_key/target_key` referenciam — nunca é o `id` do Rails, evita remapear id no autosave.

**Tipos de nó** (`FlowNode::NODE_TYPES`): `trigger` (Novo contato/Palavra-chave/Mensagem recebida/Evento/Webhook/Manual em `data.trigger_type`), `send_message`, `ask_question` (guarda resposta em `data.variable`), `send_media` (4 subtipos via `data.media_type`: image/video/audio/document), `options` (Botões e Lista de opções via `data.mode`, saídas dinâmicas nomeadas por opção — mesma ideia do `condition`), `condition` (`data.check_type`: variável/resposta/horário/dia/etiqueta/status — mas só variável é avaliado de verdade hoje), `wait`, `action` (add_tag/remove_tag/assign_agent/update_variable/send_webhook via `data.action_type` — mesmo vocabulário de `PipelineTrigger#action_type`, pensado pra um dia ser executado pelo mesmo tipo de runner), `end`.

**Execução ao vivo (`FlowRunnerService`)**: cobertura deliberadamente mínima — só o gatilho de Palavra-chave dispara de verdade (hookado no webhook da WAHA, antes do bloco de IA), e só entende `send_message`/`wait`/`condition` (sempre segue "não")/`end`. Os outros gatilhos e `ask_question`/`send_media`/`options`/`action` são só editor por enquanto — o `case` do runner simplesmente para nesse nó sem erro. Testado ponta a ponta com WhatsApp real (WAHA) em 2026-08-31, incluindo `wait` segurando de verdade (achado num teste real: sem isso as mensagens de antes/depois do Aguardar chegavam juntas, instantâneo) — `wait` enfileira `FlowContinueJob` com `.set(wait: segundos)` (SolidQueue, mesmo padrão de `ReguaAutoAdvanceJob`) e para a execução síncrona ali; o job retoma de onde parou quando dispara.

**Bug de corrida corrigido**: o eco do WhatsApp (`fromMe: true`) pode chegar no webhook antes do `Message` local ser gravado com o `source_id` certo, duplicando a mensagem. Guarda: `FlowRunnerService` escreve `Rails.cache` na chave `ai_is_replying_#{inbox}_#{chat}` (mesma já usada pela IA) antes de mandar; o webhook passou a checar essa chave incondicionalmente (antes só quando `inbox.ai_enabled`).

**Pendente do prompt original**: rascunho/publicado separado (só existe Ativo/Inativo), simulador "Testar fluxo", templates prontos, execução real dos gatilhos além de Palavra-chave e dos nós de Ação, canvas mobile.

## 11. Pendências conhecidas

- Fase 1 do Agendamento (Acertos): faltam fórmulas de "Qtd. Peças → Nº de horários" e "Dias com Maleta → Data Acerto", só a Clara pode fornecer
- Verificação de assinatura do webhook do Jueri (`HTTP_SIGNATURE`) não implementada
- API oficial do WhatsApp (seção 8)
- WAHA: fluxo de conexão/envio testado ponta a ponta com número real; recebimento de mídia (foto/áudio/vídeo) via WAHA ainda não validado com um arquivo real (só o parsing do payload foi corrigido)
- Nenhum usuário do CRM ainda vinculado aos times de vendas por "Gerenciar acesso" (visibilidade) — a atribuição de responsável (seção 6.1) é a peça que estava faltando pra isso ser útil na prática
- **Bug confirmado na API do Jueri (2026-08-30) — bloqueia Financeiro/Vendas no CRM**: os endpoints `/venda`, `/financeiro/contas_receber` e `/financeiro/contas_pagar` **ignoram completamente o parâmetro `page`** — não importa o valor pedido (2, 100, ou até a própria última página que a API informa em `last_page`), sempre devolvem o mesmo primeiro lote de registros (dados de 2017). Confirmado testando os 3 endpoints diretamente, inclusive com a URL exata sugerida pelo próprio `next_page_url` da resposta. `pedido` e `revendedor` (os únicos já sincronizados hoje) **não têm esse problema** — paginam normalmente, por isso funcionam em produção. Diagnóstico feito via `GET /jueri/debug_recurso?recurso=<venda|contas_receber|contas_pagar|representante|cliente>` (endpoint temporário, só diretoria, em `JueriController`). **Não é algo corrigível do nosso lado** — precisa ser reportado ao suporte do Jueri. Enquanto não for corrigido lá, não dá pra construir uma aba de Financeiro/Vendas confiável (o único vínculo com a revendedora nesses recursos já seria frágil por si só — texto livre no campo `contato`, sem `fk_revendedor_id` em `contas_receber`/`contas_pagar` — mas o bug de paginação é o bloqueio real, anterior a esse problema de vínculo).
