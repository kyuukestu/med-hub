
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '../../lib/supabase'
import type { Database } from '../../types/database'

type Course = Database['public']['Tables']['courses']['Row']
type Discipline = Database['public']['Tables']['disciplines']['Row']

const courses = ref<Course[]>([])
const disciplines = ref<Discipline[]>([])

const loading = ref(true)
const saving = ref(false)
const errorMessage = ref('')
const successMessage = ref('')

const searchQuery = ref('')
const showArchived = ref(false)
const selectedCourseId = ref<string | null>(null)

const courseFormOpen = ref(false)
const disciplineFormOpen = ref(false)

const editingCourseId = ref<string | null>(null)
const editingDisciplineId = ref<string | null>(null)

const courseCode = ref('')
const courseName = ref('')
const courseDescription = ref('')
const courseSortOrder = ref(0)

const disciplineCode = ref('')
const disciplineName = ref('')
const disciplineDescription = ref('')
const disciplineSortOrder = ref(0)

const selectedCourse = computed(
  () => courses.value.find((course) => course.id === selectedCourseId.value) ?? null,
)

const visibleCourses = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()

  return courses.value.filter((course) => {
    if (!showArchived.value && !course.is_active) return false

    if (!query) return true

    return (
      course.code.toLowerCase().includes(query) ||
      course.name.toLowerCase().includes(query) ||
      (course.description ?? '').toLowerCase().includes(query)
    )
  })
})

const selectedDisciplines = computed(() => {
  if (!selectedCourseId.value) return []

  return disciplines.value
    .filter((discipline) => discipline.course_id === selectedCourseId.value)
    .sort((a, b) => a.sort_order - b.sort_order)
})

async function loadData() {
  loading.value = true
  errorMessage.value = ''

  try {
    const [courseResult, disciplineResult] = await Promise.all([
      supabase
        .from('courses')
        .select('*')
        .order('sort_order')
        .order('code'),
      supabase
        .from('disciplines')
        .select('*')
        .order('sort_order')
        .order('name'),
    ])

    if (courseResult.error) throw courseResult.error
    if (disciplineResult.error) throw disciplineResult.error

    courses.value = courseResult.data
    disciplines.value = disciplineResult.data

    if (
      selectedCourseId.value &&
      !courses.value.some((course) => course.id === selectedCourseId.value)
    ) {
      selectedCourseId.value = null
    }
  } catch (error) {
    errorMessage.value =
      error instanceof Error
        ? error.message
        : 'Failed to load courses and disciplines.'
  } finally {
    loading.value = false
  }
}

function resetCourseForm() {
  editingCourseId.value = null
  courseCode.value = ''
  courseName.value = ''
  courseDescription.value = ''
  courseSortOrder.value = 0
  courseFormOpen.value = false
}

function openCreateCourse() {
  resetCourseForm()
  courseFormOpen.value = true
}

function openEditCourse(course: Course) {
  editingCourseId.value = course.id
  courseCode.value = course.code
  courseName.value = course.name
  courseDescription.value = course.description ?? ''
  courseSortOrder.value = course.sort_order
  courseFormOpen.value = true
}

async function saveCourse() {
  if (saving.value) return

  errorMessage.value = ''
  successMessage.value = ''

  const code = courseCode.value.trim().toUpperCase()
  const name = courseName.value.trim()

  if (!/^[A-Z0-9_-]+$/.test(code)) {
    errorMessage.value =
      'Course codes may only contain uppercase letters, numbers, underscores and hyphens.'
    return
  }

  if (!name) {
    errorMessage.value = 'Enter a course name.'
    return
  }

  saving.value = true

  try {
    const payload = {
      name,
      description: courseDescription.value.trim() || null,
      sort_order: courseSortOrder.value,
    }

    if (editingCourseId.value) {
      const { error } = await supabase
        .from('courses')
        .update(payload)
        .eq('id', editingCourseId.value)

      if (error) throw error
      successMessage.value = 'Course updated.'
    } else {
      const { error } = await supabase
        .from('courses')
        .insert({
          ...payload,
          code,
        })

      if (error) throw error
      successMessage.value = 'Course created.'
    }

    resetCourseForm()
    await loadData()
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Failed to save course.'
  } finally {
    saving.value = false
  }
}

