
<script setup lang="ts">
import { RouterLink, RouterView } from 'vue-router'
import { useAuthStore } from './stores/auth'

const auth = useAuthStore()
</script>

<template>
  <div class="app-shell">
    <header class="app-header">
      <RouterLink to="/" class="brand">
        <span class="brand-mark">M</span>
        <span>Med Hub</span>
      </RouterLink>

      <nav class="main-nav">
        <RouterLink to="/">Dashboard</RouterLink>
        <RouterLink to="/calendar">Calendar</RouterLink>
        <RouterLink to="/assignments">Assignments</RouterLink>
        <RouterLink to="/materials">Materials</RouterLink>
        <RouterLink to="/courses">Courses</RouterLink>
      </nav>

      <RouterLink
        :to="auth.isAdmin ? '/admin' : '/admin/login'"
        class="admin-link"
      >
        {{ auth.isAdmin ? 'Administration' : 'Admin Login' }}
      </RouterLink>
    </header>

    <main class="main-content">
      <RouterView />
    </main>

    <footer class="app-footer">
      <span>Medical School Academic Hub</span>
    </footer>
  </div>
</template>
