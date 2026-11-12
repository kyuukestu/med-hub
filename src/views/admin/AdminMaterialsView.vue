<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { supabase } from '../../lib/supabase'
import type { Database } from '../../types/database'

type Material = Database['public']['Tables']['materials']['Row']
type MaterialVersion =
  Database['public']['Tables']['material_versions']['Row']

type MaterialType = Database['public']['Enums']['material_type']
type MaterialFormat = Database['public']['Enums']['material_format']
type MaterialSource = Database['public']['Enums']['material_source']
type VerificationStatus =
  Database['public']['Enums']['material_verification_status']

const materialTypeLabels: Record<MaterialType, string> = {
  lecture_slides: 'Lecture slides',
  lecture_notes: 'Lecture notes',
  recommended_reading: 'Recommended reading',
  textbook_chapter: 'Textbook chapter',
  practical_material: 'Practical material',
  supplementary: 'Supplementary resource',
  past_exam: 'Past examination',
  other: 'Other',
}

const materialFormatLabels: Record<MaterialFormat, string> = {
  uploaded_file: 'Uploaded file',
  external_link: 'External link',
  bibliographic_reference: 'Bibliographic reference',
}

const sourceLabels: Record<MaterialSource, string> = {
  lecturer: 'Lecturer',
  moodle: 'Moodle',
  student: 'Student',
  external: 'External',
}

const verificationStatusLabels: Record<VerificationStatus, string> = {
  verified: 'Verified/current',
  unverified: 'Unverified',
  outdated: 'Outdated',
  archived: 'Archived',
}

const materials = ref<Material[]>([])
const versions = ref<MaterialVersion[]>([])

const loading = ref(true)
const saving = ref(false)
const errorMessage = ref('')
const successMessage = ref('')

const searchQuery = ref('')
const statusFilter = ref<'all' | 'published' | 'draft'>('all')
const typeFilter = ref<MaterialType | 'all'>('all')
const formatFilter = ref<MaterialFormat | 'all'>('all')

const formOpen = ref(false)
const editingMaterialId = ref<string | null>(null)

const title = ref('')
const description = ref('')
const materialType = ref<MaterialType | ''>('')
const format = ref<MaterialFormat | ''>('')
const source = ref<MaterialSource | ''>('')
const academicYear = ref('')
const aliasesInput = ref('')

const author = ref('')
const publicationTitle = ref('')
const publisher = ref('')
const publicationYear = ref('')
const edition = ref('')
const chapterNumber = ref('')
const chapterTitle = ref('')
const pageRange = ref('')
const isbn = ref('')
const externalUrl = ref('')

const versionMap = computed(
  () => new Map(versions.value.map((version) => [version.id, version])),
)

const visibleMaterials = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase()

  return materials.value.filter((material) => {
    if (
      statusFilter.value === 'published' &&
      !material.is_published
    ) {
      return false
    }

    if (
      statusFilter.value === 'draft' &&
      material.is_published
    ) {
      return false
    }

    if (
      typeFilter.value !== 'all' &&
      material.material_type !== typeFilter.value
    ) {
      return false
    }

    if (
      formatFilter.value !== 'all' &&
      material.format !== formatFilter.value
    ) {
      return false
    }

    if (!query) return true

    const version = material.current_version_id
      ? versionMap.value.get(material.current_version_id)
      : null

    const searchableValues = [
      material.title,
      material.description,
      material.author,
      material.publication_title,
      material.publisher,
      material.isbn,
      material.chapter_title,
      material.chapter_number,
      material.academic_year,
      material.aliases.join(' '),
      version?.original_filename,
    ]

    return searchableValues.some((value) =>
      value?.toLocaleLowerCase().includes(query),
    )
  })
})

