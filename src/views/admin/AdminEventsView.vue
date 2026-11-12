<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { RouterLink } from "vue-router";
import { supabase } from "../../lib/supabase";
import type { Database } from "../../types/database";

type Event = Database["public"]["Tables"]["events"]["Row"];
type Course = Database["public"]["Tables"]["courses"]["Row"];
type Discipline = Database["public"]["Tables"]["disciplines"]["Row"];

type EventType =
    | "class"
    | "practical"
    | "tutorial"
    | "lab"
    | "extra_class"
    | "examination"
    | "general";

const TIME_ZONE = "America/Jamaica";

type RecurrenceFrequency = "none" | "daily" | "weekly" | "biweekly" | "monthly";
type RecurrenceEndMode = "never" | "date";

const recurrenceFrequency = ref<RecurrenceFrequency>("none");
const recurrenceDays = ref<number[]>([]);
const recurrenceEndMode = ref<RecurrenceEndMode>("never");
const recurrenceEndDate = ref("");

const weekdays = [
    { label: "Sunday", short: "SU", value: 0 },
    { label: "Monday", short: "MO", value: 1 },
    { label: "Tuesday", short: "TU", value: 2 },
    { label: "Wednesday", short: "WE", value: 3 },
    { label: "Thursday", short: "TH", value: 4 },
    { label: "Friday", short: "FR", value: 5 },
    { label: "Saturday", short: "SA", value: 6 },
];

const weekdayByCode = Object.fromEntries(
    weekdays.map((day) => [day.short, day.value]),
) as Record<string, number>;

const weekdayByValue = Object.fromEntries(
    weekdays.map((day) => [day.value, day.short]),
) as Record<number, string>;

const eventTypes: { value: EventType; label: string }[] = [
    { value: "class", label: "Class" },
    { value: "tutorial", label: "Tutorial" },
    { value: "lab", label: "Lab" },
    { value: "practical", label: "Practical" },
    { value: "extra_class", label: "Extra class" },
    { value: "examination", label: "Examination" },
    { value: "general", label: "General event" },
];

const dateTimeFormatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
});

const dateFormatter = new Intl.DateTimeFormat("en-JM", {
    timeZone: TIME_ZONE,
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
});

const timeFormatter = new Intl.DateTimeFormat("en-JM", {
    timeZone: TIME_ZONE,
    hour: "numeric",
    minute: "2-digit",
});

function getWeekdayFromDate(dateTime: string): number {
    const date = dateTime.slice(0, 10);
    return new Date(`${date}T12:00:00Z`).getUTCDay();
}

function setDefaultRecurrenceDay() {
    if (
        recurrenceFrequency.value === "weekly" &&
        recurrenceDays.value.length === 0 &&
        startsAt.value
    ) {
        recurrenceDays.value = [getWeekdayFromDate(startsAt.value)];
    }
}

function buildRecurrenceRule(): string | null {
    const frequency = recurrenceFrequency.value;

    if (frequency === "none") {
        return null;
    }

    const parts: string[] = [];

    switch (frequency) {
        case "daily":
            parts.push("FREQ=DAILY");
            break;

        case "weekly":
            parts.push("FREQ=WEEKLY");
            break;

        case "biweekly":
            parts.push("FREQ=WEEKLY", "INTERVAL=2");
            break;

        case "monthly":
            parts.push("FREQ=MONTHLY");
            break;
    }

    if (frequency === "weekly" || frequency === "biweekly") {
        const selectedDays =
            recurrenceDays.value.length > 0
                ? recurrenceDays.value
                : [getWeekdayFromDate(startsAt.value)];

        const byDay = selectedDays
            .slice()
            .sort((a, b) => a - b)
            .map((day) => weekdayByValue[day])
            .join(",");

        parts.push(`BYDAY=${byDay}`);
    }

    if (recurrenceEndMode.value === "date" && recurrenceEndDate.value) {
        const untilIso = fromDateTimeInput(`${recurrenceEndDate.value}T23:59`);

        const until = new Date(untilIso)
            .toISOString()
            .replace(/[-:]/g, "")
            .replace(/\.\d{3}/, "");

        parts.push(`UNTIL=${until}`);
    }

    return parts.join(";");
}

