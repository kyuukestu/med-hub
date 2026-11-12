

-- =========================================================
-- 004: Academic materials repository
-- =========================================================


-- ---------------------------------------------------------
-- 1. Material categories
-- ---------------------------------------------------------

create type public.material_type as enum (
    'lecture_slides',
    'lecture_notes',
    'recommended_reading',
    'textbook_chapter',
    'practical_material',
    'supplementary',
    'past_exam',
    'other'
);


-- ---------------------------------------------------------
-- 2. Material sources
-- ---------------------------------------------------------

create type public.material_source as enum (
    'lecturer',
    'moodle',
    'student',
    'external'
);


-- ---------------------------------------------------------
-- 3. Material formats
-- ---------------------------------------------------------

create type public.material_format as enum (
    'uploaded_file',
    'external_link',
    'bibliographic_reference'
);


-- ---------------------------------------------------------
-- 4. Material verification status
-- ---------------------------------------------------------

create type public.material_verification_status as enum (
    'unverified',
    'verified',
    'outdated',
    'archived'
);


-- ---------------------------------------------------------
-- 5. Materials
--
-- Represents the logical resource, not an individual file.
-- A material may have multiple versions and associations.
-- ---------------------------------------------------------

create table public.materials (
    id uuid primary key default gen_random_uuid(),

    title text not null,

    description text,

    material_type public.material_type not null default 'other',

    source public.material_source not null,

    format public.material_format not null default 'uploaded_file',

    academic_year text,

    aliases text[] not null default '{}',

    -- Bibliographic metadata
    author text,

    publication_title text,

    edition text,

    chapter_number text,

    chapter_title text,

    page_range text,

    publisher text,

    publication_year integer,

    isbn text,

    external_url text,

    is_published boolean not null default false,

    current_version_id uuid,

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

    constraint materials_title_not_empty
        check (length(trim(title)) > 0),

    constraint materials_publication_year_valid
        check (
            publication_year is null
            or publication_year between 1000 and 9999
        ),

    constraint materials_isbn_format
        check (
            isbn is null
            or isbn ~ '^(97[89])?[0-9Xx-]{10,17}$'
        )
);

-- ---------------------------------------------------------
-- 5. Material versions
--
-- Each version represents one uploaded file.
-- The actual file is stored in Supabase Storage.
-- ---------------------------------------------------------

create table public.material_versions (
    id uuid primary key default gen_random_uuid(),

    material_id uuid not null
        references public.materials(id)
        on delete restrict,

    version_number integer not null,

    original_filename text not null,

    storage_bucket text not null default 'academic-materials',

    storage_path text not null,

    mime_type text,

    file_size_bytes bigint not null,

    sha256_hash text,

    verification_status public.material_verification_status
        not null default 'unverified',

    version_notes text,

    uploaded_by uuid
        references public.profiles(id)
        on delete set null
        default auth.uid(),

    created_at timestamptz not null default now(),

    constraint material_versions_number_positive
        check (version_number > 0),

    constraint material_versions_size_positive
        check (file_size_bytes > 0),

    constraint material_versions_filename_not_empty
        check (length(trim(original_filename)) > 0),

    constraint material_versions_path_not_empty
        check (length(trim(storage_path)) > 0),

    constraint material_versions_sha256_format
        check (
            sha256_hash is null
            or sha256_hash ~ '^[a-fA-F0-9]{64}$'
        ),

    constraint material_versions_unique_number
        unique (material_id, version_number),

    constraint material_versions_unique_storage_path
        unique (storage_bucket, storage_path)
);


-- ---------------------------------------------------------
-- 6. Current version reference
-- ---------------------------------------------------------

alter table public.material_versions
add constraint material_versions_id_material_unique
unique (id, material_id);

alter table public.materials
add constraint materials_current_version_fk
foreign key (current_version_id, id)
references public.material_versions(id, material_id)
on delete restrict;

-- ---------------------------------------------------------
-- 7. Material relationship types
-- ---------------------------------------------------------

create type public.material_relationship_type as enum (
    'lecture_resource',
    'required_reading',
    'recommended_reading',
    'supplementary',
    'reference',
    'course_resource',
    'assignment_resource'
);


