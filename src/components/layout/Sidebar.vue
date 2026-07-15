<script setup>
import { ref } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const menuItems = ref([
  { name: 'Dashboard', path: '/dashboard', icon: 'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6' },
  { name: 'Funil de Vendas', path: '/funil', icon: 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z' },
  { name: 'Imóveis', path: '/imoveis', icon: 'M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4' },
  { name: 'Clientes', path: '/clientes', icon: 'M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z' },
  { name: 'Agenda', path: '/agenda', icon: 'M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z' }
])
</script>

<template>
  <aside class="sidebar">
    <div class="sidebar-header">
      <h1 class="logo">Innova<span>web</span></h1>
    </div>

    <nav class="sidebar-nav">
      <ul>
        <li v-for="item in menuItems" :key="item.name">
          <router-link :to="item.path" class="nav-item" :class="{ active: route.path.includes(item.path) }">
            <svg class="icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" :d="item.icon" />
            </svg>
            {{ item.name }}
          </router-link>
        </li>
      </ul>
    </nav>
    
    <div class="sidebar-footer">
      <router-link to="/login" class="nav-item logout">
        <svg class="icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
        </svg>
        Sair
      </router-link>
    </div>
  </aside>
</template>

<style lang="scss" scoped>
.sidebar {
  width: 260px;
  background: var(--card-bg);
  border-right: 1px solid var(--border-color);
  display: flex;
  flex-direction: column;
}

.sidebar-header {
  padding: 1.5rem;
  border-bottom: 1px solid var(--border-color);
  
  .logo {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--text-main);
    
    span {
      color: var(--primary);
    }
  }
}

.sidebar-nav {
  flex: 1;
  padding: 1.5rem 1rem;
  overflow-y: auto;

  ul {
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  padding: 0.8rem 1rem;
  border-radius: 8px;
  color: var(--text-muted);
  font-weight: 500;
  transition: all 0.2s;

  .icon {
    width: 20px;
    height: 20px;
  }

  &:hover {
    background: var(--bg-color);
    color: var(--primary);
  }

  &.active {
    background: var(--primary);
    color: white;
    
    .icon {
      stroke: white;
    }
  }
}

.sidebar-footer {
  padding: 1rem;
  border-top: 1px solid var(--border-color);

  .logout {
    color: #ef4444; /* Red color for logout */
    
    &:hover {
      background: #fef2f2;
      color: #dc2626;
    }
  }
}
</style>
