<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import FullCalendar from "@fullcalendar/vue3";
import dayGridPlugin from "@fullcalendar/vue3/daygrid";
import timeGridPlugin from "@fullcalendar/vue3/timegrid";
import listPlugin from "@fullcalendar/vue3/list";

import "@fullcalendar/vue3/skeleton.css";
import { RRule } from "rrule";

import { supabase } from "../lib/supabase";
import type { Database } from "../types/database";

type Event = Database["public"]["Tables"]["events"]["Row"];
type Course = Database["public"]["Tables"]["courses"]["Row"];
type Discipline = Database["public"]["Tables"]["disciplines"]["Row"];
type Override =
    Database["public"]["Tables"]["event_occurrence_overrides"]["Row"];

type Material = Database["public"]["Tables"]["materials"]["Row"];
type MaterialLink = Database["public"]["Tables"]["material_links"]["Row"];
type MaterialVersion = Database["public"]["Tables"]["material_versions"]["Row"];

type EventType =
    | "class"
    | "practical"
    | "tutorial"
    | "lab"
    | "extra_class"
    | "examination"
    | "general";

interface CalendarEventProps {
    sourceEventId: string;
    originalStart: string;
    eventType: EventType;
    status: Event["status"];
    description: string | null;
    location: string | null;
    courseId: string | null;
    courseName: string | null;
    disciplineId: string | null;
    disciplineName: string | null;
    allDay: boolean;
    isRecurring: boolean;
    isModified: boolean;
    courseCode: string | null;
}

interface SelectedCalendarEvent {
    id: string;
    title: string;
    start: Date | null;
    end: Date | null;
    props: CalendarEventProps;
}

const TIME_ZONE = "America/Jamaica";

const events = ref<Event[]>([]);
const courses = ref<Course[]>([]);
const disciplines = ref<Discipline[]>([]);
const overrides = ref<Override[]>([]);

const loading = ref(true);
const errorMessage = ref("");

const searchQuery = ref("");
const selectedCourseId = ref("");
const selectedDisciplineId = ref("");
const selectedEventType = ref<EventType | "all">("all");
const showCancelled = ref(true);

const selectedEvent = ref<SelectedCalendarEvent | null>(null);

const rangeStart = ref(new Date(Date.now() - 45 * 24 * 60 * 60 * 1000));
const rangeEnd = ref(new Date(Date.now() + 90 * 24 * 60 * 60 * 1000));

const materialLinks = ref<MaterialLink[]>([]);
const materials = ref<Material[]>([]);
const materialVersions = ref<MaterialVersion[]>([]);

const eventTypeLabels: Record<EventType, string> = {
    class: "Class",
    practical: "Practical",
    tutorial: "Tutorial",
    lab: "Laboratory",
    extra_class: "Extra class",
    examination: "Examination",
    general: "General event",
};

const relationshipLabels: Record<MaterialLink["relationship_type"], string> = {
    lecture_resource: "Lecture resources",
    required_reading: "Required reading",
    recommended_reading: "Recommended reading",
    supplementary: "Supplementary resources",
    reference: "References",
    course_resource: "Course resources",
    assignment_resource: "Assignment resources",
};

const materialTypeLabels: Record<Material["material_type"], string> = {
    lecture_slides: "Lecture slides",
    lecture_notes: "Lecture notes",
    recommended_reading: "Recommended reading",
    textbook_chapter: "Textbook chapter",
    practical_material: "Practical material",
    supplementary: "Supplementary material",
    past_exam: "Past examination",
    other: "Other",
};

const eventTypeColors: Record<EventType, string> = {
    class: "#2563eb",
    practical: "#0891b2",
    tutorial: "#7c3aed",
    lab: "#0d9488",
    extra_class: "#d97706",
    examination: "#dc2626",
    general: "#64748b",
};

const availableDisciplines = computed(() => {
    if (!selectedCourseId.value) {
        return disciplines.value;
    }

    return disciplines.value.filter(
        (discipline) => discipline.course_id === selectedCourseId.value,
    );
});

watch(selectedCourseId, () => {
    selectedDisciplineId.value = "";
});

const courseMap = computed(
    () => new Map(courses.value.map((course) => [course.id, course])),
);

const disciplineMap = computed(
    () =>
        new Map(
            disciplines.value.map((discipline) => [discipline.id, discipline]),
        ),
);

