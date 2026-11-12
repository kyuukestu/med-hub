
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { supabase } from '../lib/supabase'
import type { Database } from '../types/database'

type Course = Database['public']['Tables']['courses']['Row']
type Discipline = Database['public']['Tables']['disciplines']['Row']

const courses = ref<Course[]>([])
const disciplines = ref<Discipline[]>([])

const loading = ref(true)
const errorMessage = ref('')
const searchQuery = ref('')

const normalizedQuery = computed(() => searchQuery.value.trim().toLowerCase())

function matchesCourse(course: Course) {
  const query = normalizedQuery.value

  if (!query) return true

  return (
    course.code.toLowerCase().includes(query) ||
    course.name.toLowerCase().includes(query) ||
    (course.description ?? '').toLowerCase().includes(query)
  )
}

function matchesDiscipline(discipline: Discipline) {
  const query = normalizedQuery.value

  if (!query) return true

  return (
    discipline.code.toLowerCase().includes(query) ||
    discipline.name.toLowerCase().includes(query) ||
    (discipline.description ?? '').toLowerCase().includes(query)
  )
}

const visibleCourses = computed(() =>
  courses.value.filter((course) => {
    return (
      matchesCourse(course) ||
      disciplines.value.some(
        (discipline) =>
          discipline.course_id === course.id &&
          matchesDiscipline(discipline),
      )
    )
  }),
)

function disciplinesFor(course: Course) {
  const courseDisciplines = disciplines.value
    .filter((discipline) => discipline.course_id === course.id)
    .sort((a, b) => a.sort_order - b.sort_order)

  // If the course itself matches, show all its disciplines.
  // Otherwise, show only disciplines matching the search.
  if (!normalizedQuery.value || matchesCourse(course)) {
    return courseDisciplines
  }

  return courseDisciplines.filter(matchesDiscipline)
}

async function loadCatalogue() {
  loading.value = true
  errorMessage.value = ''

  try {
    const [courseResult, disciplineResult] = await Promise.all([
      supabase
        .from('courses')
        .select('*')
        .eq('is_active', true)
        .order('sort_order')
        .order('code'),

      supabase
        .from('disciplines')
        .select('*')
        .eq('is_active', true)
        .order('sort_order')
        .order('name'),
    ])

    if (courseResult.error) throw courseResult.error
    if (disciplineResult.error) throw disciplineResult.error

    courses.value = courseResult.data
    disciplines.value = disciplineResult.data
  } catch (error) {
    errorMessage.value =
      error instanceof Error
        ? error.message
        : 'Unable to load the course catalogue.'
  } finally {
    loading.value = false
  }
}

onMounted(loadCatalogue)
</script>

<template>
  <main class="courses-page">
    <header class="page-header">
      <div>
        <p class="eyebrow">ACADEMIC DIRECTORY</p>
        <h1>Courses</h1>
        <p class="page-description">
          Browse the courses and academic disciplines in your programme.
        </p>
      </div>

      <div v-if="!loading && !errorMessage" class="course-count">
        <strong>{{ visibleCourses.length }}</strong>
        <span>
          {{ visibleCourses.length === 1 ? 'course' : 'courses' }}
        </span>
      </div>
    </header>

    <section class="catalogue">
      <div class="catalogue-toolbar">
        <input
          v-model="searchQuery"
          type="search"
          placeholder="Search courses or disciplines..."
          aria-label="Search courses and disciplines"
        />
      </div>

      <div v-if="loading" class="state-message">
        Loading course catalogue...
      </div>

      <div v-else-if="errorMessage" class="state-message error-state">
        <p>{{ errorMessage }}</p>
        <button
          class="secondary-button"
          type="button"
          @click="loadCatalogue"
        >
          Try again
        </button>
      </div>

      <div v-else-if="courses.length === 0" class="state-message">
        No courses are currently available.
      </div>

      <div v-else-if="visibleCourses.length === 0" class="state-message">
        No courses or disciplines match your search.
      </div>

      <div v-else class="course-grid">
        <article
          v-for="course in visibleCourses"
          :key="course.id"
          class="course-card"
        >
          <header class="course-header">
            <span class="course-code">{{ course.code }}</span>
            <h2>{{ course.name }}</h2>
            <p v-if="course.description" class="course-description">
              {{ course.description }}
            </p>
          </header>

          <div class="discipline-section">
            <h3>Disciplines</h3>

            <div
              v-if="disciplinesFor(course).length"
              class="discipline-list"
            >
              <div
                v-for="discipline in disciplinesFor(course)"
                :key="discipline.id"
                class="discipline-item"
              >
                <div class="discipline-heading">
                  <strong>{{ discipline.name }}</strong>
                  <span class="discipline-code">
                    {{ discipline.code }}
                  </span>
                </div>

                <p v-if="discipline.description">
                  {{ discipline.description }}
                </p>
              </div>
            </div>

            <p v-else class="empty-disciplines">
              No disciplines have been listed for this course yet.
            </p>
          </div>
        </article>
      </div>
    </section>
  </main>
