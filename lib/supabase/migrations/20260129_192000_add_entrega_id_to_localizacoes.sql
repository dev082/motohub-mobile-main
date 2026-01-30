-- Adiciona coluna entrega_id à tabela localizacoes
-- Esta coluna permite rastrear qual entrega o motorista está fazendo no momento

-- 1. Adicionar a coluna entrega_id (nullable por enquanto)
ALTER TABLE localizacoes
ADD COLUMN IF NOT EXISTS entrega_id UUID;

-- 2. Criar foreign key para entregas
ALTER TABLE localizacoes
ADD CONSTRAINT localizacoes_entrega_id_fkey
FOREIGN KEY (entrega_id)
REFERENCES entregas(id)
ON DELETE SET NULL;

-- 3. Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_localizacoes_entrega_id ON localizacoes(entrega_id);

-- 4. Comentário explicativo
COMMENT ON COLUMN localizacoes.entrega_id IS 'ID da entrega atual do motorista. Usado para rastrear localização por entrega no histórico.';
