
# Sistema de Registro IoT com pfSense

## Objetivo
Este repositório tem como objetivo armazenar todo o código produzido, exemplificar o funcionamento prático do sistema de orquestração multi-IDS para ambientes IoT, e documentar os procedimentos de instalação, execução e reivindicações do artigo.

## Resumo do Artigo
Ambientes IoT ampliam a superfície de ataque e dificultam a resposta a incidentes. O IoT-Edu orquestra múltiplos IDSs (Suricata, Snort, Zeek) em um pipeline unificado com correlação de eventos e bloqueio automatizado. Em cinco tipos de ataque (75 execuções), o sistema alcança contenção média de 5,56 s, com a latência dominada pela fase de detecção. Os resultados expõem um compromisso entre a velocidade dos métodos baseados em assinaturas e o contexto dos baseados em comportamento, demonstrando que a orquestração multi-IDS melhora a resposta automatizada em ambientes IoT dinâmicos.

---

# Estrutura do README.md

Este README.md está organizado nas seguintes seções:

1. **Título, Objetivo e Resumo:** Título do projeto, objetivo do artefato e resumo do artigo.
2. **Estrutura do README.md:** A presente estrutura.
3. **Selos considerados:** Lista dos Selos a serem considerados no processo de avaliação.
4. **Informações básicas:** Descrição dos componentes e requisitos mínimos para a execução do experimento.
5. **Dependências:** Informação sobre as dependências necessárias.
6. **Preocupações com segurança:** Lista das considerações e preocupações com a segurança.
7. **Instalação:** Instruções para instalação e configuração do sistema.
8. **Teste mínimo:** Instruções para a execução de um teste mínimo.
9. **Experimentos:** Informações de replicação das reivindicações.
10. **Licença:** Informações sobre a licença do projeto.



 ---

## Selos Considerados

Os selos considerados são:
- Artefatos Disponíveis (SeloD)
- Artefatos Funcionais (SeloF)

---

---
# Dependencias
 ### Requisitos de Software

