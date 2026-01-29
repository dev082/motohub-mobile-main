-- Migration: Smart Tracking - Reduce redundant location history
-- Problem: tracking_historico grows too fast with duplicate/redundant points
-- (e.g., driver stopped or in traffic). This causes database bloat.
--
-- Solution: Update trigger to only INSERT into tracking_historico when:
--   1. Distance > 50 meters from last saved point (ignores GPS drift)
--   2. OR Time > 5 minutes since last save (heartbeat for stopped vehicles)
--   3. OR No previous record exists (first tracking point)
--
-- Note: localizacoes table is ALWAYS updated (real-time), filtering applies only to history.

CREATE OR REPLACE FUNCTION public.sync_localizacoes_to_tracking_historico()
RETURNS TRIGGER AS $$
DECLARE
  last_record RECORD;
  distance_meters FLOAT;
  time_diff_minutes FLOAT;
  should_insert BOOLEAN := FALSE;
BEGIN
  -- tracking_historico requires entrega_id; skip if we don't have it yet
  IF NEW.entrega_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get the last saved tracking point for this entrega
  SELECT latitude, longitude, created_at
  INTO last_record
  FROM public.tracking_historico
  WHERE entrega_id = NEW.entrega_id
  ORDER BY created_at DESC
  LIMIT 1;

  -- Case 1: No previous record exists (first tracking point)
  IF last_record IS NULL THEN
    should_insert := TRUE;
  ELSE
    -- Case 2: Calculate distance using Haversine formula (in meters)
    -- Formula: 2 * R * asin(sqrt(sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlon/2)))
    -- R = 6371000 meters (Earth's radius)
    distance_meters := 2 * 6371000 * asin(sqrt(
      power(sin(radians((NEW.latitude - last_record.latitude) / 2)), 2) +
      cos(radians(last_record.latitude)) * 
      cos(radians(NEW.latitude)) * 
      power(sin(radians((NEW.longitude - last_record.longitude) / 2)), 2)
    ));

    -- Case 3: Calculate time difference in minutes
    time_diff_minutes := EXTRACT(EPOCH FROM (now() - last_record.created_at)) / 60.0;

    -- Insert if distance > 50m OR time > 5 minutes
    IF distance_meters > 50 OR time_diff_minutes > 5 THEN
      should_insert := TRUE;
    END IF;
  END IF;

  -- Only insert if conditions are met
  IF should_insert THEN
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
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add helpful comment
COMMENT ON FUNCTION public.sync_localizacoes_to_tracking_historico() IS 
  'Smart tracking: Only saves to history if moved >50m OR >5min elapsed. Prevents database bloat from GPS drift and stopped vehicles.';
