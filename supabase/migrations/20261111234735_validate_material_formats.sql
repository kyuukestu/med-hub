
-- =========================================================
-- Validate published material formats
-- =========================================================

ALTER TABLE public.materials

ADD CONSTRAINT materials_published_file_has_version
CHECK (
    NOT is_published
    OR format <> 'uploaded_file'
    OR current_version_id IS NOT NULL
);


ALTER TABLE public.materials

ADD CONSTRAINT materials_published_external_link_valid
CHECK (
    NOT is_published
    OR format <> 'external_link'
    OR (
        external_url IS NOT NULL
        AND btrim(external_url) <> ''
        AND external_url ~* '^https?://'
    )
);


ALTER TABLE public.materials

ADD CONSTRAINT materials_published_bibliographic_metadata
CHECK (
    NOT is_published
    OR format <> 'bibliographic_reference'
    OR (
        NULLIF(btrim(author), '') IS NOT NULL
        OR NULLIF(btrim(publication_title), '') IS NOT NULL
        OR NULLIF(btrim(isbn), '') IS NOT NULL
        OR NULLIF(btrim(publisher), '') IS NOT NULL
    )
);
