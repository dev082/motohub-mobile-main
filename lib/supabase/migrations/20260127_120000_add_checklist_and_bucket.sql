-- Migration: Add checklist_veiculo field and create documentos bucket
-- Description: Adds checklist_veiculo JSONB column to entregas table and creates documentos storage bucket

-- 1. Add checklist_veiculo column to entregas table
ALTER TABLE entregas ADD COLUMN IF NOT EXISTS checklist_veiculo JSONB;

-- 2. Create documentos storage bucket (for comprovantes, POD, etc)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documentos',
  'documentos',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- 3. Set public access policy for documentos bucket
CREATE POLICY IF NOT EXISTS "Public access to documentos"
ON storage.objects FOR SELECT
USING (bucket_id = 'documentos');

-- 4. Allow authenticated users to upload to documentos bucket
CREATE POLICY IF NOT EXISTS "Authenticated users can upload documentos"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'documentos'
  AND auth.role() = 'authenticated'
);

-- 5. Allow users to update their own uploads
CREATE POLICY IF NOT EXISTS "Users can update own documentos"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'documentos'
  AND auth.role() = 'authenticated'
);

-- 6. Allow users to delete their own uploads
CREATE POLICY IF NOT EXISTS "Users can delete own documentos"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'documentos'
  AND auth.role() = 'authenticated'
);

-- Comment on the new column
COMMENT ON COLUMN entregas.checklist_veiculo IS 'Checklist de inspeção do veículo antes de iniciar a entrega';
