<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { supabase } from "../lib/supabase";
import type { Database } from "../types/database";

type Material = Database["public"]["Tables"]["materials"]["Row"];
type MaterialLink = Database["public"]["Tables"]["material_links"]["Row"];
type MaterialVersion = Database["public"]["Tables"]["material_versions"]["Row"];
type Course = Database["public"]["Tables"]["courses"]["Row"];
type Discipline = Database["public"]["Tables"]["disciplines"]["Row"];

type MaterialType = Database["public"]["Enums"]["material_type"];
type MaterialFormat = Database["public"]["Enums"]["material_format"];
type VerificationStatus =
    Database["public"]["Enums"]["material_verification_status"];
type RelationshipType =
    Database["public"]["Enums"]["material_relationship_type"];

interface MaterialEntry {
    material: Material;
    version: MaterialVersion | null;
    links: MaterialLink[];
    courseNames: string[];
    disciplineNames: string[];
}

const materialTypeLabels: Record<MaterialType, string> = {
    lecture_slides: "Lecture slides",
    lecture_notes: "Lecture notes",
    recommended_reading: "Recommended reading",
    textbook_chapter: "Textbook chapters",
    practical_material: "Practical materials",
    supplementary: "Supplementary resources",
    past_exam: "Past examinations",
    other: "Other resources",
};

const materialFormatLabels: Record<MaterialFormat, string> = {
    uploaded_file: "Uploaded file",
    external_link: "External link",
    bibliographic_reference: "Bibliographic reference",
};

const verificationStatusLabels: Record<VerificationStatus, string> = {
    verified: "Verified/current",
    unverified: "Unverified",
    outdated: "Outdated",
    archived: "Archived",
};

const relationshipLabels: Record<RelationshipType, string> = {
    lecture_resource: "Lecture resource",
    required_reading: "Required reading",
    recommended_reading: "Recommended reading",
    supplementary: "Supplementary resource",
    reference: "Reference",
    course_resource: "Course resource",
    assignment_resource: "Assignment resource",
};

const sourceLabels: Record<Material["source"], string> = {
    lecturer: "Lecturer",
    moodle: "Moodle",
    student: "Student contribution",
    external: "External source",
};

const materials = ref<Material[]>([]);
const links = ref<MaterialLink[]>([]);
const versions = ref<MaterialVersion[]>([]);
const courses = ref<Course[]>([]);
const disciplines = ref<Discipline[]>([]);

const loading = ref(true);
const errorMessage = ref("");

const searchQuery = ref("");
const selectedCourseId = ref("");
const selectedDisciplineId = ref("");
const selectedMaterialType = ref<MaterialType | "all">("all");
const selectedAcademicYear = ref("");
const selectedVerificationStatus = ref<VerificationStatus | "all">("all");

const selectedMaterial = ref<MaterialEntry | null>(null);

const courseMap = computed(
    () => new Map(courses.value.map((course) => [course.id, course])),
);

const disciplineMap = computed(
    () =>
        new Map(
            disciplines.value.map((discipline) => [discipline.id, discipline]),
        ),
);

const availableDisciplines = computed(() => {
    const matchingDisciplines = selectedCourseId.value
        ? disciplines.value.filter(
              (discipline) => discipline.course_id === selectedCourseId.value,
          )
        : disciplines.value;

    return [...matchingDisciplines].sort(
        (a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name),
    );
});

watch(selectedCourseId, () => {
    if (
        selectedDisciplineId.value &&
        !availableDisciplines.value.some(
            (discipline) => discipline.id === selectedDisciplineId.value,
        )
    ) {
        selectedDisciplineId.value = "";
    }
});

const academicYears = computed(() => {
    return [
        ...new Set(
            materials.value
                .map((material) => material.academic_year)
                .filter(
                    (year): year is string => year !== null && year.length > 0,
                ),
        ),
    ].sort((a, b) => b.localeCompare(a));
});

const versionMap = computed(
    () => new Map(versions.value.map((version) => [version.id, version])),
);

