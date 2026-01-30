-- =====================================================
-- REESTRUTURAÇÃO DAS TABELAS DE TRACKING
-- =====================================================
-- Objetivo: Simplificar 'localizacoes' (real-time) e deixar
-- a lógica complexa para o trigger que popula 'tracking_historico'

-- =====================================================
-- PARTE 1: LIMPAR TABELA 'localizacoes' (real-time)
-- =====================================================

-- 1.1. Remover colunas desnecessárias
ALTER TABLE localizacoes DROP COLUMN IF EXISTS entrega_id;
ALTER TABLE localizacoes DROP COLUMN IF EXISTS email_motorista;
ALTER TABLE localizacoes DROP COLUMN IF EXISTS status;
ALTER TABLE localizacoes DROP COLUMN IF EXISTS visivel;

-- 1.2. Adicionar colunas necessárias
ALTER TABLE localizacoes ADD COLUMN IF NOT EXISTS motorista_id UUID;
ALTER TABLE localizacoes ADD COLUMN IF NOT EXISTS altitude FLOAT;

-- 1.3. Criar foreign key para motoristas
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'localizacoes_motorista_id_fkey'
  ) THEN
    ALTER TABLE localizacoes
    ADD CONSTRAINT localizacoes_motorista_id_fkey
    FOREIGN KEY (motorista_id)
    REFERENCES motoristas(id)
    ON DELETE CASCADE;
  END IF;
END $$;

-- 1.4. Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_localizacoes_motorista_id ON localizacoes(motorista_id);

-- 1.5. Comentários explicativos
COMMENT ON TABLE localizacoes IS 'Posição GPS em tempo real dos motoristas. Apenas última posição de cada motorista. O trigger sync_localizacoes_to_tracking_historico() popula tracking_historico de forma inteligente.';
COMMENT ON COLUMN localizacoes.motorista_id IS 'ID do motorista. Usado para buscar entregas ativas e popular tracking_historico.';
COMMENT ON COLUMN localizacoes.altitude IS 'Altitude em metros. Pode ser NULL se o GPS não fornecer.';

-- =====================================================
-- PARTE 2: ATUALIZAR TABELA 'tracking_historico'
-- =====================================================

-- 2.1. Remover motorista_id (redundante, pois já está em entregas)
ALTER TABLE tracking_historico DROP COLUMN IF EXISTS motorista_id;

-- 2.2. Adicionar entrega_id se não existir
ALTER TABLE tracking_historico ADD COLUMN IF NOT EXISTS entrega_id UUID;

-- 2.3. Adicionar status se não existir
ALTER TABLE tracking_historico ADD COLUMN IF NOT EXISTS status public.status_entrega;

-- 2.4. Criar foreign key para entregas (se não existir)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tracking_historico_entrega_id_fkey'
  ) THEN
    ALTER TABLE tracking_historico
    ADD CONSTRAINT tracking_historico_entrega_id_fkey
    FOREIGN KEY (entrega_id)
    REFERENCES entregas(id)
    ON DELETE CASCADE;
  END IF;
END $$;

-- 2.5. Criar índice composto para buscar histórico por entrega
CREATE INDEX IF NOT EXISTS idx_tracking_historico_entrega_created 
ON tracking_historico(entrega_id, created_at DESC);

-- 2.6. Comentários explicativos
COMMENT ON TABLE tracking_historico IS 'Histórico de rastreamento filtrado de forma inteligente. Salva apenas quando motorista se move >50m OU >5min desde último registro. Um motorista pode gerar múltiplos registros (uma para cada entrega ativa).';
COMMENT ON COLUMN tracking_historico.entrega_id IS 'ID da entrega. Permite rastrear histórico por entrega específica.';
COMMENT ON COLUMN tracking_historico.status IS 'Status da entrega no momento do registro (aguardando, saiu_para_coleta, saiu_para_entrega, entregue, problema, cancelada).';

-- =====================================================
-- PARTE 3: RECRIAR TRIGGER INTELIGENTE
-- =====================================================

-- 3.1. Remover trigger e função antigas
DROP TRIGGER IF EXISTS sync_localizacoes_trigger ON localizacoes;
DROP FUNCTION IF EXISTS public.sync_localizacoes_to_tracking_historico();

-- 3.2. Criar nova função que busca TODAS entregas ativas do motorista
CREATE OR REPLACE FUNCTION public.sync_localizacoes_to_tracking_historico()
RETURNS TRIGGER AS $$
DECLARE
  entrega_record RECORD;
  last_record RECORD;
  distance_meters FLOAT;
  time_diff_minutes FLOAT;
  should_insert BOOLEAN;
BEGIN
  -- Validação: precisa ter motorista_id
  IF NEW.motorista_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Loop em TODAS as entregas ATIVAS do motorista
  -- Status suportados: 'aguardando', 'saiu_para_coleta', 'saiu_para_entrega', 'entregue', 'problema', 'cancelada'
  FOR entrega_record IN
    SELECT id, status
    FROM public.entregas
    WHERE motorista_id = NEW.motorista_id
      AND status IN ('aguardando', 'saiu_para_coleta', 'saiu_para_entrega', 'problema')
  LOOP
    -- Reset flag para cada entrega
    should_insert := FALSE;

    -- Buscar último ponto salvo para ESTA entrega específica
    SELECT latitude, longitude, created_at
    INTO last_record
    FROM public.tracking_historico
    WHERE entrega_id = entrega_record.id
    ORDER BY created_at DESC
    LIMIT 1;

    -- Caso 1: Primeiro registro desta entrega
    IF last_record IS NULL THEN
      should_insert := TRUE;
    ELSE
      -- Caso 2: Calcular distância usando Haversine (em metros)
      distance_meters := 2 * 6371000 * asin(sqrt(
        power(sin(radians((NEW.latitude - last_record.latitude) / 2)), 2) +
        cos(radians(last_record.latitude)) * 
        cos(radians(NEW.latitude)) * 
        power(sin(radians((NEW.longitude - last_record.longitude) / 2)), 2)
      ));

      -- Caso 3: Calcular diferença de tempo (em minutos)
      time_diff_minutes := EXTRACT(EPOCH FROM (now() - last_record.created_at)) / 60.0;

      -- Salvar se: distância > 50m OU tempo > 5 minutos
      IF distance_meters > 50 OR time_diff_minutes > 5 THEN
        should_insert := TRUE;
      END IF;
    END IF;

    -- Inserir no histórico se as condições forem atendidas
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

-- 3.3. Criar trigger
CREATE TRIGGER sync_localizacoes_trigger
  AFTER INSERT OR UPDATE ON localizacoes
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_localizacoes_to_tracking_historico();

-- 3.4. Comentário explicativo
COMMENT ON FUNCTION public.sync_localizacoes_to_tracking_historico() IS 
  'Smart tracking: Busca TODAS entregas ativas do motorista e salva no histórico apenas se: (1) Primeiro registro da entrega; (2) Distância > 50m desde último registro; (3) Tempo > 5min desde último registro. Previne database bloat com GPS drift e veículos parados.';