function loadRecurrenceRule(rule: string | null) {
    recurrenceFrequency.value = "none";
    recurrenceDays.value = [];
    recurrenceEndMode.value = "never";
    recurrenceEndDate.value = "";

    if (!rule) {
        return;
    }

    const values = Object.fromEntries(
        rule.split(";").map((part) => {
            const separator = part.indexOf("=");

            return [
                part.slice(0, separator).toUpperCase(),
                part.slice(separator + 1),
            ];
        }),
    );

    const frequency = values.FREQ?.toUpperCase();
    const interval = Number(values.INTERVAL ?? 1);

    if (frequency === "DAILY") {
        recurrenceFrequency.value = "daily";
    } else if (frequency === "WEEKLY" && interval === 2) {
        recurrenceFrequency.value = "biweekly";
    } else if (frequency === "WEEKLY") {
        recurrenceFrequency.value = "weekly";
    } else if (frequency === "MONTHLY") {
        recurrenceFrequency.value = "monthly";
    }

    if (values.BYDAY) {
        recurrenceDays.value = values.BYDAY.split(",")
            .map((code) => weekdayByCode[code.toUpperCase()])
            .filter((day) => day !== undefined);
    } else if (
        (recurrenceFrequency.value === "weekly" ||
            recurrenceFrequency.value === "biweekly") &&
        startsAt.value
    ) {
        recurrenceDays.value = [getWeekdayFromDate(startsAt.value)];
    }

    if (values.UNTIL) {
      const until = values.UNTIL
    
      let untilDate: Date
    
      const dateOnlyMatch = /^(\d{4})(\d{2})(\d{2})$/.exec(until)
      const dateTimeMatch =
        /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z?$/.exec(until)
    
      if (dateOnlyMatch) {
        const [, year, month, day] = dateOnlyMatch
    
        untilDate = new Date(
          `${year}-${month}-${day}T12:00:00Z`,
        )
      } else if (dateTimeMatch) {
        const [, year, month, day, hour, minute, second] =
          dateTimeMatch
    
        untilDate = new Date(
          `${year}-${month}-${day}T${hour}:${minute}:${second}Z`,
        )
      } else {
        untilDate = new Date(until)
      }
    
      if (!Number.isNaN(untilDate.getTime())) {
        recurrenceEndMode.value = 'date'
        recurrenceEndDate.value = toDateTimeInput(
          untilDate.toISOString(),
        ).slice(0, 10)
      }
    }
}

function getZonedParts(date: Date) {
    const parts = dateTimeFormatter.formatToParts(date);
    const result: Record<string, string> = {};

    for (const part of parts) {
        if (part.type !== "literal") result[part.type] = part.value;
    }

    return result;
}

function toDateTimeInput(isoString: string) {
    const parts = getZonedParts(new Date(isoString));

    return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
}

function fromDateTimeInput(value: string) {
    const [datePart, timePart] = value.split("T");
    const [year, month, day] = datePart.split("-").map(Number);
    const [hour, minute] = timePart.split(":").map(Number);

    const intendedUtc = Date.UTC(year, month - 1, day, hour, minute);
    let timestamp = intendedUtc;

    // Iteratively account for the target timezone's UTC offset.
    for (let i = 0; i < 2; i++) {
        const parts = getZonedParts(new Date(timestamp));

        const representedUtc = Date.UTC(
            Number(parts.year),
            Number(parts.month) - 1,
            Number(parts.day),
            Number(parts.hour),
            Number(parts.minute),
        );

        timestamp = intendedUtc - (representedUtc - timestamp);
    }

    return new Date(timestamp).toISOString();
}

