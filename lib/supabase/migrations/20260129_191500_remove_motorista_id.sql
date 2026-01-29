-- Remove motorista_id column from tracking_historico
-- Reason: motorista_id can be derived from entrega_id via the entregas table
-- This eliminates redundancy and prevents sync errors

ALTER TABLE public.tracking_historico
DROP COLUMN IF EXISTS motorista_id;

COMMENT ON TABLE public.tracking_historico IS 
  'Tracking history (filtered). To get motorista_id, join via entrega_id → entregas → motorista_id.';
