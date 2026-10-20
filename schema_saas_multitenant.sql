-- ==============================================================================
-- SCHEMA COMPLETO GOVTECH SAAS (CONECTAPREFEITURA SAAS GOV)
-- Supabase / PostgreSQL com RLS, Autenticação, 16 Serviços e Múltiplas Cidades
-- ==============================================================================

-- ============================================================
-- BLOCO 0: RESET (Execute SOMENTE se desejar recriar do zero)
-- ============================================================
-- DROP TABLE IF EXISTS public.solicitacao_anexos, public.solicitacao_historico,
--   public.solicitacoes, public.cidadaos, public.catalogo_servicos,
--   public.secretarias, public.perfis, public.pedidos_adesao,
--   public.assinatura_log, public.prefeituras CASCADE;
-- DROP TYPE IF EXISTS public.papel_usuario;
-- DROP TYPE IF EXISTS public.status_assinatura;

-- ============================================================
-- BLOCO 1: TIPOS E TABELAS
-- ============================================================

-- 1. TIPOS
DO $$ BEGIN
  CREATE TYPE public.papel_usuario AS ENUM
    ('SUPER_ADMIN', 'ADMIN_PREFEITURA', 'SERVIDOR', 'CIDADAO');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.status_assinatura AS ENUM
    ('GRATUITO_BETA', 'ATIVO', 'SUSPENSA', 'CANCELADA');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. PREFEITURAS (Login via Supabase Auth)
