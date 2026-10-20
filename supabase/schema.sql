-- ==============================================================================
-- CONECTAPREFEITURA SAAS - SCHEMA DO BANCO DE DADOS SUPABASE (POSTGRESQL)
-- Etapa 1: Estrutura multi-prefeitura, RLS, Secretarias, Catálogo e Protocolos
--
-- Como executar:
-- 1. Acesse o painel do Supabase (https://supabase.com/dashboard)
-- 2. Selecione seu projeto (mnhtavsafskhiodywfat)
-- 3. No menu lateral esquerdo, clique em "SQL Editor"
-- 4. Cole todo o conteúdo deste arquivo e clique no botão "Run" (Executar)
-- ==============================================================================

-- Habilita extensões necessárias
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- LIMPEZA PREVENTIVA: REMOVE TODAS AS POLICIES, TRIGGERS E FUNÇÕES ANTIGAS
-- Evita erros de colunas com tipos incompatíveis (ex: user_id = auth.uid() uuid = text)
-- ==============================================================================
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public' LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
    END LOOP;
END $$;

DROP FUNCTION IF EXISTS public.meu_papel() CASCADE;
DROP FUNCTION IF EXISTS public.minha_prefeitura() CASCADE;
DROP FUNCTION IF EXISTS public.minha_prefeitura_id() CASCADE;
DROP FUNCTION IF EXISTS public.minha_secretaria() CASCADE;
DROP FUNCTION IF EXISTS public.minha_secretaria_id() CASCADE;
DROP FUNCTION IF EXISTS public.abrir_solicitacao(jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.abrir_solicitacao() CASCADE;
DROP FUNCTION IF EXISTS public.consultar_protocolo(text, text) CASCADE;
DROP FUNCTION IF EXISTS public.consultar_protocolo(text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.listar_meus_pedidos(text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.semear_prefeitura(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.gerar_proximo_protocolo() CASCADE;
DROP FUNCTION IF EXISTS public.gerar_codigo_publico() CASCADE;
DROP FUNCTION IF EXISTS public.trg_solicitacoes_gerar_protocolo() CASCADE;
DROP FUNCTION IF EXISTS public.antes_inserir_solicitacao() CASCADE;
DROP FUNCTION IF EXISTS public.registrar_historico() CASCADE;

DO $$ 
DECLARE
    r RECORD;
BEGIN
    DROP TRIGGER IF EXISTS trg_solicitacoes_antes_inserir ON public.solicitacoes CASCADE;
    DROP TRIGGER IF EXISTS trg_solicitacao_historico ON public.solicitacoes CASCADE;
    DROP TRIGGER IF EXISTS trg_antes_inserir_solicitacao ON public.solicitacoes CASCADE;
    DROP TRIGGER IF EXISTS trg_historico ON public.solicitacoes CASCADE;
    DROP TRIGGER IF EXISTS trigger_atualizar_solicitacoes ON public.solicitacoes CASCADE;
    DROP TRIGGER IF EXISTS trg_solicitacoes_updated ON public.solicitacoes CASCADE;
    DROP TRIGGER IF EXISTS trigger_solicitacoes_updated_at ON public.solicitacoes CASCADE;
    DROP TRIGGER IF EXISTS trg_before_insert_solicitacao ON public.solicitacoes CASCADE;

    FOR r IN (
        SELECT tgname, relname 
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' 
          AND c.relname = 'solicitacoes'
          AND NOT t.tgisinternal
    ) LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I CASCADE', r.tgname, r.relname);
    END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ==============================================================================
-- 1. TABELA DE PREFEITURAS (MUNICÍPIOS DO SUL DO ES)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.prefeituras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    cidade TEXT NOT NULL,
    uf VARCHAR(2) NOT NULL DEFAULT 'ES',
    lat NUMERIC,
    lng NUMERIC,
    brasao_url TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Garante colunas caso a tabela já existisse
ALTER TABLE public.prefeituras
    ADD COLUMN IF NOT EXISTS nome TEXT,
    ADD COLUMN IF NOT EXISTS cidade TEXT,
    ADD COLUMN IF NOT EXISTS uf VARCHAR(2) DEFAULT 'ES',
    ADD COLUMN IF NOT EXISTS lat NUMERIC,
    ADD COLUMN IF NOT EXISTS lng NUMERIC,
    ADD COLUMN IF NOT EXISTS brasao_url TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- ==============================================================================
-- 2. SEED DAS 27 PREFEITURAS DO SUL DO ESPÍRITO SANTO (UUIDs FIXOS)
-- ==============================================================================
INSERT INTO public.prefeituras (id, nome, cidade, uf, lat, lng, brasao_url) VALUES
('e0011111-0001-0001-0001-000000000001', 'Prefeitura Municipal de Cachoeiro de Itapemirim', 'Cachoeiro de Itapemirim', 'ES', -20.8489, -41.1128, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000002', 'Prefeitura Municipal de Itapemirim', 'Itapemirim', 'ES', -21.0111, -40.8339, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000003', 'Prefeitura Municipal de Marataízes', 'Marataízes', 'ES', -21.0433, -40.8244, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000004', 'Prefeitura Municipal de Anchieta', 'Anchieta', 'ES', -20.8058, -40.6453, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000005', 'Prefeitura Municipal de Piúma', 'Piúma', 'ES', -20.8336, -40.7297, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000006', 'Prefeitura Municipal de Iconha', 'Iconha', 'ES', -20.7931, -40.8108, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000007', 'Prefeitura Municipal de Rio Novo do Sul', 'Rio Novo do Sul', 'ES', -20.8625, -40.9358, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000008', 'Prefeitura Municipal de Presidente Kennedy', 'Presidente Kennedy', 'ES', -21.0967, -41.0478, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000009', 'Prefeitura Municipal de Castelo', 'Castelo', 'ES', -20.6036, -41.2033, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000010', 'Prefeitura Municipal de Vargem Alta', 'Vargem Alta', 'ES', -20.6719, -41.0078, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000011', 'Prefeitura Municipal de Muqui', 'Muqui', 'ES', -20.9525, -41.3458, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000012', 'Prefeitura Municipal de Mimoso do Sul', 'Mimoso do Sul', 'ES', -21.0642, -41.3653, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000013', 'Prefeitura Municipal de Atílio Vivácqua', 'Atílio Vivácqua', 'ES', -20.9142, -41.1983, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000014', 'Prefeitura Municipal de Alegre', 'Alegre', 'ES', -20.7631, -41.5331, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000015', 'Prefeitura Municipal de Guaçuí', 'Guaçuí', 'ES', -20.7761, -41.6792, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000016', 'Prefeitura Municipal de São José do Calçado', 'São José do Calçado', 'ES', -20.9822, -41.6547, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000017', 'Prefeitura Municipal de Bom Jesus do Norte', 'Bom Jesus do Norte', 'ES', -21.1897, -41.6703, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000018', 'Prefeitura Municipal de Apiacá', 'Apiacá', 'ES', -21.1542, -41.5678, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000019', 'Prefeitura Municipal de Jerônimo Monteiro', 'Jerônimo Monteiro', 'ES', -20.7903, -41.3967, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000020', 'Prefeitura Municipal de Ibitirama', 'Ibitirama', 'ES', -20.5417, -41.6708, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000021', 'Prefeitura Municipal de Divino de São Lourenço', 'Divino de São Lourenço', 'ES', -20.6206, -41.6853, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000022', 'Prefeitura Municipal de Dores do Rio Preto', 'Dores do Rio Preto', 'ES', -20.6894, -41.8456, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000023', 'Prefeitura Municipal de Iúna', 'Iúna', 'ES', -20.3458, -41.5358, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000024', 'Prefeitura Municipal de Irupi', 'Irupi', 'ES', -20.3456, -41.6425, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000025', 'Prefeitura Municipal de Ibatiba', 'Ibatiba', 'ES', -20.2339, -41.5111, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120'),
('e0011111-0001-0001-0001-000000000026', 'Prefeitura Municipal de Muniz Freire', 'Muniz Freire', 'ES', -20.4642, -41.4131, 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120'),
('e0011111-0001-0001-0001-000000000027', 'Prefeitura Municipal de Alfredo Chaves', 'Alfredo Chaves', 'ES', -20.6358, -40.7511, 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120')
ON CONFLICT (id) DO UPDATE SET
    nome = EXCLUDED.nome,
    cidade = EXCLUDED.cidade,
    uf = EXCLUDED.uf,
    lat = EXCLUDED.lat,
    lng = EXCLUDED.lng,
    brasao_url = EXCLUDED.brasao_url;

-- ==============================================================================
-- 3. TABELA DE SECRETARIAS MUNICIPAIS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.secretarias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prefeitura_id UUID NOT NULL REFERENCES public.prefeituras(id) ON DELETE CASCADE,
    nome TEXT NOT NULL,
    sigla TEXT NOT NULL,
    categoria TEXT,
    icone TEXT DEFAULT '🏛️',
    ativa BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Compatibilidade idempotente: relaxa restrições antigas e garante colunas necessárias
DO $$ BEGIN
    ALTER TABLE public.secretarias ALTER COLUMN categoria DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

ALTER TABLE public.secretarias
    ADD COLUMN IF NOT EXISTS categoria TEXT,
    ADD COLUMN IF NOT EXISTS icone TEXT DEFAULT '🏛️',
    ADD COLUMN IF NOT EXISTS ativa BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Sincroniza campos booleano ativo/ativa
UPDATE public.secretarias SET ativa = coalesce(ativa, ativo, true);

-- Remove duplicatas legadas de (prefeitura_id, sigla) se houver, mantendo a mais recente
DELETE FROM public.secretarias a
USING public.secretarias b
WHERE a.ctid < b.ctid 
  AND a.prefeitura_id = b.prefeitura_id 
  AND a.sigla = b.sigla;

-- Constraint de unicidade por prefeitura e sigla
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'secretarias_prefeitura_id_sigla_key'
    ) THEN
        ALTER TABLE public.secretarias ADD CONSTRAINT secretarias_prefeitura_id_sigla_key UNIQUE (prefeitura_id, sigla);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ==============================================================================
-- 4. TABELA DE USUÁRIOS DA PREFEITURA (VINCULADA AO SUPABASE AUTH)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.usuarios_prefeitura (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    prefeitura_id UUID NOT NULL REFERENCES public.prefeituras(id) ON DELETE CASCADE,
    nome TEXT,
    email TEXT,
    papel TEXT NOT NULL CHECK (papel IN ('ADMIN', 'SERVIDOR')),
    secretaria_id UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
    ativo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==============================================================================
-- 5. TABELA DE CATÁLOGO DE SERVIÇOS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.catalogo_servicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prefeitura_id UUID NOT NULL REFERENCES public.prefeituras(id) ON DELETE CASCADE,
    secretaria_id UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
    categoria TEXT DEFAULT 'GERAL',
    secretaria_sigla TEXT,
    secretaria_nome TEXT,
    nome TEXT NOT NULL,
    icone TEXT NOT NULL DEFAULT '📌',
    descricao TEXT,
    tipo_fluxo TEXT DEFAULT 'AGENDAMENTO',
    exige_unidade_saude BOOLEAN NOT NULL DEFAULT false,
    exige_endereco BOOLEAN NOT NULL DEFAULT false,
    exige_cartao_sus BOOLEAN NOT NULL DEFAULT false,
    campos_personalizados JSONB NOT NULL DEFAULT '[]'::jsonb,
    prazo_estimado_dias INT NOT NULL DEFAULT 3,
    agendamento_direto_72h BOOLEAN NOT NULL DEFAULT false,
    ativo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Compatibilidade idempotente no catálogo de serviços
DO $$ BEGIN
    ALTER TABLE public.catalogo_servicos ALTER COLUMN categoria DROP NOT NULL;
    ALTER TABLE public.catalogo_servicos ALTER COLUMN categoria SET DEFAULT 'GERAL';
    ALTER TABLE public.catalogo_servicos ALTER COLUMN tipo_fluxo DROP NOT NULL;
    ALTER TABLE public.catalogo_servicos ALTER COLUMN tipo_fluxo SET DEFAULT 'AGENDAMENTO';
EXCEPTION WHEN OTHERS THEN NULL; END $$;

ALTER TABLE public.catalogo_servicos
    ADD COLUMN IF NOT EXISTS secretaria_id UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS categoria TEXT DEFAULT 'GERAL',
    ADD COLUMN IF NOT EXISTS secretaria_sigla TEXT,
    ADD COLUMN IF NOT EXISTS secretaria_nome TEXT,
    ADD COLUMN IF NOT EXISTS descricao TEXT,
    ADD COLUMN IF NOT EXISTS agendamento_direto_72h BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS prazo_estimado_dias INT DEFAULT 3,
    ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT true;

-- ==============================================================================
-- 6. TABELA DE SOLICITAÇÕES / PROTOCOLOS DOS CIDADÃOS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.solicitacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    protocolo TEXT UNIQUE,
    protocolo_publico TEXT UNIQUE,
    prefeitura_id UUID NOT NULL REFERENCES public.prefeituras(id) ON DELETE CASCADE,
    secretaria_id UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
    servico_id TEXT,
    servico_nome TEXT,
    servico_icone TEXT DEFAULT '📌',
    setor_responsavel TEXT,
    setor_sigla TEXT,
    cidadao_nome TEXT NOT NULL,
    cidadao_cpf TEXT NOT NULL,
    cidadao_telefone TEXT NOT NULL,
    cartao_sus TEXT,
    endereco_gps TEXT,
    endereco_rua TEXT,
    endereco_numero TEXT,
    endereco_bairro TEXT,
    endereco_referencia TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    google_maps_url TEXT,
    waze_url TEXT,
    google_maps_rota TEXT,
    unidade_preferencia TEXT,
    turno_preferencia TEXT,
    tipo_atendimento TEXT DEFAULT 'PRESENCIAL',
    descricao TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDENTE',
    resposta_prefeitura TEXT,
    agendado_para TIMESTAMPTZ,
    prazo_limite TIMESTAMPTZ,
    concluido_em TIMESTAMPTZ,
    observacao_conclusao TEXT,
    respostas_personalizadas JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Compatibilidade idempotente na tabela solicitacoes
DO $$ BEGIN
    -- Converte protocolo para TEXT (se era BIGINT ou IDENTITY antigo)
    ALTER TABLE public.solicitacoes ALTER COLUMN protocolo DROP IDENTITY IF EXISTS;
    ALTER TABLE public.solicitacoes ALTER COLUMN protocolo DROP DEFAULT;
    ALTER TABLE public.solicitacoes ALTER COLUMN protocolo TYPE TEXT USING protocolo::text;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
    -- Permite que servico_id seja texto universal e sem FK restritiva
    ALTER TABLE public.solicitacoes DROP CONSTRAINT IF EXISTS solicitacoes_servico_id_fkey;
    ALTER TABLE public.solicitacoes ALTER COLUMN servico_id TYPE TEXT USING servico_id::text;
    ALTER TABLE public.solicitacoes ALTER COLUMN servico_id DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
    -- Se colunas legadas user_id ou cidadao_id existirem, garante que não barrem inserts anônimos
    ALTER TABLE public.solicitacoes ALTER COLUMN cidadao_id DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
    ALTER TABLE public.solicitacoes ALTER COLUMN user_id DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Garante todas as colunas necessárias em solicitacoes
ALTER TABLE public.solicitacoes
    ADD COLUMN IF NOT EXISTS protocolo TEXT,
    ADD COLUMN IF NOT EXISTS protocolo_publico TEXT,
    ADD COLUMN IF NOT EXISTS secretaria_id UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS servico_id TEXT,
    ADD COLUMN IF NOT EXISTS servico_nome TEXT,
    ADD COLUMN IF NOT EXISTS servico_icone TEXT DEFAULT '📌',
    ADD COLUMN IF NOT EXISTS setor_responsavel TEXT,
    ADD COLUMN IF NOT EXISTS setor_sigla TEXT,
    ADD COLUMN IF NOT EXISTS endereco_rua TEXT,
    ADD COLUMN IF NOT EXISTS endereco_numero TEXT,
    ADD COLUMN IF NOT EXISTS endereco_bairro TEXT,
    ADD COLUMN IF NOT EXISTS endereco_referencia TEXT,
    ADD COLUMN IF NOT EXISTS latitude NUMERIC,
    ADD COLUMN IF NOT EXISTS longitude NUMERIC,
    ADD COLUMN IF NOT EXISTS google_maps_url TEXT,
    ADD COLUMN IF NOT EXISTS waze_url TEXT,
    ADD COLUMN IF NOT EXISTS google_maps_rota TEXT,
    ADD COLUMN IF NOT EXISTS tipo_atendimento TEXT DEFAULT 'PRESENCIAL',
    ADD COLUMN IF NOT EXISTS agendado_para TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS prazo_limite TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS concluido_em TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS observacao_conclusao TEXT,
    ADD COLUMN IF NOT EXISTS respostas_personalizadas JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Ajusta constraint de status permitindo os status oficiais
DO $$ BEGIN
    ALTER TABLE public.solicitacoes DROP CONSTRAINT IF EXISTS solicitacoes_status_check;
    ALTER TABLE public.solicitacoes ADD CONSTRAINT solicitacoes_status_check 
        CHECK (status IN ('PENDENTE', 'AGENDADO', 'CONCLUIDO', 'CANCELADO', 'EM_ANDAMENTO', 'Em Andamento', 'Pendente', 'Concluído', 'Cancelado'));
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Garante constraints únicas para protocolos se ainda não existirem
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'solicitacoes_protocolo_key') THEN
        ALTER TABLE public.solicitacoes ADD CONSTRAINT solicitacoes_protocolo_key UNIQUE (protocolo);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'solicitacoes_protocolo_publico_key') THEN
        ALTER TABLE public.solicitacoes ADD CONSTRAINT solicitacoes_protocolo_publico_key UNIQUE (protocolo_publico);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Índices de alta performance
CREATE INDEX IF NOT EXISTS idx_solicitacoes_pref_status_created 
    ON public.solicitacoes (prefeitura_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_solicitacoes_cidadao_cpf 
    ON public.solicitacoes (cidadao_cpf);
CREATE INDEX IF NOT EXISTS idx_solicitacoes_secretaria_id 
    ON public.solicitacoes (secretaria_id);

-- ==============================================================================
-- 7. GERADOR SEQUENCIAL DE PROTOCOLO (AAAA-NNNNNN) E CÓDIGO PÚBLICO ALEATÓRIO
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.protocolo_sequencias (
    ano INT PRIMARY KEY,
    ultimo_numero BIGINT NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION public.gerar_proximo_protocolo()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ano INT := EXTRACT(YEAR FROM timezone('America/Sao_Paulo', now()))::INT;
    v_numero BIGINT;
BEGIN
    INSERT INTO public.protocolo_sequencias (ano, ultimo_numero)
    VALUES (v_ano, 1)
    ON CONFLICT (ano) DO UPDATE
    SET ultimo_numero = public.protocolo_sequencias.ultimo_numero + 1
    RETURNING ultimo_numero INTO v_numero;

    RETURN v_ano::text || '-' || lpad(v_numero::text, 6, '0');
END;
$$;

CREATE OR REPLACE FUNCTION public.gerar_codigo_publico()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    chars CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    resultado TEXT := '';
    i INT;
BEGIN
    FOR i IN 1..8 LOOP
        resultado := resultado || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    RETURN resultado;
END;
$$;

-- Trigger BEFORE INSERT na tabela solicitacoes
CREATE OR REPLACE FUNCTION public.trg_solicitacoes_gerar_protocolo()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.protocolo IS NULL OR NEW.protocolo = '' THEN
        NEW.protocolo := public.gerar_proximo_protocolo();
    END IF;
    IF NEW.protocolo_publico IS NULL OR NEW.protocolo_publico = '' THEN
        NEW.protocolo_publico := public.gerar_codigo_publico();
    END IF;
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$;

-- Limpeza de triggers legados que causam incompatibilidade de tipos
DROP TRIGGER IF EXISTS trg_antes_inserir_solicitacao ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trg_historico ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trg_solicitacoes_antes_inserir ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trg_solicitacao_historico ON public.solicitacoes CASCADE;
DROP FUNCTION IF EXISTS public.antes_inserir_solicitacao() CASCADE;
DROP FUNCTION IF EXISTS public.registrar_historico() CASCADE;

DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT tgname, relname 
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' 
          AND c.relname = 'solicitacoes'
          AND NOT t.tgisinternal
          AND tgname <> 'trg_before_insert_solicitacao'
    ) LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I CASCADE', r.tgname, r.relname);
    END LOOP;
END $$;

DROP TRIGGER IF EXISTS trg_before_insert_solicitacao ON public.solicitacoes;
CREATE TRIGGER trg_before_insert_solicitacao
BEFORE INSERT ON public.solicitacoes
FOR EACH ROW
EXECUTE FUNCTION public.trg_solicitacoes_gerar_protocolo();

-- ==============================================================================
-- 8. FUNÇÃO DE SEED IDEMPOTENTE PARA AS 27 PREFEITURAS
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.semear_prefeitura(p_prefeitura_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_semus_id UUID;
    v_semct_id UUID;
    v_semob_id UUID;
    v_seme_id  UUID;
    v_semds_id UUID;
BEGIN
    -- 1. Cria ou recupera as 5 Secretarias Padrão (incluindo coluna categoria explícita)
    INSERT INTO public.secretarias (prefeitura_id, nome, sigla, categoria, icone, ativa)
    VALUES (p_prefeitura_id, 'Secretaria Municipal de Saúde', 'SEMUS', 'SAUDE', '🏥', true)
    ON CONFLICT (prefeitura_id, sigla) DO UPDATE SET 
        nome = EXCLUDED.nome,
        categoria = coalesce(EXCLUDED.categoria, secretarias.categoria),
        icone = coalesce(EXCLUDED.icone, secretarias.icone),
        ativa = true
    RETURNING id INTO v_semus_id;

    INSERT INTO public.secretarias (prefeitura_id, nome, sigla, categoria, icone, ativa)
    VALUES (p_prefeitura_id, 'Secretaria de Cidadania, Trabalho e Direitos Humanos', 'SEMCT', 'CIDADANIA', '📝', true)
    ON CONFLICT (prefeitura_id, sigla) DO UPDATE SET 
        nome = EXCLUDED.nome,
        categoria = coalesce(EXCLUDED.categoria, secretarias.categoria),
        icone = coalesce(EXCLUDED.icone, secretarias.icone),
        ativa = true
    RETURNING id INTO v_semct_id;

    INSERT INTO public.secretarias (prefeitura_id, nome, sigla, categoria, icone, ativa)
    VALUES (p_prefeitura_id, 'Secretaria de Manutenção, Serviços e Obras (SEMOB / Zeladoria)', 'SEMOB', 'ZELADORIA', '🧹', true)
    ON CONFLICT (prefeitura_id, sigla) DO UPDATE SET 
        nome = EXCLUDED.nome,
        categoria = coalesce(EXCLUDED.categoria, secretarias.categoria),
        icone = coalesce(EXCLUDED.icone, secretarias.icone),
        ativa = true
    RETURNING id INTO v_semob_id;

    INSERT INTO public.secretarias (prefeitura_id, nome, sigla, categoria, icone, ativa)
    VALUES (p_prefeitura_id, 'Secretaria Municipal de Educação (SEME)', 'SEME', 'EDUCACAO', '🏫', true)
    ON CONFLICT (prefeitura_id, sigla) DO UPDATE SET 
        nome = EXCLUDED.nome,
        categoria = coalesce(EXCLUDED.categoria, secretarias.categoria),
        icone = coalesce(EXCLUDED.icone, secretarias.icone),
        ativa = true
    RETURNING id INTO v_seme_id;

    INSERT INTO public.secretarias (prefeitura_id, nome, sigla, categoria, icone, ativa)
    VALUES (p_prefeitura_id, 'Secretaria de Desenvolvimento Social e Habitação', 'SEMDS', 'SOCIAL', '🏠', true)
    ON CONFLICT (prefeitura_id, sigla) DO UPDATE SET 
        nome = EXCLUDED.nome,
        categoria = coalesce(EXCLUDED.categoria, secretarias.categoria),
        icone = coalesce(EXCLUDED.icone, secretarias.icone),
        ativa = true
    RETURNING id INTO v_semds_id;

    -- 2. Insere os 17 serviços do SERVICOS_BASE se ainda não existirem para esta prefeitura
    -- SAÚDE (SEMUS)
    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Consultas Médicas (UBS) - Clínico Geral e Pediatria') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semus_id, 'SAUDE', 'SEMUS', 'Secretaria Municipal de Saúde', 'Consultas Médicas (UBS) - Clínico Geral e Pediatria', '🩺', 'AGENDAMENTO', true, false, false, 3, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Atendimento Odontológico / Dentista (UBS e CEO)') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semus_id, 'SAUDE', 'SEMUS', 'Secretaria Municipal de Saúde', 'Atendimento Odontológico / Dentista (UBS e CEO)', '🦷', 'AGENDAMENTO', true, false, false, 3, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Vacinação - Calendário Nacional e Campanhas') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semus_id, 'SAUDE', 'SEMUS', 'Secretaria Municipal de Saúde', 'Vacinação - Calendário Nacional e Campanhas', '💉', 'AGENDAMENTO', true, false, false, 2, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Distribuição de Medicamentos (Farmácia Básica)') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semus_id, 'SAUDE', 'SEMUS', 'Secretaria Municipal de Saúde', 'Distribuição de Medicamentos (Farmácia Básica)', '💊', 'AGENDAMENTO', false, false, false, 1, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Pronto-Atendimento / UPA 24h (Orientações)') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semus_id, 'SAUDE', 'SEMUS', 'Secretaria Municipal de Saúde', 'Pronto-Atendimento / UPA 24h (Orientações)', '🚑', 'DOCUMENTACAO', false, false, false, 1, false, true);
    END IF;

    -- CIDADANIA (SEMCT)
    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Emissão de 2ª Via de Certidões') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semct_id, 'CIDADANIA', 'SEMCT', 'Secretaria de Cidadania, Trabalho e Direitos Humanos', 'Emissão de 2ª Via de Certidões', '📜', 'DOCUMENTACAO', false, false, false, 5, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Junta Militar - Alistamento e Certificados') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semct_id, 'CIDADANIA', 'SEMCT', 'Secretaria de Cidadania, Trabalho e Direitos Humanos', 'Junta Militar - Alistamento e Certificados', '🎖️', 'DOCUMENTACAO', false, false, false, 3, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'PAT / Agência do Trabalhador e Empregos') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semct_id, 'CIDADANIA', 'SEMCT', 'Secretaria de Cidadania, Trabalho e Direitos Humanos', 'PAT / Agência do Trabalhador e Empregos', '💼', 'AGENDAMENTO', false, false, false, 2, false, true);
    END IF;

    -- ZELADORIA (SEMOB - ATÉ 72H)
    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Coleta de Lixo Especial e Cata-Treco') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semob_id, 'ZELADORIA', 'SEMOB', 'Secretaria de Manutenção, Serviços e Obras (SEMOB / Zeladoria)', 'Coleta de Lixo Especial e Cata-Treco', '🚛', 'ZELADORIA', false, true, false, 3, true, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Iluminação Pública - Troca de Lâmpadas') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semob_id, 'ZELADORIA', 'SEMOB', 'Secretaria de Manutenção, Serviços e Obras (SEMOB / Zeladoria)', 'Iluminação Pública - Troca de Lâmpadas', '💡', 'ZELADORIA', false, true, false, 3, true, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Manutenção de Vias - Operação Tapa-Buraco') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semob_id, 'ZELADORIA', 'SEMOB', 'Secretaria de Manutenção, Serviços e Obras (SEMOB / Zeladoria)', 'Manutenção de Vias - Operação Tapa-Buraco', '🚧', 'ZELADORIA', false, true, false, 3, true, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Limpeza e Paisagismo - Corte de Mato e Praças') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semob_id, 'ZELADORIA', 'SEMOB', 'Secretaria de Manutenção, Serviços e Obras (SEMOB / Zeladoria)', 'Limpeza e Paisagismo - Corte de Mato e Praças', '🌳', 'ZELADORIA', false, true, false, 3, true, true);
    END IF;

    -- EDUCAÇÃO (SEME)
    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Creches e Pré-Escolas - Inscrição e Vagas') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_seme_id, 'EDUCACAO', 'SEME', 'Secretaria Municipal de Educação (SEME)', 'Creches e Pré-Escolas - Inscrição e Vagas', '👶', 'DOCUMENTACAO', false, true, false, 7, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Ensino Fundamental I e II - Matrículas') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_seme_id, 'EDUCACAO', 'SEME', 'Secretaria Municipal de Educação (SEME)', 'Ensino Fundamental I e II - Matrículas', '🎒', 'DOCUMENTACAO', false, false, false, 5, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Transporte Escolar (Rotas, Pontos e Carteirinha)') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_seme_id, 'EDUCACAO', 'SEME', 'Secretaria Municipal de Educação (SEME)', 'Transporte Escolar (Rotas, Pontos e Carteirinha)', '🚌', 'ZELADORIA', false, true, false, 3, true, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Alimentação e Merenda Escolar (Cardápio e Dietas)') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_seme_id, 'EDUCACAO', 'SEME', 'Secretaria Municipal de Educação (SEME)', 'Alimentação e Merenda Escolar (Cardápio e Dietas)', '🍎', 'DOCUMENTACAO', false, false, false, 3, false, true);
    END IF;

    -- SOCIAL (SEMDS)
    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'CRAS e CREAS - CadÚnico e Bolsa Família') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semds_id, 'SOCIAL', 'SEMDS', 'Secretaria de Desenvolvimento Social e Habitação', 'CRAS e CREAS - CadÚnico e Bolsa Família', '🤝', 'AGENDAMENTO', false, false, false, 3, false, true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id::text = p_prefeitura_id::text AND nome = 'Programas Habitacionais e Moradia Popular') THEN
        INSERT INTO public.catalogo_servicos (prefeitura_id, secretaria_id, categoria, secretaria_sigla, secretaria_nome, nome, icone, tipo_fluxo, exige_unidade_saude, exige_endereco, exige_cartao_sus, prazo_estimado_dias, agendamento_direto_72h, ativo)
        VALUES (p_prefeitura_id, v_semds_id, 'SOCIAL', 'SEMDS', 'Secretaria de Desenvolvimento Social e Habitação', 'Programas Habitacionais e Moradia Popular', '🏡', 'DOCUMENTACAO', false, true, false, 10, false, true);
    END IF;