const overridesByEvent = computed(() => {
    const map = new Map<string, Override[]>();

    for (const override of overrides.value) {
        const existing = map.get(override.event_id) ?? [];
        existing.push(override);
        map.set(override.event_id, existing);
    }

    return map;
});

function formatDate(date: Date | null): string {
    if (!date) return "Not specified";

    return new Intl.DateTimeFormat("en-JM", {
        dateStyle: "full",
        timeZone: TIME_ZONE,
    }).format(date);
}

function formatTime(date: Date | null): string {
    if (!date) return "";

    return new Intl.DateTimeFormat("en-JM", {
        timeStyle: "short",
        timeZone: TIME_ZONE,
    }).format(date);
}

const materialMap = computed(
    () => new Map(materials.value.map((material) => [material.id, material])),
);

const materialVersionMap = computed(
    () =>
        new Map(materialVersions.value.map((version) => [version.id, version])),
);

const selectedEventMaterials = computed(() => {
    if (!selectedEvent.value) return [];

    return materialLinks.value
        .filter(
            (link) =>
                link.event_id === selectedEvent.value?.props.sourceEventId,
        )
        .map((link) => {
            const material = materialMap.value.get(link.material_id);

            if (!material) return null;

            const version = material.current_version_id
                ? (materialVersionMap.value.get(material.current_version_id) ??
                  null)
                : null;

            return {
                link,
                material,
                version,
            };
        })
        .filter(
            (
                item,
            ): item is {
                link: MaterialLink;
                material: Material;
                version: MaterialVersion | null;
            } => item !== null,
        );
});

function hasDifferentCalendarDates(
    start: Date | null,
    end: Date | null,
): boolean {
    if (!start || !end) return false;

    return formatDate(start) !== formatDate(end);
}

async function openMaterial(
    material: Material,
    version: MaterialVersion | null,
) {
    if (material.format === "external_link") {
        if (material.external_url) {
            window.open(material.external_url, "_blank", "noopener,noreferrer");
        }

        return;
    }

    if (material.format === "bibliographic_reference") {
        return;
    }

    if (!version) {
        errorMessage.value =
            "This material does not have an available file version.";
        return;
    }

    const { data, error } = await supabase.storage
        .from(version.storage_bucket)
        .createSignedUrl(version.storage_path, 60);

    if (error) {
        errorMessage.value = `Unable to open material: ${error.message}`;
        return;
    }

    const anchor = document.createElement("a");
    anchor.href = data.signedUrl;
    anchor.target = "_blank";
    anchor.rel = "noopener noreferrer";
    anchor.click();
}

function overlapsRange(
    start: Date,
    end: Date,
    rangeStartDate: Date,
    rangeEndDate: Date,
): boolean {
    return (
        start.getTime() < rangeEndDate.getTime() &&
        end.getTime() > rangeStartDate.getTime()
    );
}

function makeCalendarEvent(
    event: Event,
    occurrenceStart: Date,
    occurrenceEnd: Date,
    originalStart: Date,
    isModified = false,
) {
    const course = event.course_id
        ? courseMap.value.get(event.course_id)
        : null;

    const discipline = event.discipline_id
        ? disciplineMap.value.get(event.discipline_id)
        : null;

    const eventType = event.event_type as EventType;

    return {
        id: `${event.id}:${originalStart.getTime()}`,
        title: event.title,
        start: occurrenceStart,
        end: occurrenceEnd,
        allDay: event.all_day,
        backgroundColor: eventTypeColors[eventType],
        borderColor: eventTypeColors[eventType],
        textColor: "#ffffff",
        classNames:
            event.status === "cancelled" ? ["calendar-event-cancelled"] : [],
        extendedProps: {
            sourceEventId: event.id,
            originalStart: originalStart.toISOString(),
            eventType,
            status: event.status,
            description: event.description,
            location: event.location,
            courseId: event.course_id,
            courseName: course?.name ?? null,
            disciplineId: event.discipline_id,
            disciplineName: discipline?.name ?? null,
            allDay: event.all_day,
            isRecurring: Boolean(event.recurrence_rule),
            isModified,
            courseCode: course?.code ?? null,
        } satisfies CalendarEventProps,
    };
}

