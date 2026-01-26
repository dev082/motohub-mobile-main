-- Migration: aceite de carga transacional (entrega + debito capacidade + debito peso disponível)
-- Data: 2026-01-26

-- 1) Entregas: adiciona carroceria_id (opcional)
ALTER TABLE entregas
  ADD COLUMN IF NOT EXISTS carroceria_id UUID REFERENCES carrocerias(id);

CREATE INDEX IF NOT EXISTS idx_entregas_carroceria_id ON entregas(carroceria_id);

-- 2) RPC transacional usado pela Edge Function accept_carga
-- Retorna o registro de entrega criado (em JSON) para facilitar parsing no frontend.
CREATE OR REPLACE FUNCTION public.accept_carga_tx(
  p_motorista_id UUID,
  p_carga_id UUID,
  p_veiculo_id UUID,
  p_carroceria_id UUID,
  p_peso_kg NUMERIC
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_carga RECORD;
  v_veiculo RECORD;
  v_peso_disponivel NUMERIC;
  v_peso_restante NUMERIC;
  v_entrega RECORD;
BEGIN
  IF p_peso_kg IS NULL OR p_peso_kg <= 0 THEN
    RAISE EXCEPTION 'peso_kg_invalido';
  END IF;

  -- Lock veículo e valida propriedade/capacidade.
  SELECT id, motorista_id, capacidade_kg
    INTO v_veiculo
    FROM veiculos
   WHERE id = p_veiculo_id
   FOR UPDATE;

  IF v_veiculo.id IS NULL THEN
    RAISE EXCEPTION 'veiculo_nao_encontrado';
  END IF;
  IF v_veiculo.motorista_id IS DISTINCT FROM p_motorista_id THEN
    RAISE EXCEPTION 'veiculo_nao_pertence_ao_motorista';
  END IF;
  IF v_veiculo.capacidade_kg IS NULL THEN
    RAISE EXCEPTION 'veiculo_sem_capacidade_kg';
  END IF;
  IF p_peso_kg > v_veiculo.capacidade_kg THEN
    RAISE EXCEPTION 'peso_maior_que_capacidade_veiculo';
  END IF;

  -- Lock carga e valida disponibilidade/status.
  SELECT id, codigo, status, peso_kg, peso_disponivel_kg, permite_fracionado
    INTO v_carga
    FROM cargas
   WHERE id = p_carga_id
   FOR UPDATE;

  IF v_carga.id IS NULL THEN
    RAISE EXCEPTION 'carga_nao_encontrada';
  END IF;

  IF NOT (v_carga.status IN ('publicada', 'parcialmente_alocada')) THEN
    RAISE EXCEPTION 'carga_indisponivel';
  END IF;

  IF v_carga.permite_fracionado = false AND p_peso_kg <> v_carga.peso_kg THEN
    RAISE EXCEPTION 'carga_nao_fracionada';
  END IF;

  v_peso_disponivel := COALESCE(v_carga.peso_disponivel_kg, v_carga.peso_kg);
  IF p_peso_kg > v_peso_disponivel THEN
    RAISE EXCEPTION 'peso_maior_que_disponivel_carga';
  END IF;

  -- Debita capacidade do veículo.
  UPDATE veiculos
     SET capacidade_kg = capacidade_kg - p_peso_kg,
         updated_at = now()
   WHERE id = p_veiculo_id;

  -- Cria entrega.
  INSERT INTO entregas (
    carga_id,
    motorista_id,
    veiculo_id,
    carroceria_id,
    status,
    peso_alocado_kg,
    codigo,
    created_at,
    updated_at
  ) VALUES (
    p_carga_id,
    p_motorista_id,
    p_veiculo_id,
    p_carroceria_id,
    'aguardando',
    p_peso_kg,
    v_carga.codigo,
    now(),
    now()
  ) RETURNING * INTO v_entrega;

  -- Debita peso disponível da carga e ajusta status.
  v_peso_restante := v_peso_disponivel - p_peso_kg;

  UPDATE cargas
     SET peso_disponivel_kg = v_peso_restante,
         status = CASE WHEN v_peso_restante <= 0 THEN 'totalmente_alocada' ELSE 'parcialmente_alocada' END,
         updated_at = now()
   WHERE id = p_carga_id;

  RETURN to_jsonb(v_entrega);
END;
$$;

-- Opcional: restringe execução para funções/server. (Edge usa service role, então OK.)
REVOKE ALL ON FUNCTION public.accept_carga_tx(UUID, UUID, UUID, UUID, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_carga_tx(UUID, UUID, UUID, UUID, NUMERIC) TO service_role;
