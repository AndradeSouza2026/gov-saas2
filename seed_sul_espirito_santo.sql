-- ==============================================================================
-- SEED OFICIAL: TODAS AS 27 CIDADES DO SUL DO ESPÍRITO SANTO (ES)
-- Execute este script no SQL Editor do Supabase (https://supabase.com/dashboard)
-- ==============================================================================

-- 1. Inserir as 27 Prefeituras do Sul do Espírito Santo
INSERT INTO public.prefeituras (id, nome, cidade, uf, brasao_url, email_admin, telefone_contato, ativo, status_assinatura) VALUES
  ('e0011111-0001-0001-0001-000000000001', 'Prefeitura Municipal de Cachoeiro de Itapemirim', 'Cachoeiro de Itapemirim', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@cachoeiro.es.gov.br', '2831555222', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000002', 'Prefeitura Municipal de Itapemirim', 'Itapemirim', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@itapemirim.es.gov.br', '2835296000', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000003', 'Prefeitura Municipal de Marataízes', 'Marataízes', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@marataizes.es.gov.br', '2835323200', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000004', 'Prefeitura Municipal de Anchieta', 'Anchieta', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@anchieta.es.gov.br', '2835360300', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000005', 'Prefeitura Municipal de Piúma', 'Piúma', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@piuma.es.gov.br', '2835201200', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000006', 'Prefeitura Municipal de Iconha', 'Iconha', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@iconha.es.gov.br', '2835371011', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000007', 'Prefeitura Municipal de Rio Novo do Sul', 'Rio Novo do Sul', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@rionovodosul.es.gov.br', '2835331120', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000008', 'Prefeitura Municipal de Presidente Kennedy', 'Presidente Kennedy', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@presidentekennedy.es.gov.br', '2835351900', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000009', 'Prefeitura Municipal de Castelo', 'Castelo', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@castelo.es.gov.br', '2835426300', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000010', 'Prefeitura Municipal de Vargem Alta', 'Vargem Alta', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@vargemalta.es.gov.br', '2835281900', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000011', 'Prefeitura Municipal de Muqui', 'Muqui', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@muqui.es.gov.br', '2835541222', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000012', 'Prefeitura Municipal de Mimoso do Sul', 'Mimoso do Sul', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@mimosodosul.es.gov.br', '2835551333', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000013', 'Prefeitura Municipal de Atílio Vivácqua', 'Atílio Vivácqua', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@atiliovivacqua.es.gov.br', '2835381109', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000014', 'Prefeitura Municipal de Alegre', 'Alegre', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@alegre.es.gov.br', '2835521244', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000015', 'Prefeitura Municipal de Guaçuí', 'Guaçuí', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@guacui.es.gov.br', '2835534900', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000016', 'Prefeitura Municipal de São José do Calçado', 'São José do Calçado', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@calcado.es.gov.br', '2835561122', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000017', 'Prefeitura Municipal de Bom Jesus do Norte', 'Bom Jesus do Norte', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@bomjesus.es.gov.br', '2835621111', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000018', 'Prefeitura Municipal de Apiacá', 'Apiacá', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@apiaca.es.gov.br', '2835571100', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000019', 'Prefeitura Municipal de Jerônimo Monteiro', 'Jerônimo Monteiro', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@jeronimomonteiro.es.gov.br', '2835581333', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000020', 'Prefeitura Municipal de Ibitirama', 'Ibitirama', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@ibitirama.es.gov.br', '2835691122', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000021', 'Prefeitura Municipal de Divino de São Lourenço', 'Divino de São Lourenço', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@divino.es.gov.br', '2835511200', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000022', 'Prefeitura Municipal de Dores do Rio Preto', 'Dores do Rio Preto', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@dores.es.gov.br', '2835591100', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000023', 'Prefeitura Municipal de Iúna', 'Iúna', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@iuna.es.gov.br', '2835451300', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000024', 'Prefeitura Municipal de Irupi', 'Irupi', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@irupi.es.gov.br', '2835481122', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000025', 'Prefeitura Municipal de Ibatiba', 'Ibatiba', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@ibatiba.es.gov.br', '2835431600', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000026', 'Prefeitura Municipal de Muniz Freire', 'Muniz Freire', 'ES', 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=120', 'gabinete@munizfreire.es.gov.br', '2835441113', true, 'GRATUITO_BETA'),
  ('e0011111-0001-0001-0001-000000000027', 'Prefeitura Municipal de Alfredo Chaves', 'Alfredo Chaves', 'ES', 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?w=120', 'gabinete@alfredochaves.es.gov.br', '2732692700', true, 'GRATUITO_BETA')
ON CONFLICT (cidade, uf) DO UPDATE 
SET ativo = true, status_assinatura = 'GRATUITO_BETA';

-- 2. Secretarias modelo para Cachoeiro de Itapemirim (cidade polo)
INSERT INTO public.secretarias (id, prefeitura_id, nome, sigla, categoria) VALUES
  ('c0011111-0001-0001-0001-000000000001','e0011111-0001-0001-0001-000000000001','Secretaria Municipal de Saúde','SEMUS','SAUDE'),
  ('c0011111-0001-0001-0001-000000000002','e0011111-0001-0001-0001-000000000001','Secretaria de Cidadania, Trabalho e Direitos Humanos','SEMCT','CIDADANIA'),
  ('c0011111-0001-0001-0001-000000000003','e0011111-0001-0001-0001-000000000001','Secretaria de Manutenção, Serviços e Obras','SEMOB','ZELADORIA'),
  ('c0011111-0001-0001-0001-000000000004','e0011111-0001-0001-0001-000000000001','Secretaria Municipal de Educação','SEME','EDUCACAO'),
  ('c0011111-0001-0001-0001-000000000005','e0011111-0001-0001-0001-000000000001','Secretaria de Desenvolvimento Social e Habitação','SEMDS','SOCIAL')
ON CONFLICT DO NOTHING;

-- 3. 16 Serviços Essenciais para Cachoeiro de Itapemirim
INSERT INTO public.catalogo_servicos
  (prefeitura_id, secretaria_id, categoria, nome, icone, tipo_fluxo,
   exige_endereco, exige_unidade_saude, exige_cartao_sus, campos_personalizados, prazo_estimado_dias)
VALUES
-- SAÚDE
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000001','SAUDE','Consultas Médicas (UBS) - Clínico Geral e Pediatria','🩺','AGENDAMENTO',false,true,true,
 '[{"chave":"especialidade","rotulo":"Especialidade","tipo":"select","obrigatorio":true,"opcoes":["Clínico Geral","Pediatria"]},
   {"chave":"motivo","rotulo":"Sintomas ou motivo principal","tipo":"texto","obrigatorio":true}]',3),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000001','SAUDE','Atendimento Odontológico / Dentista (UBS e CEO)','🦷','AGENDAMENTO',false,true,true,
 '[{"chave":"tipo_atendimento","rotulo":"Tipo de Atendimento","tipo":"select","obrigatorio":true,"opcoes":["Consulta / Avaliação","Limpeza / Profilaxia","Restauração / Obturação","Extração","Dor Aguda / Urgência"]},
   {"chave":"motivo","rotulo":"Motivo do agendamento odontológico","tipo":"texto","obrigatorio":true}]',3),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000001','SAUDE','Vacinação - Calendário Nacional e Campanhas','💉','AGENDAMENTO',false,true,true,
 '[{"chave":"vacina","rotulo":"Vacina desejada","tipo":"select","obrigatorio":true,"opcoes":["Gripe","Covid","Tríplice","Infantil"]},
   {"chave":"faixa_etaria","rotulo":"Faixa etária do vacinado","tipo":"select","obrigatorio":true,"opcoes":["Criança","Adolescente","Adulto","Idoso"]}]',2),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000001','SAUDE','Distribuição de Medicamentos Básicos (Farmácia Popular)','💊','AGENDAMENTO',false,true,true,
 '[{"chave":"medicamento","rotulo":"Nome do medicamento da receita","tipo":"texto","obrigatorio":true},
   {"chave":"receita","rotulo":"Número da receita médica","tipo":"texto","obrigatorio":true}]',1),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000001','SAUDE','Pronto-Atendimento / UPA 24h (Orientações e Triagem)','🚑','DOCUMENTACAO',false,false,false,
 '[{"chave":"urgencia","rotulo":"Descrição da urgência","tipo":"texto","obrigatorio":true}]',1),

