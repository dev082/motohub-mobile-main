-- =====================================================
-- Fix: use only the supported status_entrega values
--
-- Supported statuses:
--   aguardando, saiu_para_coleta, saiu_para_entrega, entregue, problema, cancelada
--
-- This migration updates the tracking trigger function so it considers the
-- correct set of "active" statuses when deciding which deliveries should
-- receive tracking_historico points.
-- =====================================================

CREATE OR REPLACE FUNCTION public.sync_localizacoes_to_tracking_historico()
RETURNS TRIGGER AS $$
DECLARE
  entrega_record RECORD;
  last_record RECORD;
  distance_meters FLOAT;
  time_diff_minutes FLOAT;
  should_insert BOOLEAN;
BEGIN
  -- Requires motorista_id for delivery lookup.
  IF NEW.motorista_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Loop through ALL active deliveries for this driver.
  -- Active statuses are the ones where we still expect movement/tracking.
  FOR entrega_record IN
    SELECT id, status
    FROM public.entregas
    WHERE motorista_id = NEW.motorista_id
      AND status IN ('aguardando', 'saiu_para_coleta', 'saiu_para_entrega', 'problema')
  LOOP
    should_insert := FALSE;

    -- Last saved point for this delivery.
    SELECT latitude, longitude, created_at
    INTO last_record
    FROM public.tracking_historico
    WHERE entrega_id = entrega_record.id
    ORDER BY created_at DESC
    LIMIT 1;

    IF last_record IS NULL THEN
      should_insert := TRUE;
    ELSE
      distance_meters := 2 * 6371000 * asin(sqrt(
        power(sin(radians((NEW.latitude - last_record.latitude) / 2)), 2) +
        cos(radians(last_record.latitude)) *
        cos(radians(NEW.latitude)) *
        power(sin(radians((NEW.longitude - last_record.longitude) / 2)), 2)
      ));

      time_diff_minutes := EXTRACT(EPOCH FROM (now() - last_record.created_at)) / 60.0;

      IF distance_meters > 50 OR time_diff_minutes > 5 THEN
        should_insert := TRUE;
      END IF;
    END IF;

    IF should_insert THEN
      INSERT INTO public.tracking_historico (
        entrega_id,
        latitude,
        longitude,
        altitude,
        velocidade,
        bussola_pos,
        precisao,
        status,
        created_at
      )
      VALUES (
        entrega_record.id,
        NEW.latitude,
        NEW.longitude,
        NEW.altitude,
        NEW.velocidade,
        NEW.bussola_pos,
        NEW.precisao,
        entrega_record.status,
        now()
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.sync_localizacoes_to_tracking_historico() IS
  'Smart tracking: Busca TODAS entregas ativas do motorista e salva no histórico apenas se: (1) Primeiro registro da entrega; (2) Distância > 50m desde último registro; (3) Tempo > 5min desde último registro. Status suportados: aguardando, saiu_para_coleta, saiu_para_entrega, entregue, problema, cancelada.';
