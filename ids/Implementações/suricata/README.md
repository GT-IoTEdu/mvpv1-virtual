# suricata - Sistema de Detecção de Intrusão

Sistema de detecção de intrusão baseado em Suricata para monitoramento de ataques de rede.

## 📁 Arquivos

```
suricata/
├── Dockerfile            # Imagem Docker com Suricata
├── start_suricata.sh     # Script de inicialização
├── README.md
├── etc/
│   ├── suricata.yaml           # Configuração principal
│   ├── classification.config   # Classificações de alertas
│   ├── reference.config        # Referências
│   └── threshold.config        # Thresholds
└── rules/
    ├── local.rules             # Regras gerais/customizadas
    ├── brute-force-ssh.rules   # Regras de brute force SSH
    ├── dns-tunneling.rules     # Regras de DNS tunneling
    ├── dos-http.rules          # Regras de HTTP DoS
    ├── ping-flood.rules        # Regras de ping flood
    ├── sql-injection.rules     # Regras de SQL injection
    └── classification.config   # Classificações das regras
```

## 🚀 Uso Rápido

### Modo Desenvolvimento (Recomendado para testes)

Use este modo para editar regras no repositório e aplicar mudanças rapidamente:

```bash
# Construir imagem (apenas uma vez)
docker build -t suricata .

# Executar com volume mount (regras e logs sincronizados)
docker run -d --name suricata_ids --privileged --network host \
  -v $(pwd)/rules:/var/lib/suricata/rules \
  -v $(pwd)/logs:/var/log/suricata \
  suricata enp0s3
```

Agora você pode:

1. **Editar regras** nos arquivos específicos da `rules/` directory
2. **Testar sintaxe** antes de aplicar:
   ```bash
   docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml
   ```
3. **Reiniciar** para aplicar mudanças:
   ```bash
   docker restart suricata_ids
   ```
4. **Ver logs** diretamente no host:
   ```bash
   tail -f logs/fast.log
   ```

### Modo Produção (Regras fixas na imagem)

```bash
# Rebuildar imagem com novas regras
docker build -t suricata .

# Executar
docker run -d --name suricata_ids --privileged --network host suricata enp0s3
```

## 🔍 Ataques Detectados

| Tipo                | Descrição              | Threshold           | Arquivo              |
| ------------------- | ---------------------- | ------------------- | -------------------- |
| **HTTP DoS**        | GET/POST flood         | 20/10 req em 5s     | dos-http.rules       |
| **SSH Brute Force** | Múltiplas tentativas   | 10 tent em 60s      | brute-force-ssh.rules |
| **Port Scan**       | Varredura de portas    | 25 portas em 5min   | (custom)             |
| **SQL Injection**   | UNION, OR 1=1, quotes  | Qualquer ocorrência | sql-injection.rules  |
| **Malware C2**      | Comunicação com C&C    | Qualquer ocorrência | (custom)             |
| **DNS Tunneling**   | Alto volume DNS        | 50 queries em 10s   | dns-tunneling.rules  |
| **ICMP Flood**      | Ping flood             | 50 pings em 5s      | ping-flood.rules     |

## 📝 Editando Regras

### Workflow de Desenvolvimento

O novo workflow organiza as regras por tipo de ataque:

```bash
# 1. Identificar o tipo de ataque (ex: brute-force-ssh)
# 2. Editar o arquivo correspondente ou criar um novo
nano rules/brute-force-ssh.rules

# 3. Testar sintaxe (IMPORTANTE!)
docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml

# 4. Se OK, reiniciar para aplicar
docker restart suricata_ids

# 5. Verificar se a regra foi carregada
docker exec suricata_ids grep "1000040" /var/lib/suricata/rules/brute-force-ssh.rules

# 6. Monitorar alertas em tempo real
tail -f logs/fast.log

# 7. Gerar tráfego para testar a regra
# (exemplo específico do ataque)

# 8. Verificar se a regra foi acionada nos alertas
grep "1000040" logs/fast.log
```

### Adicionando um Novo Tipo de Ataque

Se você precisa criar regras para um novo tipo de ataque:

```bash
# 1. Criar arquivo de regras específico
touch rules/novo-ataque.rules

# 2. Adicionar as regras no arquivo
nano rules/novo-ataque.rules
# Exemplo:
# alert tcp any any -> any 443 (msg:"NOVO ATAQUE -> Detecção"; sid:1000100; rev:1;)

# 3. Incluir o arquivo em etc/suricata.yaml
# Editar a seção "rule-files:" e adicionar:
# - novo-ataque.rules

# 4. Testar sintaxe
docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml

# 5. Reiniciar
docker restart suricata_ids
```