async function toggleCourseActive(course: Course) {
  const action = course.is_active ? 'archive' : 'reactivate'

  if (!window.confirm(`${action === 'archive' ? 'Archive' : 'Reactivate'} ${course.code}?`)) {
    return
  }

  errorMessage.value = ''
  successMessage.value = ''

  const { error } = await supabase
    .from('courses')
    .update({ is_active: !course.is_active })
    .eq('id', course.id)

  if (error) {
    errorMessage.value = error.message
    return
  }

  successMessage.value = `Course ${action === 'archive' ? 'archived' : 'reactivated'}.`
  await loadData()
}

function resetDisciplineForm() {
  editingDisciplineId.value = null
  disciplineCode.value = ''
  disciplineName.value = ''
  disciplineDescription.value = ''
  disciplineSortOrder.value = 0
  disciplineFormOpen.value = false
}

function openCreateDiscipline() {
  resetDisciplineForm()
  disciplineFormOpen.value = true
}

function openEditDiscipline(discipline: Discipline) {
  editingDisciplineId.value = discipline.id
  disciplineCode.value = discipline.code
  disciplineName.value = discipline.name
  disciplineDescription.value = discipline.description ?? ''
  disciplineSortOrder.value = discipline.sort_order
  disciplineFormOpen.value = true
}

async function saveDiscipline() {
  if (saving.value || !selectedCourseId.value) return

  errorMessage.value = ''
  successMessage.value = ''

  const code = disciplineCode.value.trim().toUpperCase()
  const name = disciplineName.value.trim()

  if (!code) {
    errorMessage.value = 'Enter a discipline code.'
    return
  }

  if (!name) {
    errorMessage.value = 'Enter a discipline name.'
    return
  }

  saving.value = true

  try {
    const payload = {
      code,
      name,
      description: disciplineDescription.value.trim() || null,
      sort_order: disciplineSortOrder.value,
    }

    if (editingDisciplineId.value) {
      const { error } = await supabase
        .from('disciplines')
        .update(payload)
        .eq('id', editingDisciplineId.value)

      if (error) throw error
      successMessage.value = 'Discipline updated.'
    } else {
      const { error } = await supabase
        .from('disciplines')
        .insert({
          ...payload,
          course_id: selectedCourseId.value,
        })

      if (error) throw error
      successMessage.value = 'Discipline created.'
    }

    resetDisciplineForm()
    await loadData()
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Failed to save discipline.'
  } finally {
    saving.value = false
  }
}

async function toggleDisciplineActive(discipline: Discipline) {
  const action = discipline.is_active ? 'archive' : 'reactivate'

  if (
    !window.confirm(
      `${action === 'archive' ? 'Archive' : 'Reactivate'} ${discipline.name}?`,
    )
  ) {
    return
  }

  errorMessage.value = ''
  successMessage.value = ''

  const { error } = await supabase
    .from('disciplines')
    .update({ is_active: !discipline.is_active })
    .eq('id', discipline.id)

  if (error) {
    errorMessage.value = error.message
    return
  }

  successMessage.value = `Discipline ${action === 'archive' ? 'archived' : 'reactivated'}.`
  await loadData()
}

onMounted(loadData)
</script>