function generateCalendarEvents(): ReturnType<typeof makeCalendarEvent>[] {
    const result: ReturnType<typeof makeCalendarEvent>[] = [];

    const processedOverrideIds = new Set<string>();

    for (const event of events.value) {
        const start = new Date(event.starts_at);
        const end = new Date(event.ends_at);

        const duration = end.getTime() - start.getTime();

        const eventOverrides = overridesByEvent.value.get(event.id) ?? [];

        const overrideMap = new Map(
            eventOverrides.map((override) => [
                new Date(override.original_start).getTime(),
                override,
            ]),
        );

        const addOccurrence = (occurrenceStart: Date, originalStart: Date) => {
            const originalTimestamp = originalStart.getTime();
            const override = overrideMap.get(originalTimestamp);

            if (override?.status === "cancelled") {
                if (
                    !overlapsRange(
                        occurrenceStart,
                        new Date(occurrenceStart.getTime() + duration),
                        rangeStart.value,
                        rangeEnd.value,
                    )
                ) {
                    return;
                }

                processedOverrideIds.add(override.id);
                return;
            }

            let actualStart = occurrenceStart;
            let actualEnd = new Date(occurrenceStart.getTime() + duration);
            let modified = false;

            if (override?.status === "modified") {
                if (!override.starts_at || !override.ends_at) return;

                actualStart = new Date(override.starts_at);
                actualEnd = new Date(override.ends_at);
                modified = true;

                processedOverrideIds.add(override.id);
            }

            if (
                !overlapsRange(
                    actualStart,
                    actualEnd,
                    rangeStart.value,
                    rangeEnd.value,
                )
            ) {
                return;
            }

            result.push(
                makeCalendarEvent(
                    event,
                    actualStart,
                    actualEnd,
                    originalStart,
                    modified,
                ),
            );
        };

        if (!event.recurrence_rule) {
            addOccurrence(start, start);
            continue;
        }

        try {
            const parsedRule = RRule.parseString(event.recurrence_rule);

            const rule = new RRule({
                ...parsedRule,
                dtstart: start,
            });

            // Include occurrences beginning before the visible range
            // when their duration overlaps its first day.
            const expansionStart = new Date(
                rangeStart.value.getTime() - duration,
            );

            const occurrences = rule.between(
                expansionStart,
                rangeEnd.value,
                true,
            );

            for (const occurrence of occurrences) {
                addOccurrence(occurrence, occurrence);
            }
        } catch (error) {
            console.error(
                `Could not expand recurrence for event ${event.id}:`,
                error,
            );

            // Keep the original event visible if its recurrence rule
            // cannot be parsed.
            addOccurrence(start, start);
        }

        // A rescheduled occurrence can be moved into the visible
        // range from an original date outside the expansion range.
        for (const override of eventOverrides) {
            if (
                override.status !== "modified" ||
                processedOverrideIds.has(override.id) ||
                !override.starts_at ||
                !override.ends_at
            ) {
                continue;
            }

            const modifiedStart = new Date(override.starts_at);
            const modifiedEnd = new Date(override.ends_at);

            if (
                !overlapsRange(
                    modifiedStart,
                    modifiedEnd,
                    rangeStart.value,
                    rangeEnd.value,
                )
            ) {
                continue;
            }

            result.push(
                makeCalendarEvent(
                    event,
                    modifiedStart,
                    modifiedEnd,
                    new Date(override.original_start),
                    true,
                ),
            );

            processedOverrideIds.add(override.id);
        }
    }

    return result;
}

const calendarEvents = computed(() => {
    return generateCalendarEvents().filter((event) => {
        const props = event.extendedProps as CalendarEventProps;

        if (!showCancelled.value && props.status === "cancelled") {
            return false;
        }

        if (
            selectedCourseId.value &&
            props.courseId !== selectedCourseId.value
        ) {
            return false;
        }

        if (
            selectedDisciplineId.value &&
            props.disciplineId !== selectedDisciplineId.value
        ) {
            return false;
        }

        if (
            selectedEventType.value !== "all" &&
            props.eventType !== selectedEventType.value
        ) {
            return false;
        }

        const query = searchQuery.value.trim().toLowerCase();

        if (query) {
            const searchableText = [
                event.title,
                props.description,
                props.location,
                props.courseName,
                props.disciplineName,
                eventTypeLabels[props.eventType],
            ]
                .filter(Boolean)
                .join(" ")
                .toLowerCase();

            if (!searchableText.includes(query)) {
                return false;
            }
        }

        return true;
    });
});

