<script setup>
</script>

<template>
  <header class="topbar">
    <div class="search-bar">
      <svg class="search-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
      </svg>
      <input type="text" placeholder="Buscar imóveis, clientes, negócios..." />
    </div>

    <div class="topbar-actions">
      <button class="icon-btn">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>
        <span class="badge">3</span>
      </button>

      <div class="user-profile">
        <img src="https://ui-avatars.com/api/?name=João+Silva&background=2563eb&color=fff" alt="User Avatar" class="avatar" />
        <div class="user-info">
          <span class="name">João Silva</span>
          <span class="role">Corretor</span>
        </div>
      </div>
    </div>
  </header>
</template>

<style lang="scss" scoped>
.topbar {
  height: 70px;
  background: var(--card-bg);
  border-bottom: 1px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 2rem;
}

.search-bar {
  display: flex;
  align-items: center;
  background: var(--bg-color);
  border-radius: 8px;
  padding: 0.5rem 1rem;
  width: 400px;
  border: 1px solid transparent;
  transition: all 0.2s;

  &:focus-within {
    border-color: var(--primary);
    background: white;
  }

  .search-icon {
    width: 18px;
    height: 18px;
    color: var(--text-muted);
    margin-right: 0.8rem;
  }

  input {
    border: none;
    background: transparent;
    width: 100%;
    outline: none;
    font-size: 0.95rem;
    color: var(--text-main);

    &::placeholder {
      color: var(--text-muted);
    }
  }
}

.topbar-actions {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.icon-btn {
  background: transparent;
  border: none;
  cursor: pointer;
  position: relative;
  color: var(--text-muted);
  transition: color 0.2s;

  &:hover {
    color: var(--primary);
  }

  svg {
    width: 24px;
    height: 24px;
  }

  .badge {
    position: absolute;
    top: -5px;
    right: -5px;
    background: #ef4444;
    color: white;
    font-size: 0.7rem;
    font-weight: 700;
    width: 18px;
    height: 18px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 2px solid var(--card-bg);
  }
}

.user-profile {
  display: flex;
  align-items: center;
  gap: 0.8rem;
  cursor: pointer;

  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    object-fit: cover;
  }

  .user-info {
    display: flex;
    flex-direction: column;

    .name {
      font-weight: 600;
      font-size: 0.95rem;
      color: var(--text-main);
    }

    .role {
      font-size: 0.8rem;
      color: var(--text-muted);
    }
  }
}
</style>