const linksByMaterial = computed(() => {
    const grouped = new Map<string, MaterialLink[]>();

    for (const link of links.value) {
        const existing = grouped.get(link.material_id) ?? [];
        existing.push(link);
        grouped.set(link.material_id, existing);
    }

    return grouped;
});

const materialEntries = computed<MaterialEntry[]>(() => {
    return materials.value.map((material) => {
        const materialLinks = linksByMaterial.value.get(material.id) ?? [];

        const courseIds = new Set(
            materialLinks
                .map((link) => link.course_id)
                .filter((id): id is string => id !== null),
        );

        const disciplineIds = new Set(
            materialLinks
                .map((link) => link.discipline_id)
                .filter((id): id is string => id !== null),
        );

        const courseNames = [...courseIds]
            .map((id) => courseMap.value.get(id))
            .filter((course): course is Course => course !== undefined)
            .map((course) => `${course.code} · ${course.name}`)
            .sort((a, b) => a.localeCompare(b));

        const disciplineNames = [...disciplineIds]
            .map((id) => disciplineMap.value.get(id))
            .filter(
                (discipline): discipline is Discipline =>
                    discipline !== undefined,
            )
            .map((discipline) => discipline.name)
            .sort((a, b) => a.localeCompare(b));

        return {
            material,
            version: material.current_version_id
                ? (versionMap.value.get(material.current_version_id) ?? null)
                : null,
            links: materialLinks,
            courseNames,
            disciplineNames,
        };
    });
});

const filteredMaterials = computed(() => {
    const query = searchQuery.value.trim().toLocaleLowerCase();

    return materialEntries.value.filter((entry) => {
        const { material, version, links: materialLinks } = entry;

        if (
            selectedMaterialType.value !== "all" &&
            material.material_type !== selectedMaterialType.value
        ) {
            return false;
        }

        if (
            selectedAcademicYear.value &&
            material.academic_year !== selectedAcademicYear.value
        ) {
            return false;
        }

        if (
            selectedVerificationStatus.value !== "all" &&
            version?.verification_status !== selectedVerificationStatus.value
        ) {
            return false;
        }

        if (
            selectedCourseId.value &&
            !materialLinks.some(
                (link) => link.course_id === selectedCourseId.value,
            )
        ) {
            return false;
        }

        if (
            selectedDisciplineId.value &&
            !materialLinks.some(
                (link) => link.discipline_id === selectedDisciplineId.value,
            )
        ) {
            return false;
        }

        if (!query) return true;

        const searchableValues = [
            material.title,
            material.description,
            material.author,
            material.publication_title,
            material.publisher,
            material.isbn,
            material.chapter_number,
            material.chapter_title,
            material.page_range,
            material.edition,
            material.publication_year?.toString(),
            material.academic_year,
            ...material.aliases,
            version?.original_filename,
            ...entry.courseNames,
            ...entry.disciplineNames,
        ];

        return searchableValues.some((value) =>
            value?.toLocaleLowerCase().includes(query),
        );
    });
});

const groupedMaterials = computed<[MaterialType, MaterialEntry[]][]>(() => {
  return (Object.keys(materialTypeLabels) as MaterialType[])
    .map((type): [MaterialType, MaterialEntry[]] => [
      type,
      filteredMaterials.value.filter(
        (entry) => entry.material.material_type === type,
      ),
    ])
    .filter(([, entries]) => entries.length > 0)
})

function clearFilters() {
    searchQuery.value = "";
    selectedCourseId.value = "";
    selectedDisciplineId.value = "";
    selectedMaterialType.value = "all";
    selectedAcademicYear.value = "";
    selectedVerificationStatus.value = "all";
}

function formatFileSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;

    const units = ["KB", "MB", "GB", "TB"];
    let size = bytes / 1024;
    let unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
        size /= 1024;
        unitIndex++;
    }

    return `${size.toFixed(size >= 10 ? 1 : 2)} ${units[unitIndex]}`;
}

function formatSource(source: Material["source"]): string {
    return sourceLabels[source];
}

function openMaterialDetails(entry: MaterialEntry) {
    selectedMaterial.value = entry;
}