function handleDatesSet(info: { start: Date; end: Date }) {
    rangeStart.value = info.start;
    rangeEnd.value = info.end;
}

function handleEventClick(info: {
    event: {
        id: string;
        title: string;
        start: Date | null;
        end: Date | null;
        extendedProps: Record<string, unknown>;
    };
}) {
    const props = info.event.extendedProps as unknown as CalendarEventProps;

    selectedEvent.value = {
        id: info.event.id,
        title: info.event.title,
        start: info.event.start,
        end: info.event.end,
        props,
    };
}

const calendarOptions = computed(() => ({
    plugins: [dayGridPlugin, timeGridPlugin, listPlugin],
    initialView: "dayGridMonth",
    timeZone: TIME_ZONE,
    firstDay: 1,
    height: "auto",
    expandRows: true,
    nowIndicator: true,
    weekends: true,
    editable: false,
    selectable: false,
    dayMaxEvents: 4,
    eventDisplay: "block",
    events: calendarEvents.value,
    datesSet: handleDatesSet,
    eventClick: handleEventClick,
    eventTimeFormat: {
        hour: "numeric",
        minute: "2-digit",
        meridiem: true,
    } as const,
    headerToolbar: {
        left: "prev,next today",
        center: "title",
        right: "dayGridMonth,timeGridWeek,timeGridDay,listWeek",
    },
    buttonText: {
        today: "Today",
        month: "Month",
        week: "Week",
        day: "Day",
        list: "Agenda",
    },
}));

async function loadCalendarData() {
    loading.value = true;
    errorMessage.value = "";

    try {
        const [eventResult, courseResult, disciplineResult] = await Promise.all(
            [
                supabase.from("events").select("*").order("starts_at"),
                supabase.from("courses").select("*").order("sort_order"),
                supabase.from("disciplines").select("*").order("sort_order"),
            ],
        );

        if (eventResult.error) throw eventResult.error;
        if (courseResult.error) throw courseResult.error;
        if (disciplineResult.error) throw disciplineResult.error;

        events.value = eventResult.data ?? [];
        courses.value = courseResult.data ?? [];
        disciplines.value = disciplineResult.data ?? [];

        const eventIds = events.value.map((event) => event.id);

        
        if (eventIds.length === 0) {
            overrides.value = [];
            materialLinks.value = [];
            materials.value = [];
            materialVersions.value = [];
        } else {
            const [overrideResult, linkResult] = await Promise.all([
                supabase
                    .from("event_occurrence_overrides")
                    .select("*")
                    .in("event_id", eventIds),
        
                supabase.from("material_links").select("*").in("event_id", eventIds),
            ]);
        
            if (overrideResult.error) throw overrideResult.error;
            if (linkResult.error) throw linkResult.error;
        
            overrides.value = overrideResult.data ?? [];
            materialLinks.value = linkResult.data ?? [];
        
            const materialIds = [
                ...new Set(materialLinks.value.map((link) => link.material_id)),
            ];
        
            if (materialIds.length === 0) {
                materials.value = [];
                materialVersions.value = [];
            } else {
                const { data: materialData, error: materialError } = await supabase
                    .from("materials")
                    .select("*")
                    .in("id", materialIds)
                    .eq("is_published", true);
        
                if (materialError) throw materialError;
        
                materials.value = materialData ?? [];
        
                const versionIds = [
                    ...new Set(
                        materials.value
                            .map((material) => material.current_version_id)
                            .filter((id): id is string => id !== null),
                    ),
                ];
        
                if (versionIds.length === 0) {
                    materialVersions.value = [];
                } else {
                    const { data: versionData, error: versionError } = await supabase
                        .from("material_versions")
                        .select("*")
                        .in("id", versionIds);
        
                    if (versionError) throw versionError;
        
                    materialVersions.value = versionData ?? [];
                }
            }
        }

    } catch (error) {
        errorMessage.value =
            error instanceof Error
                ? error.message
                : "Failed to load the calendar.";
    } finally {
        loading.value = false;
    }
}

function clearFilters() {
    searchQuery.value = "";
    selectedCourseId.value = "";
    selectedDisciplineId.value = "";
    selectedEventType.value = "all";
    showCancelled.value = true;
}

onMounted(loadCalendarData);
</script>

