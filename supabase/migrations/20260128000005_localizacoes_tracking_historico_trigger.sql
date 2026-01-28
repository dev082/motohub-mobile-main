-- =====================================================
-- Fix: Real-time location → tracking_historico sync
--
-- Problem we are solving:
-- - The app writes the driver's current position into public."localizações".
-- - tracking_historico must record EVERY point for a delivery.
-- - The previous trigger file targeted columns that do not exist in "localizações"
--   (and it wasn't timestamped, so it may not be applied as a migration).
--
-- This migration:
-- 1) Extends public."localizações" with the minimum fields needed to create history rows.
-- 2) Creates a trigger that inserts into public.tracking_historico on INSERT/UPDATE.
-- 3) Only inserts when NEW.entrega_id is present.
-- =====================================================

-- 1) Ensure required columns exist in public."localizações"
ALTER TABLE IF EXISTS public."localizações"
  ADD COLUMN IF NOT EXISTS entrega_id UUID REFERENCES public.entregas(id) ON DELETE SET NULL;

ALTER TABLE IF EXISTS public."localizações"
  ADD COLUMN IF NOT EXISTS status_entrega public.status_entrega;

ALTER TABLE IF EXISTS public."localizações"
  ADD COLUMN IF NOT EXISTS accuracy NUMERIC(6, 2);

ALTER TABLE IF EXISTS public."localizações"
  ADD COLUMN IF NOT EXISTS heading NUMERIC(6, 2);

ALTER TABLE IF EXISTS public."localizações"
  ADD COLUMN IF NOT EXISTS altitude NUMERIC(8, 2);

ALTER TABLE IF EXISTS public."localizações"
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Keep updated_at fresh
CREATE OR REPLACE FUNCTION public.set_localizacoes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_localizacoes_set_updated_at ON public."localizações";
CREATE TRIGGER trigger_localizacoes_set_updated_at
  BEFORE UPDATE ON public."localizações"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_localizacoes_updated_at();

-- 2) Trigger function: copy to tracking_historico
CREATE OR REPLACE FUNCTION public.sync_localizacoes_to_tracking_historico()
RETURNS TRIGGER AS $$
BEGIN
  -- tracking_historico requires entrega_id; skip if we don't have it yet
  IF NEW.entrega_id IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.tracking_historico (
    entrega_id,
    latitude,
    longitude,
    velocidade,
    bussola_pos,
    status,
    created_at
  )
  VALUES (
    NEW.entrega_id,
    NEW.latitude,
    NEW.longitude,
    NEW.velocidade,
    COALESCE(NEW.bussola_pos, NEW.heading),
    COALESCE(NEW.status_entrega, 'saiu_para_entrega'::public.status_entrega),
    now()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3) Trigger on INSERT/UPDATE
DROP TRIGGER IF EXISTS trigger_localizacoes_to_historico ON public."localizações";
CREATE TRIGGER trigger_localizacoes_to_historico
  AFTER INSERT OR UPDATE ON public."localizações"
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_localizacoes_to_tracking_historico();
