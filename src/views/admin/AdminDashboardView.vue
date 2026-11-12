
<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { RouterLink } from 'vue-router'

const auth = useAuthStore()
const router = useRouter()

const signingOut = ref(false)
const errorMessage = ref('')

async function handleSignOut() {
  if (signingOut.value) return

  signingOut.value = true
  errorMessage.value = ''

  try {
    await auth.signOut()
    await router.replace('/')
  } catch (error) {
    errorMessage.value =
      error instanceof Error
        ? error.message
        : 'An unexpected error occurred while signing out.'
  } finally {
    signingOut.value = false
  }
}

const sections = [
  {
    title: 'Courses & Disciplines',
    description: 'Manage academic courses, disciplines and their organisation.',
    icon: '01',
    status: 'Next to implement',
  },
  {
    title: 'Calendar & Events',
    description: 'Schedule lectures, tutorials, practicals and other events.',
    icon: '02',
    status: 'Planned',
  },
  {
    title: 'Assignments',
    description: 'Create assignments and manage submission deadlines.',
    icon: '03',
    status: 'Planned',
  },
  {
    title: 'Academic Materials',
    description: 'Upload resources, manage versions and link materials to lectures.',
    icon: '04',
    status: 'Planned',
  },
]
</script>

<template>
  <div class="admin-layout">
    <aside class="admin-sidebar">
      <div class="sidebar-heading">
        <span class="sidebar-eyebrow">MED HUB</span>
        <h2>Administration</h2>
      </div>

      <nav class="admin-nav" aria-label="Administration navigation">
        <RouterLink to="/admin" class="admin-nav-link" exact-active-class="active">
          <span class="nav-indicator"></span>
          Overview
        </RouterLink>
      
        <RouterLink to="/admin/courses" class="admin-nav-link">
          <span class="nav-indicator"></span>
          Courses & Disciplines
        </RouterLink>

        <RouterLink to="/admin/events" class="admin-nav-link">
          <span class="nav-indicator"></span>
          Events
        </RouterLink>

        <RouterLink to="/admin/materials" class="admin-nav-link">
            <span class="nav-indicator"></span>
          Manage materials
        </RouterLink>
      </nav>

      <div class="sidebar-account">
        <span class="account-label">SIGNED IN AS</span>
        <span class="account-email">{{ auth.user?.email }}</span>
        <button
          class="sign-out-button"
          type="button"
          :disabled="signingOut"
          @click="handleSignOut"
        >
          {{ signingOut ? 'Signing out...' : 'Sign out' }}
        </button>
      </div>
    </aside>

    <main class="admin-main">
      <header class="admin-page-header">
        <div>
          <p class="page-eyebrow">WORKSPACE</p>
          <h1>Administration Overview</h1>
          <p class="page-description">
            Manage the academic information shared with your class.
          </p>
        </div>
      </header>

      <p v-if="errorMessage" class="admin-error" role="alert">
        {{ errorMessage }}
      </p>

      <section class="admin-welcome">
        <div>
          <span class="welcome-label">ADMINISTRATOR WORKSPACE</span>
          <h2>Academic Hub Management</h2>
          <p>
            Manage your class schedule, assignments, courses and shared
            academic resources from one place.
          </p>
        </div>
      </section>

      <section class="management-section">
        <div class="section-heading">
          <div>
            <h2>Management sections</h2>
            <p>Choose an area to manage.</p>
          </div>
        </div>

        <div class="management-grid">
          <article
            v-for="section in sections"
            :key="section.title"
            class="management-card"
          >
            <span class="card-number">{{ section.icon }}</span>
            <div class="card-content">
              <h3>{{ section.title }}</h3>
              <p>{{ section.description }}</p>
            </div>
            <span class="card-status">{{ section.status }}</span>
          </article>
        </div>
      </section>
    </main>
  </div>
</template>

<style scoped>
.admin-layout {
  display: grid;
  grid-template-columns: 250px minmax(0, 1fr);
  min-height: 680px;
}

.admin-sidebar {
  display: flex;
  flex-direction: column;
  padding: 2rem 1.25rem;
  border-right: 1px solid var(--border);
  background: var(--surface);
}

.sidebar-heading {
  padding: 0 0.75rem 2rem;
}

.sidebar-eyebrow,
.account-label,
.page-eyebrow,
.welcome-label {
  color: var(--text-muted);
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.12em;
}

.sidebar-heading h2 {
  margin: 0.5rem 0 0;
  font-size: 1.15rem;
}

.admin-nav {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.admin-nav-link {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem;
  border-radius: 7px;
  color: var(--text-muted);
  font-size: 0.9rem;
}

.admin-nav-link.active,
.admin-nav-link:hover {
  background: var(--surface-raised);
  color: var(--text);
}

.nav-indicator {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--accent);
}

.sidebar-account {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-top: auto;
  padding: 1.25rem 0.75rem 0;
  border-top: 1px solid var(--border);
}

.account-email {
  overflow-wrap: anywhere;
  font-size: 0.85rem;
}

.sign-out-button {
  padding: 0.65rem;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: transparent;
  color: var(--text);
  text-align: left;
  cursor: pointer;
}

.sign-out-button:hover {
  background: var(--surface-raised);
}

.sign-out-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.admin-main {
  min-width: 0;
  padding: 2.5rem;
}

.admin-page-header {
  margin-bottom: 2rem;
}

.page-eyebrow {
  margin: 0 0 0.5rem;
}

.admin-page-header h1 {
  margin: 0;
  font-size: 1.8rem;
}

.page-description {
  margin: 0.65rem 0 0;
  color: var(--text-muted);
}

.admin-welcome {
  padding: 2rem;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface);
}

.welcome-label {
  color: var(--accent);
}

.admin-welcome h2 {
  margin: 0.75rem 0 0.5rem;
  font-size: 1.35rem;
}

.admin-welcome p {
  max-width: 650px;
  margin: 0;
  color: var(--text-muted);
  line-height: 1.6;
}

.management-section {
  margin-top: 2.5rem;
}

.section-heading {
  margin-bottom: 1.25rem;
}

.section-heading h2 {
  margin: 0;
  font-size: 1.2rem;
}

.section-heading p {
  margin: 0.4rem 0 0;
  color: var(--text-muted);
  font-size: 0.9rem;
}

.management-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

.management-card {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  min-height: 190px;
  padding: 1.25rem;
  border: 1px solid var(--border);
  border-radius: 9px;
  background: var(--surface);
}

.card-number {
  color: var(--accent);
  font-size: 0.8rem;
  font-weight: 700;
}

.card-content {
  margin-top: 1rem;
}

.card-content h3 {
  margin: 0;
  font-size: 1rem;
}

.card-content p {
  margin: 0.5rem 0 1rem;
  color: var(--text-muted);
  font-size: 0.85rem;
  line-height: 1.5;
}

.card-status {
  margin-top: auto;
  color: var(--text-muted);
  font-size: 0.75rem;
}

.admin-error {
  padding: 0.75rem;
  border-radius: 6px;
  background: rgb(180 50 50 / 15%);
  color: #ff8585;
}

@media (max-width: 900px) {
  .admin-layout {
    grid-template-columns: 200px minmax(0, 1fr);
  }

  .admin-main {
    padding: 1.5rem;
  }

  .management-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 600px) {
  .admin-layout {
    grid-template-columns: 1fr;
  }

  .admin-sidebar {
    border-right: none;
    border-bottom: 1px solid var(--border);
  }

  .sidebar-heading {
    padding-bottom: 1rem;
  }

  .sidebar-account {
    margin-top: 1.25rem;
  }
}
</style>