-- CIDADANIA
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000002','CIDADANIA','Emissão de 2ª Via de Certidões (Nascimento/Casamento)','📜','DOCUMENTACAO',false,false,false,
 '[{"chave":"tipo_certidao","rotulo":"Tipo de certidão","tipo":"select","obrigatorio":true,"opcoes":["Nascimento","Casamento","Óbito"]},
   {"chave":"cartorio","rotulo":"Cartório de registro original","tipo":"texto","obrigatorio":true}]',5),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000002','CIDADANIA','Junta Militar - Alistamento e Certificados','🎖️','DOCUMENTACAO',false,false,false,
 '[{"chave":"ano_nascimento","rotulo":"Ano de nascimento","tipo":"numero","obrigatorio":true}]',3),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000002','CIDADANIA','PAT / Agência do Trabalhador e Seguro-Desemprego','💼','AGENDAMENTO',false,false,false,
 '[{"chave":"area","rotulo":"Área de atuação / cargo desejado","tipo":"texto","obrigatorio":true}]',2),

-- ZELADORIA
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000003','ZELADORIA','Coleta de Lixo Especial e Cata-Treco (Móveis/Entulhos)','🚛','ZELADORIA',true,false,false,
 '[{"chave":"itens","rotulo":"O que precisa ser recolhido","tipo":"texto","obrigatorio":true}]',4),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000003','ZELADORIA','Iluminação Pública - Troca de Lâmpadas e Manutenção','💡','ZELADORIA',true,false,false,
 '[{"chave":"situacao","rotulo":"Situacao do poste","tipo":"select","obrigatorio":true,"opcoes":["Aceso de dia","Apagado a noite","Piscando"]}]',2),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000003','ZELADORIA','Manutenção de Vias - Tapa-Buraco e Bueiros','🚧','ZELADORIA',true,false,false,
 '[{"chave":"problema","rotulo":"Problema","tipo":"select","obrigatorio":true,"opcoes":["Buraco na pista","Bueiro entupido","Afundamento"]}]',5),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000003','ZELADORIA','Limpeza e Paisagismo - Corte de Mato e Praças','🌳','ZELADORIA',true,false,false,
 '[{"chave":"local","rotulo":"Local","tipo":"select","obrigatorio":true,"opcoes":["Praca publica","Canteiro central","Calcada"]}]',4),

