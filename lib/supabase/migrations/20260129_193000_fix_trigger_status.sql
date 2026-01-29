-- Fix trigger: Remove reference to non-existent status_entrega column
-- The localizações table has "status" (boolean), not "status_entrega" (enum)
-- We'll derive the status from the entrega's current status instead

CREATE OR REPLACE FUNCTION public.sync_localizacoes_to_tracking_historico()
RETURNS TRIGGER AS $$
DECLARE
  last_record RECORD;
  distance_meters FLOAT;
  time_diff_minutes FLOAT;
  should_insert BOOLEAN := FALSE;
  current_status public.status_entrega;
BEGIN
  -- tracking_historico requires entrega_id; skip if we don't have it yet
  IF NEW.entrega_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get current status from entregas table
  SELECT status INTO current_status
  FROM public.entregas
  WHERE id = NEW.entrega_id
  LIMIT 1;

  -- Default to 'aguardando' if not found
  IF current_status IS NULL THEN
    current_status := 'aguardando'::public.status_entrega;
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
      NEW.bussola_pos,
      current_status,
      now()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add helpful comment
COMMENT ON FUNCTION public.sync_localizacoes_to_tracking_historico() IS 
  'Smart tracking: Only saves to history if moved >50m OR >5min elapsed. Prevents database bloat from GPS drift and stopped vehicles.';