function resetForm() {
  editingMaterialId.value = null

  title.value = ''
  description.value = ''
  materialType.value = ''
  format.value = ''
  source.value = ''
  academicYear.value = ''
  aliasesInput.value = ''

  author.value = ''
  publicationTitle.value = ''
  publisher.value = ''
  publicationYear.value = ''
  edition.value = ''
  chapterNumber.value = ''
  chapterTitle.value = ''
  pageRange.value = ''
  isbn.value = ''
  externalUrl.value = ''

  errorMessage.value = ''
  successMessage.value = ''
}

function openCreateForm() {
  resetForm()
  formOpen.value = true
}

function openEditForm(material: Material) {
  resetForm()

  editingMaterialId.value = material.id

  title.value = material.title
  description.value = material.description ?? ''
  materialType.value = material.material_type
  format.value = material.format
  source.value = material.source
  academicYear.value = material.academic_year ?? ''
  aliasesInput.value = material.aliases.join(', ')

  author.value = material.author ?? ''
  publicationTitle.value = material.publication_title ?? ''
  publisher.value = material.publisher ?? ''
  publicationYear.value = material.publication_year?.toString() ?? ''
  edition.value = material.edition ?? ''
  chapterNumber.value = material.chapter_number ?? ''
  chapterTitle.value = material.chapter_title ?? ''
  pageRange.value = material.page_range ?? ''
  isbn.value = material.isbn ?? ''
  externalUrl.value = material.external_url ?? ''

  formOpen.value = true
}

function closeForm() {
  formOpen.value = false
  resetForm()
}

function nullableText(value: string): string | null {
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : null
}

function buildPayload() {
  if (
    !title.value.trim() ||
    !materialType.value ||
    !format.value ||
    !source.value
  ) {
    throw new Error(
      'Title, material type, format, and source are required.',
    )
  }
  
  const yearText = String(publicationYear.value).trim()
  const year = yearText ? Number(yearText) : null

  if (
    year !== null &&
    (!Number.isInteger(year) || year < 1000 || year > 9999)
  ) {
    throw new Error('Enter a valid four-digit publication year.')
  }

  const aliases = [
    ...new Set(
      aliasesInput.value
        .split(',')
        .map((alias) => alias.trim())
        .filter(Boolean),
    ),
  ]

  let normalizedExternalUrl: string | null = null

  if (format.value === 'external_link') {
    const rawUrl = externalUrl.value.trim()

    if (!rawUrl) {
      throw new Error('An external URL is required for this format.')
    }

    try {
      const parsedUrl = new URL(rawUrl)

      if (
        parsedUrl.protocol !== 'https:' &&
        parsedUrl.protocol !== 'http:'
      ) {
        throw new Error()
      }

      normalizedExternalUrl = parsedUrl.href
    } catch {
      throw new Error('Enter a valid HTTP or HTTPS URL.')
    }
  }

  return {
    title: title.value.trim(),
    description: nullableText(description.value),
    material_type: materialType.value,
    format: format.value,
    source: source.value,
    academic_year: nullableText(academicYear.value),
    aliases,
    author: nullableText(author.value),
    publication_title: nullableText(publicationTitle.value),
    publisher: nullableText(publisher.value),
    publication_year: year,
    edition: nullableText(edition.value),
    chapter_number: nullableText(chapterNumber.value),
    chapter_title: nullableText(chapterTitle.value),
    page_range: nullableText(pageRange.value),
    isbn: nullableText(isbn.value),
    external_url: normalizedExternalUrl,
  }
}

async function saveMaterial() {
  saving.value = true
  errorMessage.value = ''
  successMessage.value = ''

  try {
    const payload = buildPayload()

    if (editingMaterialId.value) {
      const { error } = await supabase
        .from('materials')
        .update(payload)
        .eq('id', editingMaterialId.value)

      if (error) throw error

      successMessage.value = 'Material updated.'
    } else {
      const { error } = await supabase
        .from('materials')
        .insert({
          ...payload,
          is_published: false,
        })

      if (error) throw error

      successMessage.value = 'Draft material created.'
    }

    const wasEditing = editingMaterialId.value !== null
    
    await loadMaterials()
    closeForm()
    
    successMessage.value = wasEditing
      ? 'Material updated.'
      : 'Draft material created.'
  } catch (error) {
    errorMessage.value =
      error instanceof Error
        ? error.message
        : 'Unable to save this material.'
  } finally {
    saving.value = false
  }
}