<template>
  <main class="admin-courses">
    <header class="page-header">
      <div>
        <RouterLink to="/admin" class="back-link">
          ← Administration
        </RouterLink>
        <p class="eyebrow">ACADEMIC STRUCTURE</p>
        <h1>Courses & Disciplines</h1>
        <p class="muted">
          Manage the courses and academic disciplines available to the class.
        </p>
      </div>

      <button class="primary-button" type="button" @click="openCreateCourse">
        Create course
      </button>
    </header>

    <p v-if="errorMessage" class="message error-message" role="alert">
      {{ errorMessage }}
    </p>

    <p v-if="successMessage" class="message success-message" role="status">
      {{ successMessage }}
    </p>

    <section v-if="courseFormOpen" class="form-panel">
      <div class="panel-heading">
        <h2>{{ editingCourseId ? 'Edit course' : 'New course' }}</h2>
        <button class="text-button" type="button" @click="resetCourseForm">
          Cancel
        </button>
      </div>

      <form class="form-grid" @submit.prevent="saveCourse">
        <label>
          Course code
          <input
            v-model="courseCode"
            type="text"
            placeholder="GPBSI"
            required
            :disabled="!!editingCourseId || saving"
          />
          <small>Uppercase letters, numbers, underscores and hyphens.</small>
        </label>

        <label>
          Course name
          <input
            v-model="courseName"
            type="text"
            placeholder="General Principles of Basic Sciences I"
            required
            :disabled="saving"
          />
        </label>

        <label class="full-width">
          Description
          <textarea
            v-model="courseDescription"
            rows="3"
            placeholder="Optional course description"
            :disabled="saving"
          />
        </label>

        <label>
          Display order
          <input
            v-model.number="courseSortOrder"
            type="number"
            min="0"
            step="1"
            :disabled="saving"
          />
        </label>

        <div class="form-actions full-width">
          <button class="secondary-button" type="button" @click="resetCourseForm">
            Cancel
          </button>
          <button class="primary-button" type="submit" :disabled="saving">
            {{ saving ? 'Saving...' : 'Save course' }}
          </button>
        </div>
      </form>
    </section>

    <section class="course-section">
      <div class="toolbar">
        <input
          v-model="searchQuery"
          type="search"
          placeholder="Search courses..."
          aria-label="Search courses"
        />

        <label class="checkbox-label">
          <input v-model="showArchived" type="checkbox" />
          Show archived
        </label>
      </div>

      <p v-if="loading" class="muted">Loading courses...</p>

      <div v-else class="course-layout">
        <div class="course-list">
          <button
            v-for="course in visibleCourses"
            :key="course.id"
            type="button"
            class="course-list-item"
            :class="{ selected: selectedCourseId === course.id }"
            @click="selectedCourseId = course.id; resetDisciplineForm()"
          >
            <span class="course-code">{{ course.code }}</span>
            <span class="course-name">{{ course.name }}</span>
            <span v-if="!course.is_active" class="status-tag archived">
              Archived
            </span>
          </button>

          <p v-if="visibleCourses.length === 0" class="empty-state">
            No courses found.
          </p>
        </div>

        <section v-if="selectedCourse" class="course-detail">
          <div class="detail-header">
            <div>
              <p class="eyebrow">{{ selectedCourse.code }}</p>
              <h2>{{ selectedCourse.name }}</h2>
              <p v-if="selectedCourse.description" class="muted">
                {{ selectedCourse.description }}
              </p>
              <span
                v-if="!selectedCourse.is_active"
                class="status-tag archived"
              >
                Archived
              </span>
            </div>

            <div class="detail-actions">
              <button
                class="secondary-button"
                type="button"
                @click="openEditCourse(selectedCourse)"
              >
                Edit
              </button>
              <button
                class="secondary-button"
                type="button"
                @click="toggleCourseActive(selectedCourse)"
              >
                {{ selectedCourse.is_active ? 'Archive' : 'Reactivate' }}
              </button>
            </div>
          </div>

          <div class="discipline-heading">
            <div>
              <h3>Disciplines</h3>
              <p class="muted">
                {{ selectedDisciplines.length }} total
              </p>
            </div>
            <button
              class="primary-button"
              type="button"
              :disabled="!selectedCourse.is_active"
              @click="openCreateDiscipline"
            >
              Add discipline
            </button>
          </div>

          <form
            v-if="disciplineFormOpen"
            class="discipline-form"
            @submit.prevent="saveDiscipline"
          >
            <h3>{{ editingDisciplineId ? 'Edit discipline' : 'New discipline' }}</h3>

            <label>
              Code
              <input
                v-model="disciplineCode"
                type="text"
                placeholder="EMB"
                required
                :disabled="saving"
              />
            </label>

            <label>
              Name
              <input
                v-model="disciplineName"
                type="text"
                placeholder="Embryology"
                required
                :disabled="saving"
              />
            </label>

            <label>
              Description
              <textarea
                v-model="disciplineDescription"
                rows="2"
                :disabled="saving"
              />
            </label>

            <label>
              Display order
              <input
                v-model.number="disciplineSortOrder"
                type="number"
                min="0"
                step="1"
                :disabled="saving"
              />
            </label>

            <div class="form-actions">
              <button
                class="secondary-button"
                type="button"
                @click="resetDisciplineForm"
              >
                Cancel
              </button>
              <button class="primary-button" type="submit" :disabled="saving">
                {{ saving ? 'Saving...' : 'Save discipline' }}
              </button>
            </div>
          </form>

          <div class="discipline-list">
            <article
              v-for="discipline in selectedDisciplines"
              :key="discipline.id"
              class="discipline-item"
            >
              <div>
                <strong>{{ discipline.name }}</strong>
                <span class="discipline-code">{{ discipline.code }}</span>
                <p v-if="discipline.description" class="muted">
                  {{ discipline.description }}
                </p>
                <span
                  v-if="!discipline.is_active"
                  class="status-tag archived"
                >
                  Archived
                </span>
              </div>

              <div class="detail-actions">
                <button
                  class="text-button"
                  type="button"
                  @click="openEditDiscipline(discipline)"
                >
                  Edit
                </button>
                <button
                  class="text-button"
                  type="button"
                  @click="toggleDisciplineActive(discipline)"
                >
                  {{ discipline.is_active ? 'Archive' : 'Reactivate' }}
                </button>
              </div>
            </article>

            <p v-if="selectedDisciplines.length === 0" class="empty-state">
              No disciplines have been added to this course.
            </p>
          </div>
        </section>

        <section v-else class="course-detail empty-detail">
          <p>Select a course to view and manage its disciplines.</p>
        </section>
      </div>
    </section>
  </main>