### Estrutura de uma Regra Suricata

```suricata
alert tcp any any -> any 80 (
    msg:"Descrição do alerta";           # Mensagem no log
    content:"texto-a-buscar";            # Conteúdo a detectar
    http_uri;                            # Buscar na URI HTTP
    threshold: type threshold,           # Filtro de threshold
               track by_src,             # Rastrear por origem
               count 10,                 # 10 ocorrências
               seconds 60;               # em 60 segundos
    classtype:web-application-attack;    # Classificação
    sid:1000041;                         # ID único (1000000+ para regras locais)
    rev:1;                               # Revisão da regra
)
```

### Exemplos de Regras Personalizadas

```bash
# Adicionar no arquivo de regras específico (ex: rules/custom-attack.rules):

# Detectar acesso a endpoint específico
alert http any any -> any any (msg:"ACESSO - Admin Panel"; http.uri; content:"/admin"; sid:1000041; rev:1;)

# Detectar User-Agent suspeito
alert http any any -> any any (msg:"SUSPEITO - Bot Detected"; http.user_agent; content:"bot"; nocase; sid:1000042; rev:1;)

# Detectar múltiplas requisições POST
alert http any any -> any any (msg:"ATAQUE - HTTP POST Flood"; http.method; content:"POST"; threshold:type threshold, track by_src, count 15, seconds 5; sid:1000043; rev:1;)
```

## 📊 Logs

Os alertas são salvos em:
- **Container**: `/var/log/suricata/`
- **Host** (com volume mount): `./logs/`

### Tipos de Logs

- **fast.log**: Alertas rápidos (formato resumido)
- **eve.json**: Alertas em JSON (formato estruturado)
- **stats.log**: Estatísticas do Suricata
- **suricata.log**: Logs de sistema

### Visualizando logs em tempo real

```bash
# Logs no host (com volume mount) - RECOMENDADO
tail -f logs/fast.log

# Logs em JSON (estruturado)
tail -f logs/eve.json | jq .

# Ou dentro do container
docker exec -it suricata_ids tail -f /var/log/suricata/fast.log

# Ver últimos 50 alertas
tail -50 logs/fast.log

# Buscar alertas específicos
grep "SQL Injection" logs/fast.log

# Filtrar por SID
grep "sid:1000029" logs/fast.log

# Contar alertas por tipo (via JSON)
grep '"alert":' logs/eve.json | jq -r '.alert.signature' | sort | uniq -c | sort -rn
```

### Copiando logs (se não usou volume mount)

```bash
# Copiar todos os logs
docker cp suricata_ids:/var/log/suricata/. ./suricata-logs/

# Copiar apenas fast.log
docker cp suricata_ids:/var/log/suricata/fast.log ./fast.log

# Copiar logs JSON
docker cp suricata_ids:/var/log/suricata/eve.json ./eve.json
```

## ⚙️ Parâmetros

```bash
# Interface específica
docker run -d --name suricata_ids --privileged --network host \
  -v $(pwd)/rules:/var/lib/suricata/rules \
  -v $(pwd)/logs:/var/log/suricata \
  suricata wlan0

# Com HOME_NET customizado
docker run -d --name suricata_ids --privileged --network host \
  -e SURICATA_HOME_NET="[192.168.0.0/16,10.0.0.0/8]" \
  -v $(pwd)/rules:/var/lib/suricata/rules \
  -v $(pwd)/logs:/var/log/suricata \
  suricata enp0s3

# Com argumentos extras do Suricata
docker run -d --name suricata_ids --privileged --network host \
  -e SURICATA_ARGS="--af-packet" \
  -v $(pwd)/rules:/var/lib/suricata/rules \
  -v $(pwd)/logs:/var/log/suricata \
  suricata enp0s3
```

## 🔧 Gerenciamento do Container

```bash
# Ver status
docker ps -a | grep suricata_ids

# Ver logs do Suricata em tempo real
docker logs -f suricata_ids

# Entrar no container (debug)
docker exec -it suricata_ids bash

# Reiniciar após mudanças nas regras
docker restart suricata_ids

# Ver estatísticas de recursos
docker stats suricata_ids

# Parar
docker stop suricata_ids

# Iniciar novamente
docker start suricata_ids

# Remover
docker rm -f suricata_ids
```

