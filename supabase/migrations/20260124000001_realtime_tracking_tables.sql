-- Tabela de localizacoes em tempo real (locations)
CREATE TABLE IF NOT EXISTS public.locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entrega_id UUID NOT NULL REFERENCES public.entregas(id) ON DELETE CASCADE,
  motorista_id UUID NOT NULL REFERENCES public.motoristas(id) ON DELETE CASCADE,
  latitude NUMERIC(10, 7) NOT NULL,
  longitude NUMERIC(10, 7) NOT NULL,
  accuracy NUMERIC(6, 2), -- precisão em metros
  speed NUMERIC(6, 2), -- velocidade em km/h
  heading NUMERIC(5, 2), -- direção em graus (0-360)
  altitude NUMERIC(8, 2), -- altitude em metros
  battery_level INTEGER, -- nível de bateria (0-100)
  is_moving BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para performance
CREATE INDEX idx_locations_entrega ON public.locations(entrega_id);
CREATE INDEX idx_locations_motorista ON public.locations(motorista_id);
CREATE INDEX idx_locations_created_at ON public.locations(created_at DESC);

-- Índice geoespacial para consultas de proximidade
CREATE INDEX idx_locations_geog ON public.locations USING GIST (
  ll_to_earth(latitude::float, longitude::float)
);

-- Tabela de sessões de rastreamento
CREATE TABLE IF NOT EXISTS public.tracking_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entrega_id UUID NOT NULL REFERENCES public.entregas(id) ON DELETE CASCADE,
  motorista_id UUID NOT NULL REFERENCES public.motoristas(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'cancelled')),
  total_distance_km NUMERIC(10, 2) DEFAULT 0,
  total_duration_seconds INTEGER DEFAULT 0,
  average_speed_kmh NUMERIC(6, 2),
  max_speed_kmh NUMERIC(6, 2),
  points_collected INTEGER DEFAULT 0,
  last_location_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_tracking_sessions_entrega ON public.tracking_sessions(entrega_id);
CREATE INDEX idx_tracking_sessions_motorista ON public.tracking_sessions(motorista_id);
CREATE INDEX idx_tracking_sessions_status ON public.tracking_sessions(status);

-- Tabela de dispositivos para notificações
CREATE TABLE IF NOT EXISTS public.devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  motorista_id UUID REFERENCES public.motoristas(id) ON DELETE CASCADE,
  device_token TEXT,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  app_version TEXT,
  os_version TEXT,
  last_active_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, device_token)
);

CREATE INDEX idx_devices_user ON public.devices(user_id);
CREATE INDEX idx_devices_motorista ON public.devices(motorista_id);

-- Tabela de log de notificações
CREATE TABLE IF NOT EXISTS public.notifications_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entrega_id UUID REFERENCES public.entregas(id) ON DELETE CASCADE,
  motorista_id UUID REFERENCES public.motoristas(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN (
    'coleta_iniciada',
    'chegada_origem',
    'coleta_concluida',
    'em_transito',
    'chegada_destino',
    'entrega_concluida',
    'desvio_rota',
    'bateria_baixa',
    'offline',
    'eta_update',
    'status_change'
  )),
  titulo TEXT NOT NULL,
  mensagem TEXT NOT NULL,
  dados JSONB DEFAULT '{}'::jsonb,
  enviada_em TIMESTAMPTZ DEFAULT now(),
  lida BOOLEAN DEFAULT false
);

CREATE INDEX idx_notifications_log_entrega ON public.notifications_log(entrega_id);
CREATE INDEX idx_notifications_log_motorista ON public.notifications_log(motorista_id);
CREATE INDEX idx_notifications_log_tipo ON public.notifications_log(tipo);
CREATE INDEX idx_notifications_log_enviada ON public.notifications_log(enviada_em DESC);

-- Habilitar RLS (Row Level Security)
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracking_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies para locations
CREATE POLICY "Motoristas podem inserir suas localizacoes"
  ON public.locations FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.motoristas WHERE id = motorista_id)
  );

CREATE POLICY "Motoristas podem ver suas localizacoes"
  ON public.locations FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (SELECT user_id FROM public.motoristas WHERE id = motorista_id)
  );

CREATE POLICY "Embarcadores podem ver localizacoes de suas entregas"
  ON public.locations FOR SELECT
  TO authenticated
  USING (
    entrega_id IN (
      SELECT e.id FROM public.entregas e
      INNER JOIN public.cargas c ON e.carga_id = c.id
      INNER JOIN public.usuarios u ON u.auth_user_id = auth.uid()
      WHERE c.empresa_id IS NOT NULL
    )
  );