function formatEventDate(isoString: string) {
    return dateFormatter.format(new Date(isoString));
}

function formatEventTime(isoString: string) {
    return timeFormatter.format(new Date(isoString));
}

function eventTypeLabel(type: EventType) {
    return eventTypes.find((item) => item.value === type)?.label ?? type;
}

const events = ref<Event[]>([]);
const courses = ref<Course[]>([]);
const disciplines = ref<Discipline[]>([]);

const loading = ref(true);
const saving = ref(false);
const errorMessage = ref("");
const successMessage = ref("");

const searchQuery = ref("");
const statusFilter = ref<"all" | "scheduled" | "cancelled">("all");

const formOpen = ref(false);
const editingEventId = ref<string | null>(null);

const title = ref("");
const description = ref("");
const eventType = ref<EventType>("class");
const courseId = ref("");
const disciplineId = ref("");
const startsAt = ref("");
const endsAt = ref("");
const allDay = ref(false);
const location = ref("");

const selectedDisciplines = computed(() =>
    disciplines.value
        .filter((discipline) => discipline.course_id === courseId.value)
        .sort((a, b) => a.sort_order - b.sort_order),
);

const visibleEvents = computed(() => {
    const query = searchQuery.value.trim().toLowerCase();

    return events.value.filter((event) => {
        if (
            statusFilter.value !== "all" &&
            event.status !== statusFilter.value
        ) {
            return false;
        }

        if (!query) return true;

        const course = courses.value.find(
            (item) => item.id === event.course_id,
        );
        const discipline = disciplines.value.find(
            (item) => item.id === event.discipline_id,
        );

        return [
            event.title,
            event.description ?? "",
            event.location ?? "",
            eventTypeLabel(event.event_type),
            course?.code ?? "",
            course?.name ?? "",
            discipline?.code ?? "",
            discipline?.name ?? "",
        ].some((value) => value.toLowerCase().includes(query));
    });
});

function courseName(id: string | null) {
    return courses.value.find((course) => course.id === id)?.name ?? "";
}

function courseCode(id: string | null) {
    return courses.value.find((course) => course.id === id)?.code ?? "";
}

function disciplineName(id: string | null) {
    return disciplines.value.find((item) => item.id === id)?.name ?? "";
}

async function loadData() {
    loading.value = true;
    errorMessage.value = "";

    try {
        const [eventResult, courseResult, disciplineResult] = await Promise.all(
            [
                supabase
                    .from("events")
                    .select("*")
                    .order("starts_at", { ascending: true }),

                supabase
                    .from("courses")
                    .select("*")
                    .order("sort_order")
                    .order("code"),

                supabase
                    .from("disciplines")
                    .select("*")
                    .order("sort_order")
                    .order("name"),
            ],
        );

        if (eventResult.error) throw eventResult.error;
        if (courseResult.error) throw courseResult.error;
        if (disciplineResult.error) throw disciplineResult.error;

        events.value = eventResult.data;
        courses.value = courseResult.data;
        disciplines.value = disciplineResult.data;
    } catch (error) {
        errorMessage.value =
            error instanceof Error ? error.message : "Failed to load events.";
    } finally {
        loading.value = false;
    }
}

function resetForm() {
    editingEventId.value = null;
    title.value = "";
    description.value = "";
    eventType.value = "class";
    courseId.value = "";
    disciplineId.value = "";
    startsAt.value = "";
    endsAt.value = "";
    allDay.value = false;
    location.value = "";
    formOpen.value = false;
    recurrenceFrequency.value = "none";
    recurrenceDays.value = [];
    recurrenceEndMode.value = "never";
    recurrenceEndDate.value = "";
}

function openCreateForm() {
    resetForm();
    formOpen.value = true;
    setDefaultRecurrenceDay();
}

