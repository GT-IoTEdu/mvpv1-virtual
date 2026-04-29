### 1.1 Acesse o Frontend (http://localhost:3000)
<img width="1021" height="690" alt="image" src="https://github.com/user-attachments/assets/c2870ebc-1e5d-440c-9d13-044abba012c1" />

### 1.2 Faça login com o superusuário (Google OAuth)
<img width="1021" height="738" alt="image" src="https://github.com/user-attachments/assets/8574ccfc-81e0-4e09-82ca-a10a2a972fb8" />

Ainda como superusuário vá até a aba **Instituições**:
<img width="943" height="652" alt="image" src="https://github.com/user-attachments/assets/ffe2ada5-a4cc-4728-bcc2-58a6aef0476f" />

Atualize o IP do **pfSense** para o endereço da sua Web UI:
<img width="943" height="652" alt="image" src="https://github.com/user-attachments/assets/5ced41ed-f8da-4df9-a615-738b567882ce" />

Para utilizar outras IDS, copie os campos do url e da chave do Zeek e os cole nos campos do Suricata e o Snort:
<img width="936" height="439" alt="image" src="https://github.com/user-attachments/assets/c936f418-dba4-4669-ad1c-e2602857dfa8" />

<img width="935" height="422" alt="image" src="https://github.com/user-attachments/assets/a0d01203-ee91-4091-9427-4e089a5fedc4" />

> **Dica:** os campos do Zeek e do Suricata são os mesmos. Exemplo:

```bash
# URL do servidor SSE (exemplo)
http://host.docker.internal:8001

# Chave SSE (exemplo)
a8f4c2d9-1c9b-4b6f-9d6e-aaa111bbb222
```

### 1.4 Faça login com uma conta diferente e selecione a instituição de exemplo
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/c1e40bf4-d0fd-4e72-972e-04adbfb74dcb" />

### 1.5 Volte para o superusuário e torne este usuário um administrador
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/317800e7-b3c9-4681-a288-5d18bf3bb75d" />

### 1.6 Faça login como administrador, sincronize as regras e o mapeamento
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/ac7691a8-8a59-45ac-b09b-e5388e4dc75b" />
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/2d252067-64cd-421f-a7f4-56c7d3e42102" />

### 1.7 Use uma conta comum para cadastrar um dispositivo (MAC estático)
<img width="1021" height="691" alt="image" src="https://github.com/user-attachments/assets/e7ec4695-d54b-4508-b2e2-2674ef3ee3b1" />

```bash
# Exemplo de MAC estático
92:d0:c6:0a:29:33

# Exemplo de nome
test

#Exemplo de descrição
Máquina test
```

### 1.8 Faça o deploy do container de teste 

```bash
  chmod +x setup/deploy_test_min.sh 

 ./setup/deploy_test_min.sh 

```

### 1.9 (Admin) Libere/desbloqueie o dispositivo cadastrado
Se o dispositivo aparecer como bloqueado, inclua o filtro **Dispositivos bloqueados** e clique em **Desbloquear/Liberar** para o MAC cadastrado.
<img width="1243" height="670" alt="image" src="https://github.com/user-attachments/assets/550a5ebd-d50c-4fad-bb26-4030c774b5eb" />

## 2.0 Bloquear dispositivos manualmente
Se o dispositivo aparecer como bloqueado, inclua o filtro **Dispositivos bloqueados** e clique em **Desbloquear/Liberar** para o MAC cadastrado.
<img width="1243" height="670" alt="image" src="https://github.com/user-attachments/assets/550a5ebd-d50c-4fad-bb26-4030c774b5eb" />