-- ---------------------------------------------------------
-- 8. Material associations
--
-- A material can be linked to multiple courses,
-- disciplines, events and assignments.
--
-- Exactly one primary target is required per association.
-- A discipline association must also specify its course.
-- ---------------------------------------------------------

create table public.material_links (
    id uuid primary key default gen_random_uuid(),

    material_id uuid not null
        references public.materials(id)
        on delete restrict,

    relationship_type public.material_relationship_type
        not null default 'supplementary',

    course_id uuid
        references public.courses(id)
        on delete cascade,

    discipline_id uuid,

    event_id uuid
        references public.events(id)
        on delete cascade,

    assignment_id uuid
        references public.assignments(id)
        on delete cascade,

    created_by uuid
        references public.profiles(id)
        on delete set null
        default auth.uid(),

    created_at timestamptz not null default now(),

    constraint material_links_single_target
        check (
            num_nonnulls(course_id, event_id, assignment_id) = 1
        ),

    constraint material_links_discipline_requires_course
        check (
            discipline_id is null or course_id is not null
        ),

    constraint material_links_relationship_target
        check (
            (
                relationship_type = 'lecture_resource'
                and event_id is not null
            )
            or
            (
                relationship_type = 'assignment_resource'
                and assignment_id is not null
            )
            or
            (
                relationship_type = 'course_resource'
                and course_id is not null
                and event_id is null
                and assignment_id is null
            )
            or
            relationship_type in (
                'required_reading',
                'recommended_reading',
                'supplementary',
                'reference'
            )
        )
);


-- ---------------------------------------------------------
-- 9. Discipline/course relationship enforcement
-- ---------------------------------------------------------

alter table public.disciplines
add constraint disciplines_id_course_unique
unique (id, course_id);

alter table public.material_links
add constraint material_links_discipline_course_fk
foreign key (discipline_id, course_id)
references public.disciplines(id, course_id)
on delete cascade;


-- ---------------------------------------------------------
-- 10. Indexes
-- ---------------------------------------------------------

create index materials_type_idx
on public.materials(material_type);

create index materials_source_idx
on public.materials(source);

create index materials_published_idx
on public.materials(id)
where is_published = true;

create index materials_aliases_idx
on public.materials
using gin (aliases);

create index material_versions_material_id_idx
on public.material_versions(material_id);

create index material_versions_sha256_idx
on public.material_versions(sha256_hash);

create index material_versions_verification_idx
on public.material_versions(verification_status);

create index material_links_material_id_idx
on public.material_links(material_id);

create index material_links_course_id_idx
on public.material_links(course_id)
where course_id is not null;

create index material_links_event_id_idx
on public.material_links(event_id)
where event_id is not null;

create index material_links_assignment_id_idx
on public.material_links(assignment_id)
where assignment_id is not null;

create index material_links_discipline_id_idx
on public.material_links(discipline_id)
where discipline_id is not null;

create unique index material_links_unique_course
on public.material_links(material_id, course_id)
where course_id is not null and discipline_id is null;

create unique index material_links_unique_discipline
on public.material_links(material_id, course_id, discipline_id)
where discipline_id is not null;

create unique index material_links_unique_event
on public.material_links(material_id, event_id)
where event_id is not null;

create unique index material_links_unique_assignment
on public.material_links(material_id, assignment_id)
where assignment_id is not null;

-- ---------------------------------------------------------
-- 11. Updated timestamp trigger
-- ---------------------------------------------------------

create or replace function public.set_material_updated_at()
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

create trigger set_materials_updated_at
before update on public.materials
for each row
execute function public.set_material_updated_at();


-- ---------------------------------------------------------
-- 12. Protect material version file records
--
-- File identity and storage metadata cannot be changed
-- after creation. Verification status can be updated.
-- Version records cannot be deleted through normal SQL.
-- ---------------------------------------------------------