## 🧪 Testando Regras

### Workflow de Teste Completo

```bash
# 1. Criar diretório de logs
mkdir -p logs

# 2. Iniciar Suricata com volumes
docker run -d --name suricata_ids --privileged --network host \
  -v $(pwd)/rules:/var/lib/suricata/rules/ \
  -v $(pwd)/logs:/var/log/suricata \
  suricata enp0s3

# 3. Adicionar regra de teste no arquivo específico (ex: rules/ping-flood.rules)
echo 'alert icmp any any -> any any (msg:"TESTE - Ping Detectado"; itype:8; sid:1000099; rev:1;)' >> rules/ping-flood.rules

# 4. Testar sintaxe
docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml

# 5. Reiniciar para carregar a nova regra
docker restart suricata_ids

# 6. Verificar se a regra está no container (confirmar volume mount)
docker exec suricata_ids grep "1000099" /var/lib/suricata/rules/ping-flood.rules

# 7. Monitorar logs em tempo real (DEIXAR RODANDO)
tail -f logs/fast.log

# 8. Em outro terminal, gerar tráfego de teste
ping -c 5 8.8.8.8

# 9. Verificar detecção (no primeiro terminal ou depois de parar o tail)
grep "TESTE - Ping Detectado" logs/fast.log
```

### Validando Sintaxe de Regras

```bash
# Testar configuração completa
docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml

# Ver estatísticas de regras carregadas
docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml -v | grep "rule\|loaded"

# Verificar se arquivo de regras está sendo lido
docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml -v | grep "local.rules"
```

### Diferença: Regra Carregada vs Regra Acionada

⚠️ **IMPORTANTE**: Entenda a diferença:

1. **Regra Carregada** = Regra está no Suricata e pronta para detectar
   ```bash
   # Verificar se a regra foi carregada (conferir arquivo no container)
   docker exec suricata_ids grep "sid:1000040" /var/lib/suricata/rules/seu-ataque.rules
   
   # Ou verificar logs de inicialização
   docker logs suricata_ids | grep "rule\|loaded"
   ```

2. **Regra Acionada** = Regra detectou tráfego e gerou alerta
   ```bash
   # Verificar alertas gerados (só aparece se a regra detectou algo)
   grep "sid:1000040" logs/fast.log
   
   # Ou via JSON
   grep '"sid":1000040' logs/eve.json
   ```

**Exemplo prático:**
```bash
# Adicionar regra para detectar acesso à porta 8080
echo 'alert tcp any any -> any 8080 (msg:"TESTE - Acesso porta 8080"; sid:1000040; rev:1;)' >> rules/custom-attack.rules

# Adicionar no suricata.yaml se for novo arquivo
# Editar etc/suricata.yaml e adicionar em rule-files:
# - custom-attack.rules

# Verificar se foi escrita no arquivo
grep "1000040" rules/custom-attack.rules

# Reiniciar
docker restart suricata_ids

# Verificar que o volume mount está funcionando
docker exec suricata_ids grep "1000040" /var/lib/suricata/rules/custom-attack.rules

# Agora a regra está CARREGADA mas não ACIONADA ainda

# Para ACIONAR a regra, gerar tráfego para porta 8080:
curl http://localhost:8080
# ou de outra máquina: curl http://IP_DA_MAQUINA:8080

# Agora sim, verificar o alerta nos logs:
grep "1000040" logs/fast.log
```

## 🐛 Solução de Problemas

### Regras não aplicam

```bash
# 1. Verificar se o arquivo está listado em etc/suricata.yaml
grep "seu-ataque.rules" etc/suricata.yaml

# 2. Verificar sintaxe das regras
docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml

# 3. Ver logs de erro
docker logs suricata_ids

# 4. Verificar se o volume foi montado corretamente
docker exec suricata_ids cat /var/lib/suricata/rules/seu-ataque.rules

# 5. Reiniciar forçando reload
docker restart suricata_ids
```

### Erro de sintaxe nas regras

```bash
# Ver último erro
docker logs --tail 50 suricata_ids

# Erros comuns:
# - SID duplicado: cada regra precisa de um SID único
# - Falta ponto-e-vírgula: todas as opções devem ter ';'
# - Parênteses não fechados: verificar '(' e ')'
# - Palavra-chave inválida: verificar spelling (http_uri vs http.uri)
# - Arquivo não listado em suricata.yaml: certifique-se que está em rule-files:
```

### Logs não aparecem