async function publishMaterial(material: Material) {
  const confirmed = window.confirm(
    `Publish "${material.title}"? It will become visible in the public materials catalogue.`,
  )

  if (!confirmed) return

  errorMessage.value = ''
  successMessage.value = ''

  try {
    const { error } = await supabase
      .from('materials')
      .update({ is_published: true })
      .eq('id', material.id)

    if (error) throw error

    successMessage.value = `"${material.title}" published.`
    await loadMaterials()
  } catch (error) {
    errorMessage.value =
      error instanceof Error
        ? error.message
        : 'Unable to publish this material. Check that its required information is complete.'
  }
}

async function unpublishMaterial(material: Material) {
  const confirmed = window.confirm(
    `Unpublish "${material.title}"? It will no longer appear in the public catalogue.`,
  )

  if (!confirmed) return

  errorMessage.value = ''
  successMessage.value = ''

  try {
    const { error } = await supabase
      .from('materials')
      .update({ is_published: false })
      .eq('id', material.id)

    if (error) throw error

    successMessage.value = `"${material.title}" unpublished.`
    await loadMaterials()
  } catch (error) {
    errorMessage.value =
      error instanceof Error
        ? error.message
        : 'Unable to unpublish this material.'
  }
}

async function loadMaterials() {
  loading.value = true
  errorMessage.value = ''

  try {
    const { data, error } = await supabase
      .from('materials')
      .select('*')
      .order('updated_at', { ascending: false })

    if (error) throw error

    materials.value = data ?? []

    const versionIds = [
      ...new Set(
        materials.value
          .map((material) => material.current_version_id)
          .filter((id): id is string => id !== null),
      ),
    ]

    if (versionIds.length === 0) {
      versions.value = []
      return
    }

    const { data: versionData, error: versionError } = await supabase
      .from('material_versions')
      .select('*')
      .in('id', versionIds)

    if (versionError) throw versionError

    versions.value = versionData ?? []
  } catch (error) {
    errorMessage.value =
      error instanceof Error
        ? error.message
        : 'Unable to load materials.'

    materials.value = []
    versions.value = []
  } finally {
    loading.value = false
  }
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`

  const units = ['KB', 'MB', 'GB', 'TB']
  let size = bytes / 1024
  let index = 0

  while (size >= 1024 && index < units.length - 1) {
    size /= 1024
    index++
  }

  return `${size.toFixed(1)} ${units[index]}`
}

onMounted(loadMaterials)
</script>

<template>
  <main class="admin-materials-page">
    <header class="page-header">
      <div>
        <p class="eyebrow">Administration</p>
        <h1>Materials</h1>
        <p>Manage academic resources, metadata, and publication status.</p>
      </div>

      <button type="button" class="primary-button" @click="openCreateForm">
        Add material
      </button>
    </header>

    <div v-if="errorMessage" class="message error-message" role="alert">
      {{ errorMessage }}
    </div>

    <div v-if="successMessage" class="message success-message" role="status">
      {{ successMessage }}
    </div>

    <section class="filters">
      <label>
        Search
        <input
          v-model="searchQuery"
          type="search"
          placeholder="Title, author, ISBN, filename..."
        />
      </label>

      <label>
        Publication
        <select v-model="statusFilter">
          <option value="all">All resources</option>
          <option value="published">Published</option>
          <option value="draft">Drafts</option>
        </select>
      </label>

      <label>
        Material type
        <select v-model="typeFilter">
          <option value="all">All types</option>
          <option
            v-for="(label, type) in materialTypeLabels"
            :key="type"
            :value="type"
          >
            {{ label }}
          </option>
        </select>
      </label>

      <label>
        Format
        <select v-model="formatFilter">
          <option value="all">All formats</option>
          <option
            v-for="(label, value) in materialFormatLabels"
            :key="value"
            :value="value"
          >
            {{ label }}
          </option>
        </select>
      </label>
    </section>

    <div class="results-summary">
      {{ visibleMaterials.length }}
      {{ visibleMaterials.length === 1 ? 'resource' : 'resources' }}
    </div>

    <div v-if="loading" class="empty-state">
      Loading materials...
    </div>

    <div v-else-if="visibleMaterials.length === 0" class="empty-state">
      <h2>No materials found</h2>
      <p>Try changing your search or filters, or create a new resource.</p>
    </div>

    <section v-else class="materials-list">
      <article
        v-for="material in visibleMaterials"
        :key="material.id"
        class="material-row"
      >
        <div class="material-main">
          <div class="material-heading">
            <h2>{{ material.title }}</h2>

            <span
              class="publication-status"
              :class="material.is_published ? 'published' : 'draft'"
            >
              {{ material.is_published ? 'Published' : 'Draft' }}
            </span>
          </div>

          <p v-if="material.description" class="material-description">
            {{ material.description }}
          </p>

          <div class="material-meta">
            <span>{{ materialTypeLabels[material.material_type] }}</span>
            <span>{{ materialFormatLabels[material.format] }}</span>
            <span>{{ sourceLabels[material.source] }}</span>
            <span v-if="material.academic_year">
              {{ material.academic_year }}
            </span>
          </div>

          <div v-if="material.current_version_id" class="version-meta">
            <template v-if="versionMap.get(material.current_version_id)">
              <span>
                Version
                {{ versionMap.get(material.current_version_id)?.version_number }}
              </span>
              <span>
                {{
                  verificationStatusLabels[
                    versionMap.get(material.current_version_id)!.verification_status
                  ]
                }}
              </span>
              <span>
                {{
                  formatFileSize(
                    versionMap.get(material.current_version_id)!.file_size_bytes,
                  )
                }}
              </span>
            </template>
          </div>

          <p v-else class="no-version">
            No uploaded version recorded
          </p>
        </div>

        <div class="material-actions">
          <button
            type="button"
            class="secondary-button"
            @click="openEditForm(material)"
          >
            Edit
          </button>

          <button
            v-if="!material.is_published"
            type="button"
            class="primary-button"
            @click="publishMaterial(material)"
          >
            Publish
          </button>

          <button
            v-else
            type="button"
            class="warning-button"
            @click="unpublishMaterial(material)"
          >
            Unpublish
          </button>
        </div>
      </article>
    </section>

    <section v-if="formOpen" class="editor-panel">
      <header class="editor-header">
        <div>
          <p class="eyebrow">
            {{ editingMaterialId ? 'Edit resource' : 'New resource' }}
          </p>
          <h2>
            {{ editingMaterialId ? 'Material details' : 'Create a material draft' }}
          </h2>
        </div>

        <button
          type="button"
          class="secondary-button"
          @click="closeForm"
        >
          Close
        </button>
      </header>

      <form class="material-form" @submit.prevent="saveMaterial">
        <div class="form-grid">
          <label class="full-width">
            Title *
            <input v-model="title" required maxlength="250" />
          </label>

          <label>
            Material type *
            <select v-model="materialType" required>
              <option value="" disabled>Select a type</option>
              <option
                v-for="(label, type) in materialTypeLabels"
                :key="type"
                :value="type"
              >
                {{ label }}
              </option>
            </select>
          </label>

          <label>
            Format *
            <select v-model="format" required>
              <option value="" disabled>Select a format</option>
              <option
                v-for="(label, value) in materialFormatLabels"
                :key="value"
                :value="value"
              >
                {{ label }}
              </option>
            </select>
          </label>

          <label>
            Source *
            <select v-model="source" required>
              <option value="" disabled>Select a source</option>
              <option
                v-for="(label, value) in sourceLabels"
                :key="value"
                :value="value"
              >
                {{ label }}
              </option>
            </select>
          </label>

          <label>
            Academic year
            <input
              v-model="academicYear"
              placeholder="2026/2027"
              maxlength="20"
            />
          </label>

          <label class="full-width">
            Description
            <textarea v-model="description" rows="3" />
          </label>

          <label class="full-width">
            Search aliases
            <input
              v-model="aliasesInput"
              placeholder="Alternative title, lecturer's filename, topic..."
            />
            <small>Separate aliases with commas.</small>
          </label>
        </div>

        <template v-if="format === 'external_link'">
          <h3>External resource</h3>

          <label>
            External URL *
            <input
              v-model="externalUrl"
              type="url"
              placeholder="https://..."
              required
            />
          </label>
        </template>

        <template v-if="format === 'bibliographic_reference'">
          <h3>Bibliographic information</h3>
        </template>

        <template v-if="format === 'bibliographic_reference' || format === 'uploaded_file'">
          <div class="form-grid">
            <label>
              Author
              <input v-model="author" />
            </label>

            <label>
              Publication title
              <input v-model="publicationTitle" />
            </label>

            <label>
              Publisher
              <input v-model="publisher" />
            </label>

            <label>
              Publication year
              <input
                v-model="publicationYear"
                type="number"
                min="1000"
                max="9999"
              />
            </label>

            <label>
              Edition
              <input v-model="edition" />
            </label>

            <label>
              ISBN
              <input v-model="isbn" />
            </label>

            <label>
              Chapter number
              <input v-model="chapterNumber" />
            </label>

            <label>
              Chapter title
              <input v-model="chapterTitle" />
            </label>

            <label>
              Page range
              <input v-model="pageRange" placeholder="e.g. 125–148" />
            </label>
          </div>
        </template>

        <p v-if="format === 'uploaded_file'" class="form-note">
          File upload and version management will be added in the next stage.
          You can save this metadata as a draft, but it cannot be published
          until an uploaded version exists.
        </p>

        <p v-if="format === 'bibliographic_reference'" class="form-note">
          A published bibliographic reference must include at least one of:
          author, publication title, ISBN, or publisher.
        </p>

        <div class="form-actions">
          <button
            type="button"
            class="secondary-button"
            @click="closeForm"
          >
            Cancel
          </button>

          <button
            type="submit"
            class="primary-button"
            :disabled="saving"
          >
            {{ saving ? 'Saving...' : 'Save draft' }}
          </button>
        </div>
      </form>
    </section>
  </main>
</template>

<style scoped>
.admin-materials-page {
  max-width: 1440px;
  margin: 0 auto;
  padding: 2rem;
}

.page-header,
.editor-header,
.material-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.page-header {
  margin-bottom: 1.5rem;
}

.page-header h1,
.editor-header h2 {
  margin: 0.25rem 0;
}

.page-header p,
.material-description,
.results-summary,
.no-version,
.form-note {
  color: var(--text-secondary, #64748b);
}

.eyebrow {
  margin: 0;
  color: var(--text-secondary, #64748b);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.primary-button,
.secondary-button,
.warning-button {
  padding: 0.65rem 1rem;
  border: 1px solid var(--border-color, #cbd5e1);
  border-radius: 0.45rem;
  cursor: pointer;
  font: inherit;
}

.primary-button {
  border-color: var(--primary-color, #2563eb);
  background: var(--primary-color, #2563eb);
  color: white;
}

.secondary-button {
  background: var(--surface, white);
  color: inherit;
}

.warning-button {
  border-color: #b45309;
  background: #fffbeb;
  color: #92400e;
}

.primary-button:disabled {
  opacity: 0.6;
  cursor: wait;
}

.message {
  padding: 0.85rem 1rem;
  margin-bottom: 1rem;
  border: 1px solid;
  border-radius: 0.5rem;
}

.error-message {
  border-color: #fecaca;
  background: #fef2f2;
  color: #991b1b;
}

.success-message {
  border-color: #bbf7d0;
  background: #f0fdf4;
  color: #166534;
}

.filters {
  display: grid;
  grid-template-columns: minmax(220px, 2fr) repeat(3, minmax(150px, 1fr));
  gap: 1rem;
  align-items: end;
  padding: 1rem;
  border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 0.75rem;
  background: var(--surface, white);
}

.filters label,
.material-form label {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  font-size: 0.85rem;
  font-weight: 600;
}

.filters input,
.filters select,
.material-form input,
.material-form select,
.material-form textarea {
  width: 100%;
  min-width: 0;
  padding: 0.65rem;
  border: 1px solid var(--border-color, #cbd5e1);
  border-radius: 0.4rem;
  background: var(--surface, white);
  color: inherit;
  font: inherit;
}

.material-form small {
  color: var(--text-secondary, #64748b);
  font-weight: 400;
}

.results-summary {
  margin: 1rem 0;
  font-size: 0.85rem;
}

.materials-list {
  display: grid;
  gap: 0.75rem;
}

.material-row {
  display: flex;
  justify-content: space-between;
  gap: 1.5rem;
  padding: 1.25rem;
  border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 0.75rem;
  background: var(--surface, white);
}

.material-main {
  min-width: 0;
  flex: 1;
}

.material-heading {
  justify-content: flex-start;
  flex-wrap: wrap;
  align-items: center;
}

.material-heading h2 {
  margin: 0;
  font-size: 1.05rem;
  overflow-wrap: anywhere;
}

.publication-status {
  padding: 0.2rem 0.55rem;
  border-radius: 999px;
  font-size: 0.7rem;
  font-weight: 700;
}

.publication-status.published {
  background: #dcfce7;
  color: #166534;
}

.publication-status.draft {
  background: #fef3c7;
  color: #92400e;
}

.material-description {
  margin: 0.5rem 0;
  font-size: 0.875rem;
}

.material-meta,
.version-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
  margin-top: 0.65rem;
  color: var(--text-secondary, #64748b);
  font-size: 0.75rem;
}

.no-version {
  margin: 0.65rem 0 0;
  font-size: 0.75rem;
}

.material-actions {
  display: flex;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.empty-state {
  display: grid;
  min-height: 200px;
  place-content: center;
  text-align: center;
  color: var(--text-secondary, #64748b);
}

.editor-panel {
  padding: 1.5rem;
  margin-top: 2rem;
  border: 1px solid var(--border-color, #cbd5e1);
  border-radius: 0.75rem;
  background: var(--surface, white);
}

.editor-header {
  margin-bottom: 1.5rem;
}

.material-form {
  display: grid;
  gap: 1.5rem;
}

.material-form h3 {
  margin: 0;
  font-size: 1rem;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

.full-width {
  grid-column: 1 / -1;
}

.form-note {
  padding: 0.85rem;
  margin: 0;
  border-radius: 0.4rem;
  background: var(--surface-secondary, #f1f5f9);
  font-size: 0.85rem;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding-top: 1rem;
  border-top: 1px solid var(--border-color, #e2e8f0);
}

.filters input:focus-visible,
.filters select:focus-visible,
.material-form input:focus-visible,
.material-form select:focus-visible,
.material-form textarea:focus-visible,
.primary-button:focus-visible,
.secondary-button:focus-visible,
.warning-button:focus-visible {
  outline: 2px solid var(--primary-color, #2563eb);
  outline-offset: 2px;
}

@media (max-width: 900px) {
  .filters {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .admin-materials-page {
    padding: 1rem;
  }

  .page-header,
  .material-row {
    flex-direction: column;
  }

  .page-header .primary-button,
  .material-actions {
    width: 100%;
  }

  .material-actions > button {
    flex: 1;
  }

  .filters,
  .form-grid {
    grid-template-columns: 1fr;
  }

  .full-width {
    grid-column: auto;
  }
}
</style>