async function openMaterial(entry: MaterialEntry) {
    errorMessage.value = "";

    if (entry.material.format === "external_link") {
        const externalUrl = entry.material.external_url;

        if (!externalUrl) {
            errorMessage.value = "This resource does not have an external URL.";
            return;
        }

        try {
            const url = new URL(externalUrl);

            if (url.protocol !== "https:" && url.protocol !== "http:") {
                errorMessage.value =
                    "This resource has an invalid external URL.";
                return;
            }

            window.open(url.href, "_blank", "noopener,noreferrer");
        } catch {
            errorMessage.value = "This resource has an invalid external URL.";
        }

        return;
    }

    if (entry.material.format !== "uploaded_file") return;

    if (!entry.version) {
        errorMessage.value =
            "No uploaded file version is available for this resource.";
        return;
    }

    const fileWindow = window.open("about:blank", "_blank");

    if (!fileWindow) {
        errorMessage.value =
            "Your browser blocked the file window. Allow pop-ups for this site and try again.";
        return;
    }

    fileWindow.opener = null;

    try {
        const { data, error } = await supabase.storage
            .from(entry.version.storage_bucket)
            .createSignedUrl(entry.version.storage_path, 60);

        if (error) throw error;

        if (!data.signedUrl) {
            throw new Error("Supabase did not return a signed file URL.");
        }

        fileWindow.location.href = data.signedUrl;
    } catch (error) {
        fileWindow.close();

        errorMessage.value =
            error instanceof Error
                ? `Unable to open this file: ${error.message}`
                : "An unexpected error occurred while opening this file.";
    }
}

async function loadMaterials() {
    loading.value = true;
    errorMessage.value = "";

    try {
        const [materialResult, courseResult, disciplineResult] =
            await Promise.all([
                supabase
                    .from("materials")
                    .select("*")
                    .eq("is_published", true)
                    .order("title"),

                supabase
                    .from("courses")
                    .select("*")
                    .eq("is_active", true)
                    .order("sort_order"),

                supabase
                    .from("disciplines")
                    .select("*")
                    .eq("is_active", true)
                    .order("sort_order"),
            ]);

        if (materialResult.error) throw materialResult.error;
        if (courseResult.error) throw courseResult.error;
        if (disciplineResult.error) throw disciplineResult.error;

        materials.value = materialResult.data ?? [];
        courses.value = courseResult.data ?? [];
        disciplines.value = disciplineResult.data ?? [];

        selectedMaterial.value = null;

        if (materials.value.length === 0) {
            links.value = [];
            versions.value = [];
            return;
        }

        const materialIds = materials.value.map((material) => material.id);

        const { data: linkData, error: linkError } = await supabase
            .from("material_links")
            .select("*")
            .in("material_id", materialIds);

        if (linkError) throw linkError;

        links.value = linkData ?? [];

        const versionIds = [
            ...new Set(
                materials.value
                    .map((material) => material.current_version_id)
                    .filter((id): id is string => id !== null),
            ),
        ];

        if (versionIds.length === 0) {
            versions.value = [];
            return;
        }

        const { data: versionData, error: versionError } = await supabase
            .from("material_versions")
            .select("*")
            .in("id", versionIds);

        if (versionError) throw versionError;

        versions.value = versionData ?? [];
    } catch (error) {
        errorMessage.value =
            error instanceof Error
                ? error.message
                : "Unable to load academic materials.";

        materials.value = [];
        links.value = [];
        versions.value = [];
    } finally {
        loading.value = false;
    }
}

onMounted(loadMaterials);
</script>

