# ConectaPrefeitura SaaS Gov — Polo Sul do Espírito Santo (ES)

Plataforma multi-prefeitura de atendimento ao cidadão e gestão pública municipal para os 27 municípios do Sul do Espírito Santo.

---

## 🏛️ Estrutura do Projeto

```text
├── index.html                   # App do Cidadão (catálogo, formulário dinâmico, mapa GPS Leaflet, protocolos)
├── admin.html                   # Painel da Prefeitura (login real Supabase Auth, despacho WhatsApp, gestão de serviços)
├── server.js                    # Servidor local Node.js na porta 8000
├── supabase/
│   ├── schema.sql               # Esquema completo do banco (RLS, multi-tenant, RPCs, seed das 27 cidades)
│   ├── fix_triggers.sql         # Script rápido de limpeza e ativação de triggers
│   └── functions/
│       └── convidar-usuario/    # Edge Function para convite de servidores via Supabase Auth Admin
└── README.md
```

---

## 🚀 Como Executar Localmente

Como o ambiente Windows utiliza Node.js:

1. **Iniciar o Servidor:**
   ```bash
   node server.js
   ```
   *O servidor ficará ativo em `http://localhost:8000`.*

2. **Acessar as Aplicações:**
   - **App do Cidadão:** [http://localhost:8000/index.html](http://localhost:8000/index.html)
   - **Painel Administrativo:** [http://localhost:8000/admin.html](http://localhost:8000/admin.html)

---

## 🗄️ Configuração do Banco de Dados (Supabase)

### 1. Executar o Esquema Principal
No **SQL Editor** do Supabase, cole e execute o conteúdo de:
- [`supabase/schema.sql`](file:///c:/Users/User/Desktop/Agencia%20Andrade%20e%20Souza%20%20Desing/Aplicativo%20prefeituras/supabase/schema.sql)

### 2. Executar Limpeza de Triggers (Idempotente)
Para garantir que nenhum trigger legado interfira na inserção:
- [`supabase/fix_triggers.sql`](file:///c:/Users/User/Desktop/Agencia%20Andrade%20e%20Souza%20%20Desing/Aplicativo%20prefeituras/supabase/fix_triggers.sql)

---

## 👤 Criando o Primeiro Usuário Administrador

1. No painel do **Supabase**:
   - Vá em **Authentication** > **Users** > **Add User** > **Create User**.
   - Digite o e-mail: `admin@prefeitura.gov.br` (ou o de sua preferência) e a senha.
2. No **SQL Editor** do Supabase, execute o vínculo com o município desejado:
   ```sql
   INSERT INTO public.usuarios_prefeitura (user_id, prefeitura_id, nome, email, papel, ativo)
   VALUES (
       (SELECT id FROM auth.users WHERE email = 'admin@prefeitura.gov.br'),
       'e0011111-0001-0001-0001-000000000002', -- Itapemirim (ou o UUID da cidade desejada)
       'Administrador Geral',
       'admin@prefeitura.gov.br',
       'ADMIN',
       true
   )
   ON CONFLICT (user_id) DO UPDATE SET
       papel = 'ADMIN',
       ativo = true;
   ```
3. Acesse `http://localhost:8000/admin.html` e faça login com essas credenciais.

---

## 🔒 Segurança e Arquitetura

- **Sem Chaves Secretas no Front:** Apenas a chave pública `anon` é exposta. Toda mutação de protocolo ou abertura anônima é validada por RPCs `SECURITY DEFINER`.
- **Row Level Security (RLS):**
  - Cidadão: Abertura e consulta são feitas via RPCs (`abrir_solicitacao`, `consultar_protocolo`, `listar_meus_pedidos`).
  - Servidores (`SERVIDOR`): Enxergam e despacham exclusivamente os chamados de sua secretaria designada.
  - Administradores (`ADMIN`): Visão total do município, gestão de servidores e indicadores consolidados.
- **Protocolos Oficiais:** Formato sequencial anual (`AAAA-NNNNNN`, ex: `2026-000003`) com código público de segurança de 10 caracteres.
- **Tempo Real:** Notificações instantâneas via `supabase_realtime` com sinal sonoro a cada nova solicitação do cidadão.

