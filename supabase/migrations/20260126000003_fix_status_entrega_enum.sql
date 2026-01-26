-- Fix status_entrega enum to match the Dart model values
-- The Dart code expects: aguardando_coleta, em_coleta, coletado, em_transito, em_entrega, entregue, problema, devolvida, cancelada
-- But the database has: aguardando, saiu_para_coleta, saiu_para_entrega, entregue, problema, cancelada

-- Step 1: Drop the default value constraint temporarily
ALTER TABLE entregas ALTER COLUMN status DROP DEFAULT;

-- Step 2: Create new enum with correct values matching Dart model
CREATE TYPE status_entrega_new AS ENUM (
  'aguardando_coleta',
  'em_coleta',
  'coletado',
  'em_transito',
  'em_entrega',
  'entregue',
  'problema',
  'devolvida',
  'cancelada'
);

-- Step 3: Migrate existing data to new enum values
-- Map old values to new values before type conversion
UPDATE entregas SET status = 'aguardando_coleta'::text WHERE status::text = 'aguardando';
UPDATE entregas SET status = 'em_coleta'::text WHERE status::text = 'saiu_para_coleta';
UPDATE entregas SET status = 'em_entrega'::text WHERE status::text = 'saiu_para_entrega';
-- 'entregue', 'problema', 'cancelada' already match and stay the same

-- Step 4: Update tracking_historico first (has FK constraint)
ALTER TABLE tracking_historico 
  ALTER COLUMN status TYPE status_entrega_new 
  USING (
    CASE status::text
      WHEN 'aguardando' THEN 'aguardando_coleta'
      WHEN 'saiu_para_coleta' THEN 'em_coleta'
      WHEN 'saiu_para_entrega' THEN 'em_entrega'
      ELSE status::text
    END
  )::status_entrega_new;

-- Step 5: Convert entregas column to new enum type
ALTER TABLE entregas 
  ALTER COLUMN status TYPE status_entrega_new 
  USING status::text::status_entrega_new;

-- Step 6: Drop old enum and rename new one
DROP TYPE status_entrega;
ALTER TYPE status_entrega_new RENAME TO status_entrega;

-- Step 7: Restore default value
ALTER TABLE entregas ALTER COLUMN status SET DEFAULT 'aguardando_coleta'::status_entrega;