END;
$$;

-- Executa o seed para todas as prefeituras oficiais do Sul do ES
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id FROM public.prefeituras WHERE id::text LIKE 'e0011111-%' LOOP
        PERFORM public.semear_prefeitura(r.id);
    END LOOP;
END $$;

-- Garante remoção de constraint restritiva do Cartão SUS e desativa a exigência
ALTER TABLE public.solicitacoes DROP CONSTRAINT IF EXISTS solicitacoes_cartao_sus_check;
ALTER TABLE public.solicitacoes ALTER COLUMN cartao_sus DROP NOT NULL;
UPDATE public.catalogo_servicos SET exige_cartao_sus = false;

-- ==============================================================================
-- 9. FUNÇÕES DE SUPORTE E SEGURANÇA (SECURITY DEFINER)
-- ==============================================================================

-- Retorna a prefeitura_id do usuário logado no Auth
CREATE OR REPLACE FUNCTION public.minha_prefeitura_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT coalesce(
        (SELECT prefeitura_id FROM public.usuarios_prefeitura WHERE user_id = auth.uid() AND ativo = true LIMIT 1),
        (SELECT prefeitura_id FROM public.perfis WHERE id = auth.uid() LIMIT 1)
    );
$$;

-- Alias para compatibilidade
CREATE OR REPLACE FUNCTION public.minha_prefeitura()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.minha_prefeitura_id();
$$;