function openEditForm(event: Event) {
    editingEventId.value = event.id;
    title.value = event.title;
    description.value = event.description ?? "";
    eventType.value = event.event_type;
    courseId.value = event.course_id ?? "";
    disciplineId.value = event.discipline_id ?? "";
    startsAt.value = toDateTimeInput(event.starts_at);
    endsAt.value = toDateTimeInput(event.ends_at);
    allDay.value = event.all_day;
    location.value = event.location ?? "";
    formOpen.value = true;
    errorMessage.value = "";
    successMessage.value = "";
    loadRecurrenceRule(event.recurrence_rule);
}


async function saveEvent() {
    if (saving.value) return;

    errorMessage.value = "";
    successMessage.value = "";

    const cleanTitle = title.value.trim();

    if (!cleanTitle) {
        errorMessage.value = "Enter an event title.";
        return;
    }

    if (!startsAt.value || !endsAt.value) {
        errorMessage.value = "Enter both a start and end date/time.";
        return;
    }

    if (new Date(startsAt.value) >= new Date(endsAt.value)) {
        errorMessage.value = "The event end must be after its start.";
        return;
    }

    if (disciplineId.value) {
        const selectedDiscipline = disciplines.value.find(
            (item) => item.id === disciplineId.value,
        );

        if (
            !courseId.value ||
            selectedDiscipline?.course_id !== courseId.value
        ) {
            errorMessage.value =
                "The selected discipline must belong to the selected course.";
            return;
        }
    }

    // Validate recurrence settings before saving.
    if (
        recurrenceEndMode.value === "date" &&
        recurrenceEndDate.value &&
        recurrenceEndDate.value < startsAt.value.slice(0, 10)
    ) {
        errorMessage.value =
            "The recurrence end date cannot be before the first occurrence.";
        return;
    }

    if (
        (recurrenceFrequency.value === "weekly" ||
            recurrenceFrequency.value === "biweekly") &&
        recurrenceDays.value.length === 0
    ) {
        errorMessage.value =
            "Select at least one weekday for weekly recurrence.";
        return;
    }

    if (
        recurrenceFrequency.value !== "none" &&
        recurrenceEndMode.value === "date" &&
        !recurrenceEndDate.value
    ) {
        errorMessage.value = "Select a recurrence end date.";
        return;
    }

    saving.value = true;

    try {
        const payload = {
            title: cleanTitle,
            description: description.value.trim() || null,
            event_type: eventType.value,
            course_id: courseId.value || null,
            discipline_id: disciplineId.value || null,
            starts_at: fromDateTimeInput(startsAt.value),
            ends_at: fromDateTimeInput(endsAt.value),
            all_day: allDay.value,
            location: location.value.trim() || null,
            recurrence_timezone: TIME_ZONE,
            recurrence_rule: buildRecurrenceRule(),
        };

        
        if (editingEventId.value) {
            // Retrieve the current schedule from the database.
            const { data: existingEvent, error: existingEventError } =
                await supabase
                    .from("events")
                    .select("starts_at, recurrence_rule")
                    .eq("id", editingEventId.value)
                    .single();
        
            if (existingEventError) throw existingEventError;
        
            const startChanged =
                new Date(existingEvent.starts_at).getTime() !==
                new Date(payload.starts_at).getTime();
        
            const recurrenceChanged =
                existingEvent.recurrence_rule !== payload.recurrence_rule;
        
            if (startChanged || recurrenceChanged) {
                // Check whether this series has individual occurrence exceptions.
                const { count, error: overrideError } = await supabase
                    .from("event_occurrence_overrides")
                    .select("id", { count: "exact", head: true })
                    .eq("event_id", editingEventId.value);
        
                if (overrideError) throw overrideError;
        
                if (count && count > 0) {
                    errorMessage.value =
                        "The start date, start time, or recurrence pattern cannot be changed because this event has individual occurrence exceptions. Manage or remove those exceptions first.";
        
                    return;
                }
            }
        }


        if (editingEventId.value) {
            const { error } = await supabase
                .from("events")
                .update(payload)
                .eq("id", editingEventId.value);

            if (error) throw error;

            successMessage.value = "Event updated.";
        } else {
            const { error } = await supabase
                .from("events")
                .insert(payload);

            if (error) throw error;

            successMessage.value = "Event created.";
        }

        resetForm();
        await loadData();
    } catch (error) {
        errorMessage.value =
            error instanceof Error
                ? error.message
                : "Failed to save event.";
    } finally {
        saving.value = false;
    }
}