CREATE TABLE IF NOT EXISTS public.prefeituras (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome              TEXT NOT NULL,
  cidade            TEXT NOT NULL,
  uf                VARCHAR(2) NOT NULL CHECK (uf ~ '^[A-Z]{2}$'),
  cnpj              VARCHAR(14),
  brasao_url        TEXT,
  email_admin       TEXT CHECK (email_admin IS NULL OR email_admin ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  telefone_contato  TEXT,
  ativo             BOOLEAN NOT NULL DEFAULT true,
  status_assinatura public.status_assinatura NOT NULL DEFAULT 'GRATUITO_BETA',
  motivo_status     TEXT,
  status_alterado_em TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (cidade, uf)
);

-- 3. SECRETARIAS MUNICIPAIS
CREATE TABLE IF NOT EXISTS public.secretarias (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prefeitura_id UUID NOT NULL REFERENCES public.prefeituras(id) ON DELETE RESTRICT,
  nome          TEXT NOT NULL,
  sigla         VARCHAR(20),
  categoria     TEXT NOT NULL
                CHECK (categoria IN ('SAUDE','CIDADANIA','ZELADORIA','EDUCACAO','SOCIAL','GERAL')),
  responsavel   TEXT,
  email         TEXT CHECK (email IS NULL OR email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  ativo         BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. PERFIS (Conecta auth.users ao Papel, Prefeitura e Secretaria)
CREATE TABLE IF NOT EXISTS public.perfis (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  prefeitura_id UUID REFERENCES public.prefeituras(id) ON DELETE RESTRICT,
  secretaria_id UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
  papel         public.papel_usuario NOT NULL DEFAULT 'CIDADAO',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. CATÁLOGO DE SERVIÇOS
CREATE TABLE IF NOT EXISTS public.catalogo_servicos (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prefeitura_id         UUID NOT NULL REFERENCES public.prefeituras(id) ON DELETE RESTRICT,
  secretaria_id         UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
  categoria             TEXT NOT NULL DEFAULT 'GERAL'
                        CHECK (categoria IN ('SAUDE','CIDADANIA','ZELADORIA','EDUCACAO','SOCIAL','GERAL')),
  nome                  TEXT NOT NULL,
  icone                 TEXT NOT NULL DEFAULT '📌',
  tipo_fluxo            TEXT NOT NULL CHECK (tipo_fluxo IN ('AGENDAMENTO','ZELADORIA','DOCUMENTACAO')),
  exige_unidade_saude   BOOLEAN NOT NULL DEFAULT false,
  exige_endereco        BOOLEAN NOT NULL DEFAULT false,
  exige_cartao_sus      BOOLEAN NOT NULL DEFAULT false,
  campos_personalizados JSONB NOT NULL DEFAULT '[]'::jsonb
                        CHECK (jsonb_typeof(campos_personalizados) = 'array'),
  prazo_estimado_dias   INT NOT NULL DEFAULT 5 CHECK (prazo_estimado_dias BETWEEN 0 AND 365),
  ativo                 BOOLEAN NOT NULL DEFAULT true,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- FUNÇÃO AUXILIAR: VALIDADOR DE CPF
CREATE OR REPLACE FUNCTION public.cpf_valido(c TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE s INT; d1 INT; d2 INT; i INT;
BEGIN
  IF c IS NULL OR c !~ '^[0-9]{11}$' OR c ~ '^(.)\1{10}$' THEN RETURN false; END IF;
  s := 0; FOR i IN 1..9  LOOP s := s + substr(c,i,1)::int * (11-i); END LOOP;
  d1 := (s*10) % 11; IF d1 = 10 THEN d1 := 0; END IF;
  s := 0; FOR i IN 1..10 LOOP s := s + substr(c,i,1)::int * (12-i); END LOOP;
  d2 := (s*10) % 11; IF d2 = 10 THEN d2 := 0; END IF;
  RETURN d1 = substr(c,10,1)::int AND d2 = substr(c,11,1)::int;
END $$;

-- FUNÇÃO AUXILIAR: VALIDADOR DE CNPJ
CREATE OR REPLACE FUNCTION public.cnpj_valido(c TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE w1 INT[] := ARRAY[5,4,3,2,9,8,7,6,5,4,3,2];
        w2 INT[] := ARRAY[6,5,4,3,2,9,8,7,6,5,4,3,2];
        s INT; i INT; d1 INT; d2 INT;
BEGIN
  IF c IS NULL OR c !~ '^[0-9]{14}$' OR c ~ '^(.)\1{13}$' THEN RETURN false; END IF;
  s := 0; FOR i IN 1..12 LOOP s := s + substr(c,i,1)::int * w1[i]; END LOOP;
  d1 := s % 11; d1 := CASE WHEN d1 < 2 THEN 0 ELSE 11 - d1 END;
  s := 0; FOR i IN 1..13 LOOP s := s + substr(c,i,1)::int * w2[i]; END LOOP;
  d2 := s % 11; d2 := CASE WHEN d2 < 2 THEN 0 ELSE 11 - d2 END;
  RETURN d1 = substr(c,13,1)::int AND d2 = substr(c,14,1)::int;
END $$;

-- 6. CIDADÃOS CADASTRADOS (LGPD)
CREATE TABLE IF NOT EXISTS public.cidadaos (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID REFERENCES auth.users(id) ON DELETE RESTRICT,
  prefeitura_id     UUID NOT NULL REFERENCES public.prefeituras(id) ON DELETE RESTRICT,
  nome_completo     TEXT NOT NULL CHECK (char_length(nome_completo) BETWEEN 3 AND 150),
  cpf               VARCHAR(11) NOT NULL CHECK (public.cpf_valido(cpf)),
  email             TEXT CHECK (email IS NULL OR email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  telefone          VARCHAR(11) NOT NULL CHECK (telefone ~ '^[0-9]{10,11}$'),
  canal_preferido   TEXT NOT NULL DEFAULT 'WHATSAPP' CHECK (canal_preferido IN ('WHATSAPP','SMS','EMAIL')),
  cidade            TEXT NOT NULL,
  uf                VARCHAR(2) NOT NULL CHECK (uf ~ '^[A-Z]{2}$'),
  consentimento_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
  versao_politica   TEXT NOT NULL DEFAULT '1.0',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (prefeitura_id, cpf)
);

-- 7. SOLICITAÇÕES / PROTOCOLOS DE ATENDIMENTO
CREATE TABLE IF NOT EXISTS public.solicitacoes (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  protocolo                BIGINT GENERATED BY DEFAULT AS IDENTITY (START WITH 2001),
  protocolo_publico        TEXT NOT NULL UNIQUE
                           DEFAULT upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),
  prefeitura_id            UUID NOT NULL REFERENCES public.prefeituras(id) ON DELETE RESTRICT,
  secretaria_id            UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
  servico_id               UUID NOT NULL REFERENCES public.catalogo_servicos(id) ON DELETE RESTRICT,
  cidadao_id               UUID NOT NULL REFERENCES public.cidadaos(id) ON DELETE RESTRICT,
  cartao_sus               TEXT CHECK (cartao_sus IS NULL OR cartao_sus ~ '^[0-9]{15}$'),
  endereco_gps             TEXT CHECK (char_length(endereco_gps) <= 300),
  unidade_preferencia      TEXT CHECK (char_length(unidade_preferencia) <= 150),
  turno_preferencia        TEXT CHECK (turno_preferencia IS NULL OR turno_preferencia IN ('MANHA','TARDE','NOITE','INTEGRAL')),
  respostas_personalizadas JSONB NOT NULL DEFAULT '{}'::jsonb
                           CHECK (jsonb_typeof(respostas_personalizadas) = 'object'),
  descricao                TEXT NOT NULL CHECK (char_length(descricao) BETWEEN 5 AND 2000),
  status                   TEXT NOT NULL DEFAULT 'PENDENTE'
                           CHECK (status IN ('PENDENTE','EM_ANDAMENTO','AGENDADO','CONCLUIDO','CANCELADO')),
  resposta_prefeitura      TEXT CHECK (char_length(resposta_prefeitura) <= 2000),
  prazo_limite             TIMESTAMPTZ,
  agendado_para            TIMESTAMPTZ,
  avaliacao_nota           SMALLINT CHECK (avaliacao_nota BETWEEN 1 AND 5),
  avaliacao_comentario     TEXT CHECK (char_length(avaliacao_comentario) <= 1000),
  avaliacao_em             TIMESTAMPTZ,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. HISTÓRICO, ANEXOS, PEDIDOS DE ADESÃO E AUDITORIA
CREATE TABLE IF NOT EXISTS public.solicitacao_historico (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  solicitacao_id  UUID NOT NULL REFERENCES public.solicitacoes(id) ON DELETE CASCADE,
  status_anterior TEXT,
  status_novo     TEXT NOT NULL,
  comentario      TEXT,
  alterado_por    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.solicitacao_anexos (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitacao_id UUID NOT NULL REFERENCES public.solicitacoes(id) ON DELETE CASCADE,
  nome_arquivo   TEXT NOT NULL,
  storage_path   TEXT NOT NULL,
  mime_type      TEXT,
  tamanho_bytes  BIGINT CHECK (tamanho_bytes <= 10485760),
  enviado_por    UUID DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pedidos_adesao (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prefeitura_id       UUID REFERENCES public.prefeituras(id) ON DELETE CASCADE,
  user_id             UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  cnpj                VARCHAR(14) NOT NULL,
  nome_contato        TEXT NOT NULL,
  cargo               TEXT NOT NULL,
  email_institucional TEXT NOT NULL,
  telefone            TEXT,
  status              TEXT NOT NULL DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE','APROVADO','REJEITADO')),
  observacao          TEXT,
  decidido_em         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.assinatura_log (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  prefeitura_id   UUID REFERENCES public.prefeituras(id) ON DELETE CASCADE,
  status_anterior TEXT,
  status_novo     TEXT NOT NULL,
  motivo          TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. ÍNDICES
CREATE INDEX IF NOT EXISTS idx_secretarias_pref      ON public.secretarias (prefeitura_id);
CREATE INDEX IF NOT EXISTS idx_perfis_pref           ON public.perfis (prefeitura_id);
CREATE INDEX IF NOT EXISTS idx_catalogo_pref         ON public.catalogo_servicos (prefeitura_id) WHERE ativo;
CREATE INDEX IF NOT EXISTS idx_catalogo_sec          ON public.catalogo_servicos (secretaria_id);
CREATE INDEX IF NOT EXISTS idx_cidadaos_pref         ON public.cidadaos (prefeitura_id);
CREATE INDEX IF NOT EXISTS idx_solic_pref_status     ON public.solicitacoes (prefeitura_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_solic_cidadao         ON public.solicitacoes (cidadao_id);
CREATE INDEX IF NOT EXISTS idx_solic_secretaria      ON public.solicitacoes (secretaria_id);
CREATE INDEX IF NOT EXISTS idx_solic_servico         ON public.solicitacoes (servico_id);
CREATE INDEX IF NOT EXISTS idx_hist_solic            ON public.solicitacao_historico (solicitacao_id, created_at);
CREATE INDEX IF NOT EXISTS idx_anexos_solic          ON public.solicitacao_anexos (solicitacao_id);


-- ============================================================
-- BLOCO 2: FUNÇÕES AUXILIARES, TRIGGERS E REGRAS DE NEGÓCIO
-- ============================================================

CREATE OR REPLACE FUNCTION public.meu_papel()
RETURNS public.papel_usuario LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT papel FROM public.perfis WHERE id = auth.uid() $$;

CREATE OR REPLACE FUNCTION public.minha_prefeitura()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT prefeitura_id FROM public.perfis WHERE id = auth.uid() $$;

CREATE OR REPLACE FUNCTION public.minha_secretaria()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT secretaria_id FROM public.perfis WHERE id = auth.uid() $$;

CREATE OR REPLACE FUNCTION public.exigir_super_admin()
RETURNS VOID LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF public.meu_papel() <> 'SUPER_ADMIN' THEN
    RAISE EXCEPTION 'Acesso restrito ao Super Administrador';
  END IF;
END $$;

-- Trigger: Novo usuário no Auth => perfil CIDADAO automático
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.perfis (id, papel) VALUES (NEW.id, 'CIDADAO')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger: Atualização automática de updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS trg_solicitacoes_updated ON public.solicitacoes;
CREATE TRIGGER trg_solicitacoes_updated
BEFORE UPDATE ON public.solicitacoes
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Trigger: Validação e amarração segura ao criar solicitação
CREATE OR REPLACE FUNCTION public.antes_inserir_solicitacao()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_serv public.catalogo_servicos%ROWTYPE;
  v_cid  public.cidadaos%ROWTYPE;
BEGIN
  SELECT * INTO v_serv FROM public.catalogo_servicos WHERE id = NEW.servico_id AND ativo;
  IF NOT FOUND THEN RAISE EXCEPTION 'Serviço inexistente ou inativo'; END IF;

  SELECT * INTO v_cid FROM public.cidadaos WHERE id = NEW.cidadao_id;
  IF NOT FOUND OR v_cid.prefeitura_id <> v_serv.prefeitura_id THEN
    RAISE EXCEPTION 'Cidadão não pertence ao município deste serviço';
  END IF;

  IF v_serv.exige_endereco AND coalesce(btrim(NEW.endereco_gps), '') = '' THEN
    RAISE EXCEPTION 'Este serviço exige endereço ou marcação no mapa';
  END IF;
  IF v_serv.exige_cartao_sus AND (NEW.cartao_sus IS NULL OR coalesce(btrim(NEW.cartao_sus), '') = '') THEN
    RAISE EXCEPTION 'Este serviço exige o Cartão SUS (15 dígitos)';
  END IF;
  IF v_serv.exige_unidade_saude AND coalesce(btrim(NEW.unidade_preferencia), '') = '' THEN
    RAISE EXCEPTION 'Este serviço exige a unidade de preferência';
  END IF;

  NEW.prefeitura_id := v_serv.prefeitura_id;
  NEW.secretaria_id := v_serv.secretaria_id;
  NEW.status        := 'PENDENTE';
  NEW.prazo_limite  := now() + make_interval(days => v_serv.prazo_estimado_dias);
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_antes_inserir_solicitacao ON public.solicitacoes;
CREATE TRIGGER trg_antes_inserir_solicitacao
BEFORE INSERT ON public.solicitacoes
FOR EACH ROW EXECUTE FUNCTION public.antes_inserir_solicitacao();

-- Trigger: Histórico automático de alterações de status
CREATE OR REPLACE FUNCTION public.registrar_historico()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.solicitacao_historico (solicitacao_id, status_anterior, status_novo, comentario, alterado_por)
    VALUES (NEW.id, NULL, NEW.status, 'Solicitação registrada', auth.uid());
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.solicitacao_historico (solicitacao_id, status_anterior, status_novo, comentario, alterado_por)
    VALUES (NEW.id, OLD.status, NEW.status, coalesce(NEW.resposta_prefeitura, 'Status atualizado'), auth.uid());
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_historico ON public.solicitacoes;
CREATE TRIGGER trg_historico
AFTER INSERT OR UPDATE ON public.solicitacoes
FOR EACH ROW EXECUTE FUNCTION public.registrar_historico();

-- RPC: Consulta pública de protocolo por código público (ou número) + 4 dígitos finais do CPF
CREATE OR REPLACE FUNCTION public.consultar_protocolo(p_protocolo TEXT, p_cpf_final TEXT)
RETURNS TABLE (
  protocolo BIGINT,
  protocolo_publico TEXT,
  servico TEXT,
  status TEXT,
  resposta_prefeitura TEXT,
  prazo_limite TIMESTAMPTZ,
  agendado_para TIMESTAMPTZ,
  atualizado_em TIMESTAMPTZ,
  cidade TEXT,
  uf TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT 
    s.protocolo,
    s.protocolo_publico,
    cs.nome AS servico,
    s.status,
    s.resposta_prefeitura,
    s.prazo_limite,
    s.agendado_para,
    s.updated_at AS atualizado_em,
    p.cidade,
    p.uf::text
  FROM public.solicitacoes s
  JOIN public.cidadaos c           ON c.id  = s.cidadao_id
  JOIN public.catalogo_servicos cs ON cs.id = s.servico_id
  JOIN public.prefeituras p        ON p.id  = s.prefeitura_id
  WHERE (s.protocolo_publico = upper(btrim(p_protocolo)) OR s.protocolo::text = regexp_replace(p_protocolo, '\D', '', 'g'))
    AND right(c.cpf, 4) = regexp_replace(p_cpf_final, '\D', '', 'g')
$$;

-- RPC: Avaliação de atendimento pelo cidadão
CREATE OR REPLACE FUNCTION public.avaliar_solicitacao(p_id UUID, p_nota SMALLINT, p_comentario TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.solicitacoes s
     SET avaliacao_nota = p_nota,
         avaliacao_comentario = left(p_comentario, 1000),
         avaliacao_em = now()
   WHERE s.id = p_id
     AND s.status = 'CONCLUIDO'
     AND s.avaliacao_nota IS NULL
     AND s.cidadao_id IN (SELECT id FROM public.cidadaos WHERE user_id = auth.uid());
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitação não encontrada, não concluída ou já avaliada';
  END IF;
END $$;

-- RPC: Listar municípios para seleção
CREATE OR REPLACE FUNCTION public.listar_municipios()
RETURNS TABLE (id UUID, cidade TEXT, uf TEXT, nome TEXT, brasao_url TEXT, ativo BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.id, p.cidade, p.uf::text, p.nome, p.brasao_url, p.ativo
  FROM public.prefeituras p
  ORDER BY p.cidade ASC;
$$;

-- RPC: Solicitar adesão da prefeitura ao SaaS
CREATE OR REPLACE FUNCTION public.solicitar_adesao(
  p_prefeitura UUID, p_cnpj TEXT, p_nome TEXT, p_cargo TEXT, p_email TEXT, p_tel TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_cnpj TEXT := regexp_replace(coalesce(p_cnpj,''), '\D', '', 'g');
        v_email TEXT := lower(btrim(coalesce(p_email,'')));
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.prefeituras WHERE id = p_prefeitura) THEN
    RAISE EXCEPTION 'Município não cadastrado no catálogo';
  END IF;
  IF NOT public.cnpj_valido(v_cnpj) THEN
    RAISE EXCEPTION 'CNPJ inválido (verifique os dígitos)';
  END IF;
  IF char_length(btrim(coalesce(p_nome,''))) NOT BETWEEN 3 AND 150
     OR char_length(btrim(coalesce(p_cargo,''))) NOT BETWEEN 2 AND 100 THEN
    RAISE EXCEPTION 'Informe seu nome completo e cargo oficial';
  END IF;
  IF v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'E-mail institucional inválido';
  END IF;
  IF EXISTS (SELECT 1 FROM public.pedidos_adesao WHERE status = 'PENDENTE'
             AND (cnpj = v_cnpj OR (prefeitura_id = p_prefeitura AND email_institucional = v_email))) THEN
    RAISE EXCEPTION 'Já existe um pedido de adesão em análise para esta prefeitura';
  END IF;

  INSERT INTO public.pedidos_adesao (prefeitura_id, user_id, cnpj, nome_contato, cargo, email_institucional, telefone)
  VALUES (p_prefeitura, auth.uid(), v_cnpj, btrim(p_nome), btrim(p_cargo), v_email, p_tel);
END $$;

-- Funções Administrativas do SaaS Master
CREATE OR REPLACE FUNCTION public.admin_listar_adesoes()
RETURNS TABLE (id UUID, cidade TEXT, uf TEXT, cnpj TEXT, nome_contato TEXT, cargo TEXT,
               email_institucional TEXT, telefone TEXT, status TEXT, email_gov BOOLEAN, created_at TIMESTAMPTZ)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.exigir_super_admin();
  RETURN QUERY
  SELECT a.id, p.cidade, p.uf::text, a.cnpj::text, a.nome_contato, a.cargo, a.email_institucional,
         a.telefone, a.status, a.email_institucional ~* '\.gov\.br$', a.created_at
  FROM public.pedidos_adesao a JOIN public.prefeituras p ON p.id = a.prefeitura_id
  ORDER BY (a.status = 'PENDENTE') DESC, a.created_at DESC LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.admin_decidir_adesao(p_id UUID, p_aprovar BOOLEAN, p_obs TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v public.pedidos_adesao%ROWTYPE; v_old public.status_assinatura;
BEGIN
  PERFORM public.exigir_super_admin();
  SELECT * INTO v FROM public.pedidos_adesao WHERE id = p_id AND status = 'PENDENTE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pedido não encontrado ou já processado'; END IF;

  UPDATE public.pedidos_adesao
     SET status = CASE WHEN p_aprovar THEN 'APROVADO' ELSE 'REJEITADO' END,
         observacao = p_obs, decidido_em = now()
   WHERE id = p_id;

  IF p_aprovar THEN
    SELECT status_assinatura INTO v_old FROM public.prefeituras WHERE id = v.prefeitura_id;
    UPDATE public.prefeituras
       SET ativo = true, cnpj = v.cnpj, email_admin = v.email_institucional,
           telefone_contato = coalesce(v.telefone, telefone_contato),
           status_assinatura = 'GRATUITO_BETA',
           motivo_status = 'Adesão oficial aprovada', status_alterado_em = now()
     WHERE id = v.prefeitura_id;
    INSERT INTO public.assinatura_log (prefeitura_id, status_anterior, status_novo, motivo)
    SELECT id, v_old::text, status_assinatura::text, 'Adesão oficial aprovada' FROM public.prefeituras WHERE id = v.prefeitura_id;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_vincular_usuario(
  p_email TEXT, p_prefeitura UUID, p_papel public.papel_usuario, p_secretaria UUID DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid UUID;
BEGIN
  PERFORM public.exigir_super_admin();
  IF p_papel NOT IN ('ADMIN_PREFEITURA','SERVIDOR') THEN RAISE EXCEPTION 'Papel deve ser ADMIN_PREFEITURA ou SERVIDOR'; END IF;
  IF p_papel = 'SERVIDOR' AND NOT EXISTS (
       SELECT 1 FROM public.secretarias WHERE id = p_secretaria AND prefeitura_id = p_prefeitura) THEN
    RAISE EXCEPTION 'A secretaria selecionada deve pertencer a esta prefeitura'; END IF;

  SELECT id INTO v_uid FROM auth.users
   WHERE lower(email) = lower(btrim(p_email));
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado. Convide o e-mail primeiro em Authentication -> Users.'; END IF;

  INSERT INTO public.perfis (id, prefeitura_id, secretaria_id, papel)
  VALUES (v_uid, p_prefeitura, CASE WHEN p_papel = 'SERVIDOR' THEN p_secretaria END, p_papel)
  ON CONFLICT (id) DO UPDATE
    SET prefeitura_id = EXCLUDED.prefeitura_id, secretaria_id = EXCLUDED.secretaria_id, papel = EXCLUDED.papel;
END $$;


-- ============================================================
-- BLOCO 3: PERMISSÕES E ROW LEVEL SECURITY (RLS)
-- ============================================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- Leitura Pública
GRANT SELECT ON public.prefeituras TO anon, authenticated;
GRANT SELECT ON public.secretarias TO anon, authenticated;
GRANT SELECT ON public.catalogo_servicos TO anon, authenticated;

-- Autenticados
GRANT SELECT ON public.perfis, public.cidadaos, public.solicitacoes,
                public.solicitacao_historico, public.solicitacao_anexos TO authenticated;

GRANT INSERT, UPDATE ON public.cidadaos TO authenticated;
GRANT INSERT, UPDATE ON public.solicitacoes TO authenticated;
GRANT INSERT ON public.solicitacao_anexos TO authenticated;
GRANT INSERT, UPDATE ON public.catalogo_servicos, public.secretarias TO authenticated;
GRANT UPDATE ON public.prefeituras TO authenticated;

-- Funções Executáveis
GRANT EXECUTE ON FUNCTION public.consultar_protocolo(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.listar_municipios() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.solicitar_adesao(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.avaliar_solicitacao(UUID, SMALLINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_listar_adesoes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_decidir_adesao(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_vincular_usuario(TEXT, UUID, public.papel_usuario, UUID) TO authenticated;

-- Ativar RLS
ALTER TABLE public.prefeituras             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.secretarias             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfis                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_servicos       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cidadaos                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitacoes            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitacao_historico   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitacao_anexos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos_adesao          ENABLE ROW LEVEL SECURITY;

-- Políticas PREFEITURAS
DROP POLICY IF EXISTS prefeituras_leitura ON public.prefeituras;
CREATE POLICY prefeituras_leitura ON public.prefeituras FOR SELECT
  USING (ativo = true OR public.meu_papel() = 'SUPER_ADMIN' OR id = public.minha_prefeitura());

DROP POLICY IF EXISTS prefeituras_update ON public.prefeituras;
CREATE POLICY prefeituras_update ON public.prefeituras FOR UPDATE
  USING (public.meu_papel() = 'SUPER_ADMIN'
         OR (id = public.minha_prefeitura() AND public.meu_papel() = 'ADMIN_PREFEITURA'))
  WITH CHECK (public.meu_papel() = 'SUPER_ADMIN'
         OR (id = public.minha_prefeitura() AND public.meu_papel() = 'ADMIN_PREFEITURA'));

-- Políticas SECRETARIAS
DROP POLICY IF EXISTS secretarias_leitura ON public.secretarias;
CREATE POLICY secretarias_leitura ON public.secretarias FOR SELECT
  USING (ativo = true OR prefeitura_id = public.minha_prefeitura() OR public.meu_papel() = 'SUPER_ADMIN');

DROP POLICY IF EXISTS secretarias_admin ON public.secretarias;
CREATE POLICY secretarias_admin ON public.secretarias FOR ALL
  USING (prefeitura_id = public.minha_prefeitura() AND public.meu_papel() = 'ADMIN_PREFEITURA')
  WITH CHECK (prefeitura_id = public.minha_prefeitura() AND public.meu_papel() = 'ADMIN_PREFEITURA');

-- Políticas PERFIS
DROP POLICY IF EXISTS perfis_proprio ON public.perfis;
CREATE POLICY perfis_proprio ON public.perfis FOR SELECT
  USING (id = auth.uid());

DROP POLICY IF EXISTS perfis_admin ON public.perfis;
CREATE POLICY perfis_admin ON public.perfis FOR SELECT
  USING (public.meu_papel() = 'SUPER_ADMIN'
         OR (public.meu_papel() = 'ADMIN_PREFEITURA' AND prefeitura_id = public.minha_prefeitura()));

-- Políticas CATÁLOGO
DROP POLICY IF EXISTS catalogo_leitura ON public.catalogo_servicos;
CREATE POLICY catalogo_leitura ON public.catalogo_servicos FOR SELECT
  USING (ativo = true OR prefeitura_id = public.minha_prefeitura());

DROP POLICY IF EXISTS catalogo_admin_ins ON public.catalogo_servicos;
CREATE POLICY catalogo_admin_ins ON public.catalogo_servicos FOR INSERT
  WITH CHECK (prefeitura_id = public.minha_prefeitura() AND public.meu_papel() = 'ADMIN_PREFEITURA');

DROP POLICY IF EXISTS catalogo_admin_upd ON public.catalogo_servicos;
CREATE POLICY catalogo_admin_upd ON public.catalogo_servicos FOR UPDATE
  USING (prefeitura_id = public.minha_prefeitura() AND public.meu_papel() = 'ADMIN_PREFEITURA')
  WITH CHECK (prefeitura_id = public.minha_prefeitura() AND public.meu_papel() = 'ADMIN_PREFEITURA');

-- Políticas CIDADÃOS
DROP POLICY IF EXISTS cidadao_proprio_sel ON public.cidadaos;
CREATE POLICY cidadao_proprio_sel ON public.cidadaos FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS cidadao_staff_sel ON public.cidadaos;
CREATE POLICY cidadao_staff_sel ON public.cidadaos FOR SELECT
  USING (prefeitura_id = public.minha_prefeitura()
         AND public.meu_papel() IN ('ADMIN_PREFEITURA','SERVIDOR'));

DROP POLICY IF EXISTS cidadao_proprio_ins ON public.cidadaos;
CREATE POLICY cidadao_proprio_ins ON public.cidadaos FOR INSERT
  WITH CHECK (user_id = auth.uid()
              AND EXISTS (SELECT 1 FROM public.prefeituras p WHERE p.id = prefeitura_id AND p.ativo));

DROP POLICY IF EXISTS cidadao_proprio_upd ON public.cidadaos;
CREATE POLICY cidadao_proprio_upd ON public.cidadaos FOR UPDATE
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Políticas SOLICITAÇÕES
DROP POLICY IF EXISTS solic_cidadao_sel ON public.solicitacoes;
CREATE POLICY solic_cidadao_sel ON public.solicitacoes FOR SELECT
  USING (cidadao_id IN (SELECT id FROM public.cidadaos WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS solic_cidadao_ins ON public.solicitacoes;
CREATE POLICY solic_cidadao_ins ON public.solicitacoes FOR INSERT
  WITH CHECK (cidadao_id IN (SELECT id FROM public.cidadaos WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS solic_staff_sel ON public.solicitacoes;
CREATE POLICY solic_staff_sel ON public.solicitacoes FOR SELECT
  USING (prefeitura_id = public.minha_prefeitura()
         AND (public.meu_papel() = 'ADMIN_PREFEITURA'
              OR (public.meu_papel() = 'SERVIDOR' AND secretaria_id = public.minha_secretaria())));

DROP POLICY IF EXISTS solic_staff_upd ON public.solicitacoes;
CREATE POLICY solic_staff_upd ON public.solicitacoes FOR UPDATE
  USING (prefeitura_id = public.minha_prefeitura()
         AND (public.meu_papel() = 'ADMIN_PREFEITURA'
              OR (public.meu_papel() = 'SERVIDOR' AND secretaria_id = public.minha_secretaria())))
  WITH CHECK (prefeitura_id = public.minha_prefeitura());

-- Políticas HISTÓRICO e ANEXOS
DROP POLICY IF EXISTS hist_sel ON public.solicitacao_historico;
CREATE POLICY hist_sel ON public.solicitacao_historico FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.solicitacoes s WHERE s.id = solicitacao_id));

DROP POLICY IF EXISTS anexos_sel ON public.solicitacao_anexos;
CREATE POLICY anexos_sel ON public.solicitacao_anexos FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.solicitacoes s WHERE s.id = solicitacao_id));

DROP POLICY IF EXISTS anexos_ins ON public.solicitacao_anexos;
CREATE POLICY anexos_ins ON public.solicitacao_anexos FOR INSERT
  WITH CHECK (enviado_por = auth.uid()
              AND EXISTS (SELECT 1 FROM public.solicitacoes s WHERE s.id = solicitacao_id));

-- Realtime para solicitações
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.solicitacoes;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ============================================================
-- BLOCO 4: DADOS INICIAIS (SEED COM 16 SERVIÇOS ESSENCIAIS)
-- ============================================================

-- Inserir Prefeituras Piloto
INSERT INTO public.prefeituras (id, nome, cidade, uf, brasao_url, email_admin, telefone_contato, ativo) VALUES
  ('a1111111-1111-1111-1111-111111111111','Prefeitura Municipal de Santos','Santos','SP','https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120','admin@santos.sp.gov.br','1332015000', true),
  ('b2222222-2222-2222-2222-222222222222','Prefeitura Municipal de Campinas','Campinas','SP','https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120','admin@campinas.sp.gov.br','1921160100', true)
ON CONFLICT (cidade, uf) DO NOTHING;

-- Secretarias Estruturadas de Santos
INSERT INTO public.secretarias (id, prefeitura_id, nome, sigla, categoria) VALUES
  ('d1111111-1111-1111-1111-111111111111','a1111111-1111-1111-1111-111111111111','Secretaria Municipal de Saúde','SMS','SAUDE'),
  ('d2222222-2222-2222-2222-222222222222','a1111111-1111-1111-1111-111111111111','Secretaria de Cidadania, Documentação e Trabalho','SMCT','CIDADANIA'),
  ('d3333333-3333-3333-3333-333333333333','a1111111-1111-1111-1111-111111111111','Secretaria de Serviços Públicos e Obras','SESERP','ZELADORIA'),
  ('d4444444-4444-4444-4444-444444444444','a1111111-1111-1111-1111-111111111111','Secretaria Municipal de Educação','SEDUC','EDUCACAO'),
  ('d5555555-5555-5555-5555-555555555555','a1111111-1111-1111-1111-111111111111','Secretaria de Habitação e Assistência Social','SEDES','SOCIAL')
ON CONFLICT DO NOTHING;

-- 16 Serviços Essenciais (Santos)
INSERT INTO public.catalogo_servicos
  (prefeitura_id, secretaria_id, categoria, nome, icone, tipo_fluxo,
   exige_endereco, exige_unidade_saude, exige_cartao_sus, campos_personalizados, prazo_estimado_dias)
VALUES
-- 1. SAÚDE PÚBLICA
('a1111111-1111-1111-1111-111111111111','d1111111-1111-1111-1111-111111111111','SAUDE','Postos de Saúde (UBS) - Consultas e Odonto','🩺','AGENDAMENTO',false,true,true,
 '[{"chave":"especialidade","rotulo":"Especialidade","tipo":"select","obrigatorio":true,"opcoes":["Clínico Geral","Pediatria","Odontologia"]},
   {"chave":"motivo","rotulo":"Sintomas ou motivo principal","tipo":"texto","obrigatorio":true}]',3),
('a1111111-1111-1111-1111-111111111111','d1111111-1111-1111-1111-111111111111','SAUDE','Vacinação - Calendário Nacional e Campanhas','💉','AGENDAMENTO',false,true,true,
 '[{"chave":"vacina","rotulo":"Vacina desejada","tipo":"select","obrigatorio":true,"opcoes":["Gripe","Covid","Tríplice","Infantil"]},
   {"chave":"faixa_etaria","rotulo":"Faixa etária do vacinado","tipo":"select","obrigatorio":true,"opcoes":["Criança","Adolescente","Adulto","Idoso"]}]',2),
('a1111111-1111-1111-1111-111111111111','d1111111-1111-1111-1111-111111111111','SAUDE','Distribuição de Medicamentos Básicos (Farmácia Popular)','💊','AGENDAMENTO',false,true,true,
 '[{"chave":"medicamento","rotulo":"Nome do medicamento da receita","tipo":"texto","obrigatorio":true},
   {"chave":"receita","rotulo":"Número da receita médica","tipo":"texto","obrigatorio":true}]',1),
('a1111111-1111-1111-1111-111111111111','d1111111-1111-1111-1111-111111111111','SAUDE','Pronto-Atendimento / UPA 24h (Orientações e Triagem)','🚑','DOCUMENTACAO',false,false,false,
 '[{"chave":"urgencia","rotulo":"Descrição da urgência","tipo":"texto","obrigatorio":true}]',1),

-- 2. DOCUMENTAÇÃO E CIDADANIA
('a1111111-1111-1111-1111-111111111111','d2222222-2222-2222-2222-222222222222','CIDADANIA','Emissão de 2ª Via de Certidões (Nascimento/Casamento)','📜','DOCUMENTACAO',false,false,false,
 '[{"chave":"tipo_certidao","rotulo":"Tipo de certidão","tipo":"select","obrigatorio":true,"opcoes":["Nascimento","Casamento","Óbito"]},
   {"chave":"cartorio","rotulo":"Cartório de registro original","tipo":"texto","obrigatorio":true},
   {"chave":"livro_folha","rotulo":"Livro/Folha (se souber)","tipo":"texto","obrigatorio":false}]',5),
('a1111111-1111-1111-1111-111111111111','d2222222-2222-2222-2222-222222222222','CIDADANIA','Junta Militar - Alistamento e Certificados','🎖️','DOCUMENTACAO',false,false,false,
 '[{"chave":"ano_nascimento","rotulo":"Ano de nascimento","tipo":"numero","obrigatorio":true},
   {"chave":"possui_cam","rotulo":"Já possui CAM (Certificado de Alistamento)?","tipo":"booleano","obrigatorio":true}]',3),
('a1111111-1111-1111-1111-111111111111','d2222222-2222-2222-2222-222222222222','CIDADANIA','PAT / Banco de Empregos e Seguro-Desemprego','💼','AGENDAMENTO',false,false,false,
 '[{"chave":"area","rotulo":"Área de atuação / cargo desejado","tipo":"texto","obrigatorio":true},
   {"chave":"ctps_digital","rotulo":"Possui Carteira de Trabalho Digital?","tipo":"booleano","obrigatorio":true}]',2),

-- 3. INFRAESTRUTURA E ZELADORIA URBANA
('a1111111-1111-1111-1111-111111111111','d3333333-3333-3333-3333-333333333333','ZELADORIA','Coleta de Lixo Especial e Cata-Treco (Móveis/Entulhos)','🚛','ZELADORIA',true,false,false,
 '[{"chave":"itens","rotulo":"O que precisa ser recolhido","tipo":"texto","obrigatorio":true},
   {"chave":"quantidade","rotulo":"Quantidade aproximada de itens","tipo":"numero","obrigatorio":true}]',4),
('a1111111-1111-1111-1111-111111111111','d3333333-3333-3333-3333-333333333333','ZELADORIA','Iluminação Pública - Troca de Lâmpadas e Manutenção','💡','ZELADORIA',true,false,false,
 '[{"chave":"numero_poste","rotulo":"Número do poste (se visível)","tipo":"texto","obrigatorio":false},
   {"chave":"situacao","rotulo":"Situação do poste","tipo":"select","obrigatorio":true,"opcoes":["Aceso de dia","Apagado à noite","Piscando"]}]',2),
('a1111111-1111-1111-1111-111111111111','d3333333-3333-3333-3333-333333333333','ZELADORIA','Manutenção de Vias - Tapa-Buraco e Bueiros','🚧','ZELADORIA',true,false,false,
 '[{"chave":"problema","rotulo":"Problema","tipo":"select","obrigatorio":true,"opcoes":["Buraco na pista","Bueiro entupido","Afundamento"]},
   {"chave":"referencia","rotulo":"Ponto de referência da rua","tipo":"texto","obrigatorio":false}]',5),
('a1111111-1111-1111-1111-111111111111','d3333333-3333-3333-3333-333333333333','ZELADORIA','Limpeza e Paisagismo - Corte de Mato e Praças','🌳','ZELADORIA',true,false,false,
 '[{"chave":"local","rotulo":"Local","tipo":"select","obrigatorio":true,"opcoes":["Praça pública","Canteiro central","Calçada"]},
   {"chave":"obstrui_visibilidade","rotulo":"A vegetação obstrui a visibilidade?","tipo":"booleano","obrigatorio":true}]',4),

-- 4. EDUCAÇÃO INFANTIL E FUNDAMENTAL
('a1111111-1111-1111-1111-111111111111','d4444444-4444-4444-4444-444444444444','EDUCACAO','Creches e Pré-Escolas - Inscrição e Vagas','👶','DOCUMENTACAO',true,false,false,
 '[{"chave":"nome_crianca","rotulo":"Nome completo da criança","tipo":"texto","obrigatorio":true},
   {"chave":"nascimento_crianca","rotulo":"Data de nascimento","tipo":"data","obrigatorio":true},
   {"chave":"periodo","rotulo":"Período desejado","tipo":"select","obrigatorio":true,"opcoes":["Integral","Parcial"]}]',7),
('a1111111-1111-1111-1111-111111111111','d4444444-4444-4444-4444-444444444444','EDUCACAO','Ensino Fundamental I e II - Transferências e Matrículas','🎒','DOCUMENTACAO',false,false,false,
 '[{"chave":"serie","rotulo":"Série / ano escolar","tipo":"texto","obrigatorio":true},
   {"chave":"escola","rotulo":"Escola municipal de preferência","tipo":"texto","obrigatorio":false}]',5),
('a1111111-1111-1111-1111-111111111111','d4444444-4444-4444-4444-444444444444','EDUCACAO','Transporte Escolar e Alimentação / Merenda','🚌','DOCUMENTACAO',true,false,false,
 '[{"chave":"origem","rotulo":"Linha ou bairro de origem","tipo":"texto","obrigatorio":true},
   {"chave":"escola_destino","rotulo":"Escola de destino","tipo":"texto","obrigatorio":true},
   {"chave":"distancia_km","rotulo":"Distância aproximada (km)","tipo":"numero","obrigatorio":false}]',4),

-- 5. HABITAÇÃO E ASSISTÊNCIA SOCIAL
('a1111111-1111-1111-1111-111111111111','d5555555-5555-5555-5555-555555555555','SOCIAL','CRAS e CREAS - CadÚnico e Bolsa Família','🤝','AGENDAMENTO',false,false,true,
 '[{"chave":"pessoas_residencia","rotulo":"Pessoas que moram na residência","tipo":"numero","obrigatorio":true},
   {"chave":"nis","rotulo":"Número NIS (se já possuir)","tipo":"texto","obrigatorio":false}]',3),
('a1111111-1111-1111-1111-111111111111','d5555555-5555-5555-5555-555555555555','SOCIAL','Programas Habitacionais e Moradia Popular','🏡','DOCUMENTACAO',true,false,false,
 '[{"chave":"renda_familiar","rotulo":"Renda familiar mensal total","tipo":"numero","obrigatorio":true},
   {"chave":"situacao_moradia","rotulo":"Situação de moradia","tipo":"select","obrigatorio":true,"opcoes":["Aluguel","Área de risco","Cedida","Outra"]}]',10)
ON CONFLICT DO NOTHING;

-- Campinas: Secretarias e Catálogo Clonado
INSERT INTO public.secretarias (prefeitura_id, nome, sigla, categoria)
SELECT 'b2222222-2222-2222-2222-222222222222', nome, sigla, categoria
FROM public.secretarias WHERE prefeitura_id = 'a1111111-1111-1111-1111-111111111111'
  AND NOT EXISTS (SELECT 1 FROM public.secretarias WHERE prefeitura_id = 'b2222222-2222-2222-2222-222222222222');

INSERT INTO public.catalogo_servicos
  (prefeitura_id, secretaria_id, categoria, nome, icone, tipo_fluxo, exige_endereco,
   exige_unidade_saude, exige_cartao_sus, campos_personalizados, prazo_estimado_dias)
SELECT 'b2222222-2222-2222-2222-222222222222', sc.id, cs.categoria, cs.nome, cs.icone, cs.tipo_fluxo,
       cs.exige_endereco, cs.exige_unidade_saude, cs.exige_cartao_sus, cs.campos_personalizados, cs.prazo_estimado_dias
FROM public.catalogo_servicos cs
JOIN public.secretarias sc ON sc.prefeitura_id = 'b2222222-2222-2222-2222-222222222222' AND sc.categoria = cs.categoria
WHERE cs.prefeitura_id = 'a1111111-1111-1111-1111-111111111111'
  AND NOT EXISTS (SELECT 1 FROM public.catalogo_servicos WHERE prefeitura_id = 'b2222222-2222-2222-2222-222222222222');
