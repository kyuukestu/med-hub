
<script setup lang="ts">
defineProps<{
  title: string
  description: string
}>()
</script>

<template>
  <section class="page-placeholder">
    <h1>{{ title }}</h1>
    <p>{{ description }}</p>
  </section>
</template>

<style scoped>
.page-placeholder {
  padding: 2rem;
}

h1 {
  margin-bottom: 0.5rem;
}

p {
  color: var(--text-muted);
}
</style>