-- EDUCAÇÃO
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000004','EDUCACAO','Creches e Pré-Escolas - Inscrição e Vagas','👶','DOCUMENTACAO',true,false,false,
 '[{"chave":"nome_crianca","rotulo":"Nome da crianca","tipo":"texto","obrigatorio":true},
   {"chave":"periodo","rotulo":"Periodo desejado","tipo":"select","obrigatorio":true,"opcoes":["Integral","Parcial"]}]',7),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000004','EDUCACAO','Ensino Fundamental I e II - Matrículas e Transferências','🎒','DOCUMENTACAO',false,false,false,
 '[{"chave":"serie","rotulo":"Serie escolar","tipo":"texto","obrigatorio":true}]',5),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000004','EDUCACAO','Transporte Escolar (Rotas, Pontos e Carteirinha)','🚌','DOCUMENTACAO',true,false,false,
 '[{"chave":"origem","rotulo":"Linha ou bairro de origem","tipo":"texto","obrigatorio":true},
   {"chave":"escola","rotulo":"Escola de destino","tipo":"texto","obrigatorio":true}]',3),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000004','EDUCACAO','Alimentação e Merenda Escolar (Cardápio e Dietas)','🍎','DOCUMENTACAO',false,false,false,
 '[{"chave":"escola","rotulo":"Escola do aluno","tipo":"texto","obrigatorio":true},
   {"chave":"dieta_especial","rotulo":"Restrição alimentar ou solicitação","tipo":"texto","obrigatorio":true}]',3),

-- SOCIAL
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000005','SOCIAL','CRAS e CREAS - CadÚnico e Bolsa Família','🤝','AGENDAMENTO',false,false,true,
 '[{"chave":"pessoas_residencia","rotulo":"Pessoas na residencia","tipo":"numero","obrigatorio":true}]',3),
('e0011111-0001-0001-0001-000000000001','c0011111-0001-0001-0001-000000000005','SOCIAL','Programas Habitacionais e Moradia Popular','🏡','DOCUMENTACAO',true,false,false,
 '[{"chave":"renda_familiar","rotulo":"Renda familiar mensal","tipo":"numero","obrigatorio":true}]',10)
ON CONFLICT DO NOTHING;

-- 4. Replicar os 16 Serviços para todas as outras 26 Prefeituras do Sul do ES
INSERT INTO public.catalogo_servicos
  (prefeitura_id, categoria, nome, icone, tipo_fluxo, exige_endereco,
   exige_unidade_saude, exige_cartao_sus, campos_personalizados, prazo_estimado_dias)
SELECT 
  p.id AS prefeitura_id,
  cs.categoria, cs.nome, cs.icone, cs.tipo_fluxo,
  cs.exige_endereco, cs.exige_unidade_saude, cs.exige_cartao_sus,
  cs.campos_personalizados, cs.prazo_estimado_dias
FROM public.prefeituras p
CROSS JOIN (
  SELECT * FROM public.catalogo_servicos WHERE prefeitura_id = 'e0011111-0001-0001-0001-000000000001'
) cs
WHERE p.uf = 'ES' 
  AND p.id <> 'e0011111-0001-0001-0001-000000000001'
  AND NOT EXISTS (
    SELECT 1 FROM public.catalogo_servicos existing 
    WHERE existing.prefeitura_id = p.id AND existing.nome = cs.nome
  );

