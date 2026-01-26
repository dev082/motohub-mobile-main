-- Migration: Adicionar tabelas para eventos, POD, geofences, documentos, KPIs e auditoria
-- Data: 2026-01-26 14:34:16

-- =====================================================
-- 1) TABELA DE EVENTOS DE ENTREGA (TIMELINE + AUDITORIA)
-- =====================================================
CREATE TABLE IF NOT EXISTS entrega_eventos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entrega_id UUID NOT NULL REFERENCES entregas(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN (
    'aceite', 'inicio_coleta', 'chegada_coleta', 'carregou', 
    'inicio_rota', 'parada', 'chegada_destino', 'descarregou', 
    'finalizado', 'problema', 'cancelado', 'desvio_rota', 
    'parada_prolongada', 'velocidade_anormal', 'perda_sinal', 
    'recuperacao_sinal', 'entrada_geofence', 'saida_geofence'
  )),
  timestamp TIMESTAMPTZ NOT NULL,
  observacao TEXT,
  latitude NUMERIC,
  longitude NUMERIC,
  user_id UUID,
  user_nome TEXT,
  foto_url TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_entrega_eventos_entrega_id ON entrega_eventos(entrega_id);
CREATE INDEX idx_entrega_eventos_timestamp ON entrega_eventos(timestamp);
CREATE INDEX idx_entrega_eventos_tipo ON entrega_eventos(tipo);

ALTER TABLE entrega_eventos ENABLE ROW LEVEL SECURITY;

CREATE POLICY entrega_eventos_select ON entrega_eventos
  FOR SELECT USING (true);

CREATE POLICY entrega_eventos_all ON entrega_eventos
  FOR ALL USING (auth.uid() IS NOT NULL);

-- =====================================================
-- 2) TABELA DE PROVAS DE ENTREGA (POD)
-- =====================================================
CREATE TABLE IF NOT EXISTS provas_entrega (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entrega_id UUID NOT NULL UNIQUE REFERENCES entregas(id) ON DELETE CASCADE,
  assinatura_url TEXT,
  fotos_urls TEXT[] DEFAULT '{}',
  nome_recebedor TEXT NOT NULL,
  documento_recebedor TEXT,
  timestamp TIMESTAMPTZ NOT NULL,
  checklist JSONB NOT NULL DEFAULT '{
    "avarias_constatadas": false,
    "lacre_intacto": true,
    "quantidade_conferida": true,
    "nota_fiscal_presente": true
  }'::jsonb,
  observacoes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_provas_entrega_entrega_id ON provas_entrega(entrega_id);

ALTER TABLE provas_entrega ENABLE ROW LEVEL SECURITY;

CREATE POLICY provas_entrega_select ON provas_entrega
  FOR SELECT USING (true);

CREATE POLICY provas_entrega_all ON provas_entrega
  FOR ALL USING (auth.uid() IS NOT NULL);

-- =====================================================
-- 3) TABELA DE GEOFENCES
-- =====================================================
CREATE TABLE IF NOT EXISTS geofences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entrega_id UUID REFERENCES entregas(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  latitude NUMERIC NOT NULL,
  longitude NUMERIC NOT NULL,
  raio_metros NUMERIC NOT NULL DEFAULT 200.0,
  tipo TEXT NOT NULL CHECK (tipo IN ('origem', 'destino', 'parada', 'personalizado')),
  ativo BOOLEAN NOT NULL DEFAULT true,
  notificar_entrada BOOLEAN NOT NULL DEFAULT true,
  notificar_saida BOOLEAN NOT NULL DEFAULT false,
  mudar_status_auto BOOLEAN NOT NULL DEFAULT false,
  status_apos_entrada TEXT,
  status_apos_saida TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_geofences_entrega_id ON geofences(entrega_id);
CREATE INDEX idx_geofences_ativo ON geofences(ativo);

ALTER TABLE geofences ENABLE ROW LEVEL SECURITY;

CREATE POLICY geofences_select ON geofences
  FOR SELECT USING (true);

CREATE POLICY geofences_all ON geofences
  FOR ALL USING (auth.uid() IS NOT NULL);

-- =====================================================
-- 4) TABELA DE DOCUMENTOS COM VALIDAÇÃO
-- =====================================================
CREATE TABLE IF NOT EXISTS documentos_validacao (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  motorista_id UUID REFERENCES motoristas(id) ON DELETE CASCADE,
  veiculo_id UUID REFERENCES veiculos(id) ON DELETE CASCADE,
  carroceria_id UUID REFERENCES carrocerias(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('cnh', 'crlv', 'antt', 'seguro', 'tacografo', 'outro')),
  numero TEXT NOT NULL,
  url TEXT,
  data_emissao DATE,
  data_vencimento DATE,
  status TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('ok', 'vence_30_dias', 'vence_15_dias', 'vence_7_dias', 'vencido', 'pendente')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (motorista_id IS NOT NULL AND veiculo_id IS NULL AND carroceria_id IS NULL) OR
    (motorista_id IS NULL AND veiculo_id IS NOT NULL AND carroceria_id IS NULL) OR
    (motorista_id IS NULL AND veiculo_id IS NULL AND carroceria_id IS NOT NULL)
  )
);