<template>
    <main class="materials-page">
        <header class="materials-header">
            <div>
                <p class="eyebrow">Academic resources</p>
                <h1>Materials</h1>
                <p class="page-description">
                    Browse lecture slides, notes, readings, practical materials,
                    and other academic resources.
                </p>
            </div>

            <button
                type="button"
                class="refresh-button"
                :disabled="loading"
                @click="loadMaterials"
            >
                {{ loading ? "Loading..." : "Refresh materials" }}
            </button>
        </header>

        <div v-if="errorMessage" class="materials-error" role="alert">
            {{ errorMessage }}
        </div>

        <section class="materials-filters">
            <div class="filter-field search-field">
                <label for="materials-search">Search</label>
                <input
                    id="materials-search"
                    v-model="searchQuery"
                    type="search"
                    placeholder="Search titles, authors, ISBNs, filenames..."
                />
            </div>

            <div class="filter-field">
                <label for="materials-course">Course</label>
                <select id="materials-course" v-model="selectedCourseId">
                    <option value="">All courses</option>
                    <option
                        v-for="course in courses"
                        :key="course.id"
                        :value="course.id"
                    >
                        {{ course.code }} · {{ course.name }}
                    </option>
                </select>
            </div>

            <div class="filter-field">
                <label for="materials-discipline">Discipline</label>
                <select
                    id="materials-discipline"
                    v-model="selectedDisciplineId"
                >
                    <option value="">All disciplines</option>
                    <option
                        v-for="discipline in availableDisciplines"
                        :key="discipline.id"
                        :value="discipline.id"
                    >
                        {{ discipline.name }}
                    </option>
                </select>
            </div>

            <div class="filter-field">
                <label for="materials-type">Material type</label>
                <select id="materials-type" v-model="selectedMaterialType">
                    <option value="all">All types</option>
                    <option
                        v-for="(label, type) in materialTypeLabels"
                        :key="type"
                        :value="type"
                    >
                        {{ label }}
                    </option>
                </select>
            </div>

            <div class="filter-field">
                <label for="materials-year">Academic year</label>
                <select id="materials-year" v-model="selectedAcademicYear">
                    <option value="">All years</option>
                    <option
                        v-for="year in academicYears"
                        :key="year"
                        :value="year"
                    >
                        {{ year }}
                    </option>
                </select>
            </div>

            <div class="filter-field">
                <label for="materials-verification">Verification</label>
                <select
                    id="materials-verification"
                    v-model="selectedVerificationStatus"
                >
                    <option value="all">All statuses</option>
                    <option
                        v-for="(label, status) in verificationStatusLabels"
                        :key="status"
                        :value="status"
                    >
                        {{ label }}
                    </option>
                </select>
            </div>

            <button
                type="button"
                class="clear-filters-button"
                @click="clearFilters"
            >
                Clear filters
            </button>
        </section>

        <div class="catalogue-summary">
            <span>
                {{ filteredMaterials.length }}
                {{ filteredMaterials.length === 1 ? "resource" : "resources" }}
            </span>
        </div>

        <div v-if="loading" class="materials-loading">
            Loading academic materials...
        </div>

        <div v-else-if="filteredMaterials.length === 0" class="materials-empty">
            <h2>No materials found</h2>
            <p>No published resources match your current search and filters.</p>
            <button
                type="button"
                class="clear-filters-button"
                @click="clearFilters"
            >
                Clear filters
            </button>
        </div>

        <section v-else class="materials-groups">
            <section
                v-for="[type, entries] in groupedMaterials"
                :key="type"
                class="material-group"
            >
                <header class="material-group-header">
                    <h2>{{ materialTypeLabels[type] }}</h2>
                    <span>{{ entries.length }}</span>
                </header>

                <div class="material-grid">
                    <article
                        v-for="entry in entries"
                        :key="entry.material.id"
                        class="material-card"
                    >
                        <div class="material-card-header">
                            <span class="material-format">
                                {{
                                    materialFormatLabels[entry.material.format]
                                }}
                            </span>

                            <span
                                v-if="entry.version"
                                class="verification-tag"
                                :class="`verification-${entry.version.verification_status}`"
                            >
                                {{
                                    verificationStatusLabels[
                                        entry.version.verification_status
                                    ]
                                }}
                            </span>
                        </div>

                        <h3>{{ entry.material.title }}</h3>

                        <p
                            v-if="entry.material.description"
                            class="material-card-description"
                        >
                            {{ entry.material.description }}
                        </p>

                        <div
                            v-if="
                                entry.courseNames.length ||
                                entry.disciplineNames.length
                            "
                            class="material-context"
                        >
                            <span v-if="entry.courseNames.length">
                                {{ entry.courseNames.join(", ") }}
                            </span>

                            <span v-if="entry.disciplineNames.length">
                                {{ entry.disciplineNames.join(", ") }}
                            </span>
                        </div>

                        <div class="material-card-meta">
                            <span v-if="entry.material.academic_year">
                                {{ entry.material.academic_year }}
                            </span>

                            <span v-if="entry.version">
                                {{
                                    formatFileSize(
                                        entry.version.file_size_bytes,
                                    )
                                }}
                            </span>

                            <span v-if="entry.material.author">
                                {{ entry.material.author }}
                            </span>
                        </div>

                        <div class="material-card-actions">
                            <button
                                type="button"
                                class="details-button"
                                @click="openMaterialDetails(entry)"
                            >
                                Details
                            </button>

                            <button
                                v-if="
                                    entry.material.format !==
                                    'bibliographic_reference'
                                "
                                type="button"
                                class="open-material-button"
                                @click="openMaterial(entry)"
                            >
                                {{
                                    entry.material.format === "external_link"
                                        ? "Open link"
                                        : "Open file"
                                }}
                            </button>
                        </div>
                    </article>
                </div>
            </section>
        </section>

        <section v-if="selectedMaterial" class="material-details">
            <header class="material-details-header">
                <div>
                    <p class="eyebrow">Resource details</p>
                    <h2>{{ selectedMaterial.material.title }}</h2>
                </div>

                <button
                    type="button"
                    class="close-details-button"
                    aria-label="Close material details"
                    @click="selectedMaterial = null"
                >
                    Close
                </button>
            </header>

            <div class="material-details-tags">
                <span class="material-format">
                    {{ materialFormatLabels[selectedMaterial.material.format] }}
                </span>

                <span>
                    {{
                        materialTypeLabels[
                            selectedMaterial.material.material_type
                        ]
                    }}
                </span>

                <span v-if="selectedMaterial.version">
                    {{
                        verificationStatusLabels[
                            selectedMaterial.version.verification_status
                        ]
                    }}
                </span>
            </div>

            <p v-if="selectedMaterial.material.description">
                {{ selectedMaterial.material.description }}
            </p>

            <dl class="material-details-grid">
                <div v-if="selectedMaterial.material.author">
                    <dt>Author</dt>
                    <dd>{{ selectedMaterial.material.author }}</dd>
                </div>

                <div v-if="selectedMaterial.material.publication_title">
                    <dt>Publication</dt>
                    <dd>{{ selectedMaterial.material.publication_title }}</dd>
                </div>

                <div v-if="selectedMaterial.material.publisher">
                    <dt>Publisher</dt>
                    <dd>{{ selectedMaterial.material.publisher }}</dd>
                </div>

                <div v-if="selectedMaterial.material.publication_year">
                    <dt>Publication year</dt>
                    <dd>{{ selectedMaterial.material.publication_year }}</dd>
                </div>

                <div v-if="selectedMaterial.material.edition">
                    <dt>Edition</dt>
                    <dd>{{ selectedMaterial.material.edition }}</dd>
                </div>

                <div v-if="selectedMaterial.material.chapter_number">
                    <dt>Chapter number</dt>
                    <dd>{{ selectedMaterial.material.chapter_number }}</dd>
                </div>

                <div v-if="selectedMaterial.material.chapter_title">
                    <dt>Chapter title</dt>
                    <dd>{{ selectedMaterial.material.chapter_title }}</dd>
                </div>

                <div v-if="selectedMaterial.material.page_range">
                    <dt>Page range</dt>
                    <dd>{{ selectedMaterial.material.page_range }}</dd>
                </div>

                <div v-if="selectedMaterial.material.isbn">
                    <dt>ISBN</dt>
                    <dd>{{ selectedMaterial.material.isbn }}</dd>
                </div>

                <div v-if="selectedMaterial.material.academic_year">
                    <dt>Academic year</dt>
                    <dd>{{ selectedMaterial.material.academic_year }}</dd>
                </div>

                <div>
                    <dt>Source</dt>
                    <dd>
                        {{ formatSource(selectedMaterial.material.source) }}
                    </dd>
                </div>

                <div v-if="selectedMaterial.version">
                    <dt>Filename</dt>
                    <dd>{{ selectedMaterial.version.original_filename }}</dd>
                </div>

                <div v-if="selectedMaterial.version">
                    <dt>File size</dt>
                    <dd>
                        {{
                            formatFileSize(
                                selectedMaterial.version.file_size_bytes,
                            )
                        }}
                    </dd>
                </div>
            </dl>

            <div
                v-if="selectedMaterial.links.length"
                class="material-relationships"
            >
                <h3>Academic associations</h3>

                <ul>
                    <li v-for="link in selectedMaterial.links" :key="link.id">
                        <span>
                            {{ relationshipLabels[link.relationship_type] }}
                        </span>

                        <span v-if="link.course_id">
                            · {{ courseMap.get(link.course_id)?.code }}
                        </span>

                        <span v-if="link.discipline_id">
                            · {{ disciplineMap.get(link.discipline_id)?.name }}
                        </span>
                    </li>
                </ul>
            </div>

            <button
                v-if="
                    selectedMaterial.material.format !==
                    'bibliographic_reference'
                "
                type="button"
                class="open-material-button"
                @click="openMaterial(selectedMaterial)"
            >
                {{
                    selectedMaterial.material.format === "external_link"
                        ? "Open external resource"
                        : "Open file"
                }}
            </button>
        </section>
    </main>
