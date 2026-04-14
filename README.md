
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

./configurar_rede.sh

```

### 2.1. Instalar o Virtualbox
Para instalar o virtualbox acesse https://www.virtualbox.org/wiki/Downloads e escolha o seu OS.

### 2.2. Instale a imagem do pfsense
Este arquivo detalha os passos de instalação do pfsense e alternativamente uma imagem pronta para o virtualbox [Instalacao_PFSense.pdf](https://github.com/user-attachments/files/26728713/Instalacao_PFSense.pdf)

### 2.3. Trocar no Virtualbox para que a interface 2 do pfSense seja a tap0 no modo bridge
<img width="766" height="118" alt="image" src="https://github.com/user-attachments/assets/7bed4431-7336-4f71-9c0c-b453cc7178b2" />

 

 <img width="950" height="375" alt="pfsense_bridge2" src="https://github.com/user-attachments/assets/2488ce95-7a8d-4d64-a0d5-8d959970561a" />

### 2.4. Garanta que a interface 1 esteja na sua interface da placa de rede
 <img width="1013" height="368" alt="image" src="https://github.com/user-attachments/assets/d1d17a16-1c21-41fd-bca9-5fbacc65218c" />


### 2.5. Na máquina do pfsense selecione a segunda opção, então 1 e responda sim para todas as perguntas
<img width="512" height="444" alt="image" src="https://github.com/user-attachments/assets/87b06d0f-efbd-41fb-8936-90b3e480c7cb" />
Como resultado a wan tera um endereço ip que pode ser acessado no seu navegador, uma vez lá navegue até a interface LAN

<img width="1017" height="626" alt="image" src="https://github.com/user-attachments/assets/9fb26554-1baf-47be-9d56-60eb0d2e1420" />

### 2.6. Atribua um ip estatico ipv4 para a LAN

<img width="1017" height="211" alt="image" src="https://github.com/user-attachments/assets/ce3f9d21-787a-4581-9c8e-1fb93439b43c" />

<img width="935" height="228" alt="image" src="https://github.com/user-attachments/assets/67877420-ddff-4504-9829-3eeedc7b9e3e" />
O ip escolhido é um exemplo 

### 2.7. Ative o servidor dhcp da LAN
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
 
 ## 📊 Passo 4: Configurar atacante e alvo
 ### 4.1 Acesse o localhost 3000
 <img width="1021" height="690" alt="image" src="https://github.com/user-attachments/assets/c2870ebc-1e5d-440c-9d13-044abba012c1" />

### 4.2 Faça o login via conta google com o super usuário registrado no env
<img width="1021" height="738" alt="image" src="https://github.com/user-attachments/assets/8574ccfc-81e0-4e09-82ca-a10a2a972fb8" />

### 4.3 Va até a aba de administrador e cadastre sua rede: 
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/fcbab1bd-a8af-4cd1-8ce7-0a9fb9edd90b" />
os campos do zeek e suricata são os mesmo com o url sendo: http://host.docker.internal:8001 e chave: a8f4c2d9-1c9b-4b6f-9d6e-aaa111bbb222
 
### 4.4 Faça login com uma conta diferente e selecione a instituição que você cadastrou 
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/c1e40bf4-d0fd-4e72-972e-04adbfb74dcb" />

### 4.5 Volte para o user usuário e torne este usuário um administrador
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/317800e7-b3c9-4681-a288-5d18bf3bb75d" />

### 4.6 Como adiministrador sincronize as regras e mapamento
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/ac7691a8-8a59-45ac-b09b-e5388e4dc75b" />
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/2d252067-64cd-421f-a7f4-56c7d3e42102" />

### 4.7 utilize uma conta comun para cadastrar os seguintes macs estaticos
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/e7ec4695-d54b-4508-b2e2-2674ef3ee3b1" />
92:d0:c6:0a:29:32 e 92:d0:c6:0a:29:33 escolha o nome e descrição que preferir

### 4.8 Instancie os ataque e alvo utilizando o script
 ```bash
deploy_atacante-alvo.sh
```

### 4.9 Monitore a aba de dispositivos bloqueados e incidentes de segurança
