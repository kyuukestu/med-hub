<template>
  <section class="dashboard">
    <header class="welcome">
      <p class="eyebrow">MEDICAL SCHOOL · ACADEMIC HUB</p>
      <h1>Academic Dashboard</h1>
      <p>
        Your central place for academic schedules, assignments and
        learning materials.
      </p>
    </header>

    <section class="dashboard-grid">
      <article class="dashboard-card">
        <h2>Upcoming Classes</h2>
        <p>See your upcoming lectures, tutorials and practicals.</p>
      </article>

      <article class="dashboard-card">
        <h2>Assignments</h2>
        <p>Keep track of shared assignments and submission deadlines.</p>
      </article>

      <article class="dashboard-card">
        <h2>Recent Materials</h2>
        <p>Find recently uploaded lecture slides and other resources.</p>
      </article>
    </section>
  </section>
</template>

<style scoped>
.dashboard {
  padding: 2rem;
}

.welcome {
  margin-bottom: 2rem;
}

.eyebrow {
  color: var(--accent);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.12em;
}

.welcome h1 {
  margin: 0.5rem 0;
}

.welcome > p:last-child {
  color: var(--text-muted);
}

.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 1rem;
}

.dashboard-card {
  padding: 1.5rem;
  border: 1px solid var(--border);
  border-radius: 0.75rem;
  background: var(--surface);
}

.dashboard-card p {
  color: var(--text-muted);
}
</style>
