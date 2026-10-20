-- ==============================================================================
-- ATIVAÇÃO AUTOMÁTICA DE ADMINISTRADOR NO CONECTAPREFEITURA
-- 1. Execute este comando no SQL Editor do Supabase (leva 1 segundo)
-- 2. Ele limpa registros antigos corrompidos e instala o gatilho automático
-- ==============================================================================

-- 1. Remove registro corrompido para permitir criar pelo painel oficial
DELETE FROM auth.users WHERE email = 'admin@prefeitura.gov.br';

-- 2. Gatilho automático: qualquer usuário criado no Supabase Auth vira ADMIN de Itapemirim
CREATE OR REPLACE FUNCTION public.trg_vincular_novo_usuario_prefeitura()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.usuarios_prefeitura (
        user_id,
        prefeitura_id,
        nome,
        email,
        papel,
        ativo
    ) VALUES (
        NEW.id,
        'e0011111-0001-0001-0001-000000000002', -- Itapemirim (ou o UUID da sua cidade)
        coalesce(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        NEW.email,
        'ADMIN',
        true
    )
    ON CONFLICT (user_id) DO UPDATE SET
        papel = 'ADMIN',
        ativo = true;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_novo_usuario_prefeitura ON auth.users;
CREATE TRIGGER trg_novo_usuario_prefeitura
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.trg_vincular_novo_usuario_prefeitura();

-- 3. Sincroniza imediatamente todos os usuários que já existirem em auth.users
INSERT INTO public.usuarios_prefeitura (user_id, prefeitura_id, nome, email, papel, ativo)
SELECT 
    id, 
    'e0011111-0001-0001-0001-000000000002', 
    coalesce(raw_user_meta_data->>'full_name', split_part(email, '@', 1)), 
    email, 
    'ADMIN', 
    true
FROM auth.users
ON CONFLICT (user_id) DO UPDATE SET papel = 'ADMIN', ativo = true;