<template>
    <main class="calendar-page">
        <header class="calendar-header">
            <div>
                <p class="eyebrow">Academic schedule</p>
                <h1>Calendar</h1>
                <p class="calendar-description">
                    View classes, practicals, tutorials, examinations, and other
                    academic events.
                </p>
            </div>

            <button
                type="button"
                class="refresh-button"
                :disabled="loading"
                @click="loadCalendarData"
            >
                {{ loading ? "Loading..." : "Refresh calendar" }}
            </button>
        </header>

        <div v-if="errorMessage" class="calendar-error">
            {{ errorMessage }}
        </div>

        <section class="calendar-filters">
            <div class="filter-field search-field">
                <label for="calendar-search">Search</label>
                <input
                    id="calendar-search"
                    v-model="searchQuery"
                    type="search"
                    placeholder="Search events, locations, courses..."
                />
            </div>

            <div class="filter-field">
                <label for="calendar-course">Course</label>
                <select id="calendar-course" v-model="selectedCourseId">
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
                <label for="calendar-discipline">Discipline</label>
                <select id="calendar-discipline" v-model="selectedDisciplineId">
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
                <label for="calendar-type">Event type</label>
                <select id="calendar-type" v-model="selectedEventType">
                    <option value="all">All event types</option>
                    <option
                        v-for="(label, value) in eventTypeLabels"
                        :key="value"
                        :value="value"
                    >
                        {{ label }}
                    </option>
                </select>
            </div>

            <label class="cancelled-filter">
                <input v-model="showCancelled" type="checkbox" />
                Show cancelled events
            </label>

            <button
                type="button"
                class="clear-filters-button"
                @click="clearFilters"
            >
                Clear filters
            </button>
        </section>

        <section class="calendar-legend">
            <span
                v-for="(label, type) in eventTypeLabels"
                :key="type"
                class="legend-item"
            >
                <span
                    class="legend-dot"
                    :style="{
                        backgroundColor: eventTypeColors[type as EventType],
                    }"
                />
                {{ label }}
            </span>
        </section>

        <section class="calendar-panel">
            <div v-if="loading" class="calendar-loading">
                Loading academic schedule...
            </div>

            <FullCalendar v-else :options="calendarOptions" />
        </section>

        <section v-if="selectedEvent" class="event-details">
            <div class="event-details-header">
                <div>
                    <p class="eyebrow">Event details</p>
                    <h2>{{ selectedEvent.title }}</h2>
                    <p v-if="selectedEvent.props.isRecurring">
                        Details for this occurrence of a recurring event.
                    </p>
                    <p v-else>Event information</p>
                </div>

                <button
                    type="button"
                    class="close-details-button"
                    aria-label="Close event details"
                    @click="selectedEvent = null"
                >
                    Close
                </button>
            </div>

            <div class="event-details-meta">
                <span
                    class="event-type-tag"
                    :style="{
                        backgroundColor:
                            eventTypeColors[selectedEvent.props.eventType],
                    }"
                >
                    {{ eventTypeLabels[selectedEvent.props.eventType] }}
                </span>

                <span
                    v-if="selectedEvent.props.status === 'cancelled'"
                    class="cancelled-tag"
                >
                    Cancelled
                </span>

                <span
                    v-if="selectedEvent.props.isRecurring"
                    class="recurring-tag"
                >
                    Recurring event
                </span>

                <span
                    v-if="selectedEvent.props.isModified"
                    class="modified-tag"
                >
                    Rescheduled occurrence
                </span>
            </div>

            <dl class="event-details-grid">
                <div>
                    <dt>Date</dt>
                    <dd>
                        {{ formatDate(selectedEvent.start) }}

                        <template
                            v-if="
                                hasDifferentCalendarDates(
                                    selectedEvent.start,
                                    selectedEvent.end,
                                )
                            "
                        >
                            – {{ formatDate(selectedEvent.end) }}
                        </template>
                    </dd>
                </div>

                <div>
                    <dt>Time</dt>
                    <dd>
                        <template v-if="selectedEvent.props.allDay">
                            All day
                        </template>
                        <template v-else>
                            {{ formatTime(selectedEvent.start) }}
                            <span v-if="selectedEvent.end">
                                – {{ formatTime(selectedEvent.end) }}
                            </span>
                        </template>
                    </dd>
                </div>

                <div v-if="selectedEvent.props.courseName">
                    <dt>Course</dt>
                    <dd>
                        <template v-if="selectedEvent.props.courseCode">
                            {{ selectedEvent.props.courseCode }} ·
                        </template>
                        {{ selectedEvent.props.courseName }}
                    </dd>
                </div>

                <div v-if="selectedEvent.props.disciplineName">
                    <dt>Discipline</dt>
                    <dd>{{ selectedEvent.props.disciplineName }}</dd>
                </div>

                <div v-if="selectedEvent.props.location">
                    <dt>Location</dt>
                    <dd>{{ selectedEvent.props.location }}</dd>
                </div>

                <div>
                    <dt>Timezone</dt>
                    <dd>Jamaica Standard Time (UTC−5)</dd>
                </div>
            </dl>

            <div
                v-if="selectedEvent.props.description"
                class="event-description"
            >
                <h3>Description</h3>
                <p>{{ selectedEvent.props.description }}</p>
            </div>
        </section>

        <section class="event-materials">
            <div class="event-materials-header">
                <h3>Related materials</h3>
                <span>{{ selectedEventMaterials.length }} resources</span>
            </div>

            <p v-if="selectedEventMaterials.length === 0" class="no-materials">
                No published materials are currently linked to this event.
            </p>

            <div
                v-for="[relationship, label] in Object.entries(
                    relationshipLabels,
                )"
                :key="relationship"
                v-show="
                    selectedEventMaterials.some(
                        (item) => item.link.relationship_type === relationship,
                    )
                "
                class="material-group"
            >
                <h4>{{ label }}</h4>

                <article
                    v-for="item in selectedEventMaterials.filter(
                        (entry) =>
                            entry.link.relationship_type === relationship,
                    )"
                    :key="item.material.id"
                    class="material-item"
                >
                    <div class="material-item-content">
                        <h5>{{ item.material.title }}</h5>

                        <div class="material-tags">
                            <span class="material-type-tag">
                                {{
                                    materialTypeLabels[
                                        item.material.material_type
                                    ]
                                }}
                            </span>

                            <span
                                v-if="item.version"
                                class="material-status-tag"
                            >
                                {{ item.version.verification_status }}
                            </span>
                        </div>

                        <p
                            v-if="item.material.description"
                            class="material-description"
                        >
                            {{ item.material.description }}
                        </p>

                        <p
                            v-if="
                                item.material.format === 'uploaded_file' &&
                                item.version
                            "
                            class="material-filename"
                        >
                            {{ item.version.original_filename }}
                        </p>

                        <div
                            v-if="
                                item.material.format ===
                                'bibliographic_reference'
                            "
                            class="bibliographic-details"
                        >
                            <p v-if="item.material.author">
                                {{ item.material.author }}
                            </p>

                            <p v-if="item.material.publication_title">
                                <em>{{ item.material.publication_title }}</em>
                            </p>

                            <p v-if="item.material.chapter_title">
                                Chapter: {{ item.material.chapter_title }}
                            </p>

                            <p v-if="item.material.edition">
                                Edition: {{ item.material.edition }}
                            </p>

                            <p v-if="item.material.page_range">
                                Pages: {{ item.material.page_range }}
                            </p>

                            <p v-if="item.material.publisher">
                                {{ item.material.publisher }}
                                <span v-if="item.material.publication_year">
                                    ({{ item.material.publication_year }})
                                </span>
                            </p>

                            <p v-if="item.material.isbn">
                                ISBN: {{ item.material.isbn }}
                            </p>
                        </div>
                    </div>

                    <button
                        v-if="
                            item.material.format !== 'bibliographic_reference'
                        "
                        type="button"
                        class="material-open-button"
                        @click="openMaterial(item.material, item.version)"
                    >
                        {{
                            item.material.format === "external_link"
                                ? "Open link"
                                : "Open file"
                        }}
                    </button>
                </article>
            </div>
        </section>

        <p class="calendar-timezone-note">
            Calendar times are displayed in Jamaica Standard Time.
        </p>
    </main>
