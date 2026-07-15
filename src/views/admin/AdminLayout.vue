<script setup>
import { ref, onMounted } from 'vue'

const isSidebarOpen = ref(true)

const logout = () => {
  localStorage.removeItem('auth_token')
  localStorage.removeItem('user')
  window.location.href = '/login'
}
</script>

<template>
  <div class="admin-layout">
    <!-- Sidebar escura para diferenciar -->
    <aside class="admin-sidebar" :class="{ 'closed': !isSidebarOpen }">
      <div class="sidebar-header">
        <h1 class="logo">SaaS <span>Master</span></h1>
      </div>
      
      <nav class="sidebar-nav">
        <router-link to="/admin/dashboard" class="nav-item">
          Dashboard Global
        </router-link>
        <router-link to="/admin/empresas" class="nav-item">Empresas e Clientes</router-link>
        <router-link to="/admin/integracoes" class="nav-item">Integrações Globais</router-link>
        <router-link to="/admin/suporte" class="nav-item support-item">Suporte (Tickets)</router-link>
      </nav>

      <div class="sidebar-footer">
        <button class="nav-item logout-btn" @click="logout">
          Sair do Painel
        </button>
      </div>
    </aside>

    <main class="admin-main">
      <div class="top-nav">
        <button class="toggle-btn" @click="isSidebarOpen = !isSidebarOpen">☰</button>
        <div class="top-nav-title">Painel de Administração do SaaS</div>
      </div>
      
      <div class="content-area">
        <router-view></router-view>
      </div>
    </main>
  </div>
</template>

<style scoped lang="scss">
.admin-layout {
  display: flex;
  height: 100vh;
  background-color: #f1f5f9;
  font-family: 'Inter', sans-serif;
}

.admin-sidebar {
  width: 260px;
  background-color: #0f172a;
  color: #f8fafc;
  display: flex;
  flex-direction: column;
  transition: width 0.3s;
  
  &.closed {
    width: 0;
    overflow: hidden;
  }

  .sidebar-header {
    padding: 1.5rem;
    border-bottom: 1px solid #1e293b;
    
    .logo {
      font-size: 1.2rem;
      font-weight: 700;
      color: white;
      margin: 0;
      
      span {
        color: #38bdf8;
      }
    }
  }

  .sidebar-nav {
    flex: 1;
    padding: 1rem 0;
    display: flex;
    flex-direction: column;
    
    .nav-item {
      padding: 0.6rem 1.2rem;
      color: #cbd5e1;
      text-decoration: none;
      font-size: 0.85rem;
      font-weight: 500;
      transition: all 0.2s;
      
      &:hover, &.router-link-active {
        background-color: #1e293b;
        color: #38bdf8;
        border-left: 3px solid #38bdf8;
      }
    }
  }

  .sidebar-footer {
    padding: 1rem;
    border-top: 1px solid #1e293b;
    
    .logout-btn {
      width: 100%;
      background: none;
      border: none;
      color: #ef4444;
      text-align: left;
      cursor: pointer;
      font-size: 0.85rem;
      
      &:hover {
        color: #f87171;
      }
    }
  }
}

.admin-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;

  .top-nav {
    background: white;
    height: 50px;
    display: flex;
    align-items: center;
    padding: 0 1.5rem;
    border-bottom: 1px solid #e2e8f0;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05);
    
    .toggle-btn {
      background: none;
      border: none;
      font-size: 1.25rem;
      cursor: pointer;
      color: #64748b;
      margin-right: 1rem;
    }

    .top-nav-title {
      font-size: 0.9rem;
      font-weight: 600;
      color: #334155;
    }
  }

  .content-area {
    flex: 1;
    padding: 2rem;
    overflow-y: auto;
  }
}
</style>
