# CRM Clara Ferreira Acessórios — Documentação Geral

> Documento vivo — atualizado a cada mudança relevante de arquitetura ou regra de negócio. Última atualização: 2026-08-07.

## 1. O que é

CRM de relacionamento para revendedoras de joias/semijoias no modelo consignado. Entidade central é a **Revendedora** (model `Contact` no código, nome herdado do fork original), sincronizada automaticamente do ERP **Jueri** do cliente.

## 2. Stack

- **Backend**: Ruby on Rails 8 (API mode), PostgreSQL, Devise + Devise-JWT (auth), ActionCable (tempo real), Solid Queue (jobs em background)
- **Frontend**: Vue 3 (`<script setup>`), Pinia, Vue Router 4, Axios
- **WhatsApp**: Baileys (não-oficial, self-hosted) — API oficial (Meta Cloud API) ainda não implementada, ver seção 8
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

## 6. Times de vendas (hierarquia Jueri) — feature 2026-08-07

No Jueri, todo revendedor tem `fk_tipo_revendedor_id`: `2` = revendedora normal, `1` = **"revendedor líder"** (não é pessoa física — é o registro que representa um time/carteira, ex: "Vendas 1"..."Vendas 6", mas também pode ser o nome de uma pessoa real). Toda revendedora normal aponta pro seu líder via `fk_revendedor_gerente_id` (campo com nome legado — a UI do Jueri já chama de "líder"; existe também um `supervisor` que **não é usado** pra nada, não confundir).

No CRM:
- `SalesTeam` — catálogo dos líderes, sincronizado automaticamente a cada ciclo do `JueriSyncService` (mesmo lote já buscado, zero custo extra de API)
- `SalesTeamMembership` — join table: quais usuários do CRM podem ver a carteira **inteira** de um time (múltiplos operadores por time, igual ao "gerenciar agendas" do próprio Jueri — não é 1:1)
- `User.jueri_gerente_id` — mapeamento legado 1:1 (Agentes > "ID do Gerente no Jueri"), continua funcionando e conta como membro automático do time
- Tela `Configurações > Times de Vendas` (`requiresFullPortfolio` — gerente + diretoria) pra gerenciar quem vê cada time
- `visible_contacts_scope`/`visible_conversations_scope`/`visible_tarefas_scope` (nos controllers) expandidos: consultor vê o que é responsável direto (`Contact#user_id`) **OU** o que pertence a um time que ele tem acesso (`custom_attributes['gerente_jueri_id']` do Contact IN os times do usuário)

## 7. Storage de arquivos (MinIO)

Anexos (fotos, áudio, documentos do WhatsApp e do chat interno) usam `ActiveStorage` com serviço `:minio` (S3-compatível, self-hosted no Coolify) em produção — **nunca `:local`**, porque o disco do container é apagado a cada redeploy.

URLs de anexo usam `rails_storage_proxy_url` (não `rails_blob_url`) em todo lugar — o Rails busca o arquivo do MinIO internamente e entrega pelo domínio público já existente (`crm-api.clarajoias.com.br`), sem precisar expor o MinIO na internet nem depender de DNS novo.

**Broadcast em tempo real de anexo**: mensagens do WhatsApp são criadas (`Message.create!`) ANTES da mídia terminar de baixar — o primeiro broadcast via ActionCable sai sem `attachmentUrl`. `Message#rebroadcast` é chamado explicitamente depois que o anexo termina de processar, e o frontend faz merge (não descarta) mensagens repetidas por id.

## 8. WhatsApp (Baileys)

`WhatsappBaileysService` fala com uma API Baileys self-hosted (Coolify Service, não Application — ver infra). `connected?` confia **só** no cache escrito pelo webhook `connection.update` — nunca inferir conexão por outro meio (já teve bug de falso-positivo).

Inboxes têm botão **Reconectar** (reabre QR sem apagar a caixa) e **Desconectar** (desloga a sessão sem apagar histórico — `Inbox has_many :conversations, dependent: :nullify`, apagar caixa nunca apaga conversa/mensagem). Banner global no CRM quando um canal cai.

API oficial do WhatsApp (Meta Cloud API) **ainda não implementada** — decisão é manter as duas em paralelo quando a empresa tiver conta Meta verificada + número dedicado. Arquitetura seguiria o mesmo padrão do canal Instagram (novo `provider` em `Inbox`, novo service, novo webhook controller).

## 9. Decisões de produto importantes (não óbvias pelo código)

- **Atribuição de responsável é manual** (gerente decide quem cuida de quem) — não existe rodízio automático de leads novos. A exceção é o vínculo por time de vendas (seção 6), que reflete a hierarquia real do Jueri, não um sorteio.
- Deletar uma caixa de entrada (WhatsApp) **nunca** apaga conversas/mensagens — só desvincula.
- Status Resgate/Negativado/Descadastrada nunca reativam sozinhos mesmo com pedido novo — só manual.

## 10. Pendências conhecidas

- Fase 1 do Agendamento (Acertos): faltam fórmulas de "Qtd. Peças → Nº de horários" e "Dias com Maleta → Data Acerto", só a Clara pode fornecer
- Verificação de assinatura do webhook do Jueri (`HTTP_SIGNATURE`) não implementada
- API oficial do WhatsApp (seção 8)
- Nenhum usuário do CRM ainda vinculado aos times de vendas (feature pronta, falta configuração manual da Clara)