</template>

<style scoped>
.admin-courses {
  padding: 2.5rem;
}

.page-header,
.panel-heading,
.detail-header,
.discipline-heading,
.toolbar,
.form-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.page-header {
  margin-bottom: 2rem;
}

.page-header h1 {
  margin: 0.4rem 0;
  font-size: 1.8rem;
}

.back-link,
.text-button {
  color: var(--accent-hover);
  font-size: 0.85rem;
}

.back-link {
  display: inline-block;
  margin-bottom: 1.25rem;
}

.eyebrow {
  margin: 0;
  color: var(--text-muted);
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.12em;
}

.muted {
  color: var(--text-muted);
  font-size: 0.88rem;
  line-height: 1.5;
}

.primary-button,
.secondary-button {
  padding: 0.7rem 1rem;
  border: 1px solid var(--border);
  border-radius: 6px;
  font: inherit;
  font-size: 0.85rem;
  cursor: pointer;
}

.primary-button {
  border-color: transparent;
  background: var(--accent);
  color: #111318;
  font-weight: 600;
}

.secondary-button {
  background: var(--surface-raised);
  color: var(--text);
}

button:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.text-button {
  border: 0;
  background: transparent;
  cursor: pointer;
}

.message {
  padding: 0.8rem 1rem;
  border-radius: 6px;
  font-size: 0.9rem;
}

.error-message {
  background: rgb(180 50 50 / 15%);
  color: #ff8585;
}

