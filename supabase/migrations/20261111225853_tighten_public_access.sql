-- =========================================================
-- 1. PUBLIC SCHEMA TABLE PRIVILEGES
-- =========================================================

REVOKE ALL PRIVILEGES
ON ALL TABLES IN SCHEMA public
FROM anon, authenticated;

-- Public read access to academic information.
GRANT SELECT ON
    public.courses,
    public.disciplines,
    public.events,
    public.event_occurrence_overrides,
    public.assignments,
    public.materials,
    public.material_versions,
    public.material_links
TO anon;

-- Authenticated users can read the academic data.
GRANT SELECT ON
    public.courses,
    public.disciplines,
    public.events,
    public.event_occurrence_overrides,
    public.event_history,
    public.assignments,
    public.materials,
    public.material_versions,
    public.material_links,
    public.profiles
TO authenticated;

-- Course and discipline administration.
GRANT INSERT, UPDATE, DELETE ON
    public.courses,
    public.disciplines
TO authenticated;

-- Event administration.
GRANT INSERT, UPDATE, DELETE ON
    public.events,
    public.event_occurrence_overrides
TO authenticated;

-- Assignment administration.
GRANT INSERT, UPDATE, DELETE ON
    public.assignments
TO authenticated;

-- Material administration.
GRANT INSERT, UPDATE ON
    public.materials
TO authenticated;

GRANT INSERT ON
    public.material_versions
TO authenticated;

-- Only mutable version fields should be directly updated.
GRANT UPDATE (verification_status, version_notes)
ON public.material_versions
TO authenticated;

GRANT INSERT, DELETE ON
    public.material_links
TO authenticated;

-- Profiles: users may update their display name only.
GRANT UPDATE (display_name)
ON public.profiles
TO authenticated;


-- =========================================================
-- 2. DEFAULT PRIVILEGES
-- =========================================================

-- Prevent future tables from inheriting excessive privileges.

ALTER DEFAULT PRIVILEGES
FOR ROLE postgres
IN SCHEMA public
REVOKE ALL ON TABLES FROM anon, authenticated;

-- No public sequence access is needed by the current schema.

ALTER DEFAULT PRIVILEGES
FOR ROLE postgres
IN SCHEMA public
REVOKE ALL ON SEQUENCES FROM anon, authenticated;


-- =========================================================
-- 3. PUBLIC READ POLICIES
-- =========================================================

CREATE POLICY "Public can view courses"
ON public.courses
FOR SELECT
TO anon
USING (true);

CREATE POLICY "Public can view disciplines"
ON public.disciplines
FOR SELECT
TO anon
USING (true);

CREATE POLICY "Public can view events"
ON public.events
FOR SELECT
TO anon
USING (true);

CREATE POLICY "Public can view event occurrence overrides"
ON public.event_occurrence_overrides
FOR SELECT
TO anon
USING (true);

CREATE POLICY "Public can view published assignments"
ON public.assignments
FOR SELECT
TO anon
USING (
    status IN ('published', 'cancelled')
);

CREATE POLICY "Public can view published materials"
ON public.materials
FOR SELECT
TO anon
USING (is_published = true);

CREATE POLICY "Public can view published material versions"
ON public.material_versions
FOR SELECT
TO anon
USING (
    EXISTS (
        SELECT 1
        FROM public.materials m
        WHERE m.id = material_versions.material_id
          AND m.is_published = true
    )
);

CREATE POLICY "Public can view published material links"
ON public.material_links
FOR SELECT
TO anon
USING (
    EXISTS (
        SELECT 1
        FROM public.materials m
        WHERE m.id = material_links.material_id
          AND m.is_published = true
    )
);

-- =========================================================
-- 4. STORAGE OBJECT PRIVILEGES
-- =========================================================

REVOKE ALL PRIVILEGES
ON TABLE storage.objects
FROM anon, authenticated;

GRANT SELECT ON TABLE storage.objects TO anon;

GRANT SELECT, INSERT
ON TABLE storage.objects
TO authenticated;

DROP POLICY IF EXISTS
    "Users can view published material files"
ON storage.objects;

CREATE POLICY "Users can view published material files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'academic-materials'
    AND EXISTS (
        SELECT 1
        FROM public.material_versions mv
        JOIN public.materials m
            ON m.id = mv.material_id
        WHERE mv.storage_bucket = objects.bucket_id
          AND mv.storage_path = objects.name
          AND (
              m.is_published = true
              OR public.current_user_role()
                  IN ('admin', 'editor')
          )
    )
);

CREATE POLICY "Public can view published material files"
ON storage.objects
FOR SELECT
TO anon
USING (
    bucket_id = 'academic-materials'
    AND EXISTS (
        SELECT 1
        FROM public.material_versions mv
        JOIN public.materials m
            ON m.id = mv.material_id
        WHERE mv.storage_bucket = objects.bucket_id
          AND mv.storage_path = objects.name
          AND m.is_published = true
    )
);
