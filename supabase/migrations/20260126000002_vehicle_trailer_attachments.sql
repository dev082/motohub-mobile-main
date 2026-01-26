-- Add attachment fields for veiculos and carrocerias

ALTER TABLE IF EXISTS public.veiculos
  ADD COLUMN IF NOT EXISTS fotos_urls JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS tipo_propriedade TEXT,
  ADD COLUMN IF NOT EXISTS uf TEXT,
  ADD COLUMN IF NOT EXISTS documento_veiculo_url TEXT,
  ADD COLUMN IF NOT EXISTS comprovante_endereco_proprietario_url TEXT,
  ADD COLUMN IF NOT EXISTS proprietario_nome TEXT,
  ADD COLUMN IF NOT EXISTS proprietario_cpf_cnpj TEXT;

ALTER TABLE IF EXISTS public.carrocerias
  ADD COLUMN IF NOT EXISTS fotos_urls JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS uf TEXT,
  ADD COLUMN IF NOT EXISTS documento_carroceria_url TEXT,
  ADD COLUMN IF NOT EXISTS antt_rntrc TEXT,
  ADD COLUMN IF NOT EXISTS comprovante_endereco_proprietario_url TEXT,
  ADD COLUMN IF NOT EXISTS tipo_propriedade TEXT;