async function toggleEventStatus(event: Event) {
    const nextStatus = event.status === "scheduled" ? "cancelled" : "scheduled";
    const action = nextStatus === "cancelled" ? "Cancel" : "Restore";

    if (!window.confirm(`${action} "${event.title}"?`)) return;

    errorMessage.value = "";
    successMessage.value = "";

    const { error } = await supabase
        .from("events")
        .update({ status: nextStatus })
        .eq("id", event.id);

    if (error) {
        errorMessage.value = error.message;
        return;
    }

    successMessage.value =
        nextStatus === "cancelled" ? "Event cancelled." : "Event restored.";

    await loadData();
}

async function deleteEvent(event: Event) {
    const isRecurring = Boolean(event.recurrence_rule);

    const warning = isRecurring
        ? `Delete the entire recurring series "${event.title}" and its occurrence overrides? This cannot be undone.`
        : `Permanently delete "${event.title}"? This cannot be undone.`;

    if (!window.confirm(warning)) return;

    errorMessage.value = "";
    successMessage.value = "";

    const { error } = await supabase.from("events").delete().eq("id", event.id);

    if (error) {
        errorMessage.value = error.message;
        return;
    }

    successMessage.value = "Event deleted.";
    await loadData();
}

onMounted(loadData);
</script>

