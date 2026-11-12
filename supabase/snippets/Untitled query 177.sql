SELECT
    tablename,
    policyname,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
      'materials',
      'material_links',
      'material_versions'
  )
ORDER BY tablename, policyname;