create or replace function public.protect_material_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        raise exception 'Material versions cannot be deleted.';
    end if;

    if
        new.id is distinct from old.id
        or new.material_id is distinct from old.material_id
        or new.version_number is distinct from old.version_number
        or new.original_filename is distinct from old.original_filename
        or new.storage_bucket is distinct from old.storage_bucket
        or new.storage_path is distinct from old.storage_path
        or new.mime_type is distinct from old.mime_type
        or new.file_size_bytes is distinct from old.file_size_bytes
        or new.sha256_hash is distinct from old.sha256_hash
        or new.uploaded_by is distinct from old.uploaded_by
        or new.created_at is distinct from old.created_at
    then
        raise exception 'Material version file metadata is immutable.';
    end if;

    return new;
end;
$$;

create trigger protect_material_versions
before update or delete on public.material_versions
for each row
execute function public.protect_material_version();

create or replace function public.prevent_material_versions_truncate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception 'Material versions cannot be truncated.';
end;
$$;

create trigger prevent_material_versions_truncate
before truncate on public.material_versions
for each statement
execute function public.prevent_material_versions_truncate();


-- ---------------------------------------------------------
-- 13. Enable Row Level Security
-- ---------------------------------------------------------

alter table public.materials enable row level security;
alter table public.material_versions enable row level security;
alter table public.material_links enable row level security;

-- ---------------------------------------------------------
-- 14. Material policies
-- ---------------------------------------------------------

create policy "Users can view published materials"
on public.materials
for select
to authenticated
using (
    is_published
    or public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
);

create policy "Editors can create materials"
on public.materials
for insert
to authenticated
with check (
    public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
);

create policy "Editors can update materials"
on public.materials
for update
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
-- 15. Material version policies
-- ---------------------------------------------------------

create policy "Users can view versions of visible materials"
on public.material_versions
for select
to authenticated
using (
    exists (
        select 1
        from public.materials m
        where m.id = material_versions.material_id
        and (
            m.is_published
            or public.current_user_role() in (
                'admin'::public.app_role,
                'editor'::public.app_role
            )
        )
    )
);

create policy "Editors can upload material versions"
on public.material_versions
for insert
to authenticated
with check (
    public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
    and exists (
        select 1
        from public.materials m
        where m.id = material_versions.material_id
        and m.format = 'uploaded_file'::public.material_format
    )
);

create policy "Editors can update material version metadata"
on public.material_versions
for update
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
-- 16. Material link policies
-- ---------------------------------------------------------

create policy "Users can view links for visible materials"
on public.material_links
for select
to authenticated
using (
    exists (
        select 1
        from public.materials m
        where m.id = material_links.material_id
        and (
            m.is_published
            or public.current_user_role() in (
                'admin'::public.app_role,
                'editor'::public.app_role
            )
        )
    )
);

create policy "Editors can create material links"
on public.material_links
for insert
to authenticated
with check (
    public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
);

create policy "Editors can delete material links"
on public.material_links
for delete
to authenticated
using (
    public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
);


-- ---------------------------------------------------------
-- 17. Table permissions
-- ---------------------------------------------------------

grant select, insert, update
on public.materials
to authenticated;

grant select, insert, update
on public.material_versions
to authenticated;

grant select, insert, delete
on public.material_links
to authenticated;


-- ---------------------------------------------------------
-- 18. Private Storage bucket
-- ---------------------------------------------------------

insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit
)
values (
    'academic-materials',
    'academic-materials',
    false,
    52428800
)
on conflict (id) do update
set
    name = excluded.name,
    public = false,
    file_size_limit = excluded.file_size_limit;


-- ---------------------------------------------------------
-- 19. Storage policies
--
-- Storage paths must begin with the material UUID:
--
-- material_id/version_id/filename
--
-- Students can download files belonging to published
-- materials. Editors and administrators can upload and
-- manage files.
-- ---------------------------------------------------------

create policy "Users can view published material files"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'academic-materials'
    and exists (
        select 1
        from public.materials m
        where m.id::text = (storage.foldername(name))[1]
        and (
            m.is_published
            or public.current_user_role() in (
                'admin'::public.app_role,
                'editor'::public.app_role
            )
        )
    )
);

create policy "Editors can upload material files"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'academic-materials'
    and public.current_user_role() in (
        'admin'::public.app_role,
        'editor'::public.app_role
    )
    and exists (
        select 1
        from public.materials m
        where m.id::text = (storage.foldername(name))[1]
    )
);
