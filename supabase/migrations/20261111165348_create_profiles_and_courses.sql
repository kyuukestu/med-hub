
-- =========================================================
-- 001: Profiles, roles, courses and disciplines
-- =========================================================

-- ---------------------------------------------------------
-- 1. Application roles
-- ---------------------------------------------------------

create type public.app_role as enum (
    'admin',
    'editor',
    'student'
);

-- ---------------------------------------------------------
-- 2. Timestamp utility
-- ---------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- ---------------------------------------------------------
-- 3. User profiles
-- ---------------------------------------------------------

create table public.profiles (
    id uuid primary key references auth.users(id)
        on delete cascade,

    display_name text not null default 'Student',

    role public.app_role not null default 'student',

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

-- ---------------------------------------------------------
-- 4. Automatically create profiles for new users
-- ---------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (
        id,
        display_name
    )
    values (
        new.id,
        coalesce(
            nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
            nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
            'Student'
        )
    );

    return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- ---------------------------------------------------------
-- 5. Role lookup utility
-- ---------------------------------------------------------

create or replace function public.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
    select p.role
    from public.profiles p
    where p.id = (select auth.uid())
    limit 1;
$$;

revoke all on function public.current_user_role()
from public, anon;

grant execute on function public.current_user_role()
to authenticated;

-- ---------------------------------------------------------
-- 6. Courses
-- ---------------------------------------------------------

create table public.courses (
    id uuid primary key default gen_random_uuid(),

    code text not null unique
        check (code ~ '^[A-Z0-9_-]+$'),

    name text not null,

    description text,

    sort_order integer not null default 0,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

create trigger set_courses_updated_at
before update on public.courses
for each row
execute function public.set_updated_at();

-- ---------------------------------------------------------
-- 7. Disciplines
-- ---------------------------------------------------------

create table public.disciplines (
    id uuid primary key default gen_random_uuid(),

    course_id uuid not null
        references public.courses(id)
        on delete cascade,

    code text not null,

    name text not null,

    description text,

    sort_order integer not null default 0,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint disciplines_course_code_unique
        unique (course_id, code)
);

create trigger set_disciplines_updated_at
before update on public.disciplines
for each row
execute function public.set_updated_at();

create index disciplines_course_id_idx
on public.disciplines(course_id);

-- ---------------------------------------------------------
-- 8. Enable Row Level Security
-- ---------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.disciplines enable row level security;

-- ---------------------------------------------------------
-- 9. Profile policies
-- ---------------------------------------------------------

create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using (
    id = (select auth.uid())
    or public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
);

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Only display_name can be modified through the client API.
grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

-- ---------------------------------------------------------
-- 10. Course policies
-- ---------------------------------------------------------

create policy "Authenticated users can view courses"
on public.courses
for select
to authenticated
using (true);

create policy "Editors can manage courses"
on public.courses
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
on public.courses
to authenticated;

-- ---------------------------------------------------------
-- 11. Discipline policies
-- ---------------------------------------------------------

create policy "Authenticated users can view disciplines"
on public.disciplines
for select
to authenticated
using (true);

create policy "Editors can manage disciplines"
on public.disciplines
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
on public.disciplines
to authenticated;
