# CRM Clara Ferreira Acessórios — Documentação

> Última atualização: 2026-07-20. Este documento descreve o CRM de relacionamento com revendedoras, construído a partir de um fork do CRM da VisitaIA (Rails + Vue) adaptado pro modelo de revenda consignada. Substitui o uso do Kommo descrito no briefing original.

## Visão Geral

O CRM organiza o relacionamento com as **revendedoras** de joias e semijoias no modelo consignado: elas retiram uma maleta de peças, vendem, e retornam para o acerto num ciclo de ~30 dias.

O sistema segue a diretriz do briefing: **o Jueri (ERP) é a fonte oficial da verdade** para cadastro, pedidos e financeiro. O CRM não duplica essas funções — ele consome os dados do Jueri automaticamente e adiciona a camada que o Jueri não cobre: conversas por WhatsApp, tarefas da régua, histórico de relacionamento e visão de carteira por consultora.

---

## Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Backend | Ruby on Rails 8 (API mode) |
| Frontend | Vue.js 3 + Vite + Pinia |
| Banco de dados | PostgreSQL |
| WhatsApp | Baileys API (container próprio, porta 3025) |
| IA | OpenAI GPT-4o |
| Autenticação | Devise + JWT |
| WebSocket | ActionCable (tempo real) |
| Fila de jobs | Solid Queue |
| Deploy | Docker Compose |

---

## A entidade central: Revendedora

No banco, a revendedora é o model `Contact`, vinculado ao Jueri pelo campo `id_jueri` (chave única por conta). Esse é o requisito central do briefing (seção 7): **tudo gira em torno do cadastro do Jueri, não do telefone ou da conversa**.

- Uma revendedora pode ter vários telefones (dela, da irmã, da filha etc.) guardados em `custom_attributes.telefones_adicionais`. Quando chega mensagem de qualquer um desses números, o sistema reconhece que é a mesma revendedora e não cria um cadastro duplicado.
- Todo dado que já existe no Jueri (nome, CPF, endereço, telefones, valor de vendas, peças em aberto) é **sincronizado automaticamente** — ninguém digita isso duas vezes.
- O que o CRM guarda por conta própria: consultora responsável, status da régua, observações, histórico de conversas no WhatsApp e tarefas.

---

## Sincronização automática com o Jueri

A cada **30 minutos**, o sistema busca sozinho no Jueri quais revendedoras têm pedido em aberto e atualiza o cadastro no CRM. Isso roda em segundo plano, sem ação de ninguém.

### Regra de ativação (briefing seção 11)

Uma revendedora entra automaticamente como **Ativa** quando a soma das peças dos pedidos em aberto dela no Jueri passa de **25 peças**. Não existe cadastro manual — se ela pegou maleta suficiente no Jueri, ela aparece no CRM sozinha.

### O que é atualizado a cada sincronização
- Nome, CPF, endereço, telefones
- Valor total em vendas e quantidade de peças em aberto
- Lista dos pedidos abertos dela

### Reativação automática
Se uma revendedora que estava inativa volta a ter pedido em aberto acima de 25 peças, o sistema reativa o ciclo dela sozinho — **exceto quem está em status "Resgate"**, que nunca reativa automaticamente (é uma decisão manual da equipe, mesmo que exista pedido aberto no Jueri).

### Limitação conhecida da API do Jueri
A API do Jueri não conecta o "contas a receber" a um ID de revendedora específico (só existe um campo de nome em texto livre) — por isso os status **"Inativa com Pendência"** e **"Reativação"** (que dependem de saber se a revendedora está devendo) **não são automáticos hoje** e precisam ser marcados manualmente pela equipe quando identificarem a situação. Se o Jueri disponibilizar esse vínculo no futuro, dá pra automatizar.

---

## A Régua — como o ciclo avança sozinho

Esse é o coração do sistema (briefing seções 12-13). Uma vez que a revendedora está Ativa, o status dela avança **sozinho**, sem ninguém precisar mexer, conforme os dias passam:

| Etapa | Quando acontece | O que a equipe deve fazer |
|---|---|---|
| **Ativa** | Pedido aberto > 25 peças no Jueri | Nada, o ciclo já começou |
| **3º dia** | 3 dias depois do início do ciclo | Mandar mensagem de incentivo, perguntar se viu o catálogo |
| **10º dia** | 10 dias depois | Perguntar como estão as vendas, lembrar do prazo |
| **20º dia** | 20 dias depois | Agendar o acerto, pegar encomenda pro próximo mês |
| **Atrasada** | Passou de 35 dias sem acerto | Alerta de prioridade, tentar contato urgente |
| **Suspensa por Atraso** | Virou o mês sem fazer acerto | Sai da carteira ativa, vai pra Inativas |
| **Sem Maleta** | O pedido em aberto dela fechou no Jueri (fez o acerto) e ela não abriu um pedido novo | Pode ser trabalhada pra reativação depois |