CREATE INDEX idx_documentos_motorista_id ON documentos_validacao(motorista_id);
CREATE INDEX idx_documentos_veiculo_id ON documentos_validacao(veiculo_id);
CREATE INDEX idx_documentos_carroceria_id ON documentos_validacao(carroceria_id);
CREATE INDEX idx_documentos_status ON documentos_validacao(status);
CREATE INDEX idx_documentos_vencimento ON documentos_validacao(data_vencimento);

ALTER TABLE documentos_validacao ENABLE ROW LEVEL SECURITY;

CREATE POLICY documentos_select ON documentos_validacao
  FOR SELECT USING (true);

CREATE POLICY documentos_all ON documentos_validacao
  FOR ALL USING (auth.uid() IS NOT NULL);

-- =====================================================
-- 5) TABELAS DE KPIs E CUSTOS
-- =====================================================
CREATE TABLE IF NOT EXISTS motorista_kpis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  motorista_id UUID NOT NULL REFERENCES motoristas(id) ON DELETE CASCADE,
  periodo_inicio DATE NOT NULL,
  periodo_fim DATE NOT NULL,
  km_rodado NUMERIC DEFAULT 0.0,
  tempo_em_rota_minutos INTEGER DEFAULT 0,
  tempo_parado_minutos INTEGER DEFAULT 0,
  consumo_estimado_litros NUMERIC DEFAULT 0.0,
  custo_estimado NUMERIC DEFAULT 0.0,
  entregas_finalizadas INTEGER DEFAULT 0,
  entregas_atrasadas INTEGER DEFAULT 0,
  taxa_atraso NUMERIC DEFAULT 0.0,
  media_pedagios NUMERIC DEFAULT 0.0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_motorista_kpis_motorista_id ON motorista_kpis(motorista_id);
CREATE INDEX idx_motorista_kpis_periodo ON motorista_kpis(periodo_inicio, periodo_fim);

CREATE TABLE IF NOT EXISTS veiculo_custo_config (
  veiculo_id UUID PRIMARY KEY REFERENCES veiculos(id) ON DELETE CASCADE,
  consumo_urbano_km_l NUMERIC DEFAULT 4.0,
  consumo_rodoviario_km_l NUMERIC DEFAULT 5.5,
  custo_por_km NUMERIC DEFAULT 2.5,
  pedagio_medio NUMERIC DEFAULT 15.0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE motorista_kpis ENABLE ROW LEVEL SECURITY;
ALTER TABLE veiculo_custo_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY motorista_kpis_select ON motorista_kpis
  FOR SELECT USING (true);

CREATE POLICY motorista_kpis_all ON motorista_kpis
  FOR ALL USING (auth.uid() IS NOT NULL);

CREATE POLICY veiculo_custo_select ON veiculo_custo_config
  FOR SELECT USING (true);

CREATE POLICY veiculo_custo_all ON veiculo_custo_config
  FOR ALL USING (auth.uid() IS NOT NULL);

-- =====================================================
-- 6) ADICIONAR CAMPOS DE AUDITORIA
-- =====================================================
ALTER TABLE veiculos ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
ALTER TABLE veiculos ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id);

ALTER TABLE carrocerias ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
ALTER TABLE carrocerias ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id);

ALTER TABLE entregas ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
ALTER TABLE entregas ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id);

-- =====================================================
-- 7) TABELA DE LOGS DE AUDITORIA
-- =====================================================
CREATE TABLE IF NOT EXISTS auditoria_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tabela TEXT NOT NULL,
  registro_id UUID NOT NULL,
  operacao TEXT NOT NULL CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE')),
  usuario_id UUID,
  dados_anteriores JSONB,
  dados_novos JSONB,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_auditoria_tabela_registro ON auditoria_logs(tabela, registro_id);
CREATE INDEX idx_auditoria_usuario_id ON auditoria_logs(usuario_id);
CREATE INDEX idx_auditoria_timestamp ON auditoria_logs(timestamp);

ALTER TABLE auditoria_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY auditoria_logs_select ON auditoria_logs
  FOR SELECT USING (true);

-- =====================================================
-- 8) ADICIONAR CAMPOS PARA ARMAZENAR FOTOS_URLS COMO ARRAY
-- =====================================================
ALTER TABLE veiculos ADD COLUMN IF NOT EXISTS fotos_urls TEXT[] DEFAULT '{}';
ALTER TABLE carrocerias ADD COLUMN IF NOT EXISTS fotos_urls TEXT[] DEFAULT '{}';