</template>

<style scoped>
.materials-page {
    max-width: 1440px;
    margin: 0 auto;
    padding: 2rem;
}

.materials-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1.5rem;
    margin-bottom: 1.75rem;
}

.materials-header h1 {
    margin: 0.25rem 0;
}

.eyebrow {
    margin: 0;
    color: var(--text-secondary, #64748b);
    font-size: 0.75rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
}

.page-description {
    margin: 0.5rem 0 0;
    color: var(--text-secondary, #64748b);
}

.refresh-button,
.clear-filters-button,
.details-button,
.close-details-button,
.open-material-button {
    padding: 0.65rem 1rem;
    border: 1px solid var(--border-color, #cbd5e1);
    border-radius: 0.45rem;
    background: var(--surface, #fff);
    color: inherit;
    cursor: pointer;
}

.refresh-button:disabled {
    opacity: 0.6;
    cursor: wait;
}

.open-material-button {
    border-color: var(--primary-color, #2563eb);
    background: var(--primary-color, #2563eb);
    color: white;
}

.materials-error {
    padding: 1rem;
    margin-bottom: 1rem;
    border: 1px solid #fecaca;
    border-radius: 0.5rem;
    background: #fef2f2;
    color: #991b1b;
}

.materials-filters {
    display: grid;
    grid-template-columns: minmax(200px, 2fr) repeat(3, minmax(140px, 1fr));
    gap: 1rem;
    align-items: end;
    padding: 1.25rem;
    margin-bottom: 1rem;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.75rem;
    background: var(--surface, #fff);
}

.filter-field {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
}

.filter-field label {
    font-size: 0.85rem;
    font-weight: 600;
}

.filter-field input,
.filter-field select {
    width: 100%;
    min-width: 0;
    padding: 0.65rem;
    border: 1px solid var(--border-color, #cbd5e1);
    border-radius: 0.4rem;
    background: var(--surface, #fff);
    color: inherit;
}

.clear-filters-button {
    justify-self: start;
}

.catalogue-summary {
    margin: 1.25rem 0;
    color: var(--text-secondary, #64748b);
    font-size: 0.85rem;
}

.materials-loading,
.materials-empty {
    display: grid;
    min-height: 250px;
    place-content: center;
    text-align: center;
    color: var(--text-secondary, #64748b);
}

.materials-empty h2 {
    margin-bottom: 0.25rem;
    color: var(--text-primary, #0f172a);
}

.materials-empty p {
    margin-top: 0.25rem;
}

.material-group {
    margin-top: 2rem;
}

.material-group-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 1rem;
}

.material-group-header h2 {
    margin: 0;
    font-size: 1.2rem;
}

.material-group-header span {
    color: var(--text-secondary, #64748b);
    font-size: 0.85rem;
}

.material-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 1rem;
}

.material-card {
    display: flex;
    flex-direction: column;
    min-width: 0;
    padding: 1.25rem;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.75rem;
    background: var(--surface, #fff);
}

.material-card-header {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
}

.material-format,
.verification-tag {
    display: inline-block;
    padding: 0.25rem 0.55rem;
    border-radius: 999px;
    background: var(--surface-secondary, #f1f5f9);
    color: var(--text-secondary, #475569);
    font-size: 0.7rem;
    font-weight: 600;
}

.verification-verified {
    background: #dcfce7;
    color: #166534;
}

.verification-unverified {
    background: #fef3c7;
    color: #92400e;
}

.verification-outdated {
    background: #fee2e2;
    color: #991b1b;
}

.verification-archived {
    background: #e2e8f0;
    color: #475569;
}

.material-card h3 {
    margin: 1rem 0 0.5rem;
    font-size: 1.05rem;
    overflow-wrap: anywhere;
}

.material-card-description {
    margin: 0;
    color: var(--text-secondary, #64748b);
    font-size: 0.875rem;
    line-height: 1.5;
    display: -webkit-box;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 3;
    line-clamp: 3;
    overflow: hidden;
}

.material-context {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    margin-top: 0.85rem;
    font-size: 0.8rem;
}

.material-context span {
    color: var(--text-secondary, #64748b);
}

.material-card-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem 0.75rem;
    margin-top: 0.85rem;
    color: var(--text-secondary, #64748b);
    font-size: 0.75rem;
}

.material-card-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: auto;
    padding-top: 1.25rem;
}

.material-details {
    padding: 1.5rem;
    margin-top: 2rem;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.75rem;
    background: var(--surface, #fff);
    scroll-margin-top: 1.5rem;
}

.material-details-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 1rem;
}

.material-details-header h2 {
    margin: 0.35rem 0 0;
}

.material-details-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin: 1rem 0;
}

.material-details-tags > span:not(.material-format) {
    padding: 0.25rem 0.55rem;
    border-radius: 999px;
    background: var(--surface-secondary, #f1f5f9);
    color: var(--text-secondary, #475569);
    font-size: 0.75rem;
}

.material-details-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1rem;
    margin: 1.5rem 0;
}

.material-details-grid dt {
    margin-bottom: 0.3rem;
    color: var(--text-secondary, #64748b);
    font-size: 0.8rem;
    font-weight: 600;
}

.material-details-grid dd {
    margin: 0;
    overflow-wrap: anywhere;
}

.material-relationships {
    padding-top: 1rem;
    margin: 1rem 0;
    border-top: 1px solid var(--border-color, #e2e8f0);
}

.material-relationships h3 {
    font-size: 1rem;
}

.material-relationships ul {
    padding-left: 1.25rem;
}

.material-relationships li {
    margin: 0.4rem 0;
    color: var(--text-secondary, #64748b);
    font-size: 0.85rem;
}

.refresh-button:focus-visible,
.clear-filters-button:focus-visible,
.details-button:focus-visible,
.close-details-button:focus-visible,
.open-material-button:focus-visible,
.filter-field input:focus-visible,
.filter-field select:focus-visible {
    outline: 2px solid var(--primary-color, #2563eb);
    outline-offset: 2px;
}

.refresh-button:hover:not(:disabled),
.clear-filters-button:hover,
.details-button:hover,
.close-details-button:hover {
    border-color: var(--primary-color, #2563eb);
}

@media (max-width: 1100px) {
    .material-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }
}

@media (max-width: 900px) {
    .materials-filters {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .search-field {
        grid-column: 1 / -1;
    }
}

@media (max-width: 640px) {
    .materials-page {
        padding: 1rem;
    }

    .materials-header {
        flex-direction: column;
    }

    .refresh-button {
        width: 100%;
    }

    .materials-filters,
    .material-grid,
    .material-details-grid {
        grid-template-columns: 1fr;
    }

    .search-field {
        grid-column: auto;
    }

    .material-details-header {
        align-items: flex-start;
    }

    .close-details-button {
        flex-shrink: 0;
    }
}
</style>
