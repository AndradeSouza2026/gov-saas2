-- ==============================================================================
-- SCRIPT SQL DE TESTE - ESTRUTURA INICIAL PARA APLICATIVO PREFEITURAS
-- Compatível com Supabase (PostgreSQL)
-- ==============================================================================

-- 1. Tabela de Secretarias Municipais
CREATE TABLE IF NOT EXISTS public.secretarias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(150) NOT NULL,
    sigla VARCHAR(20),
    responsavel VARCHAR(150),
    telefone VARCHAR(30),
    email VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Tabela de Serviços ao Cidadão
CREATE TABLE IF NOT EXISTS public.servicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    secretaria_id UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
    titulo VARCHAR(150) NOT NULL,
    descricao TEXT,
    icone VARCHAR(50) DEFAULT 'info',
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Tabela de Solicitações / Chamados do Cidadão (Ouvidoria / Zeladoria Urbana)
CREATE TABLE IF NOT EXISTS public.solicitacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    protocolo VARCHAR(20) UNIQUE NOT NULL,
    secretaria_id UUID REFERENCES public.secretarias(id) ON DELETE SET NULL,
    nome_cidadao VARCHAR(150) NOT NULL,
    cpf_cidadao VARCHAR(20),
    telefone VARCHAR(30),
    endereco_ocorrencia TEXT NOT NULL,
    bairro VARCHAR(100),
    tipo_solicitacao VARCHAR(100) NOT NULL, -- Ex: Iluminação pública, Buraco na pista, Poda de árvore
    descricao TEXT NOT NULL,
    foto_url TEXT,
    status VARCHAR(30) DEFAULT 'Pendente' CHECK (status IN ('Pendente', 'Em Análise', 'Em Execução', 'Concluído', 'Cancelado')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Tabela de Notícias / Avisos Oficiais da Prefeitura
CREATE TABLE IF NOT EXISTS public.noticias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo VARCHAR(255) NOT NULL,
    resumo TEXT,
    conteudo TEXT NOT NULL,
    imagem_capa TEXT,
    publicado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    destaque BOOLEAN DEFAULT false
);

-- ==============================================================================
-- DADOS DE TESTE (MOCK DATA)
-- ==============================================================================

-- Inserindo secretarias de exemplo
INSERT INTO public.secretarias (id, nome, sigla, responsavel, telefone, email)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Secretaria Municipal de Obras e Serviços Públicos', 'SEMOSP', 'Carlos Silva', '(11) 3000-0001', 'obras@prefeitura.gov.br'),
    ('22222222-2222-2222-2222-222222222222', 'Secretaria Municipal de Saúde', 'SMS', 'Dra. Maria Fernanda', '(11) 3000-0002', 'saude@prefeitura.gov.br'),
    ('33333333-3333-3333-3333-333333333333', 'Secretaria Municipal de Meio Ambiente', 'SMMA', 'Roberto Andrade', '(11) 3000-0003', 'meioambiente@prefeitura.gov.br')
ON CONFLICT (id) DO NOTHING;

-- Inserindo serviços de exemplo
INSERT INTO public.servicos (secretaria_id, titulo, descricao, icone)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'Reparo de Iluminação Pública', 'Solicite a troca de lâmpadas ou reparo de postes apagados.', 'lightbulb'),
    ('11111111-1111-1111-1111-111111111111', 'Operação Tapa-Buraco', 'Comunique buracos e problemas no asfalto da sua rua.', 'road'),
    ('33333333-3333-3333-3333-333333333333', 'Poda de Árvore', 'Solicitação de vistoria e poda preventiva em via pública.', 'tree'),
    ('22222222-2222-2222-2222-222222222222', 'Agendamento de Consulta Básica', 'Agende atendimento na UBS do seu bairro.', 'calendar');

-- Inserindo uma solicitação de exemplo
INSERT INTO public.solicitacoes (protocolo, secretaria_id, nome_cidadao, cpf_cidadao, telefone, endereco_ocorrencia, bairro, tipo_solicitacao, descricao, status)
VALUES
    ('20261014-001', '11111111-1111-1111-1111-111111111111', 'Cidadão Exemplo', '123.456.789-00', '(11) 99999-0000', 'Rua das Flores, altura do nº 150', 'Centro', 'Reparo de Iluminação Pública', 'Poste apagado há 3 noites consecutivas em frente ao ponto de ônibus.', 'Pendente')
ON CONFLICT (protocolo) DO NOTHING;

-- Inserindo uma notícia de exemplo
INSERT INTO public.noticias (titulo, resumo, conteudo, destaque)
VALUES
    ('Campanha de Vacinação no Próximo Sábado', 'Todos os postos de saúde estarão abertos das 08h às 17h para atualização da caderneta.', 'A Prefeitura Municipal informa que no próximo sábado acontecerá o Dia D de Vacinação...', true);

-- ==============================================================================
-- HABILITAR RLS (Row Level Security) - RECOMENDADO NO SUPABASE
-- ==============================================================================
ALTER TABLE public.secretarias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.servicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.noticias ENABLE ROW LEVEL SECURITY;

-- Políticas de leitura pública para teste
CREATE POLICY "Permitir leitura publica de secretarias" ON public.secretarias FOR SELECT USING (true);
CREATE POLICY "Permitir leitura publica de servicos" ON public.servicos FOR SELECT USING (true);
CREATE POLICY "Permitir leitura publica de noticias" ON public.noticias FOR SELECT USING (true);
CREATE POLICY "Permitir insercao de chamados por qualquer cidadao" ON public.solicitacoes FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir leitura de chamados criados" ON public.solicitacoes FOR SELECT USING (true);