-- RLS Policies para tracking_sessions
CREATE POLICY "Motoristas podem gerenciar suas sessões"
  ON public.tracking_sessions FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (SELECT user_id FROM public.motoristas WHERE id = motorista_id)
  );

CREATE POLICY "Embarcadores podem ver sessões de suas entregas"
  ON public.tracking_sessions FOR SELECT
  TO authenticated
  USING (
    entrega_id IN (
      SELECT e.id FROM public.entregas e
      INNER JOIN public.cargas c ON e.carga_id = c.id
      INNER JOIN public.usuarios u ON u.auth_user_id = auth.uid()
      WHERE c.empresa_id IS NOT NULL
    )
  );

-- RLS Policies para devices
CREATE POLICY "Usuários podem gerenciar seus dispositivos"
  ON public.devices FOR ALL
  TO authenticated
  USING (user_id = auth.uid());

-- RLS Policies para notifications_log
CREATE POLICY "Motoristas podem ver suas notificações"
  ON public.notifications_log FOR SELECT
  TO authenticated
  USING (
    motorista_id IN (SELECT id FROM public.motoristas WHERE user_id = auth.uid())
  );

CREATE POLICY "Sistema pode inserir notificações"
  ON public.notifications_log FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Habilitar Realtime para as tabelas
ALTER PUBLICATION supabase_realtime ADD TABLE public.locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tracking_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications_log;

-- Function para calcular distância entre dois pontos (Haversine)
CREATE OR REPLACE FUNCTION public.calculate_distance_km(
  lat1 NUMERIC, lon1 NUMERIC, lat2 NUMERIC, lon2 NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
  earth_radius CONSTANT NUMERIC := 6371.0; -- km
  dlat NUMERIC;
  dlon NUMERIC;
  a NUMERIC;
  c NUMERIC;
BEGIN
  dlat := radians(lat2 - lat1);
  dlon := radians(lon2 - lon1);
  a := sin(dlat / 2) * sin(dlat / 2) +
       cos(radians(lat1)) * cos(radians(lat2)) *
       sin(dlon / 2) * sin(dlon / 2);
  c := 2 * atan2(sqrt(a), sqrt(1 - a));
  RETURN earth_radius * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Trigger para atualizar tracking_sessions automaticamente
CREATE OR REPLACE FUNCTION public.update_tracking_session_stats()
RETURNS TRIGGER AS $$
DECLARE
  prev_location RECORD;
  distance_km NUMERIC;
  time_diff_seconds INTEGER;
BEGIN
  -- Buscar localização anterior da mesma sessão
  SELECT latitude, longitude, created_at INTO prev_location
  FROM public.locations
  WHERE entrega_id = NEW.entrega_id
    AND created_at < NEW.created_at
  ORDER BY created_at DESC
  LIMIT 1;

  IF prev_location IS NOT NULL THEN
    -- Calcular distância
    distance_km := public.calculate_distance_km(
      prev_location.latitude,
      prev_location.longitude,
      NEW.latitude,
      NEW.longitude
    );

    -- Calcular diferença de tempo
    time_diff_seconds := EXTRACT(EPOCH FROM (NEW.created_at - prev_location.created_at))::INTEGER;

    -- Atualizar sessão ativa
    UPDATE public.tracking_sessions
    SET
      total_distance_km = total_distance_km + distance_km,
      total_duration_seconds = total_duration_seconds + time_diff_seconds,
      points_collected = points_collected + 1,
      last_location_at = NEW.created_at,
      max_speed_kmh = GREATEST(COALESCE(max_speed_kmh, 0), COALESCE(NEW.speed, 0)),
      average_speed_kmh = CASE
        WHEN total_duration_seconds + time_diff_seconds > 0
        THEN ((total_distance_km + distance_km) / (total_duration_seconds + time_diff_seconds)) * 3600
        ELSE 0
      END
    WHERE entrega_id = NEW.entrega_id
      AND status = 'active';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_tracking_stats
  AFTER INSERT ON public.locations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_tracking_session_stats();

-- Comentários nas tabelas
COMMENT ON TABLE public.locations IS 'Armazena pontos de localização em tempo real dos motoristas durante entregas';
COMMENT ON TABLE public.tracking_sessions IS 'Gerencia sessões de rastreamento com métricas agregadas';
COMMENT ON TABLE public.devices IS 'Registra dispositivos dos usuários para notificações locais';
COMMENT ON TABLE public.notifications_log IS 'Log de todas as notificações enviadas aos motoristas';