<template>
    <main class="admin-events">
        <header class="page-header">
            <div>
                <RouterLink to="/admin" class="back-link">
                    ← Administration
                </RouterLink>
                <p class="eyebrow">ACADEMIC SCHEDULE</p>
                <h1>Events</h1>
                <p class="muted">
                    Manage classes, tutorials, practicals, examinations and
                    other events.
                </p>
            </div>

            <button
                class="primary-button"
                type="button"
                @click="openCreateForm"
            >
                Create event
            </button>
        </header>

        <p v-if="errorMessage" class="message error-message" role="alert">
            {{ errorMessage }}
        </p>

        <p v-if="successMessage" class="message success-message" role="status">
            {{ successMessage }}
        </p>

        <section v-if="formOpen" class="form-panel">
            <div class="panel-heading">
                <div>
                    <h2>{{ editingEventId ? "Edit event" : "New event" }}</h2>
                    <p class="muted">Times are interpreted in Jamaica time.</p>
                </div>

                <button class="text-button" type="button" @click="resetForm">
                    Close
                </button>
            </div>

            <form class="form-grid" @submit.prevent="saveEvent">
                <label class="full-width">
                    Event title
                    <input
                        v-model="title"
                        type="text"
                        placeholder="e.g. Upper Limb Anatomy Lecture"
                        required
                        :disabled="saving"
                    />
                </label>

                <label>
                    Event type
                    <select v-model="eventType" :disabled="saving">
                        <option
                            v-for="type in eventTypes"
                            :key="type.value"
                            :value="type.value"
                        >
                            {{ type.label }}
                        </option>
                    </select>
                </label>

                <label>
                    Course
                    <select
                        v-model="courseId"
                        :disabled="saving"
                        @change="disciplineId = ''"
                    >
                        <option value="">No course association</option>
                        <option
                            v-for="course in courses.filter(
                                (item) => item.is_active,
                            )"
                            :key="course.id"
                            :value="course.id"
                        >
                            {{ course.code }} · {{ course.name }}
                        </option>
                    </select>
                </label>

                <label>
                    Discipline
                    <select
                        v-model="disciplineId"
                        :disabled="saving || !courseId"
                    >
                        <option value="">No discipline association</option>
                        <option
                            v-for="discipline in selectedDisciplines.filter(
                                (item) => item.is_active,
                            )"
                            :key="discipline.id"
                            :value="discipline.id"
                        >
                            {{ discipline.code }} · {{ discipline.name }}
                        </option>
                    </select>
                </label>

                <div class="full-width date-fields">
                    <label>
                        Starts
                        <input
                            v-model="startsAt"
                            type="datetime-local"
                            required
                            :disabled="saving"
                        />
                    </label>

                    <label>
                        Ends
                        <input
                            v-model="endsAt"
                            type="datetime-local"
                            required
                            :disabled="saving"
                        />
                    </label>
                </div>

                <label class="checkbox-label full-width">
                    <input
                        v-model="allDay"
                        type="checkbox"
                        :disabled="saving"
                    />
                    All-day event
                </label>

                <label class="full-width">
                    Location
                    <input
                        v-model="location"
                        type="text"
                        placeholder="e.g. Lecture Theatre 2"
                        :disabled="saving"
                    />
                </label>

                <section class="recurrence-section">
                  <div class="recurrence-heading">
                    <div>
                      <h3>Recurrence</h3>
                      <p>Choose whether this event repeats.</p>
                    </div>
                  </div>
                
                  <div class="form-field">
                    <label for="recurrence-frequency">Repeat</label>
                    <select
                      id="recurrence-frequency"
                      v-model="recurrenceFrequency"
                      @change="setDefaultRecurrenceDay"
                    >
                      <option value="none">Does not repeat</option>
                      <option value="daily">Daily</option>
                      <option value="weekly">Weekly</option>
                      <option value="biweekly">Every two weeks</option>
                      <option value="monthly">Monthly</option>
                    </select>
                  </div>
                
                  <div
                    v-if="
                      recurrenceFrequency === 'weekly' ||
                      recurrenceFrequency === 'biweekly'
                    "
                    class="form-field recurrence-days-field"
                  >
                    <label>Repeat on</label>
                
                    <div class="weekday-options">
                      <label
                        v-for="day in weekdays"
                        :key="day.value"
                        class="weekday-option"
                      >
                        <input
                          v-model="recurrenceDays"
                          type="checkbox"
                          :value="day.value"
                        />
                        <span>{{ day.label }}</span>
                      </label>
                    </div>
                  </div>
                
                  <div
                    v-if="recurrenceFrequency !== 'none'"
                    class="recurrence-end"
                  >
                    <div class="form-field">
                      <label for="recurrence-end-mode">Ends</label>
                      <select
                        id="recurrence-end-mode"
                        v-model="recurrenceEndMode"
                      >
                        <option value="never">Never</option>
                        <option value="date">On a specific date</option>
                      </select>
                    </div>
                
                    <div
                      v-if="recurrenceEndMode === 'date'"
                      class="form-field"
                    >
                      <label for="recurrence-end-date">End date</label>
                      <input
                        id="recurrence-end-date"
                        v-model="recurrenceEndDate"
                        type="date"
                        :min="startsAt.slice(0, 10)"
                      />
                    </div>
                  </div>
                
                  <p
                    v-if="recurrenceFrequency !== 'none'"
                    class="recurrence-note"
                  >
                    The first occurrence uses the start and end times above.
                    Subsequent occurrences follow this recurrence pattern.
                  </p>
                </section>

                <label class="full-width">
                    Description
                    <textarea
                        v-model="description"
                        rows="4"
                        placeholder="Additional details about this event..."
                        :disabled="saving"
                    />
                </label>

                <div class="form-actions full-width">
                    <button
                        class="secondary-button"
                        type="button"
                        @click="resetForm"
                    >
                        Cancel
                    </button>
                    <button
                        class="primary-button"
                        type="submit"
                        :disabled="saving"
                    >
                        {{ saving ? "Saving..." : "Save event" }}
                    </button>
                </div>
            </form>

            <p
                v-if="
                    editingEventId &&
                    events.find((item) => item.id === editingEventId)
                        ?.recurrence_rule
                "
                class="form-note"
            >
                This event belongs to a recurring series. Changes here affect
                the series, not an individual occurrence.
            </p>
        </section>

        <section class="events-section">
            <div class="toolbar">
                <input
                    v-model="searchQuery"
                    type="search"
                    placeholder="Search events..."
                    aria-label="Search events"
                />

                <select
                    v-model="statusFilter"
                    aria-label="Filter by event status"
                >
                    <option value="all">All statuses</option>
                    <option value="scheduled">Scheduled</option>
                    <option value="cancelled">Cancelled</option>
                </select>
            </div>

            <p v-if="loading" class="muted">Loading events...</p>

            <div v-else-if="visibleEvents.length" class="event-list">
                <article
                    v-for="event in visibleEvents"
                    :key="event.id"
                    class="event-card"
                    :class="{ cancelled: event.status === 'cancelled' }"
                >
                    <div class="event-main">
                        <div class="event-meta">
                            <span class="type-tag">{{
                                eventTypeLabel(event.event_type)
                            }}</span>
                            <span
                                v-if="event.status === 'cancelled'"
                                class="status-tag cancelled-tag"
                            >
                                Cancelled
                            </span>
                            <span
                                v-if="event.recurrence_rule"
                                class="status-tag recurring-tag"
                            >
                                Recurring series
                            </span>
                        </div>

                        <h2>{{ event.title }}</h2>

                        <p class="event-date">
                            {{ formatEventDate(event.starts_at) }}
                            <span v-if="!event.all_day">
                                · {{ formatEventTime(event.starts_at) }} –
                                {{ formatEventTime(event.ends_at) }}
                            </span>
                            <span v-else> · All day</span>
                        </p>

                        <p v-if="event.location" class="event-detail">
                            {{ event.location }}
                        </p>

                        <p v-if="event.course_id" class="event-detail">
                            {{ courseCode(event.course_id) }} ·
                            {{ courseName(event.course_id) }}
                            <span v-if="event.discipline_id">
                                / {{ disciplineName(event.discipline_id) }}
                            </span>
                        </p>

                        <p v-if="event.description" class="event-description">
                            {{ event.description }}
                        </p>
                    </div>

                    <div class="event-actions">
                        <button
                            class="text-button"
                            type="button"
                            @click="openEditForm(event)"
                        >
                            Edit
                        </button>

                        <button
                            class="text-button"
                            type="button"
                            @click="toggleEventStatus(event)"
                        >
                            {{
                                event.status === "scheduled"
                                    ? "Cancel"
                                    : "Restore"
                            }}
                        </button>

                        <button
                            class="text-button danger-button"
                            type="button"
                            @click="deleteEvent(event)"
                        >
                            Delete
                        </button>
                    </div>
                </article>
            </div>

            <div v-else class="empty-state">
                {{
                    searchQuery || statusFilter !== "all"
                        ? "No events match your filters."
                        : "No events have been created yet."
                }}
            </div>
        </section>
    </main>