-- Retorna o papel do usuário logado ('ADMIN' ou 'SERVIDOR')
CREATE OR REPLACE FUNCTION public.meu_papel()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT coalesce(
        (SELECT papel FROM public.usuarios_prefeitura WHERE user_id = auth.uid() AND ativo = true LIMIT 1),
        (SELECT papel::text FROM public.perfis WHERE id = auth.uid() LIMIT 1),
        'CIDADAO'
    );
$$;

-- Retorna a secretaria_id do usuário logado (se for SERVIDOR)
CREATE OR REPLACE FUNCTION public.minha_secretaria_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT coalesce(
        (SELECT secretaria_id FROM public.usuarios_prefeitura WHERE user_id = auth.uid() AND ativo = true LIMIT 1),
        (SELECT secretaria_id FROM public.perfis WHERE id = auth.uid() LIMIT 1)
    );
$$;

-- Alias para compatibilidade
CREATE OR REPLACE FUNCTION public.minha_secretaria()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.minha_secretaria_id();
$$;

-- ==============================================================================
-- 10. RPC PÚBLICA: abrir_solicitacao(payload jsonb)
-- Usada pelo app do cidadão para registrar pedidos sem necessidade de login.
-- Valida dados obrigatórios, gera protocolo e devolve dados do comprovante.
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.abrir_solicitacao(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pref_id UUID;
    v_serv_id TEXT;
    v_cid_nome TEXT;
    v_cid_cpf TEXT;
    v_cid_tel TEXT;
    v_cpf_limpo TEXT;
    v_desc TEXT;
    v_serv RECORD;
    v_secretaria_id UUID;
    v_setor_nome TEXT;
    v_setor_sigla TEXT;
    v_setor_icone TEXT;
    v_is_campo_72h BOOLEAN;
    v_status TEXT;
    v_resposta TEXT;
    v_agendado_para TIMESTAMPTZ;
    v_prazo_limite TIMESTAMPTZ;
    v_novo_id UUID;
    v_protocolo TEXT;
    v_protocolo_publico TEXT;
    v_created_at TIMESTAMPTZ;
BEGIN
    -- 1. Extração e Validação dos Campos Obrigatórios
    v_pref_id := (payload->>'prefeitura_id')::UUID;
    v_serv_id := payload->>'servico_id';
    v_cid_nome := trim(coalesce(payload->>'cidadao_nome', ''));
    v_cid_cpf := trim(coalesce(payload->>'cidadao_cpf', ''));
    v_cid_tel := trim(coalesce(payload->>'cidadao_telefone', ''));
    v_desc := trim(coalesce(payload->>'descricao', ''));

    IF v_pref_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.prefeituras WHERE id::text = v_pref_id::text) THEN
        RAISE EXCEPTION 'Município inválido ou não informado.';
    END IF;

    IF v_cid_nome = '' THEN
        RAISE EXCEPTION 'Nome completo do cidadão é obrigatório.';
    END IF;

    v_cpf_limpo := regexp_replace(v_cid_cpf, '\D', '', 'g');
    IF length(v_cpf_limpo) <> 11 THEN
        RAISE EXCEPTION 'CPF deve conter exatamente 11 dígitos.';
    END IF;

    IF v_cid_tel = '' THEN
        RAISE EXCEPTION 'Telefone / WhatsApp com DDD é obrigatório.';
    END IF;

    IF v_desc = '' THEN
        RAISE EXCEPTION 'Descrição do pedido é obrigatória.';
    END IF;

    -- 2. Busca informações do serviço no catálogo
    SELECT s.*, sec.id AS sec_id, sec.nome AS sec_nome, sec.sigla AS sec_sigla, sec.icone AS sec_icone
    INTO v_serv
    FROM public.catalogo_servicos s
    LEFT JOIN public.secretarias sec ON sec.id::text = s.secretaria_id::text
    WHERE s.prefeitura_id::text = v_pref_id::text 
      AND (s.id::text = v_serv_id::text OR s.nome = (payload->>'servico_nome'))
      AND s.ativo = true
    LIMIT 1;

    -- Define secretaria e nomes
    IF v_serv.id IS NOT NULL THEN
        v_secretaria_id := v_serv.sec_id;
        v_setor_nome := coalesce(v_serv.sec_nome, v_serv.secretaria_nome, 'Secretaria Municipal');
        v_setor_sigla := coalesce(v_serv.sec_sigla, v_serv.secretaria_sigla, 'SEM');
        v_setor_icone := coalesce(v_serv.sec_icone, v_serv.icone, '🏛️');
        v_is_campo_72h := coalesce(v_serv.agendamento_direto_72h, false) OR (v_serv.categoria = 'ZELADORIA') OR (v_serv.tipo_fluxo = 'ZELADORIA');
    ELSE
        -- Fallback seguro para serviços enviados pelo app
        v_secretaria_id := NULL;
        v_setor_nome := coalesce(payload->>'setor_responsavel', 'Secretaria Competente');
        v_setor_sigla := coalesce(payload->>'setor_sigla', 'GAB');
        v_setor_icone := coalesce(payload->>'servico_icone', '📌');
        v_is_campo_72h := (payload->>'tipo_atendimento' = 'CAMPO_72H') OR ((payload->>'servico_nome') ILIKE '%Iluminação%') OR ((payload->>'servico_nome') ILIKE '%Lixo%');
    END IF;

    -- 3. Define prazos e status
    IF v_is_campo_72h THEN
        v_status := 'AGENDADO';
        v_agendado_para := timezone('utc'::text, now()) + interval '72 hours';
        v_prazo_limite := v_agendado_para;
        v_resposta := 'Ordem de serviço aberta e despachada para a equipe de campo! O atendimento no local informado será realizado em até 72 horas.';
    ELSE
        v_status := 'PENDENTE';
        v_agendado_para := NULL;
        v_prazo_limite := NULL;
        v_resposta := NULL;
    END IF;

    -- 4. Insere no banco de dados (o trigger preenche protocolo e protocolo_publico)
    INSERT INTO public.solicitacoes (
        prefeitura_id,
        secretaria_id,
        servico_id,
        servico_nome,
        servico_icone,
        setor_responsavel,
        setor_sigla,
        cidadao_nome,
        cidadao_cpf,
        cidadao_telefone,
        cartao_sus,
        endereco_gps,
        endereco_rua,
        endereco_numero,
        endereco_bairro,
        endereco_referencia,
        latitude,
        longitude,
        google_maps_url,
        waze_url,
        google_maps_rota,
        unidade_preferencia,
        turno_preferencia,
        tipo_atendimento,
        descricao,
        status,
        resposta_prefeitura,
        agendado_para,
        prazo_limite,
        respostas_personalizadas
    ) VALUES (
        v_pref_id,
        v_secretaria_id,
        v_serv_id,
        coalesce(payload->>'servico_nome', v_serv.nome, 'Atendimento Geral'),
        coalesce(payload->>'servico_icone', v_serv.icone, '📌'),
        v_setor_nome,
        v_setor_sigla,
        v_cid_nome,
        v_cid_cpf,
        v_cid_tel,
        nullif(trim(payload->>'cartao_sus'), ''),
        payload->>'endereco_gps',
        payload->>'endereco_rua',
        payload->>'endereco_numero',
        payload->>'endereco_bairro',
        payload->>'endereco_referencia',
        (payload->>'latitude')::NUMERIC,
        (payload->>'longitude')::NUMERIC,
        payload->>'google_maps_url',
        payload->>'waze_url',
        payload->>'google_maps_rota',
        payload->>'unidade_preferencia',
        payload->>'turno_preferencia',
        CASE WHEN v_is_campo_72h THEN 'CAMPO_72H' ELSE 'PRESENCIAL' END,
        v_desc,
        v_status,
        v_resposta,
        v_agendado_para,
        v_prazo_limite,
        coalesce(payload->'respostas_personalizadas', '{}'::jsonb)
    )
    RETURNING id, protocolo, protocolo_publico, created_at
    INTO v_novo_id, v_protocolo, v_protocolo_publico, v_created_at;

    -- 5. Retorna o comprovante gerado com sucesso
    RETURN jsonb_build_object(
        'success', true,
        'id', v_novo_id,
        'protocolo', v_protocolo,
        'protocolo_publico', v_protocolo_publico,
        'status', v_status,
        'resposta_prefeitura', v_resposta,
        'created_at', v_created_at
    );
