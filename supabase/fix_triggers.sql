-- ==============================================================================
-- CORREÇÃO IMEDIATA: REMOVE TRIGGERS LEGADOS E RESTRIÇÃO DO CARTÃO SUS
-- Cole e execute este comando no SQL Editor do Supabase (leva 1 segundo)
-- ==============================================================================

-- 1. Remove qualquer CHECK constraint ou obrigatoriedade de Cartão SUS
ALTER TABLE public.solicitacoes DROP CONSTRAINT IF EXISTS solicitacoes_cartao_sus_check;
ALTER TABLE public.solicitacoes ALTER COLUMN cartao_sus DROP NOT NULL;
UPDATE public.catalogo_servicos SET exige_cartao_sus = false;

-- 2. Remove triggers legados que bloqueavam o insert
DROP TRIGGER IF EXISTS trg_antes_inserir_solicitacao ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trg_historico ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trg_solicitacoes_antes_inserir ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trg_solicitacao_historico ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trigger_atualizar_solicitacoes ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trg_solicitacoes_updated ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trigger_solicitacoes_updated_at ON public.solicitacoes CASCADE;
DROP TRIGGER IF EXISTS trg_before_insert_solicitacao ON public.solicitacoes CASCADE;

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
    ) LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I CASCADE', r.tgname, r.relname);
    END LOOP;
END $$;

DROP FUNCTION IF EXISTS public.antes_inserir_solicitacao() CASCADE;
DROP FUNCTION IF EXISTS public.registrar_historico() CASCADE;

-- Recria o trigger oficial de protocolos sequenciais
DROP TRIGGER IF EXISTS trg_before_insert_solicitacao ON public.solicitacoes CASCADE;
CREATE TRIGGER trg_before_insert_solicitacao
BEFORE INSERT ON public.solicitacoes
FOR EACH ROW
EXECUTE FUNCTION public.trg_solicitacoes_gerar_protocolo();

-- Garante permissões de execução pública para o App do Cidadão
GRANT EXECUTE ON FUNCTION public.abrir_solicitacao(jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consultar_protocolo(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.listar_meus_pedidos(text, uuid) TO anon, authenticated;