</template>

<style scoped>

.recurrence-section {
  display: flex;
  flex-direction: column;
  grid-column: 1 / -1;
  gap: 1rem;
  padding: 1.25rem;
  border: 1px solid var(--border-color, #d1d5db);
  border-radius: 0.75rem;
  background: var(--surface-secondary, #f9fafb);
}

.recurrence-heading h3 {
  margin: 0;
  font-size: 1rem;
}

.recurrence-heading p {
  margin: 0.35rem 0 0;
  color: var(--text-secondary, #6b7280);
  font-size: 0.875rem;
}

.recurrence-section .form-field {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.recurrence-section .form-field select,
.recurrence-section .form-field input[type="date"] {
  width: 100%;
  max-width: 24rem;
}

.weekday-options {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
}

.weekday-option {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  cursor: pointer;
}

.weekday-option input {
  accent-color: var(--primary-color, #2563eb);
}

.recurrence-end {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

.recurrence-note {
  margin: 0;
  color: var(--text-secondary, #6b7280);
  font-size: 0.85rem;
  line-height: 1.5;
}

@media (max-width: 640px) {
  .recurrence-end {
    grid-template-columns: 1fr;
  }
}

.admin-events {
    padding: 2.5rem;
}

.page-header,
.panel-heading,
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

.danger-button {
    color: #ff8585;
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

.form-panel {
    margin-bottom: 1.5rem;
    padding: 1.5rem;
    border: 1px solid var(--border);
    border-radius: 9px;
    background: var(--surface);
}

.panel-heading {
    margin-bottom: 1.25rem;
}

.panel-heading h2 {
    margin: 0;
    font-size: 1.15rem;
}

.panel-heading p {
    margin: 0.35rem 0 0;
}

.form-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1rem;
}

.form-grid label {
    display: flex;
    flex-direction: column;
    gap: 0.45rem;
    font-size: 0.85rem;
    font-weight: 600;
}

.form-grid input,
.form-grid select,
.form-grid textarea,
.toolbar input,
.toolbar select {
    width: 100%;
    min-width: 0;
    padding: 0.7rem;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: var(--background);
    color: var(--text);
    font: inherit;
}

.full-width {
    grid-column: 1 / -1;
}

.date-fields {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1rem;
}

.checkbox-label {
    display: flex !important;
    flex-direction: row !important;
    align-items: center;
    gap: 0.6rem !important;
}

.checkbox-label input {
    width: auto;
}

.form-actions {
    justify-content: flex-end;
}

.form-note {
    margin: 1rem 0 0;
    color: var(--text-muted);
    font-size: 0.8rem;
}

.events-section {
    margin-top: 1.5rem;
}

.toolbar {
    margin-bottom: 1rem;
}

.toolbar input {
    max-width: 420px;
}

.toolbar select {
    max-width: 180px;
}

.event-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
}

.event-card {
    display: flex;
    justify-content: space-between;
    gap: 1.5rem;
    padding: 1.25rem;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: var(--surface);
}

.event-card.cancelled {
    opacity: 0.65;
}

.event-main {
    min-width: 0;
}

.event-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 0.45rem;
    margin-bottom: 0.55rem;
}

.type-tag,
.status-tag {
    display: inline-block;
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
    font-size: 0.7rem;
}

.type-tag {
    background: var(--surface-raised);
    color: var(--accent-hover);
}

.cancelled-tag {
    background: rgb(180 50 50 / 15%);
    color: #ff8585;
}

.recurring-tag {
    background: rgb(80 120 180 / 15%);
    color: #91b9ef;
}

.event-card h2 {
    margin: 0;
    font-size: 1.05rem;
}

.event-date {
    margin: 0.5rem 0;
    color: var(--text);
    font-size: 0.85rem;
}

.event-detail,
.event-description {
    margin: 0.35rem 0 0;
    color: var(--text-muted);
    font-size: 0.82rem;
    line-height: 1.5;
}

.event-actions {
    display: flex;
    flex-shrink: 0;
    align-items: flex-start;
    gap: 0.75rem;
}

.empty-state {
    padding: 2rem;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: var(--surface);
    color: var(--text-muted);
    text-align: center;
}

@media (max-width: 850px) {
    .admin-events {
        padding: 1.5rem;
    }

    .event-card {
        flex-direction: column;
    }

    .event-actions {
        justify-content: flex-start;
    }
}

@media (max-width: 550px) {
    .page-header,
    .toolbar {
        align-items: flex-start;
        flex-direction: column;
    }

    .form-grid,
    .date-fields {
        grid-template-columns: 1fr;
    }

    .toolbar input,
    .toolbar select {
        max-width: none;
    }

    .event-actions {
        flex-wrap: wrap;
    }
}
</style>
