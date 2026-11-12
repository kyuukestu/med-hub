
-- =========================================================
-- 003: Shared assignments and deadlines
-- =========================================================

-- ---------------------------------------------------------
-- 1. Assignment statuses
-- ---------------------------------------------------------

create type public.assignment_status as enum (
    'draft',
    'published',
    'cancelled'
);

-- ---------------------------------------------------------
-- 2. Assignments
-- ---------------------------------------------------------

create table public.assignments (
    id uuid primary key default gen_random_uuid(),

    title text not null,

    description text,

    instructions text,

    course_id uuid not null
        references public.courses(id)
        on delete restrict,

    discipline_id uuid
        references public.disciplines(id)
        on delete set null,

    assigned_at timestamptz not null default now(),

    due_at timestamptz,

    submission_method text,

    submission_location text,

    submission_url text,

    status public.assignment_status not null default 'draft',

    created_by uuid
        references public.profiles(id)
        on delete set null
        default auth.uid(),

    updated_by uuid
        references public.profiles(id)
        on delete set null
        default auth.uid(),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------
-- 3. Automatic update timestamp and user tracking
-- ---------------------------------------------------------

create or replace function public.set_assignment_updated_at()
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

create trigger set_assignments_updated_at
before update on public.assignments
for each row
execute function public.set_assignment_updated_at();

-- ---------------------------------------------------------
-- 4. Indexes
-- ---------------------------------------------------------

create index assignments_course_id_idx
on public.assignments(course_id);

create index assignments_discipline_id_idx
on public.assignments(discipline_id);

create index assignments_due_at_idx
on public.assignments(due_at);

create index assignments_status_idx
on public.assignments(status);

create index assignments_created_at_idx
on public.assignments(created_at desc);

-- ---------------------------------------------------------
-- 5. Enable Row Level Security
-- ---------------------------------------------------------

alter table public.assignments
enable row level security;

-- ---------------------------------------------------------
-- 6. Assignment visibility
--
-- Students can see published and cancelled assignments.
-- Editors and administrators can also see drafts.
-- ---------------------------------------------------------

create policy "Users can view published assignments"
on public.assignments
for select
to authenticated
using (
    status in (
        'published'::public.assignment_status,
        'cancelled'::public.assignment_status
    )
    or public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
);

-- ---------------------------------------------------------
-- 7. Assignment management
--
-- Only administrators and editors can manage records.
-- ---------------------------------------------------------

create policy "Editors can manage assignments"
on public.assignments
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

-- ---------------------------------------------------------
-- 8. Client permissions
-- ---------------------------------------------------------

grant select, insert, update, delete
on public.assignments
to authenticated;