END;
$$;

-- ==============================================================================
-- 11. RPC PÚBLICA: consultar_protocolo(p_cpf text, p_codigo text)
-- Permite ao cidadão consultar o andamento informando CPF + Código Público ou Protocolo
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.consultar_protocolo(p_cpf TEXT, p_codigo TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cpf_limpo TEXT;
    v_cod_limpo TEXT;
    v_sol RECORD;
BEGIN
    v_cpf_limpo := regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g');
    v_cod_limpo := trim(upper(coalesce(p_codigo, '')));

    IF length(v_cpf_limpo) < 4 OR v_cod_limpo = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Informe o CPF e o Código de Protocolo.');
    END IF;

    SELECT s.id, s.protocolo, s.protocolo_publico, s.servico_nome, s.servico_icone,
           s.setor_responsavel, s.setor_sigla, s.status, s.tipo_atendimento,
           s.resposta_prefeitura, s.agendado_para, s.prazo_limite, s.concluido_em,
           s.endereco_gps, s.unidade_preferencia, s.turno_preferencia, s.descricao,
           s.created_at, p.cidade, p.uf
    INTO v_sol
    FROM public.solicitacoes s
    JOIN public.prefeituras p ON p.id::text = s.prefeitura_id::text
    WHERE (
            upper(s.protocolo_publico) = v_cod_limpo 
            OR upper(s.protocolo) = v_cod_limpo 
            OR replace(s.protocolo, '-', '') = replace(v_cod_limpo, '-', '')
          )
      AND (
            regexp_replace(s.cidadao_cpf, '\D', '', 'g') = v_cpf_limpo
            OR regexp_replace(s.cidadao_cpf, '\D', '', 'g') LIKE ('%' || v_cpf_limpo)
          )
    LIMIT 1;

    IF v_sol.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Nenhum protocolo localizado para este CPF e Código informados.');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'dados', jsonb_build_object(
            'id', v_sol.id,
            'protocolo', v_sol.protocolo,
            'protocolo_publico', v_sol.protocolo_publico,
            'servico_nome', v_sol.servico_nome,
            'servico_icone', v_sol.servico_icone,
            'setor_responsavel', v_sol.setor_responsavel,
            'setor_sigla', v_sol.setor_sigla,
            'status', v_sol.status,
            'tipo_atendimento', v_sol.tipo_atendimento,
            'resposta_prefeitura', v_sol.resposta_prefeitura,
            'agendado_para', v_sol.agendado_para,
            'prazo_limite', v_sol.prazo_limite,
            'concluido_em', v_sol.concluido_em,
            'endereco_gps', v_sol.endereco_gps,
            'unidade_preferencia', v_sol.unidade_preferencia,
            'turno_preferencia', v_sol.turno_preferencia,
            'descricao', v_sol.descricao,
            'created_at', v_sol.created_at,
            'cidade', v_sol.cidade,
            'uf', v_sol.uf
        )
    );
