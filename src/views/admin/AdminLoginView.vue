
<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const errorMessage = ref('')
const submitting = ref(false)

async function handleSubmit() {
  if (submitting.value) return

  errorMessage.value = ''
  submitting.value = true

  try {
    await auth.signIn(email.value.trim(), password.value)

    if (!auth.isAdmin) {
      await auth.signOut()
      throw new Error('This account does not have administrator access.')
    }

    const redirect = route.query.redirect

    // Only accept internal application paths.
    const destination =
      typeof redirect === 'string' &&
      redirect.startsWith('/') &&
      !redirect.startsWith('//')
        ? redirect
        : '/admin'

    await router.replace(destination)
  } catch (error) {
    errorMessage.value =
      error instanceof Error
        ? error.message
        : 'An unexpected error occurred while signing in.'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="login-page">
    <form class="login-card" @submit.prevent="handleSubmit">
      <div class="login-heading">
        <h1>Administrator Login</h1>
        <p>Sign in to manage academic information.</p>
      </div>

      <div class="form-field">
        <label for="email">Email address</label>
        <input
          id="email"
          v-model="email"
          type="email"
          autocomplete="username"
          placeholder="admin@example.com"
          required
          :disabled="submitting"
        />
      </div>

      <div class="form-field">
        <label for="password">Password</label>
        <input
          id="password"
          v-model="password"
          type="password"
          autocomplete="current-password"
          placeholder="Enter your password"
          required
          :disabled="submitting"
        />
      </div>

      <p v-if="errorMessage" class="login-error" role="alert">
        {{ errorMessage }}
      </p>

      <button type="submit" :disabled="submitting">
        {{ submitting ? 'Signing in...' : 'Sign in' }}
      </button>
    </form>
  </main>
</template>

<style scoped>
.login-page {
  min-height: 65vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem 1rem;
}

.login-card {
  width: 100%;
  max-width: 420px;
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  padding: 2rem;
  border: 1px solid var(--border-color, #333);
  border-radius: 12px;
  background: var(--surface-color, #1c1c1c);
}

.login-heading h1 {
  margin: 0 0 0.5rem;
  font-size: 1.5rem;
}

.login-heading p {
  margin: 0;
  color: var(--text-muted, #aaa);
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-field label {
  font-size: 0.9rem;
  font-weight: 600;
}

.form-field input {
  width: 100%;
  box-sizing: border-box;
  padding: 0.75rem;
  border: 1px solid var(--border-color, #444);
  border-radius: 6px;
  background: var(--background-color, #121212);
  color: inherit;
  font: inherit;
}

.login-card button {
  padding: 0.8rem;
  border: none;
  border-radius: 6px;
  background: var(--accent-color, #6478db);
  color: white;
  font: inherit;
  font-weight: 600;
  cursor: pointer;
}

.login-card button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.login-error {
  margin: 0;
  padding: 0.75rem;
  border-radius: 6px;
  background: rgb(180 50 50 / 15%);
  color: #ff8585;
  font-size: 0.9rem;
}
</style>