| Componente | Versão Mínima |
|---|---|
| Python | 3.9+ (testado com 3.12) |
|Docker | 29.2.1|
| pfSense | 2.8.1 (veja [Passo 2](#3-configuração-do-pfsense)) |
| Node.js | 18+ |
| npm / pnpm | qualquer versão recente |

### Requisitos de Hardware (referência dos autores)

| Componente | Especificação |
|---|---|
| CPU | AMD Ryzen 5 5500X |
| Memória RAM | 32 GB DDR4 |
| SO | Ubuntu / Kubuntu 24.04 LTS (bare-metal) |

## Preocupações com Segurança


- Não exponha o pfSense diretamente à internet durante os testes. Utilize uma rede isolada ou laboratório virtual.
- O arquivo `backend/.env` contém credenciais sensíveis (banco de dados, OAuth, chave de API do pfSense). Nunca versione esse arquivo.
- A chave de API do pfSense gerada durante o setup deve ser tratada como senha. Regenere-a após a avaliação.
- Os scripts de setup criam um usuário SUPERUSER cujas credenciais são definidas nas variáveis de ambiente — altere-as antes de qualquer uso em produção.

---

---


# Instalação  


### Dependências do Sistema Operacional

Antes de instalar os pacotes Python, instale as bibliotecas de sistema necessárias. No Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y \
    python3 python3-pip python3-venv python3-dev \
    libxml2-dev libxmlsec1-dev libxmlsec1-openssl \
    default-libmysqlclient-dev build-essential pkg-config
```
## 🔧 Passo 1: Preparar Ambiente

```bash
git clone https://github.com/GT-IoTEdu/wticifes2026-iotedu.git
cd API_SBRC26_SF
```
  

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

./configurar_rede.sh

```

### 2.1. Instalar o Virtualbox
Para instalar o virtualbox acesse https://www.virtualbox.org/wiki/Downloads e escolha o seu OS.

### 2.2. Instale a imagem do pfsense
Este arquivo detalha os passos de instalação do pfsense e alternativamente uma imagem pronta para o virtualbox [Instalacao_PFSense.pdf](https://github.com/user-attachments/files/26728713/Instalacao_PFSense.pdf) 
[imagem pronta](https://drive.google.com/file/d/1Q9IO_MZtKf6JvTIgJVl-p2nDt5d_ohEj/view?usp=sharing)  
Caso selecione a imagem pronta siga apenas o passo 2.4 e 2.6.

### 2.3. Trocar no Virtualbox para que a interface 2 do pfSense seja a tap0 no modo bridge
<img width="766" height="118" alt="image" src="https://github.com/user-attachments/assets/7bed4431-7336-4f71-9c0c-b453cc7178b2" />

 

 <img width="950" height="375" alt="pfsense_bridge2" src="https://github.com/user-attachments/assets/2488ce95-7a8d-4d64-a0d5-8d959970561a" />

### 2.4. Garanta que a interface 1 esteja na sua interface da placa de rede
 <img width="1013" height="368" alt="image" src="https://github.com/user-attachments/assets/d1d17a16-1c21-41fd-bca9-5fbacc65218c" />


### 2.5. Na máquina do pfsense selecione a segunda opção, então 1 e responda sim para todas as perguntas
<img width="512" height="444" alt="image" src="https://github.com/user-attachments/assets/87b06d0f-efbd-41fb-8936-90b3e480c7cb" />

### 2.6 Como resultado a wan tera um endereço ip que pode ser acessado no seu navegador, uma vez lá navegue até a interface LAN

<img width="1017" height="626" alt="image" src="https://github.com/user-attachments/assets/9fb26554-1baf-47be-9d56-60eb0d2e1420" />
Gerar a chave de API

1. Vá em **System → REST API → Keys**.
2. Clique em **Add** e selecione o tipo **SHA256** com tamanho **32** (utilize 16 ou 32 — 36 não é um tamanho válido).
3. Copie a chave gerada e insira no campo `PFSENSE_API_KEY` do arquivo `backend/.env`.


### 2.7. Atribua um ip estatico ipv4 para a LAN


<img width="1017" height="211" alt="image" src="https://github.com/user-attachments/assets/ce3f9d21-787a-4581-9c8e-1fb93439b43c" />

<img width="935" height="228" alt="image" src="https://github.com/user-attachments/assets/67877420-ddff-4504-9829-3eeedc7b9e3e" />
O ip escolhido é um exemplo 

### 2.8. Ative o servidor dhcp da LAN
<img width="999" height="640" alt="image" src="https://github.com/user-attachments/assets/b4e9dd3f-3bc2-4c0e-8c52-32bbd0e03396" />

<img width="999" height="640" alt="image" src="https://github.com/user-attachments/assets/44494820-1bb8-45b9-8cda-3fcafca70c95" />

<img width="940" height="276" alt="image" src="https://github.com/user-attachments/assets/2c128d34-e6e2-4162-ab50-f21ea5e7af85" />

 ## 📊 Passo 3: Instanciar a rede docker

 ### 3.1 faça o deploy da rede
 ```bash
./deploy.sh
```
### 3.2 abra outro terminal e execute 
 ```bash
cd ids-log-monitor/
uvicorn sse_server:app --host 0.0.0.0 --port 8001 --reload

```
 
 ## Teste Mínimo
 ### 1.1 Acesse o localhost 3000
 <img width="1021" height="690" alt="image" src="https://github.com/user-attachments/assets/c2870ebc-1e5d-440c-9d13-044abba012c1" />

### 1.2 Faça o login via conta google com o super usuário registrado no env
<img width="1021" height="738" alt="image" src="https://github.com/user-attachments/assets/8574ccfc-81e0-4e09-82ca-a10a2a972fb8" />

### 1.3 Va até a aba de administrador e cadastre sua rede: 
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/fcbab1bd-a8af-4cd1-8ce7-0a9fb9edd90b" />
os campos do zeek e suricata são os mesmo com o url sendo: http://host.docker.internal:8001 e chave: a8f4c2d9-1c9b-4b6f-9d6e-aaa111bbb222
 
### 1.4 Faça login com uma conta diferente e selecione a instituição que você cadastrou 
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/c1e40bf4-d0fd-4e72-972e-04adbfb74dcb" />

### 1.5 Volte para o user usuário e torne este usuário um administrador
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/317800e7-b3c9-4681-a288-5d18bf3bb75d" />

### 1.6 Como adiministrador sincronize as regras e mapamento
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/ac7691a8-8a59-45ac-b09b-e5388e4dc75b" />
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/2d252067-64cd-421f-a7f4-56c7d3e42102" />

### 1.7 utilize uma conta comun para cadastrar o seguintes macs estatico
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/e7ec4695-d54b-4508-b2e2-2674ef3ee3b1" />
92:d0:c6:0a:29:33 escolha o nome e descrição que preferir

### 1.8 Instancie os ataque e alvo utilizando o script
 ```bash
deploy_atacante-alvo.sh
```

### 1.9 Monitore a aba de dispositivos bloqueados e incidentes de segurança

### 1.9.9 Quando o dispositivo estiver bloqueado, para verificar as conexões 
 Para conexões externas da rede
 ```bash
docker exec -it atacante ping 8.8.8.8
```
tente desbloquear o dispositivo enquanto o comando está rodando
<img width="539" height="198" alt="image" src="https://github.com/user-attachments/assets/75f31b2c-d866-4e5d-b33a-5c6c629327a8" />


## Licença

Copyright (c) 2025 RNP – National Research and Education Network (Brazil)

This code was developed is licensed under the terms of the BSD License. It may be freely used, modified, and distributed, including for commercial purposes, provided that this copyright notice is retained. This software is provided "as is", without any warranty, express or implied, including, but not limited to, warranties of merchantability or fitness for a particular purpose. RNP and the authors shall not be held liable for any damages or losses arising from the use of this software.