**Agendado** e **Reagendar** são os únicos passos que exigem ação manual da consultora — ela marca a data do acerto, e se a revendedora não aparecer, marca "Reagendar" pra remarcar.

Cada etapa da régua já vem com uma lista de tarefas sugeridas — isso aparece na tela **Tarefas**, calculado automaticamente a partir do status de cada revendedora (não precisa criar tarefa manualmente).

---

## Status manuais (sobrescrita da equipe)

Alguns status **nunca** são definidos automaticamente — são decisões que só uma pessoa pode tomar, e uma vez marcados, o sistema respeita e não tenta mudar sozinho:

- **Resgate** — revendedora que sumiu com as peças. Mesmo que exista pedido aberto no Jueri, ela nunca volta a ser tratada como Ativa automaticamente.
- **Negativado/Jurídico** — inadimplente que precisou de ação jurídica.
- **Descadastrada** — a empresa não quer mais reativar essa pessoa.
- **Inativa com Pendência** e **Reativação** — hoje manuais por causa da limitação do Jueri explicada acima.

---

## Telas do sistema

| Tela | O que mostra |
|---|---|
| **Minhas Revendedoras Ativas** (`/carteira`) | Carteira da consultora logada, com busca e filtro por etapa da régua |
| **Revendedoras Inativas** (`/inativas`) | Filtra pelos 7 status de inativa do briefing |
| **Tarefas** (`/tarefas`) | Checklist de ações por etapa, calculado a partir do status |
| **Visão Gerencial** (`/gerencial`, só dono/admin) | Totais por consultora, por status, atrasadas, agendadas |
| **Funil (Kanban)** (`/funil`) | Visão em quadro das etapas da régua, arrastar e soltar |
| **Detalhe da revendedora** | Dados do Jueri, telefones, conversas, notas, histórico de status |
| **Conversas** | Inbox do WhatsApp, tempo real |
| **Relatórios** | Visão geral, por consultora, por etiqueta, performance |

---

## WhatsApp (Baileys)

O CRM conecta números de WhatsApp via **Baileys** (não é a API oficial do WhatsApp Business).

**Como conectar um número:**
1. `Configurações → Caixas de Entrada → Nova Caixa`
2. O sistema gera um QR Code
3. Escaneia com o WhatsApp do número que vai atender
4. A partir daí, toda mensagem recebida chega automaticamente no CRM

Uma conta pode ter mais de um número conectado (mais de um Inbox).

**IA no WhatsApp:** cada inbox pode ter uma IA (GPT-4o) configurada pra responder automaticamente fora do horário de atendimento, adaptando a conversa pra cada etapa da régua da revendedora. Sempre que um humano manda mensagem manualmente, a IA pausa sozinha naquela conversa.

---

## Webhook do Jueri (pronto, aguardando domínio público)

Existe um endpoint (`POST /webhooks/jueri/:token`) pronto pra receber eventos em tempo real do Jueri (pedido criado, atualizado, cancelado etc.), o que deixaria a sincronização quase instantânea em vez de esperar até 30 minutos. **Só falta registrar essa URL no Jueri**, e isso só pode ser feito quando o CRM estiver hospedado num endereço público (hoje ele roda só localmente) — fica pra quando a empresa decidir subir pra um servidor de produção.

---

## Permissões

O sistema tem 4 papéis pensados pro briefing (seção 30): **Consultor**, **Gerente**, **Diretoria** e **Financeiro**. Hoje eles existem no cadastro de usuário, mas o controle de acesso completo por papel (o que cada um pode ver/fazer) ainda está em desenvolvimento — atualmente o sistema distingue apenas entre "dono/admin" (acesso total) e "consultora" (vê só a própria carteira).

---

## O que ainda não está pronto

- Vínculo automático de inadimplência (bloqueado pela API do Jueri, ver acima)
- Status "Sem Maleta" há mais de 60 dias virando "Reativação" automática (depende do item acima)
- Permissões completas dos 4 papéis nas telas
- Registro do webhook do Jueri em produção (precisa de domínio público)
- Filtros avançados nas telas de carteira (data de pedido, valor em aberto etc.)
