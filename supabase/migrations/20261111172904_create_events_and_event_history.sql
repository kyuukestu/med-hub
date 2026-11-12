
-- =========================================================
-- 002: Events, recurring schedules and event history
-- =========================================================

-- ---------------------------------------------------------
-- 1. Event types and statuses
-- ---------------------------------------------------------

create type public.event_type as enum (
    'class',
    'practical',
    'tutorial',
    'lab',
    'extra_class',
    'examination',
    'general'
);

create type public.event_status as enum (
    'scheduled',
    'cancelled'
);

create type public.occurrence_override_status as enum (
    'cancelled',
    'modified'
);

-- ---------------------------------------------------------
-- 2. Events
--
-- A non-recurring event is represented by one row.
-- A recurring event is represented by one series row.
-- recurrence_rule stores an RFC 5545 RRULE value.
-- ---------------------------------------------------------

create table public.events (
    id uuid primary key default gen_random_uuid(),

    title text not null,

    description text,

    event_type public.event_type not null,

    course_id uuid
        references public.courses(id)
        on delete set null,

    discipline_id uuid
        references public.disciplines(id)
        on delete set null,

    starts_at timestamptz not null,

    ends_at timestamptz not null,

    all_day boolean not null default false,

    location text,

    recurrence_rule text,

    recurrence_timezone text not null
        default 'America/Jamaica',

    status public.event_status not null default 'scheduled',

    created_by uuid
        references public.profiles(id)
        on delete set null
        default auth.uid(),

    updated_by uuid
        references public.profiles(id)
        on delete set null
        default auth.uid(),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint events_valid_time_range
        check (ends_at > starts_at),

    constraint events_valid_recurrence_rule
        check (
            recurrence_rule is null
            or length(recurrence_rule) <= 500
        ),

    constraint events_discipline_requires_course
        check (
            discipline_id is null
            or course_id is not null
        )
);

-- ---------------------------------------------------------
-- 3. Event update timestamp and user tracking
-- ---------------------------------------------------------

create or replace function public.set_event_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    new.updated_by = auth.uid();
    return new;
end;
$$;

create trigger set_events_updated_at
before update on public.events
for each row
execute function public.set_event_updated_at();

-- ---------------------------------------------------------
-- 4. Recurring event occurrence overrides
--
-- Only exceptional occurrences are stored here.
-- Normal occurrences are generated from the RRULE.
-- ---------------------------------------------------------

create table public.event_occurrence_overrides (
    id uuid primary key default gen_random_uuid(),

    event_id uuid not null
        references public.events(id)
        on delete cascade,

    original_start timestamptz not null,

    status public.occurrence_override_status not null,

    starts_at timestamptz,

    ends_at timestamptz,

    reason text,

    created_by uuid
        references public.profiles(id)
        on delete set null
        default auth.uid(),

    updated_by uuid
        references public.profiles(id)
        on delete set null
        default auth.uid(),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint event_override_unique_occurrence
        unique (event_id, original_start),

    constraint event_override_valid_time_range
        check (
            (
                status = 'cancelled'
                and starts_at is null
                and ends_at is null
            )
            or
            (
                status = 'modified'
                and starts_at is not null
                and ends_at is not null
                and ends_at > starts_at
            )
        )
);

create trigger set_event_overrides_updated_at
before update on public.event_occurrence_overrides
for each row
execute function public.set_event_updated_at();

-- ---------------------------------------------------------
-- 5. Event history
--
-- Records inserts, updates and deletions.
-- Old and new values are preserved as JSONB.
-- ---------------------------------------------------------

create table public.event_history (
    id uuid primary key default gen_random_uuid(),

    event_id uuid
        references public.events(id)
        on delete set null,

    entity_type text not null
        check (
            entity_type in (
                'event',
                'occurrence_override'
            )
        ),

    action text not null
        check (
            action in (
                'insert',
                'update',
                'delete'
            )
        ),

    actor_id uuid
        references public.profiles(id)
        on delete set null,

    old_values jsonb,

    new_values jsonb,

    created_at timestamptz not null default now()
);

