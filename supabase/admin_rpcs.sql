-- ==============================================================================
-- FUNÇÕES ADMINISTRATIVAS: CONFIRMAR AGENDAMENTO, CONCLUIR E CANCELAR CHAMADOS
-- Cole e execute no SQL Editor do Supabase (leva 1 segundo)
-- ==============================================================================

-- 1. Garante a existência das colunas necessárias na tabela solicitacoes
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

UPDATE public.usuarios_prefeitura 
SET papel = 'SUPER_ADMIN' 
WHERE email = 'joseandrade1406@gmail.com';

-- Garante que administradores possam visualizar e alternar entre prefeituras no RLS
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

-- 2. Função RPC para Confirmar Agendamento
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

-- 3. Função RPC para Concluir Solicitação
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

-- 4. Função RPC para Cancelar Solicitação
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

-- 5. Garante permissões de execução
GRANT EXECUTE ON FUNCTION public.confirmar_agendamento(UUID, TIMESTAMPTZ, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.concluir_solicitacao(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.cancelar_solicitacao(UUID, TEXT) TO authenticated, anon;

-- 6. Função Utilitária para Vincular Servidor a uma Cidade de forma segura e amigável
CREATE OR REPLACE FUNCTION public.vincular_servidor(
    p_email TEXT,
    p_cidade TEXT,
    p_nome TEXT,
    p_papel TEXT DEFAULT 'ADMIN'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_pref_id UUID;
    v_cidade_oficial TEXT;
BEGIN
    -- 1. Busca o usuário no Auth pelo e-mail
    SELECT id INTO v_user_id FROM auth.users WHERE lower(email) = lower(trim(p_email)) LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'O e-mail "%" ainda não foi cadastrado no Auth! Crie o usuário primeiro em Authentication > Users > Add user no Supabase.', p_email;
    END IF;

    -- 2. Busca a prefeitura pelo nome da cidade (busca aproximada sem case-sensitive)
    SELECT id, cidade INTO v_pref_id, v_cidade_oficial 
    FROM public.prefeituras 
    WHERE lower(cidade) ILIKE '%' || lower(trim(p_cidade)) || '%' 
    LIMIT 1;
    
    IF v_pref_id IS NULL THEN
        RAISE EXCEPTION 'Município com o termo "%" não foi encontrado na tabela prefeituras.', p_cidade;
    END IF;

    -- 3. Insere ou atualiza o vínculo com a prefeitura
    INSERT INTO public.usuarios_prefeitura (user_id, prefeitura_id, nome, email, papel, ativo)
    VALUES (v_user_id, v_pref_id, p_nome, p_email, upper(trim(p_papel)), true)
    ON CONFLICT (user_id) DO UPDATE SET
        prefeitura_id = EXCLUDED.prefeitura_id,
        nome = EXCLUDED.nome,
        email = EXCLUDED.email,
        papel = EXCLUDED.papel,
        ativo = true;

    RETURN '✅ Sucesso! O usuário ' || p_email || ' (' || p_nome || ') foi vinculado como ' || upper(trim(p_papel)) || ' de ' || v_cidade_oficial || '!';
END;
$$;

GRANT EXECUTE ON FUNCTION public.vincular_servidor(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

-- 7. Notifica o PostgREST para recarregar o cache de schema imediatamente
NOTIFY pgrst, 'reload schema';

