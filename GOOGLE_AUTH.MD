### 1.1. Obter Credenciais do Google OAuth

Para que o login via Google funcione, é necessário criar um projeto no Google Cloud e gerar um **Client ID** e um **Client Secret**. Siga os passos abaixo:

#### 1.1.1. Acesse o Google Cloud Console
Acesse [console.cloud.google.com](https://console.cloud.google.com) e faça login com sua conta Google.

#### 1.1.2. Crie um novo projeto
- Clique no seletor de projetos no topo da página.
- Clique em **"Novo Projeto"**, dê um nome (ex: `IoT-EDU`) e clique em **"Criar"**.
- Aguarde e certifique-se de que o novo projeto está selecionado.

<img width="1920" height="1080" alt="1" src="https://github.com/user-attachments/assets/1751adec-6af0-4047-b3de-9519b1fe28b1" />

<img width="1920" height="1080" alt="2" src="https://github.com/user-attachments/assets/8a395a87-9174-4d5b-ae1c-8c3e7c2bb748" />

<img width="1920" height="1080" alt="3" src="https://github.com/user-attachments/assets/b3342c16-fa0a-4110-a00a-0c333b861590" />


#### 1.1.3. Configure a Tela de Consentimento OAuth
- No menu lateral, vá em **"APIs e Serviços" → "Tela de consentimento OAuth"**.
- Selecione o tipo **"Externo"** e clique em **"Criar"**.
- Preencha os campos obrigatórios:
  - **Nome do app:** IoT-EDU (ou qualquer nome)
  - **E-mail de suporte:** seu e-mail
  - **E-mail do desenvolvedor:** seu e-mail
- Clique em **"Salvar e continuar"** até finalizar (as demais etapas podem ficar vazias para ambiente de teste).

<img width="1920" height="1080" alt="4" src="https://github.com/user-attachments/assets/8c20fbd8-2c0f-4dac-a79c-e123a6355a91" />

<img width="1920" height="1080" alt="5" src="https://github.com/user-attachments/assets/0e4124fb-b4cb-4b83-8ee7-f21581be7091" />

<img width="1920" height="1080" alt="6" src="https://github.com/user-attachments/assets/98e20f62-a34a-492d-a0d8-2293471abb87" />

#### 1.1.4. Crie as Credenciais OAuth
- Vá em **"APIs e Serviços" → "Credenciais"**.
- Clique em **"+ Criar Credenciais" → "ID do cliente OAuth"**.
- Em **"Tipo de aplicativo"**, selecione **"Aplicativo da Web"**.
- Dê um nome (ex: `IoT-EDU Web`).
- Em **"Origens JavaScript autorizadas"**, adicione:
  ```
  http://localhost:3000
  ```
- Em **"URIs de redirecionamento autorizados"**, adicione:
  ```
  http://localhost:8000/api/auth/google/callback
  ```
- Clique em **"Criar"**.

<img width="1920" height="1080" alt="7" src="https://github.com/user-attachments/assets/64494464-85aa-4c3a-9b0e-683abfab3c9d" />

<img width="1920" height="1080" alt="8" src="https://github.com/user-attachments/assets/828e950a-6d2a-4df1-8152-4924fa799249" />

#### 1.1.5. Copie as credenciais
Uma janela exibirá seu **Client ID** e **Client Secret**. Guarde esses valores — eles serão usados no passo seguinte.

<img width="1920" height="1080" alt="9" src="https://github.com/user-attachments/assets/60f226fd-5f03-45a7-afda-f4a607a6545b" />

> ⚠️ **Atenção:** Nunca versione o `Client Secret` nem o compartilhe publicamente.
