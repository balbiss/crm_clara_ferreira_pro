# CRM Clara Ferreira Acessórios — Frontend (Vue 3)

## Origem deste repositório
Cópia local do frontend da VisitaIA (`crm_inoovaweb_oficial`), feita em 2026-07-14 pra virar a base do CRM da Clara Ferreira Acessórios (revenda consignada de joias/semijoias). **Sem relação de git com o original** — fork desconectado.

Plano completo: `C:\Users\inoov\.claude\plans\parsed-petting-owl.md` (Fases 1-4). **Status atual: Fase 1 concluída** (cópia + rebrand cosmético básico + boot verificado). A Fase 3 (cirurgia de domínio no frontend) ainda não começou — **as telas `Properties.vue`, `Condominiums.vue`, `Appointments.vue` e as rotas `/imoveis`, `/condominios`, `/agendamentos` ainda existem, são resquício da VisitaIA e serão removidas**. Não tratar como intencional.

## Stack Frontend (herdada, mantida)
- Vue 3 + `<script setup>` (Composition API)
- Pinia, Vue Router 4, Lucide Vue Next, SweetAlert2, Axios via `src/api/index.js`

## O que muda na Fase 3 (referência rápida — ver plano pra detalhe)
- `Contacts.vue`/`ContactDetails.vue` → evoluem pra telas de Revendedora (Carteira, Detalhe)
- Novas telas: Inativas, Tarefas/régua, Financeiro (spec funcional já prototipada em React em `C:\Users\inoov\clara-crm`, mas o código de lá não é reaproveitado — é framework diferente, só a spec)
- `Conversas.vue` + `store/conversations.js` + componentes de apoio: **mantidos quase sem alteração** — é chat/inbox genérico, maior peça reaproveitável do projeto
- Remove: `Properties.vue`, `Condominiums.vue`, `Appointments.vue` + stores + rotas + itens de nav em `DashboardLayout.vue`, `settings/Portals.vue`
- Tema: `src/config/brand.js` já tem os valores padrão da Clara Ferreira (rosa `#FF007F`), mas **ainda não está conectado às variáveis CSS em `style.scss`** — isso é bug herdado da VisitaIA, corrigir na Fase 3. Também existem ~115 hex hardcoded espalhados em componentes `<style scoped>` — só vale a pena limpar nas telas que sobrevivem (Conversas, DashboardLayout, telas novas), não nas que serão removidas.

## Autenticação
- JWT em `localStorage('auth_token')`, usuário em `localStorage('user')`. Sem store dedicado de auth — lido ad hoc onde precisa.
- Roles hoje ainda são as da VisitaIA (`atendente`/`empresa`/`admin`) — **vão virar 4 perfis** (consultor/gerente/diretoria/financeiro, seção 30 do briefing) na Fase 2/3.

## Backend
Repositório irmão em `C:\Users\inoov\clara_crm_backend` (também fork desconectado do `crm_backend_inoovaweb_oficial`). Comunicação via REST (Axios) + WebSocket ActionCable (`/cable`, implementado como WebSocket cru falando o protocolo de subscription do ActionCable — ver `setupWebSocket()` em `src/store/conversations.js`).
