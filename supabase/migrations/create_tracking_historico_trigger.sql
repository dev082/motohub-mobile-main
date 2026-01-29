-- Função trigger que copia atualizações de localizações para tracking_historico
-- quando há uma entrega ativa
CREATE OR REPLACE FUNCTION trigger_localizacoes_to_historico()
RETURNS TRIGGER AS $$
BEGIN
  -- Busca a entrega ativa para este motorista
  -- (entrega mais recente com status em rota)
  INSERT INTO tracking_historico (
    entrega_id,
    latitude,
    longitude,
    bussola_pos,
    velocidade,
    status,
    observacao,
    created_at
  )
  SELECT 
    e.id,
    NEW.latitude,
    NEW.longitude,
    NEW.bussola_pos,
    NEW.velocidade,
    e.status,
    'Auto-tracking'::text,
    NOW()
  FROM entregas e
  INNER JOIN motoristas m ON m.id = e.motorista_id
  WHERE m.email = NEW.email_motorista
    AND e.status IN ('saiu_para_coleta', 'saiu_para_entrega')
  ORDER BY e.updated_at DESC
  LIMIT 1;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Cria o trigger na tabela localizações
DROP TRIGGER IF EXISTS on_localizacoes_update ON localizações;
CREATE TRIGGER on_localizacoes_update
  AFTER INSERT OR UPDATE ON localizações
  FOR EACH ROW
  EXECUTE FUNCTION trigger_localizacoes_to_historico();
