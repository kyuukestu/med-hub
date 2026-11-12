-- =========================================================
-- Restrict Storage reads to object retrieval operations
-- =========================================================

DROP POLICY IF EXISTS
    "Public can view published material files"
ON storage.objects;

DROP POLICY IF EXISTS
    "Users can view published material files"
ON storage.objects;


CREATE POLICY "Public can view published material files"
ON storage.objects
FOR SELECT
TO anon
USING (
    bucket_id = 'academic-materials'

    AND storage.allow_any_operation(
        ARRAY[
            'object.get_authenticated_info',
            'object.get_authenticated'
        ]
    )

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


CREATE POLICY "Users can view published material files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'academic-materials'

    AND storage.allow_any_operation(
        ARRAY[
            'object.get_authenticated_info',
            'object.get_authenticated'
        ]
    )

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
