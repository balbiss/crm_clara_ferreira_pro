import { createRouter, createWebHistory } from 'vue-router'

const OWNER_ROLES = ['empresa', 'admin']

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
          path: 'imoveis',
          name: 'imoveis',
          component: () => import('../views/Properties.vue')
        },
        {
          path: 'imoveis/novo',
          name: 'imoveis_novo',
          component: () => import('../views/PropertyForm.vue')
        },
        {
          path: 'imoveis/:id/editar',
          name: 'imoveis_editar',
          component: () => import('../views/PropertyForm.vue')
        },
        {
          path: 'condominios',
          name: 'condominios',
          component: () => import('../views/Condominiums.vue')
        },
        {
          path: 'condominios/novo',
          name: 'condominios_novo',
          component: () => import('../views/CondominiumForm.vue')
        },
        {
          path: 'condominios/:id/editar',
          name: 'condominios_editar',
          component: () => import('../views/CondominiumForm.vue')
        },
        {
          path: 'agendamentos',
          name: 'agendamentos',
          component: () => import('../views/Appointments.vue')
        },
        {
          path: 'agendamentos/novo',
          name: 'agendamentos_novo',
          component: () => import('../views/AppointmentForm.vue')
        },
        {
          path: 'agendamentos/:id/editar',
          name: 'agendamentos_editar',
          component: () => import('../views/AppointmentForm.vue')
        },
        // Rotas exclusivas do dono (empresa/admin)
        {
          path: 'agentes',
          name: 'agentes',
          component: () => import('../views/Agents.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'agentes/novo',
          name: 'agentes_novo',
          component: () => import('../views/AgentForm.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'agentes/:id/editar',
          name: 'agentes_editar',
          component: () => import('../views/AgentForm.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'settings/inboxes',
          name: 'SettingsInboxes',
          component: () => import('../views/SettingsInboxes.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'settings/inboxes/new',
          name: 'settings_inboxes_new',
          component: () => import('../views/NewInbox.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'settings/inboxes/:id',
          name: 'settings_inbox_detail',
          component: () => import('../views/SettingsInboxDetail.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'settings/account',
          name: 'SettingsAccount',
          component: () => import('../views/settings/Account.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'settings/tags',
          name: 'SettingsTags',
          component: () => import('../views/settings/Tags.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'settings/portals',
          name: 'SettingsPortals',
          component: () => import('../views/settings/Portals.vue'),
          meta: { requiresOwner: true }
        },
        {
          path: 'settings/asaas',
          name: 'SettingsAsaas',
          component: () => import('../views/settings/Asaas.vue'),
          meta: { requiresOwner: true }
        },
        // Rotas abertas a todos
        {
          path: 'funil',
          name: 'funil',
          component: () => import('../views/Kanban.vue')
        },
        {
          path: 'suporte',
          name: 'suporte',
          component: () => import('../views/Support.vue')
        },
        {
          path: 'relatorios',
          name: 'relatorios',
          component: () => import('../views/Reports.vue')
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

  // Rotas com requiresOwner: empresa, admin, ou agente com permissao administrativa total
  if (to.meta?.requiresOwner && user && !OWNER_ROLES.includes(user.role) && !user.permissions?.admin) {
    return next({ name: 'dashboard' })
  }

  next()
})

export default router
