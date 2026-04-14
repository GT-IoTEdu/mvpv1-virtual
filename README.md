
# Sistema de Registro IoT com Autenticação CAFe e pfSense

## Diagrama de Arquitetura
![Diagrama de Arquitetura do Sistema](https://github.com/GT-IoTEdu/API/blob/main/diagramas/images/Arquitetura_v1.png)

*Diagrama completo dos componentes e fluxos do sistema*

## Visão Geral
Sistema integrado para gerenciamento seguro de dispositivos IoT em ambientes acadêmicos, combinando:
- ✅ Autenticação federada via CAFe
- 🔐 Gerenciamento automatizado de regras no pfSense
- 🤖 Monitoramento inteligente de tráfego com IA
- 📊 Painel administrativo de dispositivos IoTs cadastrados


# 🚀 Guia Completo de Instalação

  

Este guia detalha o processo completo de instalação do sistema do zero, incluindo banco de dados vazio e pfSense sem configurações.

  

## 📋 Pré-requisitos

  

 

  

## 🔧 Passo 1: Preparar Ambiente

  

###  Opcional: Usar um ambiente virtual

```bash
pip install virtualenv
python3 -m venv venv
source venv/bin/activate
```

  
### 1.1. Configurar Variáveis de Ambiente

  

```bash

cd  backend

cp  env_example.txt  .env

```

  

Edite o arquivo `.env`:

  

```env

# Banco de Dados

MYSQL_USER=IoT_EDU

MYSQL_PASSWORD=sua_senha_aqui

MYSQL_HOST=localhost

MYSQL_DB=iot_edu

# Google OAuth (para login)

GOOGLE_CLIENT_ID=seu_client_id

GOOGLE_CLIENT_SECRET=seu_client_secret

IDS_SSE_TLS_VERIFY=False
AUTH_STRICT_SESSION=False

# Superusuário

SUPERUSER_ACCESS=seu_email@gmail.com

```

  

### 1.2. Instalar Dependências

  

```bash
 
pip  install  -r  requirements.txt

```

  

## 📊 Passo 2: Configurar o pfsense

  

```bash

# Esse script criara uma interface virtual tap0 que sera utilizada na configuração do pfsense

configurar_rede.sh

```

### 2.1. Instalar o Virtualbox
Para instalar o virtualbox acesse https://www.virtualbox.org/wiki/Downloads e escolha o seu OS.

### 2.2. Instale a imagem do pfsense
Este arquivo detalha os passos de instalação do pfsense e alternativamente uma imagem pronta para o virtualbox [Instalacao_PFSense.pdf](https://github.com/user-attachments/files/26728713/Instalacao_PFSense.pdf)

### 2.3. Trocar no Virtualbox para que a interface 2 do pfSense seja a tap0 no modo bridge
![Configuração da interface de clientes como Bridge](diagramas/images/pfsense_bridge2.png)

 

  

**Verificar:**

```sql

USE iot_edu;

SHOW TABLES;

```

  

Deve mostrar todas as tabelas criadas:

- users

- institutions

- dhcp_servers

- dhcp_static_mappings

- pfsense_aliases

- pfsense_alias_addresses

- pfsense_firewall_rules

- zeek_incidents

- etc.

  

## 🛡️ Passo 3: Configurar pfSense

  

### 5.1. Habilitar API REST no pfSense

  

1. Acesse a interface web do pfSense

2. Vá em **System > Package Manager**

3. Instale o pacote **API** (pfsense-pkg-API)

4. Vá em **System > API**

5. Gere uma nova chave de API (SHA256 tamanho 36)

6. Anote a **API Key**

  
  

## 🚀 Passo 4: Criar Aliases e Regras Iniciais
**Importante:** O script `setup_initial_aliases_and_rules.py` precisa ser executado **após** criar a instituição (PASSO 5), pois ele cria os aliases e regras para cada instituição cadastrada.
  

```bash

# Para todas as instituições

python  scripts/setup_initial_aliases_and_rules.py

  

```

  

**O que este script faz:**

1. ✅ Cria alias "Autorizados" no pfSense e banco

2. ✅ Cria alias "Bloqueados" no pfSense e banco

3. ✅ Cria regra BLOCK para alias "Bloqueados"

4. ✅ Cria regra PASS para alias "Autorizados"

5. ✅ Sincroniza regras com o banco de dados

  

**Nota:** Este script requer que a instituição já esteja cadastrada no banco de dados. Se ainda não criou a instituição, veja o Passo 5.

  

## 👥 Passo 5: Criar Instituição e Administrador via Interface Web

  

Após executar os scripts acima, você precisa:

  

1.  **Iniciar o servidor backend:**

```bash

python start_server.py

```

  

2.  **Acessar a interface web** e fazer login com o email configurado em `SUPERUSER_ACCESS` no arquivo `.env`

  

3.  **Criar Instituição:**

- Acesse a seção de **Instituições** na interface web

- Clique em **Nova Instituição**

- Preencha os dados:

- Nome (ex: "Unipampa")

- Cidade (ex: "Alegrete")

- URL do pfSense (ex: "https://seu-pfsense.local/api/v2/")

- Chave API do pfSense

- Range de IPs (ex: "192.168.1.1" a "192.168.1.254")

- Salve a instituição

  

4.  **Criar Usuário Administrador:**

- Acesse a seção de **Usuários** na interface web

- Clique em **Novo Usuário** ou atribua permissão ADMIN a um usuário existente

- Associe o usuário à instituição criada

- Defina a permissão como **ADMIN**

  

**Importante:** O script `setup_initial_aliases_and_rules.py` precisa ser executado **após** criar a instituição, pois ele cria os aliases e regras para cada instituição cadastrada.

  
  

## 📝 Checklist de Instalação

  

Use este checklist para garantir que tudo foi configurado:

  

- [ ] Banco de dados criado e vazio

- [ ] Variáveis de ambiente configuradas (.env)

- [ ] Dependências Python instaladas

- [ ] Banco de dados configurado (`python -m db.setup_database`)

- [ ] pfSense API configurada e testada

- [ ] Servidor backend iniciado

- [ ] Login realizado como SUPERUSER

- [ ] Instituição criada via interface web

- [ ] Usuário ADMIN criado/atribuído via interface web

- [ ] Script de setup inicial executado (`python scripts/setup_initial_aliases_and_rules.py`)

- [ ] Aliases verificados no banco

- [ ] Aliases verificados no pfSense

- [ ] Regras verificadas no banco

- [ ] Regras verificadas no pfSense

  

## 🐛 Troubleshooting

  

### Erro: "Configurações do pfSense não encontradas"

  

**Solução:**

1. Verificar se a instituição foi criada no banco

2. Verificar se `pfsense_base_url` e `pfsense_key` estão corretos

3. Verificar se o usuário tem `institution_id` associado

  

### Erro: "Timeout ao conectar no pfSense"

  

**Solução:**

1. Verificar conectividade de rede

2. Verificar URL do pfSense (deve terminar com `/api/v2/`)

3. Verificar se API está habilitada no pfSense


 

### Erro: "Usuário ADMIN não encontrado"

  

**Solução:**

1. Criar usuário ADMIN via interface web:

- Acesse a seção de Usuários

- Atribua permissão ADMIN ao usuário

  

2. Ou criar manualmente via SQL:

```sql

UPDATE users SET permission = 'ADMIN', institution_id = 1  WHERE id = X;

```

  

## 📚 Resumo da Instalação

  

O processo de instalação foi simplificado para apenas **2 comandos principais**:

  

1.  **Criar tabelas:**  `python -m db.setup_database`

2. **Instalar pfsense:** mais detalhes em [pfsense install]()

3.  **Criar aliases e regras:**  `python scripts/setup_initial_aliases_and_rules.py`

  

**Após executar os comandos:**

- Criar instituição via interface web (como SUPERUSER)

- Criar/atribuir usuário ADMIN via interface web


 
