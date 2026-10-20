-- ==============================================================================
-- CONECTAPREFEITURA SAAS - FUNÇÕES ADMINISTRATIVAS E MULTI-TENANT COMPLETAS
-- 1. Gestão de Prefeituras (Criar com Seed automático de Serviços e Excluir)
-- 2. Cadastro 100% Automático de Servidores (Auth + Perfil + Senha Provisória)
-- 3. Confirmação de Agendamentos, Conclusão com WhatsApp e Cancelamento
-- Cole e execute no SQL Editor do Supabase (leva 2 segundos)
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Garante colunas necessárias na tabela solicitacoes
ALTER TABLE public.solicitacoes ADD COLUMN IF NOT EXISTS agendado_para TIMESTAMPTZ;
ALTER TABLE public.solicitacoes ADD COLUMN IF NOT EXISTS prazo_limite TIMESTAMPTZ;
ALTER TABLE public.solicitacoes ADD COLUMN IF NOT EXISTS concluido_em TIMESTAMPTZ;
ALTER TABLE public.solicitacoes ADD COLUMN IF NOT EXISTS observacao_conclusao TEXT;
ALTER TABLE public.solicitacoes ADD COLUMN IF NOT EXISTS resposta_prefeitura TEXT;
ALTER TABLE public.solicitacoes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Suporte a SUPER_ADMIN na tabela de usuários da prefeitura
DO $$ BEGIN
    ALTER TABLE public.usuarios_prefeitura DROP CONSTRAINT IF EXISTS usuarios_prefeitura_papel_check;
    ALTER TABLE public.usuarios_prefeitura ADD CONSTRAINT usuarios_prefeitura_papel_check CHECK (papel IN ('ADMIN', 'SERVIDOR', 'SUPER_ADMIN'));
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Garante que o desenvolvedor/gestor principal seja SUPER_ADMIN
UPDATE public.usuarios_prefeitura 
SET papel = 'SUPER_ADMIN' 
WHERE email = 'joseandrade1406@gmail.com';

-- Remove triggers legados que forçavam vínculo incorreto a uma única cidade
DROP TRIGGER IF EXISTS trg_novo_usuario_prefeitura ON auth.users;
DROP FUNCTION IF EXISTS public.trg_vincular_novo_usuario_prefeitura() CASCADE;

-- ==============================================================================
-- 2. POLÍTICAS RLS: GESTÃO MULTI-PREFEITURA E USUÁRIOS
-- ==============================================================================

-- RLS de Solicitações
DROP POLICY IF EXISTS "solicitacoes_servidores_select" ON public.solicitacoes;
CREATE POLICY "solicitacoes_servidores_select" 
ON public.solicitacoes FOR SELECT 
TO authenticated 
USING (
    public.meu_papel() IN ('ADMIN', 'SUPER_ADMIN')
    OR (auth.jwt()->>'email' IN ('admin@prefeitura.gov.br', 'joseandrade1406@gmail.com'))
    OR (
        prefeitura_id::text = public.minha_prefeitura_id()::text 
        AND (secretaria_id::text = public.minha_secretaria_id()::text OR secretaria_id IS NULL)
    )
);

DROP POLICY IF EXISTS "solicitacoes_servidores_update" ON public.solicitacoes;
CREATE POLICY "solicitacoes_servidores_update" 
ON public.solicitacoes FOR UPDATE 
TO authenticated 
USING (
    public.meu_papel() IN ('ADMIN', 'SUPER_ADMIN')
    OR (auth.jwt()->>'email' IN ('admin@prefeitura.gov.br', 'joseandrade1406@gmail.com'))
    OR (
        prefeitura_id::text = public.minha_prefeitura_id()::text 
        AND (secretaria_id::text = public.minha_secretaria_id()::text OR secretaria_id IS NULL)
    )
);

