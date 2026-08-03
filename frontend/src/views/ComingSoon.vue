<script setup>
import { useRoute } from 'vue-router'
import { Construction } from 'lucide-vue-next'

const route = useRoute()
const title = route.meta?.title || 'Em construção'
const description = route.meta?.description || 'Essa área ainda está sendo construída.'
</script>

<template>
  <div class="coming-soon">
    <div class="cs-icon"><Construction :size="28" /></div>
    <h2>{{ title }}</h2>
    <p>{{ description }}</p>
  </div>
</template>

<style lang="scss" scoped>
.coming-soon {
  height: 100%;
  min-height: 60vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 2rem;
  color: var(--text-muted);

  .cs-icon {
    width: 56px;
    height: 56px;
    border-radius: 16px;
    background: var(--bg-tertiary, #f1e9ed);
    color: var(--primary);
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 1rem;
  }

  h2 {
    font-size: 1.2rem;
    font-weight: 700;
    color: var(--text-main);
    margin-bottom: 0.4rem;
  }

  p {
    max-width: 360px;
    font-size: 0.9rem;
    line-height: 1.5;
  }
}
</style>