</template>

<style scoped>
.calendar-page {
    max-width: 1440px;
    margin: 0 auto;
    padding: 2rem;
}

.calendar-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1.5rem;
    margin-bottom: 1.75rem;
}

.calendar-header h1 {
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

.calendar-description {
    color: var(--text-secondary, #64748b);
    margin: 0.5rem 0 0;
}

.refresh-button,
.clear-filters-button,
.close-details-button {
    padding: 0.65rem 1rem;
    border: 1px solid var(--border-color, #d1d5db);
    border-radius: 0.5rem;
    background: var(--surface, #fff);
    color: inherit;
    cursor: pointer;
}

.refresh-button:disabled {
    opacity: 0.6;
    cursor: wait;
}

.calendar-error {
    padding: 1rem;
    margin-bottom: 1rem;
    border: 1px solid #fecaca;
    border-radius: 0.5rem;
    background: #fef2f2;
    color: #991b1b;
}

.calendar-filters {
    display: grid;
    grid-template-columns: minmax(180px, 2fr) repeat(3, minmax(140px, 1fr));
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

.cancelled-filter {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.85rem;
}

.clear-filters-button {
    justify-self: start;
}

.calendar-legend {
    display: flex;
    flex-wrap: wrap;
    gap: 0.8rem 1.25rem;
    margin: 1rem 0;
}

.legend-item {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.8rem;
    color: var(--text-secondary, #64748b);
}

.legend-dot {
    width: 0.65rem;
    height: 0.65rem;
    border-radius: 50%;
}

.calendar-panel {
    min-height: 400px;
    padding: 1.25rem;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.75rem;
    background: var(--surface, #fff);
}

.calendar-loading {
    display: grid;
    min-height: 350px;
    place-items: center;
    color: var(--text-secondary, #64748b);
}

.event-details {
    padding: 1.5rem;
    margin-top: 1.5rem;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.75rem;
    background: var(--surface, #fff);
}

.event-details-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
}

.event-details-header h2 {
    margin: 0.35rem 0 0;
}

.event-details-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin: 1rem 0;
}

.event-type-tag,
.cancelled-tag,
.recurring-tag,
.modified-tag {
    display: inline-block;
    padding: 0.3rem 0.65rem;
    border-radius: 999px;
    color: white;
    font-size: 0.75rem;
    font-weight: 600;
}

.cancelled-tag {
    background: #b91c1c;
}

.recurring-tag {
    background: #475569;
}

.modified-tag {
    background: #0369a1;
}

.event-details-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1rem;
    margin: 1.25rem 0;
}

.event-details-grid dt {
    margin-bottom: 0.3rem;
    color: var(--text-secondary, #64748b);
    font-size: 0.8rem;
    font-weight: 600;
}

.event-details-grid dd {
    margin: 0;
}

.event-description {
    padding-top: 1rem;
    border-top: 1px solid var(--border-color, #e2e8f0);
}

.event-description h3 {
    margin-top: 0;
    font-size: 1rem;
}

.event-description p {
    white-space: pre-wrap;
}

.calendar-timezone-note {
    margin-top: 1rem;
    color: var(--text-secondary, #64748b);
    font-size: 0.8rem;
    text-align: right;
}

:deep(.fc) {
    --fc-border-color: var(--border-color, #e2e8f0);
    --fc-page-bg-color: var(--surface, #fff);
    --fc-neutral-bg-color: var(--surface-secondary, #f8fafc);
    --fc-today-bg-color: rgba(37, 99, 235, 0.07);
    color: var(--text-primary, inherit);
}

:deep(.fc .fc-button-primary) {
    border-color: var(--primary-color, #2563eb);
    background: var(--primary-color, #2563eb);
}

:deep(.fc .fc-button-primary:hover) {
    border-color: var(--primary-hover, #1d4ed8);
    background: var(--primary-hover, #1d4ed8);
}

:deep(.fc .fc-button-primary:disabled) {
    opacity: 0.55;
}

:deep(.fc .fc-toolbar-title) {
    font-size: 1.25rem;
}

:deep(.fc .fc-event) {
    cursor: pointer;
    border-radius: 0.25rem;
    padding: 1px 2px;
}

:deep(.fc .calendar-event-cancelled) {
    opacity: 0.65;
    text-decoration: line-through;
}

@media (max-width: 900px) {
    .calendar-filters {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .search-field {
        grid-column: 1 / -1;
    }
}

@media (max-width: 640px) {
    .calendar-page {
        padding: 1rem;
    }

    .calendar-header {
        flex-direction: column;
    }

    .calendar-filters {
        grid-template-columns: 1fr;
    }

    .search-field {
        grid-column: auto;
    }

    .event-details-grid {
        grid-template-columns: 1fr;
    }

    :deep(.fc .fc-toolbar) {
        flex-direction: column;
        gap: 0.75rem;
    }

    :deep(.fc .fc-toolbar-chunk) {
        display: flex;
        justify-content: center;
        flex-wrap: wrap;
        gap: 0.25rem;
    }

    :deep(.fc .fc-toolbar-title) {
        font-size: 1.1rem;
    }
}

/* Consistent keyboard navigation */
.refresh-button:focus-visible,
.clear-filters-button:focus-visible,
.close-details-button:focus-visible,
.filter-field input:focus-visible,
.filter-field select:focus-visible {
    outline: 2px solid var(--primary-color, #2563eb);
    outline-offset: 2px;
}

/* Make buttons respond consistently */
.refresh-button:hover:not(:disabled),
.clear-filters-button:hover,
.close-details-button:hover {
    border-color: var(--primary-color, #2563eb);
}

/* Prevent the calendar from breaking narrow layouts */
.calendar-panel {
    min-width: 0;
    overflow-x: auto;
}

/* Improve legend visibility */
.legend-dot {
    flex-shrink: 0;
    border: 1px solid rgba(0, 0, 0, 0.12);
}

/* Better event details layout */
.event-details {
    scroll-margin-top: 1.5rem;
}

.event-details-grid dd {
    overflow-wrap: anywhere;
}

/* Make cancelled events distinguishable beyond opacity */
:deep(.fc .calendar-event-cancelled) {
    opacity: 0.65;
    text-decoration: line-through;
    filter: grayscale(0.5);
}

/* Improve mobile calendar controls */
@media (max-width: 640px) {
    .refresh-button {
        width: 100%;
    }

    .calendar-legend {
        gap: 0.65rem 1rem;
    }

    .event-details-header {
        align-items: flex-start;
    }

    .close-details-button {
        flex-shrink: 0;
    }

    :deep(.fc .fc-button) {
        padding: 0.35rem 0.55rem;
        font-size: 0.8rem;
    }
}

.event-materials {
    padding-top: 1.25rem;
    margin-top: 1.25rem;
    border-top: 1px solid var(--border-color, #e2e8f0);
}

.event-materials-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
}

.event-materials-header h3 {
    margin: 0;
    font-size: 1rem;
}

.event-materials-header > span {
    color: var(--text-secondary, #64748b);
    font-size: 0.8rem;
}

.no-materials {
    color: var(--text-secondary, #64748b);
    font-size: 0.9rem;
}

.material-group {
    margin-top: 1.25rem;
}

.material-group h4 {
    margin: 0 0 0.65rem;
    font-size: 0.9rem;
}

.material-item {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 1rem;
    padding: 1rem;
    margin-top: 0.5rem;
    border: 1px solid var(--border-color, #e2e8f0);
    border-radius: 0.5rem;
}

.material-item-content {
    min-width: 0;
}

.material-item h5 {
    margin: 0;
    font-size: 0.95rem;
}

.material-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
    margin-top: 0.5rem;
}

.material-type-tag,
.material-status-tag {
    padding: 0.2rem 0.5rem;
    border-radius: 999px;
    background: var(--surface-secondary, #f1f5f9);
    color: var(--text-secondary, #475569);
    font-size: 0.7rem;
    font-weight: 600;
}

.material-description,
.material-filename,
.bibliographic-details {
    margin: 0.6rem 0 0;
    color: var(--text-secondary, #64748b);
    font-size: 0.85rem;
}

.material-filename {
    overflow-wrap: anywhere;
}

.bibliographic-details p {
    margin: 0.25rem 0;
}

.material-open-button {
    flex-shrink: 0;
    padding: 0.55rem 0.8rem;
    border: 1px solid var(--border-color, #cbd5e1);
    border-radius: 0.4rem;
    background: var(--surface, #fff);
    color: inherit;
    cursor: pointer;
}

.material-open-button:hover {
    border-color: var(--primary-color, #2563eb);
}

.material-open-button:focus-visible {
    outline: 2px solid var(--primary-color, #2563eb);
    outline-offset: 2px;
}

@media (max-width: 640px) {
    .material-item {
        flex-direction: column;
    }

    .material-open-button {
        width: 100%;
    }
}
</style>