create index event_history_event_id_idx
on public.event_history(event_id);

create index event_history_created_at_idx
on public.event_history(created_at desc);

-- ---------------------------------------------------------
-- 6. Automatic event history recording
-- ---------------------------------------------------------

create or replace function public.record_event_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_old_values jsonb;
    v_new_values jsonb;
    v_event_id uuid;
    v_action text;
    v_entity_type text;
begin
    v_entity_type := case
        when tg_table_name = 'events'
            then 'event'
        else 'occurrence_override'
    end;

    if tg_op = 'INSERT' then
        v_new_values := to_jsonb(new);
        -- Preserve the deleted record's identity in old_values.
        -- Do not reference a row that has already been deleted.
        v_event_id := null;
        v_action := 'insert';

    elsif tg_op = 'UPDATE' then
        v_old_values := to_jsonb(old);
        v_new_values := to_jsonb(new);
        v_event_id := case
            when v_entity_type = 'event'
                then (v_new_values ->> 'id')::uuid
            else (v_new_values ->> 'event_id')::uuid
        end;
        v_action := 'update';

    elsif tg_op = 'DELETE' then
        v_old_values := to_jsonb(old);
        v_event_id := case
            when v_entity_type = 'event'
                then (v_old_values ->> 'id')::uuid
            else (v_old_values ->> 'event_id')::uuid
        end;
        v_action := 'delete';
    end if;

    insert into public.event_history (
        event_id,
        entity_type,
        action,
        actor_id,
        old_values,
        new_values
    )
    values (
        v_event_id,
        v_entity_type,
        v_action,
        auth.uid(),
        v_old_values,
        v_new_values
    );

    if tg_op = 'DELETE' then
        return old;
    end if;

    return new;
end;
$$;

revoke all on function public.record_event_history()
from public, anon, authenticated;

create trigger record_events_history
after insert or update or delete
on public.events
for each row
execute function public.record_event_history();

create trigger record_event_overrides_history
after insert or update or delete
on public.event_occurrence_overrides
for each row
execute function public.record_event_history();

-- ---------------------------------------------------------
-- 7. Indexes
-- ---------------------------------------------------------

create index events_starts_at_idx
on public.events(starts_at);

create index events_course_id_idx
on public.events(course_id);

create index events_discipline_id_idx
on public.events(discipline_id);

create index events_status_idx
on public.events(status);

create index events_type_idx
on public.events(event_type);

create index event_overrides_event_id_idx
on public.event_occurrence_overrides(event_id);

create index event_overrides_original_start_idx
on public.event_occurrence_overrides(original_start);

-- ---------------------------------------------------------
-- 8. Enable Row Level Security
-- ---------------------------------------------------------

alter table public.events enable row level security;

alter table public.event_occurrence_overrides
enable row level security;

alter table public.event_history enable row level security;

-- ---------------------------------------------------------
-- 9. Event policies
-- ---------------------------------------------------------

create policy "Authenticated users can view events"
on public.events
for select
to authenticated
using (true);

create policy "Editors can manage events"
on public.events
for all
to authenticated
using (
    public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
)
with check (
    public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
);

grant select, insert, update, delete
on public.events
to authenticated;

-- ---------------------------------------------------------
-- 10. Occurrence override policies
-- ---------------------------------------------------------

create policy "Authenticated users can view occurrence overrides"
on public.event_occurrence_overrides
for select
to authenticated
using (true);

create policy "Editors can manage occurrence overrides"
on public.event_occurrence_overrides
for all
to authenticated
using (
    public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
)
with check (
    public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
);

grant select, insert, update, delete
on public.event_occurrence_overrides
to authenticated;

-- ---------------------------------------------------------
-- 11. Event history policies
-- ---------------------------------------------------------

create policy "Authenticated users can view event history"
on public.event_history
for select
to authenticated
using (true);

grant select on public.event_history to authenticated;

-- No direct client insert, update or delete permissions
-- are granted for event history.