END;
$$;

-- ==============================================================================
-- 12. RPC PÚBLICA: listar_meus_pedidos(p_cpf text, p_prefeitura_id uuid)
-- Usada na aba "Meus Protocolos" do app do cidadão
-- Devolve apenas os dados seguros dos chamados daquele CPF
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.listar_meus_pedidos(p_cpf TEXT, p_prefeitura_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cpf_limpo TEXT;
    v_resultado JSONB;
BEGIN
    v_cpf_limpo := regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g');

    IF length(v_cpf_limpo) <> 11 THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT coalesce(jsonb_agg(
        jsonb_build_object(
            'id', s.id,
            'protocolo', s.protocolo,
            'protocolo_publico', s.protocolo_publico,
            'servico_id', s.servico_id,
            'servico_nome', s.servico_nome,
            'servico_icone', s.servico_icone,
            'setor_responsavel', s.setor_responsavel,
            'setor_sigla', s.setor_sigla,
            'tipo_atendimento', s.tipo_atendimento,
            'status', s.status,
            'resposta_prefeitura', s.resposta_prefeitura,
            'agendado_para', s.agendado_para,
            'prazo_limite', s.prazo_limite,
            'concluido_em', s.concluido_em,
            'endereco_gps', s.endereco_gps,
            'latitude', s.latitude,
            'longitude', s.longitude,
            'google_maps_url', s.google_maps_url,
            'unidade_preferencia', s.unidade_preferencia,
            'turno_preferencia', s.turno_preferencia,
            'descricao', s.descricao,
            'created_at', s.created_at
        ) ORDER BY s.created_at DESC
    ), '[]'::jsonb)
    INTO v_resultado
    FROM public.solicitacoes s
    WHERE s.prefeitura_id::text = p_prefeitura_id::text
      AND regexp_replace(s.cidadao_cpf, '\D', '', 'g') = v_cpf_limpo;

    RETURN v_resultado;
END;
$$;

-- ==============================================================================
-- 12b. RPCS ADMINISTRATIVAS (USADAS PELO PAINEL DA PREFEITURA / ADMIN)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.confirmar_agendamento(
    p_solicitacao_id UUID,
    p_data_hora TIMESTAMPTZ,
    p_local TEXT,
    p_orientacoes TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pref_id UUID;
    v_resposta TEXT;
    v_dataFormatada TEXT;
BEGIN
    v_pref_id := public.minha_prefeitura_id();
    IF v_pref_id IS NULL THEN
        RAISE EXCEPTION 'Acesso não autorizado.';
    END IF;

    v_dataFormatada := to_char(p_data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY às HH24:MI');
    v_resposta := 'Agendamento confirmado para ' || v_dataFormatada || ' no local: ' || coalesce(p_local, 'Sede do Município') || '. ' || coalesce(p_orientacoes, '');

    UPDATE public.solicitacoes
    SET status = 'AGENDADO',
        agendado_para = p_data_hora,
        resposta_prefeitura = v_resposta,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_solicitacao_id
      AND prefeitura_id = v_pref_id;

    RETURN jsonb_build_object('success', true, 'resposta', v_resposta);
END;
$$;

CREATE OR REPLACE FUNCTION public.concluir_solicitacao(
    p_solicitacao_id UUID,
    p_observacao TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pref_id UUID;
BEGIN
    v_pref_id := public.minha_prefeitura_id();
    IF v_pref_id IS NULL THEN
        RAISE EXCEPTION 'Acesso não autorizado.';
    END IF;

    UPDATE public.solicitacoes
    SET status = 'CONCLUIDO',
        concluido_em = timezone('utc'::text, now()),
        observacao_conclusao = p_observacao,
        resposta_prefeitura = coalesce(p_observacao, 'Atendimento concluído com sucesso pela equipe municipal.'),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_solicitacao_id
      AND prefeitura_id = v_pref_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.cancelar_solicitacao(
    p_solicitacao_id UUID,
    p_motivo TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pref_id UUID;
BEGIN
    v_pref_id := public.minha_prefeitura_id();
    IF v_pref_id IS NULL THEN
        RAISE EXCEPTION 'Acesso não autorizado.';
    END IF;

    IF trim(coalesce(p_motivo, '')) = '' THEN
        RAISE EXCEPTION 'Justificativa de cancelamento é obrigatória.';
    END IF;

    UPDATE public.solicitacoes
    SET status = 'CANCELADO',
        resposta_prefeitura = 'Chamado cancelado: ' || p_motivo,
        observacao_conclusao = p_motivo,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_solicitacao_id
      AND prefeitura_id = v_pref_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ==============================================================================
-- 13. ROW LEVEL SECURITY (RLS) E POLICIES
-- ==============================================================================

-- Ativa RLS em todas as tabelas
ALTER TABLE public.prefeituras ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.secretarias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_prefeitura ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_servicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitacoes ENABLE ROW LEVEL SECURITY;

-- 1. Políticas PREFEITURAS
CREATE POLICY "prefeituras_select_publico" 
ON public.prefeituras FOR SELECT 
USING (true);

-- 2. Políticas SECRETARIAS
CREATE POLICY "secretarias_select_anon" 
ON public.secretarias FOR SELECT 
TO anon 
USING (ativa = true);

CREATE POLICY "secretarias_auth_select" 
ON public.secretarias FOR SELECT 
TO authenticated 
USING (prefeitura_id::text = public.minha_prefeitura_id()::text);

CREATE POLICY "secretarias_admin_insert" 
ON public.secretarias FOR INSERT 
TO authenticated 
WITH CHECK (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN');

CREATE POLICY "secretarias_admin_update" 
ON public.secretarias FOR UPDATE 
TO authenticated 
USING (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN')
WITH CHECK (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN');

CREATE POLICY "secretarias_admin_delete" 
ON public.secretarias FOR DELETE 
TO authenticated 
USING (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN');

-- 3. Políticas CATÁLOGO DE SERVIÇOS
CREATE POLICY "catalogo_select_anon" 
ON public.catalogo_servicos FOR SELECT 
TO anon 
USING (ativo = true);

CREATE POLICY "catalogo_auth_select" 
ON public.catalogo_servicos FOR SELECT 
TO authenticated 
USING (prefeitura_id::text = public.minha_prefeitura_id()::text);

CREATE POLICY "catalogo_admin_insert" 
ON public.catalogo_servicos FOR INSERT 
TO authenticated 
WITH CHECK (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN');

CREATE POLICY "catalogo_admin_update" 
ON public.catalogo_servicos FOR UPDATE 
TO authenticated 
USING (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN')
WITH CHECK (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN');

CREATE POLICY "catalogo_admin_delete" 
ON public.catalogo_servicos FOR DELETE 
TO authenticated 
USING (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN');

-- 4. Políticas SOLICITAÇÕES
CREATE POLICY "solicitacoes_servidores_select" 
ON public.solicitacoes FOR SELECT 
TO authenticated 
USING (
    prefeitura_id::text = public.minha_prefeitura_id()::text 
    AND (
        public.meu_papel() = 'ADMIN' 
        OR secretaria_id::text = public.minha_secretaria_id()::text 
        OR secretaria_id IS NULL
    )
);

CREATE POLICY "solicitacoes_servidores_update" 
ON public.solicitacoes FOR UPDATE 
TO authenticated 
USING (
    prefeitura_id::text = public.minha_prefeitura_id()::text 
    AND (
        public.meu_papel() = 'ADMIN' 
        OR secretaria_id::text = public.minha_secretaria_id()::text 
        OR secretaria_id IS NULL
    )
)
WITH CHECK (
    prefeitura_id::text = public.minha_prefeitura_id()::text
);

-- 5. Políticas USUÁRIOS DA PREFEITURA
CREATE POLICY "usuarios_prefeitura_select_own" 
ON public.usuarios_prefeitura FOR SELECT 
TO authenticated 
USING (
    user_id = auth.uid() 
    OR (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN')
);

CREATE POLICY "usuarios_prefeitura_admin_manage" 
ON public.usuarios_prefeitura FOR ALL 
TO authenticated 
USING (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN')
WITH CHECK (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN');

-- ==============================================================================
-- 14. PERMISSÕES DE ROLES (GRANTS)
-- ==============================================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Prefeituras: leitura pública
GRANT SELECT ON public.prefeituras TO anon, authenticated;

-- Secretarias e Catálogo: leitura pública
GRANT SELECT ON public.secretarias TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.secretarias TO authenticated;

GRANT SELECT ON public.catalogo_servicos TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.catalogo_servicos TO authenticated;

-- Solicitações: sem acesso direto para anon (somente authenticated)
REVOKE ALL ON public.solicitacoes FROM anon;
GRANT SELECT, UPDATE ON public.solicitacoes TO authenticated;

-- Usuários Prefeitura
REVOKE ALL ON public.usuarios_prefeitura FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.usuarios_prefeitura TO authenticated;

-- Execução das RPCs públicas e administrativas
GRANT EXECUTE ON FUNCTION public.abrir_solicitacao(JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consultar_protocolo(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.listar_meus_pedidos(TEXT, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirmar_agendamento(UUID, TIMESTAMPTZ, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.concluir_solicitacao(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_solicitacao(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.minha_prefeitura_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.minha_prefeitura() TO authenticated;
GRANT EXECUTE ON FUNCTION public.meu_papel() TO authenticated;
GRANT EXECUTE ON FUNCTION public.minha_secretaria_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.minha_secretaria() TO authenticated;

-- ==============================================================================
-- 15. HABILITAR SUPABASE REALTIME EM SOLICITAÇÕES
-- ==============================================================================
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.solicitacoes;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ==============================================================================
-- 16. MODELO DE INSERT DO PRIMEIRO USUÁRIO ADMIN (EXEMPLO)
-- Substitua 'admin@prefeitura.gov.br' e a prefeitura_id conforme seu usuário Auth.
-- ==============================================================================
/*
-- 1. Primeiro crie o usuário em: Supabase > Authentication > Users > Add user
--    Exemplo: admin@prefeitura.gov.br / 123456
-- 2. Em seguida, execute este comando no SQL Editor para torná-lo ADMIN de Itapemirim:

INSERT INTO public.usuarios_prefeitura (user_id, prefeitura_id, nome, email, papel, ativo)
VALUES (
    (SELECT id FROM auth.users WHERE email = 'admin@prefeitura.gov.br'),
    'e0011111-0001-0001-0001-000000000002', -- Itapemirim
    'Administrador Geral',
    'admin@prefeitura.gov.br',
    'ADMIN',
    true
)
ON CONFLICT (user_id) DO UPDATE SET
    papel = 'ADMIN',
    ativo = true;
*/

-- ==============================================================================
-- 17. CONSULTAS DE TESTE E VALIDAÇÃO (COMENTADAS)
-- ==============================================================================
/*
-- Teste A: Testar RPC de abertura de chamado pelo cidadão (anônimo)
SELECT public.abrir_solicitacao('{
    "prefeitura_id": "e0011111-0001-0001-0001-000000000002",
    "servico_id": "srv-09",
    "servico_nome": "Iluminação Pública - Troca de Lâmpadas",
    "servico_icone": "💡",
    "cidadao_nome": "Maria Cidadã de Teste",
    "cidadao_cpf": "123.456.789-00",
    "cidadao_telefone": "(28) 99999-8888",
    "endereco_rua": "Av. Beira Mar",
    "endereco_numero": "100",
    "endereco_bairro": "Centro",
    "endereco_gps": "Av. Beira Mar, nº 100 - Centro, Itapemirim - ES",
    "latitude": -21.0111,
    "longitude": -40.8339,
    "tipo_atendimento": "CAMPO_72H",
    "descricao": "Lâmpada do poste em frente apagada há 3 dias."
}'::jsonb);

-- Teste B: Consultar o protocolo pelo código público e CPF
SELECT public.consultar_protocolo('123.456.789-00', 'ES2026');

-- Teste C: Listar chamados do cidadão na cidade
SELECT public.listar_meus_pedidos('123.456.789-00', 'e0011111-0001-0001-0001-000000000002');

-- Teste D: Tentar ler solicitacoes diretamente como anon (deve retornar vazio / negado)
SET ROLE anon;
SELECT * FROM public.solicitacoes;
RESET ROLE;
*/
