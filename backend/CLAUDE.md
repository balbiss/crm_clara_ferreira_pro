# CRM Clara Ferreira Acessórios — Backend (Rails 8)

## Origem deste repositório
Esse código nasceu como uma **cópia local** do backend da VisitaIA (`crm_backend_inoovaweb_oficial`, CRM SaaS pra imobiliárias), copiado em 2026-07-14 pra virar a base do CRM de relacionamento da Clara Ferreira Acessórios (revenda consignada de joias/semijoias). **Não tem relação de git com o repositório original** — é um fork desconectado, iniciado do zero.

Plano completo da adaptação: ver `C:\Users\inoov\.claude\plans\parsed-petting-owl.md` (Fases 1-4).

**Status atual: Fase 1 concluída** (cópia limpa, segredos regenerados, boot verificado). As Fases 2 (adaptação de domínio no backend) e 3 (frontend) ainda não começaram — isso significa que **os models `Property`, `Condominium`, `Appointment` e o job `PropertyMatchJob` ainda existem no código, são resquício da VisitaIA e serão removidos na Fase 2**. Não tratar como intencional.

## Visão Geral
CRM de relacionamento pra revendedoras consignadas. Entidade central: Revendedora vinculada ao ID do ERP Jueri do cliente (ver briefing do projeto pra detalhes de regras de negócio — régua de ciclo, status ativa/inativa, etc.)
Deploy planejado via: Docker Swarm + Portainer (mesmo padrão da VisitaIA)

## Stack Backend (herdada da VisitaIA, mantida)
- Ruby on Rails 8 (API mode)
- PostgreSQL
- Devise + Devise-JWT (autenticação)
- ActionCable (WebSocket para chat em tempo real)
- Solid Queue (background jobs)
- WhatsApp via Baileys (`WhatsappBaileysService`) — arquitetura genérica, reaproveitada como está

## Modelos (estado herdado — ver Fase 2 do plano pro que muda)
- `User` — hoje ainda com roles da VisitaIA (atendente/empresa/admin). **Vai virar 4 perfis**: consultor/gerente/diretoria/financeiro (seção 30 do briefing do cliente).
- `Account` — tenant. Mantido como está (só 1 conta pra Clara Ferreira, sem UI multi-tenant exposta).
- `Contact` — **vai ser renomeado pra `Revendedora`** e ganhar campos do briefing (id_jueri, status_operacional, telefones múltiplos). Hoje ainda tem campos de qualificação de crédito imobiliário (a remover).
- `Conversation`/`Message`/`Inbox`/`Tag` — infraestrutura de chat genérica, mantida como está.
- `Property`/`Condominium`/`Appointment` — **resíduo da VisitaIA, remover na Fase 2.**
- `RoundRobinGroup` + `RoundRobinAssignmentService` — distribuição de conversa entre consultoras, mantido (só o `department: 'corretor'` hardcoded precisa mudar).

## Autenticação
- Devise-JWT com JTI matcher
- `active_for_authentication?` verifica `status == 'active'`
- ActionCable autentica via `?token=` JWT decodado manualmente em `app/channels/application_cable/connection.rb`

## Segredos
`deploy/docker-stack.yml` e `deploy/docker-stack-staging.yml` foram limpos (só placeholders `CHANGE_ME_*`) — **gerar credenciais novas antes de qualquer deploy real**, nunca reaproveitar as da VisitaIA. `db/seeds.rb` também já usa dado fictício da Clara Ferreira.

## Frontend
Este backend serve uma aplicação Vue 3 separada, copiada em paralelo pra `C:\Users\inoov\clara_crm_frontend` (também fork desconectado do original `crm_inoovaweb_oficial`).