-- RLS de Usuários da Prefeitura
DROP POLICY IF EXISTS "usuarios_prefeitura_select_own" ON public.usuarios_prefeitura;
CREATE POLICY "usuarios_prefeitura_select_own" 
ON public.usuarios_prefeitura FOR SELECT 
TO authenticated 
USING (
    public.meu_papel() = 'SUPER_ADMIN'
    OR (auth.jwt()->>'email' IN ('admin@prefeitura.gov.br', 'joseandrade1406@gmail.com'))
    OR user_id = auth.uid() 
    OR (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN')
);

DROP POLICY IF EXISTS "usuarios_prefeitura_admin_manage" ON public.usuarios_prefeitura;
CREATE POLICY "usuarios_prefeitura_admin_manage" 
ON public.usuarios_prefeitura FOR ALL 
TO authenticated 
USING (
    public.meu_papel() = 'SUPER_ADMIN'
    OR (auth.jwt()->>'email' IN ('admin@prefeitura.gov.br', 'joseandrade1406@gmail.com'))
    OR (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN')
)
WITH CHECK (
    public.meu_papel() = 'SUPER_ADMIN'
    OR (auth.jwt()->>'email' IN ('admin@prefeitura.gov.br', 'joseandrade1406@gmail.com'))
    OR (prefeitura_id::text = public.minha_prefeitura_id()::text AND public.meu_papel() = 'ADMIN')
);

-- RLS de Prefeituras (Super Admin pode gerenciar livremente)
DROP POLICY IF EXISTS "prefeituras_superadmin_all" ON public.prefeituras;
CREATE POLICY "prefeituras_superadmin_all"
ON public.prefeituras FOR ALL
TO authenticated
USING (
    public.meu_papel() = 'SUPER_ADMIN' 
    OR auth.jwt()->>'email' IN ('joseandrade1406@gmail.com')
)
WITH CHECK (
    public.meu_papel() = 'SUPER_ADMIN' 
    OR auth.jwt()->>'email' IN ('joseandrade1406@gmail.com')
);

GRANT ALL ON public.prefeituras TO authenticated, service_role;
GRANT ALL ON public.usuarios_prefeitura TO authenticated, service_role;

-- ==============================================================================
-- 3. CADASTRO 100% AUTOMÁTICO DE USUÁRIOS / SERVIDORES (SEM DASHBOARD SUPABASE)
-- Cria no Supabase Auth + Hash Bcrypt + Confirmação Imediata + Perfil Municipal
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cadastrar_novo_usuario_sistema(
    p_email TEXT,
    p_senha TEXT,
    p_nome TEXT,
    p_prefeitura_id UUID,
    p_papel TEXT DEFAULT 'SERVIDOR',
    p_secretaria_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id UUID;
    v_encrypted_pw TEXT;
    v_role TEXT := upper(trim(coalesce(p_papel, 'SERVIDOR')));
    v_clean_email TEXT := lower(trim(p_email));
    v_cidade_nome TEXT;
    v_has_provider_id BOOLEAN;
BEGIN
    -- 1. Validação de permissão do usuário executor
    IF public.meu_papel() NOT IN ('ADMIN', 'SUPER_ADMIN') 
       AND auth.jwt()->>'email' NOT IN ('admin@prefeitura.gov.br', 'joseandrade1406@gmail.com') THEN
        RAISE EXCEPTION 'Acesso negado: apenas Administradores podem cadastrar novos servidores.';
    END IF;

    -- Se for ADMIN municipal comum, só pode cadastrar servidores na sua respectiva cidade
    IF public.meu_papel() = 'ADMIN' AND auth.jwt()->>'email' NOT IN ('joseandrade1406@gmail.com') THEN
        IF p_prefeitura_id::text <> public.minha_prefeitura_id()::text THEN
            RAISE EXCEPTION 'Acesso negado: você só tem permissão para cadastrar servidores na sua própria prefeitura.';
        END IF;
        IF v_role = 'SUPER_ADMIN' THEN
            v_role := 'ADMIN';
        END IF;
    END IF;

    -- 2. Validações de campos obrigatórios
    IF v_clean_email = '' OR v_clean_email IS NULL THEN
        RAISE EXCEPTION 'O e-mail é obrigatório.';
    END IF;
    IF p_senha IS NULL OR length(trim(p_senha)) < 6 THEN
        RAISE EXCEPTION 'A senha provisória deve conter no mínimo 6 caracteres.';
    END IF;
    IF p_prefeitura_id IS NULL THEN
        RAISE EXCEPTION 'Selecione uma prefeitura válida para o servidor.';
    END IF;

    -- Busca o nome da cidade para retorno informativo
    SELECT cidade INTO v_cidade_nome FROM public.prefeituras WHERE id = p_prefeitura_id;
    IF v_cidade_nome IS NULL THEN
        RAISE EXCEPTION 'Prefeitura informada não existe no banco de dados.';
    END IF;

    -- 3. Gera hash seguro de senha utilizando bcrypt do PostgreSQL
    v_encrypted_pw := crypt(trim(p_senha), gen_salt('bf'));

    -- 4. Verifica se a conta já existe em auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE lower(email) = v_clean_email LIMIT 1;

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();

        -- Criação da conta no Supabase Auth com e-mail confirmado imediatamente
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_clean_email,
            v_encrypted_pw,
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', trim(p_nome), 'nome', trim(p_nome), 'prefeitura_id', p_prefeitura_id::text, 'papel', v_role),
            now(),
            now(),
            '',
            ''
        );

        -- Insere identidade auth.identities compatível com qualquer versão do Supabase
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'auth' AND table_name = 'identities' AND column_name = 'provider_id'
        ) INTO v_has_provider_id;

        IF v_has_provider_id THEN
            EXECUTE 'INSERT INTO auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
                     VALUES ($1, $2, $3, $4, $5, now(), now(), now())
                     ON CONFLICT DO NOTHING'
            USING gen_random_uuid()::text, v_user_id::text, v_user_id, jsonb_build_object('sub', v_user_id::text, 'email', v_clean_email), 'email';
        ELSE
            EXECUTE 'INSERT INTO auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
                     VALUES ($1, $2, $3, $4, now(), now(), now())
                     ON CONFLICT DO NOTHING'
            USING gen_random_uuid()::text, v_user_id, jsonb_build_object('sub', v_user_id::text, 'email', v_clean_email), 'email';
        END IF;

    ELSE
        -- Usuário já existia no auth: atualiza senha e ativa confirmação
        UPDATE auth.users
        SET encrypted_password = v_encrypted_pw,
            email_confirmed_at = coalesce(email_confirmed_at, now()),
            raw_user_meta_data = jsonb_build_object('full_name', trim(p_nome), 'nome', trim(p_nome), 'prefeitura_id', p_prefeitura_id::text, 'papel', v_role),
            updated_at = now()
        WHERE id = v_user_id;
    END IF;

    -- 5. Insere ou atualiza o vínculo funcional em public.usuarios_prefeitura
    INSERT INTO public.usuarios_prefeitura (
        user_id,
        prefeitura_id,
        secretaria_id,
        nome,
        email,
        papel,
        ativo,
        created_at
    ) VALUES (
        v_user_id,
        p_prefeitura_id,
        CASE WHEN v_role IN ('ADMIN', 'SUPER_ADMIN') THEN NULL ELSE p_secretaria_id END,
        trim(p_nome),
        v_clean_email,
        v_role,
        true,
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        prefeitura_id = EXCLUDED.prefeitura_id,
        secretaria_id = CASE WHEN EXCLUDED.papel IN ('ADMIN', 'SUPER_ADMIN') THEN NULL ELSE EXCLUDED.secretaria_id END,
        nome = EXCLUDED.nome,
        email = EXCLUDED.email,
        papel = EXCLUDED.papel,
        ativo = true;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'email', v_clean_email,
        'nome', trim(p_nome),
        'cidade', v_cidade_nome,
        'papel', v_role,
        'message', 'Usuário ' || v_clean_email || ' cadastrado e ativado com sucesso! Já pode fazer login imediatamente.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cadastrar_novo_usuario_sistema(TEXT, TEXT, TEXT, UUID, TEXT, UUID) TO authenticated, service_role;

-- ==============================================================================
-- 4. EXCLUSÃO DEFINITIVA DE USUÁRIO / SERVIDOR
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.excluir_usuario_prefeitura(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF public.meu_papel() NOT IN ('ADMIN', 'SUPER_ADMIN') 
       AND auth.jwt()->>'email' NOT IN ('admin@prefeitura.gov.br', 'joseandrade1406@gmail.com') THEN
        RAISE EXCEPTION 'Acesso negado: apenas Administradores podem excluir usuários.';
    END IF;

    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Você não pode excluir o seu próprio usuário logado no sistema.';
    END IF;

    DELETE FROM public.usuarios_prefeitura WHERE user_id = p_user_id;
    DELETE FROM auth.users WHERE id = p_user_id;

    RETURN jsonb_build_object('success', true, 'message', 'Usuário e acessos excluídos com sucesso.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.excluir_usuario_prefeitura(UUID) TO authenticated, service_role;

-- ==============================================================================
-- 5. CADASTRO DE NOVA PREFEITURA COM SEED AUTOMÁTICO DE SECRETARIAS E SERVIÇOS
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cadastrar_prefeitura_completa(
    p_nome TEXT,
    p_cidade TEXT,
    p_uf TEXT DEFAULT 'ES',
    p_lat NUMERIC DEFAULT NULL,
    p_lng NUMERIC DEFAULT NULL,
    p_brasao_url TEXT DEFAULT NULL,
    p_semear BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_nova_id UUID;
    v_brasao TEXT;
BEGIN
    IF public.meu_papel() <> 'SUPER_ADMIN' 
       AND auth.jwt()->>'email' NOT IN ('joseandrade1406@gmail.com') THEN
        RAISE EXCEPTION 'Acesso restrito: apenas o Super Administrador pode cadastrar novas prefeituras.';
    END IF;

    IF trim(coalesce(p_nome, '')) = '' OR trim(coalesce(p_cidade, '')) = '' THEN
        RAISE EXCEPTION 'O nome oficial da prefeitura e o nome da cidade são obrigatórios.';
    END IF;

    v_brasao := coalesce(nullif(trim(p_brasao_url), ''), 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120');

    INSERT INTO public.prefeituras (nome, cidade, uf, lat, lng, brasao_url)
    VALUES (trim(p_nome), trim(p_cidade), upper(trim(coalesce(p_uf, 'ES'))), p_lat, p_lng, v_brasao)
    RETURNING id INTO v_nova_id;

    -- Se solicitado, instala automaticamente o ecossistema padrão de 5 Secretarias e 17 Serviços
    IF coalesce(p_semear, true) = true THEN
        PERFORM public.semear_prefeitura(v_nova_id);
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'id', v_nova_id, 
        'nome', trim(p_nome), 
        'cidade', trim(p_cidade),
        'message', 'Prefeitura de ' || trim(p_cidade) || ' cadastrada e estruturada com sucesso!'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cadastrar_prefeitura_completa(TEXT, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, BOOLEAN) TO authenticated, service_role;

-- ==============================================================================
-- 6. EXCLUSÃO DE PREFEITURA (CASCADE COMPLETO DE SERVIÇOS, CHAMADOS E EQUIPE)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.excluir_prefeitura_completa(p_prefeitura_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cidade TEXT;
BEGIN
    IF public.meu_papel() <> 'SUPER_ADMIN' 
       AND auth.jwt()->>'email' NOT IN ('joseandrade1406@gmail.com') THEN
        RAISE EXCEPTION 'Acesso restrito: apenas o Super Administrador pode excluir prefeituras do sistema.';
    END IF;

    SELECT cidade INTO v_cidade FROM public.prefeituras WHERE id = p_prefeitura_id;
    IF v_cidade IS NULL THEN
        RAISE EXCEPTION 'Prefeitura não encontrada no sistema.';
    END IF;

    -- Deleta a prefeitura. O Postgres ON DELETE CASCADE removerá automaticamente
    -- secretarias, catalogo_servicos, solicitacoes e usuarios_prefeitura vinculados.
    DELETE FROM public.prefeituras WHERE id = p_prefeitura_id;

    RETURN jsonb_build_object(
        'success', true, 
        'cidade', v_cidade,
        'message', 'Prefeitura de ' || v_cidade || ' e todos os seus registros foram excluídos com sucesso!'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.excluir_prefeitura_completa(UUID) TO authenticated, service_role;

-- ==============================================================================
-- 7. FUNÇÕES RPC: CONFIRMAR AGENDAMENTO, CONCLUIR E CANCELAR CHAMADOS
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.confirmar_agendamento(
    p_solicitacao_id UUID,
    p_data_hora TIMESTAMPTZ,
    p_local TEXT DEFAULT 'Sede do Município',
    p_orientacoes TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_resposta TEXT;
    v_dataFormatada TEXT;
BEGIN
    v_dataFormatada := to_char(p_data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY às HH24:MI');
    v_resposta := 'Agendamento confirmado para ' || v_dataFormatada || ' no local: ' || coalesce(nullif(trim(p_local), ''), 'Sede do Município') || '. ' || coalesce(p_orientacoes, '');

    UPDATE public.solicitacoes
    SET status = 'AGENDADO',
        agendado_para = p_data_hora,
        resposta_prefeitura = v_resposta,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_solicitacao_id;

    RETURN jsonb_build_object('success', true, 'resposta', v_resposta);
END;
$$;

CREATE OR REPLACE FUNCTION public.concluir_solicitacao(
    p_solicitacao_id UUID,
    p_observacao TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_resposta TEXT;
BEGIN
    v_resposta := coalesce(nullif(trim(p_observacao), ''), 'Atendimento concluído com sucesso pela equipe municipal.');

    UPDATE public.solicitacoes
    SET status = 'CONCLUIDO',
        concluido_em = timezone('utc'::text, now()),
        observacao_conclusao = p_observacao,
        resposta_prefeitura = v_resposta,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_solicitacao_id;

    RETURN jsonb_build_object('success', true, 'resposta', v_resposta);
END;
$$;

CREATE OR REPLACE FUNCTION public.cancelar_solicitacao(
    p_solicitacao_id UUID,
    p_motivo TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_resposta TEXT;
BEGIN
    v_resposta := coalesce(nullif(trim(p_motivo), ''), 'Solicitação cancelada pelo município.');

    UPDATE public.solicitacoes
    SET status = 'CANCELADO',
        resposta_prefeitura = v_resposta,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_solicitacao_id;

    RETURN jsonb_build_object('success', true, 'resposta', v_resposta);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirmar_agendamento(UUID, TIMESTAMPTZ, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.concluir_solicitacao(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.cancelar_solicitacao(UUID, TEXT) TO authenticated, anon;

-- Notifica o PostgREST para recarregar o cache de schema imediatamente
NOTIFY pgrst, 'reload schema';
