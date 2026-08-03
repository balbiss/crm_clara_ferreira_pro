import { createRouter, createWebHistory } from 'vue-router'

// Três níveis de acesso (briefing seção 30) — espelham os do backend
// (ApplicationController#owner?/full_portfolio?/finance?):
// - FULL_PORTFOLIO_ROLES: enxerga a carteira inteira (Painel Gerencial).
// - CRITICAL_CONFIG_ROLES: configurações críticas do sistema. Gerente NÃO
//   entra aqui — ele opera a carteira, não mexe em config.
// - FINANCE_BLOCKED_ROUTES: telas operacionais (Carteira/Tarefas) que o
//   Financeiro não deve ver — ele vê Inativas/Conversas/Cobrança.
const FULL_PORTFOLIO_ROLES = ['empresa', 'admin', 'gerente', 'diretoria']
const CRITICAL_CONFIG_ROLES = ['empresa', 'admin', 'diretoria']
const FINANCE_BLOCKED_ROUTES = ['revendedoras_ativas', 'tarefas']

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/dashboard'
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/Login.vue')
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('../views/Register.vue')
    },
    {
      path: '/forgot-password',
      name: 'forgot-password',
      component: () => import('../views/ForgotPassword.vue')
    },
    {
      path: '/users/password/edit',
      name: 'reset-password',
      component: () => import('../views/ResetPassword.vue')
    },
    {
      path: '/',
      component: () => import('../views/DashboardLayout.vue'),
      children: [
        {
          path: 'dashboard',
          name: 'dashboard',
          component: () => import('../views/Dashboard.vue')
        },
        {
          path: 'carteira',
          name: 'revendedoras_ativas',
          component: () => import('../views/RevendedorasAtivas.vue')
        },
        {
          path: 'inativas',
          name: 'revendedoras_inativas',
          component: () => import('../views/RevendedorasInativas.vue')
        },
        {
          path: 'tarefas',
          name: 'tarefas',
          component: () => import('../views/TarefasView.vue')
        },
        {
          path: 'gerencial',
          name: 'gerencial',
          component: () => import('../views/GerencialView.vue'),
          meta: { requiresFullPortfolio: true }
        },
        {
          path: 'conversas',
          name: 'conversas',
          component: () => import('../views/Conversas.vue')
        },
        {
          path: 'conversas/inbox/:inboxId',
          name: 'conversas_inbox',
          component: () => import('../views/Conversas.vue')
        },
        {
          path: 'conversas/:filter',
          name: 'conversas_filter',
          component: () => import('../views/Conversas.vue')
        },
        {
          path: 'contatos',
          name: 'contatos',
          component: () => import('../views/Contacts.vue')
        },
        {
          path: 'contatos/:id',
          name: 'contact_details',
          component: () => import('../views/ContactDetails.vue')
        },
        {
          path: 'email',
          name: 'inbox_email',
          component: () => import('../views/ComingSoon.vue'),
          meta: { title: 'Inbox de e-mail', description: 'Atendimento por e-mail integrado ao CRM — ainda não disponível.' }
        },
        {
          path: 'pipelines/todos-leads',
          name: 'pipeline_todos_leads',
          component: () => import('../views/TodosLeadsView.vue')
        },
        {
          path: 'pipelines/:slug',
          name: 'pipeline_board',
          component: () => import('../views/PipelineBoard.vue')
        },
        {
          path: 'pipelines/:slug/automatize',
          name: 'pipeline_automation',
          component: () => import('../views/PipelineAutomation.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'calendario',
          name: 'calendario',
          component: () => import('../views/ComingSoon.vue'),
          meta: { title: 'Calendário', description: 'Agenda consolidada de agendamentos — ainda não disponível.' }
        },
        {
          path: 'segmentos',
          name: 'segmentos',
          component: () => import('../views/ComingSoon.vue'),
          meta: { title: 'Segmentos', description: 'Segmentação de carteira — ainda não disponível.' }
        },
        {
          path: 'listas',
          name: 'listas',
          component: () => import('../views/ComingSoon.vue'),
          meta: { title: 'Listas', description: 'Listas salvas e filtros personalizados — ainda não disponível.' }
        },
        {
          path: 'agente-ia',
          name: 'agente_ia',
          component: () => import('../views/ComingSoon.vue'),
          meta: { title: 'Agente de IA', description: 'Configuração do assistente de IA — ainda não disponível.' }
        },
        {
          path: 'automacoes',
          name: 'automacoes',
          component: () => import('../views/ComingSoon.vue'),
          meta: { title: 'Automações', description: 'Regras automáticas de tarefas e mensagens — ainda não disponível.' }
        },
        // Rotas exclusivas do dono (empresa/admin)
        {
          path: 'agentes',
          name: 'agentes',
          component: () => import('../views/Agents.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'agentes/novo',
          name: 'agentes_novo',
          component: () => import('../views/AgentForm.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'agentes/:id/editar',
          name: 'agentes_editar',
          component: () => import('../views/AgentForm.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'settings/inboxes',
          name: 'SettingsInboxes',
          component: () => import('../views/SettingsInboxes.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'settings/inboxes/new',
          name: 'settings_inboxes_new',
          component: () => import('../views/NewInbox.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'settings/inboxes/:id',
          name: 'settings_inbox_detail',
          component: () => import('../views/SettingsInboxDetail.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'settings/account',
          name: 'SettingsAccount',
          component: () => import('../views/settings/Account.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'settings/tags',
          name: 'SettingsTags',
          component: () => import('../views/settings/Tags.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'settings/asaas',
          name: 'SettingsAsaas',
          component: () => import('../views/settings/Asaas.vue'),
          meta: { requiresCriticalConfig: true }
        },
        // Rotas abertas a todos
        {
          path: 'funil',
          name: 'funil',
          component: () => import('../views/Kanban.vue')
        },
        {
          path: 'funil/automatize',
          name: 'regua_automation',
          component: () => import('../views/ReguaAutomation.vue'),
          meta: { requiresCriticalConfig: true }
        },
        {
          path: 'suporte',
          name: 'suporte',
          component: () => import('../views/Support.vue')
        },
        {
          path: 'relatorios',
          name: 'relatorios',
          component: () => import('../views/Reports.vue'),
          meta: { requiresFullPortfolio: true }
        },
        {
          path: 'manual',
          name: 'manual',
          component: () => import('../views/Manual.vue')
        }
      ]
    },
    {
      path: '/admin',
      component: () => import('../views/admin/AdminLayout.vue'),
      children: [
        {
          path: '',
          redirect: '/admin/dashboard'
        },
        {
          path: 'dashboard',
          name: 'admin_dashboard',
          component: () => import('../views/admin/AdminDashboard.vue')
        },
        {
          path: 'empresas',
          name: 'admin_empresas',
          component: () => import('../views/admin/AdminCompanies.vue')
        },
        {
          path: 'integracoes',
          name: 'admin_integracoes',
          component: () => import('../views/admin/AdminIntegrations.vue')
        },
        {
          path: 'suporte',
          name: 'admin_suporte',
          component: () => import('../views/admin/AdminSupport.vue')
        }
      ]
    }
  ]
})

router.beforeEach((to, _from, next) => {
  const isAuthenticated = !!localStorage.getItem('auth_token')
  let user = null
  try {
    user = JSON.parse(localStorage.getItem('user'))
  } catch (e) {}

  // Rota pública: não precisa de autenticação
  const publicRoutes = ['login', 'register', 'forgot-password', 'reset-password']
  if (publicRoutes.includes(to.name)) {
    return next()
  }

  // Não autenticado → login
  if (!isAuthenticated) {
    return next({ name: 'login' })
  }

  // Área /admin: apenas usuários com role 'admin'
  if (to.path.startsWith('/admin') && (!user || user.role !== 'admin')) {
    return next({ name: 'dashboard' })
  }

  // Painel Gerencial: gerente/diretoria/empresa/admin (carteira inteira)
  if (to.meta?.requiresFullPortfolio && user && !FULL_PORTFOLIO_ROLES.includes(user.role) && !user.permissions?.admin) {
    return next({ name: 'dashboard' })
  }

  // Configurações críticas do sistema: só diretoria/empresa/admin — gerente
  // acompanha a operação, mas não mexe em config (briefing seção 30).
  if (to.meta?.requiresCriticalConfig && user && !CRITICAL_CONFIG_ROLES.includes(user.role) && !user.permissions?.admin) {
    return next({ name: 'dashboard' })
  }

  // Financeiro não opera Carteira/Tarefas (telas operacionais do consultor) —
  // ele trabalha em Inativas/Conversas/Cobrança (briefing seção 30).
  if (user?.role === 'financeiro' && FINANCE_BLOCKED_ROUTES.includes(to.name)) {
    return next({ name: 'revendedoras_inativas' })
  }

  // Rotas com requiresOwner: empresa, admin, ou agente com permissao administrativa total
  if (to.meta?.requiresOwner && user && !OWNER_ROLES.includes(user.role) && !user.permissions?.admin) {
    return next({ name: 'dashboard' })
  }

  next()
})

export default router
