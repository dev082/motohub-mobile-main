-- Migration: Add checklist_veiculo field and create documentos bucket
-- Description:
-- 1) Adds checklist_veiculo JSONB column to entregas table
-- 2) Creates a public storage bucket `documentos`
-- 3) Adds basic storage policies for authenticated users

-- 1. Add checklist_veiculo column to entregas table
ALTER TABLE public.entregas ADD COLUMN IF NOT EXISTS checklist_veiculo jsonb;

COMMENT ON COLUMN public.entregas.checklist_veiculo
IS 'Checklist de inspeção do veículo antes de iniciar a entrega';

-- 2. Create documentos storage bucket (for comprovantes, POD, etc)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documentos',
  'documentos',
  true,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- 3. Storage policies (CREATE POLICY has no IF NOT EXISTS, so we guard via pg_policies)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Public access to documentos'
  ) THEN
    CREATE POLICY "Public access to documentos"
    ON storage.objects
    FOR SELECT
    USING (bucket_id = 'documentos');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Authenticated users can upload documentos'
  ) THEN
    CREATE POLICY "Authenticated users can upload documentos"
    ON storage.objects
    FOR INSERT
    WITH CHECK (bucket_id = 'documentos' AND auth.role() = 'authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Users can update own documentos'
  ) THEN
    CREATE POLICY "Users can update own documentos"
    ON storage.objects
    FOR UPDATE
    USING (bucket_id = 'documentos' AND auth.role() = 'authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Users can delete own documentos'
  ) THEN
    CREATE POLICY "Users can delete own documentos"
    ON storage.objects
    FOR DELETE
    USING (bucket_id = 'documentos' AND auth.role() = 'authenticated');
  END IF;
END$$;