```bash
# Verificar se o Suricata está rodando
docker exec suricata_ids ps aux | grep suricata

# Verificar permissões do diretório de logs
ls -la logs/

# Gerar tráfego de teste
ping -c 10 8.8.8.8

# Ver logs em tempo real
docker logs -f suricata_ids
```

### Container não inicia

```bash
# Ver erro completo
docker logs suricata_ids

# Testar sem daemon
docker run --rm --privileged --network host \
  -v $(pwd)/rules:/var/lib/suricata/rules \
  suricata enp0s3

# Verificar interface
ip link show enp0s3
```

### Alto uso de CPU/Memória

```bash
# Monitorar recursos
docker stats suricata_ids

# Limitar recursos do container
docker update --cpus="2" --memory="2g" suricata_ids

# Ajustar workers no suricata.yaml
# Editar etc/suricata.yaml e modificar 'runmode: workers'
```

## 📚 Documentação Adicional

- [Suricata User Guide](https://suricata.readthedocs.io/)
- [Suricata Rules](https://suricata.readthedocs.io/en/latest/rules/)
- [Writing Suricata Rules](https://suricata.readthedocs.io/en/latest/rules/intro.html)
- [Rule Keywords](https://suricata.readthedocs.io/en/latest/rules/index.html)
- [Eve JSON Format](https://suricata.readthedocs.io/en/latest/output/eve/eve-json-format.html)

## 💡 Dicas de Desenvolvimento

### SIDs Recomendados

- **1000000-1000999**: Regras de teste
- **1001000-1009999**: Regras de produção customizadas
- **1010000+**: Regras experimentais

### Organização de Arquivos de Regras

- **local.rules**: Regras gerais ou customizadas que não se encaixam em nenhuma categoria
- **[tipo-ataque].rules**: Um arquivo para cada tipo/categoria de ataque
- **etc/suricata.yaml**: Listado na seção `rule-files:` com entrada `- [tipo-ataque].rules`

### Boas Práticas

1. **Sempre teste a sintaxe** antes de reiniciar:
   ```bash
   docker exec suricata_ids suricata -T -c /etc/suricata/suricata.yaml
   ```

2. **Use SIDs únicos** para cada regra

3. **Documente suas regras** com comentários descritivos

4. **Backup antes de alterações críticas**:
   ```bash
   cp rules/*.rules rules/backup/
   cp etc/suricata.yaml etc/suricata.yaml.backup
   ```

5. **Monitore falsos positivos** e ajuste thresholds

6. **Use eve.json para análise avançada**:
   ```bash
   cat logs/eve.json | jq '.alert | select(.severity==1)'
   ```

7. **Organize por tipo de ataque**: crie um arquivo para cada categoria

### Diferenças Suricata vs Snort

| Aspecto | Suricata | Snort |
|---------|----------|-------|
| **Sintaxe de Regras** | Moderna (http.uri) | Clássica (http_uri) |
| **Multi-threading** | ✅ Nativo | ⚠️ Limitado |
| **JSON Output** | ✅ Eve.json | ⚠️ Via plugin |
| **Performance** | 🚀 Mais rápido | 🐢 Mais lento |
| **Logs** | fast.log, eve.json | alert_full.txt |
| **Organização** | Arquivo YAML para includes | all.rules para includes |

### Comparação de Modos

| Aspecto | Volume Mount | Rebuild |
|---------|--------------|---------|
| **Velocidade** | ⚡ Rápido (restart) | 🐌 Lento |
| **Uso** | 🧪 Desenvolvimento | 🏭 Produção |
| **Sincronização** | ✅ Tempo real | ❌ Manual |
| **Persistência** | ⚠️ Depende do host | ✅ Na imagem |
| **Rollback** | ✅ Fácil (git) | ⚠️ Rebuild |

## ⚠️ Notas Importantes

- **Desenvolvimento**: Use sempre com volume mount para agilidade
- **Produção**: Rebuilde a imagem para embutir regras testadas
- **Performance**: Suricata é multi-threaded, aproveite múltiplos cores
- **Backup**: Faça backup regular dos arquivos de regras e logs
- **Segurança**: Os logs contêm dados sensíveis - proteja adequadamente
- **SIDs Únicos**: Cada regra precisa de um SID único (1000000+ para regras locais)
- **JSON**: Use `eve.json` para integração com SIEM/análise automatizada
- **YAML**: Certifique-se de que todos os arquivos `.rules` estão listados em `etc/suricata.yaml` na seção `rule-files:`