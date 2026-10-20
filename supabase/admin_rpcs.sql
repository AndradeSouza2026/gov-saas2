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

-- 6. Notifica o PostgREST para recarregar o cache de schema imediatamente
NOTIFY pgrst, 'reload schema';