</template>

<style scoped>
.courses-page {
  padding: 2.5rem;
}

.page-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.eyebrow {
  margin: 0 0 0.5rem;
  color: var(--text-muted);
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.12em;
}

.page-header h1 {
  margin: 0;
  font-size: 2rem;
}

.page-description {
  margin: 0.6rem 0 0;
  color: var(--text-muted);
  font-size: 0.95rem;
  line-height: 1.5;
}

.course-count {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
  color: var(--text-muted);
  font-size: 0.85rem;
}

.course-count strong {
  color: var(--text);
  font-size: 1.5rem;
}

.catalogue-toolbar {
  margin-bottom: 1.5rem;
}

.catalogue-toolbar input {
  width: 100%;
  max-width: 460px;
  padding: 0.8rem 1rem;
  border: 1px solid var(--border);
  border-radius: 7px;
  background: var(--surface);
  color: var(--text);
  font: inherit;
  font-size: 0.9rem;
}

.catalogue-toolbar input:focus {
  border-color: var(--accent);
  outline: none;
}

.course-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
  align-items: start;
}

.course-card {
  overflow: hidden;
  border: 1px solid var(--border);
  border-radius: 9px;
  background: var(--surface);
}

.course-header {
  padding: 1.4rem;
  border-bottom: 1px solid var(--border);
}

.course-code {
  display: inline-block;
  margin-bottom: 0.6rem;
  color: var(--accent);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.04em;
}

.course-header h2 {
  margin: 0;
  font-size: 1.2rem;
  line-height: 1.4;
}

.course-description {
  margin: 0.7rem 0 0;
  color: var(--text-muted);
  font-size: 0.85rem;
  line-height: 1.6;
}

.discipline-section {
  padding: 1.25rem 1.4rem;
}

.discipline-section h3 {
  margin: 0 0 0.8rem;
  color: var(--text-muted);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.discipline-list {
  display: flex;
  flex-direction: column;
}

.discipline-item {
  padding: 0.8rem 0;
  border-bottom: 1px solid var(--border);
}

.discipline-item:first-child {
  padding-top: 0;
}

.discipline-item:last-child {
  padding-bottom: 0;
  border-bottom: 0;
}

.discipline-heading {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 0.6rem;
}

.discipline-heading strong {
  font-size: 0.9rem;
}

.discipline-code {
  color: var(--text-muted);
  font-size: 0.75rem;
}

.discipline-item p {
  margin: 0.4rem 0 0;
  color: var(--text-muted);
  font-size: 0.82rem;
  line-height: 1.5;
}

.empty-disciplines {
  margin: 0;
  color: var(--text-muted);
  font-size: 0.85rem;
}

.state-message {
  padding: 2rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
  color: var(--text-muted);
  font-size: 0.9rem;
  text-align: center;
}

.error-state {
  color: #ff8585;
}

.secondary-button {
  padding: 0.65rem 1rem;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--surface-raised);
  color: var(--text);
  font: inherit;
  font-size: 0.85rem;
  cursor: pointer;
}

@media (max-width: 850px) {
  .courses-page {
    padding: 1.5rem;
  }

  .course-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 550px) {
  .page-header {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