.success-message {
  background: rgb(50 150 100 / 15%);
  color: #8cdbac;
}

.form-panel,
.course-detail {
  padding: 1.5rem;
  border: 1px solid var(--border);
  border-radius: 9px;
  background: var(--surface);
}

.form-panel {
  margin-bottom: 1.5rem;
}

.panel-heading {
  margin-bottom: 1.25rem;
}

.panel-heading h2 {
  margin: 0;
  font-size: 1.15rem;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

.form-grid label,
.discipline-form label {
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  font-size: 0.85rem;
  font-weight: 600;
}

.form-grid input,
.form-grid textarea,
.discipline-form input,
.discipline-form textarea,
.toolbar input {
  width: 100%;
  padding: 0.7rem;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--background);
  color: var(--text);
  font: inherit;
}

.form-grid small {
  color: var(--text-muted);
  font-size: 0.75rem;
  font-weight: 400;
}

.full-width {
  grid-column: 1 / -1;
}

.course-section {
  margin-top: 1.5rem;
}

.toolbar {
  margin-bottom: 1rem;
}

.toolbar > input {
  max-width: 360px;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--text-muted);
  font-size: 0.85rem;
}

.course-layout {
  display: grid;
  grid-template-columns: minmax(220px, 0.8fr) minmax(0, 2fr);
  gap: 1rem;
  align-items: start;
}

.course-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.course-list-item {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.35rem;
  padding: 1rem;
  border: 1px solid var(--border);
  border-radius: 7px;
  background: var(--surface);
  color: var(--text);
  text-align: left;
  cursor: pointer;
}

.course-list-item.selected {
  border-color: var(--accent);
  background: var(--surface-raised);
}

.course-code {
  color: var(--accent);
  font-size: 0.75rem;
  font-weight: 700;
}

.course-name {
  font-size: 0.9rem;
}

.status-tag {
  display: inline-block;
  padding: 0.2rem 0.45rem;
  border-radius: 4px;
  font-size: 0.7rem;
}

.archived {
  background: rgb(150 150 150 / 15%);
  color: var(--text-muted);
}

.detail-header {
  align-items: flex-start;
  padding-bottom: 1.25rem;
  border-bottom: 1px solid var(--border);
}

.detail-header h2 {
  margin: 0.4rem 0;
  font-size: 1.35rem;
}

.detail-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.discipline-heading {
  margin: 1.5rem 0 1rem;
}

.discipline-heading h3 {
  margin: 0;
  font-size: 1rem;
}

.discipline-heading p {
  margin: 0.25rem 0 0;
}

.discipline-form {
  display: grid;
  gap: 1rem;
  margin-bottom: 1rem;
  padding: 1rem;
  border: 1px solid var(--border);
  border-radius: 7px;
}

.discipline-form h3 {
  margin: 0;
}

.discipline-list {
  display: flex;
  flex-direction: column;
}

.discipline-item {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 0;
  border-bottom: 1px solid var(--border);
}

.discipline-item:last-child {
  border-bottom: 0;
}

.discipline-code {
  margin-left: 0.5rem;
  color: var(--text-muted);
  font-size: 0.8rem;
}

.discipline-item p {
  margin: 0.4rem 0;
}

.empty-state,
.empty-detail {
  padding: 1.5rem;
  color: var(--text-muted);
  font-size: 0.9rem;
}

@media (max-width: 850px) {
  .admin-courses {
    padding: 1.5rem;
  }

  .course-layout {
    grid-template-columns: 1fr;
  }

  .course-list {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 550px) {
  .page-header,
  .detail-header,
  .discipline-heading,
  .toolbar {
    align-items: flex-start;
    flex-direction: column;
  }

  .form-grid {
    grid-template-columns: 1fr;
  }

  .course-list {
    grid-template-columns: 1fr;
  }

  .discipline-item {
    flex-direction: column;
  }
}
</style>
