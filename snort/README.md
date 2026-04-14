# snort - Detector de Intrusão

Sistema de detecção de intrusão baseado em Snort para monitoramento de ataques de rede.

## 📁 Arquivos

```
snort/
├── Dockerfile         # Imagem Docker com Snort
├── snort.lua          # Configuração do Snort
├── start_snort.sh     # Script de inicialização
└── rules/             # Regras de detecção (*.rules)
    ├── all.rules      # Arquivo que inclui todas as regras
    ├── local.rules    # Regras gerais/customizadas
    ├── brute-force-ssh.rules
    ├── dns-tunneling.rules
    ├── dos-http.rules
    ├── ping-flood.rules
    └── sql-injection.rules
```

## 🚀 Uso Rápido

### Modo Desenvolvimento (Recomendado para testes)

Use este modo para editar regras no repositório e aplicar mudanças rapidamente:

```bash
# Construir imagem (apenas uma vez)
docker build -t snort .

# Executar com volume mount (regras e logs sincronizados)
docker run -d --name snort_ids --privileged --network host \
  -v $(pwd)/rules:/opt/snort3/etc/snort/rules \
  -v $(pwd)/logs:/opt/snort3/logs \
  snort enp0s3
```

Agora você pode:

1. **Editar regras** nos arquivos específicos da `rules/` directory
2. **Testar sintaxe** antes de aplicar:
   ```bash
   docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua -T
   ```
3. **Reiniciar** para aplicar mudanças:
   ```bash
   docker restart snort_ids
   ```
4. **Verificar** se a regra foi carregada:
   ```bash
   docker exec snort_ids grep "seu_sid" /opt/snort3/etc/snort/rules/seu-ataque.rules
   ```
5. **Ver logs** diretamente no host:
   ```bash
   tail -f logs/alert_full.txt
   ```

### Modo Produção (Regras fixas na imagem)

```bash
# Rebuildar imagem com novas regras
docker build -t snort .

# Executar
docker run -d --name snort_ids --privileged --network host snort enp0s3
```

> [!NOTE]
> A imagem pode demorar alguns minutos (cerca de 18 minutos) para ser construída, pois compila o snort e suas dependências.
> Para adiantar o processo, você pode usar a imagem já pronta do Docker Hub:

```bash
docker pull joaoprdo/snort:latest

# Executar com volume mount
docker run -d --name snort_ids --privileged --network host \
  -v $(pwd)/rules:/opt/snort3/etc/snort/rules \
  -v $(pwd)/logs:/opt/snort3/logs \
  joaoprdo/snort:latest enp0s3
```

## 🔍 Ataques Detectados

| Tipo                | Descrição              | Threshold           | Arquivo              |
| ------------------- | ---------------------- | ------------------- | -------------------- |
| **HTTP DoS**        | GET/POST flood         | 20/10 req em 5s     | dos-http.rules       |
| **SSH Brute Force** | Múltiplas conexões SSH | 10 tent em 60s      | brute-force-ssh.rules |
| **ICMP Flood**      | Ping flood             | 50 pings em 5s      | ping-flood.rules     |
| **SQL Injection**   | UNION, OR 1=1, quotes  | Qualquer ocorrência | sql-injection.rules  |
| **DNS Tunneling**   | Alto volume DNS        | 50 queries em 10s   | dns-tunneling.rules  |

## 📝 Editando Regras

### Workflow de Desenvolvimento

O novo workflow organiza as regras por tipo de ataque:

```bash
# 1. Identificar o tipo de ataque (ex: brute-force-ssh)
# 2. Editar o arquivo correspondente ou criar um novo
nano rules/brute-force-ssh.rules

# 3. Testar sintaxe (IMPORTANTE!)
docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua -T

# 4. Se OK, reiniciar para aplicar
docker restart snort_ids

# 5. Verificar se a regra foi carregada
docker exec snort_ids grep "1000040" /opt/snort3/etc/snort/rules/brute-force-ssh.rules

# 6. Monitorar alertas em tempo real
tail -f logs/alert_full.txt

# 7. Gerar tráfego para testar a regra
# (exemplo específico do ataque)

# 8. Verificar se a regra foi acionada nos alertas
grep "1000040" logs/alert_full.txt
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

# 3. Incluir o arquivo em rules/all.rules
echo "include novo-ataque.rules" >> rules/all.rules

# 4. Testar sintaxe
docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua -T

# 5. Reiniciar
docker restart snort_ids
```

### Estrutura de uma Regra Snort

```snort
alert tcp any any -> any 80 (
    msg:"Descrição do alerta";           # Mensagem no log
    content:"texto-a-buscar";            # Conteúdo a detectar
    http_uri;                            # Buscar na URI HTTP
    detection_filter:track by_src,       # Filtro de detecção
                    count 10,            # 10 ocorrências
                    seconds 60;          # em 60 segundos
    sid:1000041;                         # ID único (1000000-1999999 para regras locais)
    rev:1;                               # Revisão da regra
)
```

### Exemplos de Regras Personalizadas

```bash
# Adicionar no arquivo de regras específico (ex: rules/custom-attack.rules):

# Detectar acesso a endpoint específico
alert tcp any any -> any 80 (msg:"ACESSO -> Admin Panel"; content:"/admin"; http_uri; sid:1000041; rev:1;)

# Detectar User-Agent suspeito
alert tcp any any -> any 80 (msg:"SUSPEITO -> Bot Detected"; content:"bot"; http_user_agent; nocase; sid:1000042; rev:1;)

# Detectar múltiplas requisições POST
alert tcp any any -> any 443 (msg:"ATAQUE -> HTTPS POST Flood"; content:"POST"; http_method; detection_filter:track by_src, count 15, seconds 5; sid:1000043; rev:1;)
```

## 📊 Logs

Os alertas são salvos em:
- **Container**: `/opt/snort3/logs/`
- **Host** (com volume mount): `./logs/`

### Visualizando logs em tempo real

```bash
# Logs no host (com volume mount) - RECOMENDADO
tail -f logs/alert_full.txt

# Ou dentro do container
docker exec -it snort_ids tail -f /opt/snort3/logs/alert_full.txt

# Ver últimos 50 alertas
tail -50 logs/alert_full.txt

# Buscar alertas específicos
grep "SQL Injection" logs/alert_full.txt

# Filtrar por SID
grep "sid:1000029" logs/alert_full.txt

# Contar alertas por tipo
grep -oP 'msg:"[^"]*"' logs/alert_full.txt | sort | uniq -c | sort -rn
```

### Copiando logs (se não usou volume mount)

```bash
# Copiar todos os logs
docker cp snort_ids:/opt/snort3/logs/. ./snort-logs/

# Copiar apenas alert_full.txt
docker cp snort_ids:/opt/snort3/logs/alert_full.txt ./alert_full.txt
```

## ⚙️ Parâmetros

```bash
# Interface específica
docker run -d --name snort_ids --privileged --network host \
  -v $(pwd)/rules:/opt/snort3/etc/snort/rules \
  -v $(pwd)/logs:/opt/snort3/logs \
  snort wlan0

# Com alertas rápidos (formato simplificado)
docker run -d --name snort_ids --privileged --network host \
  -v $(pwd)/rules:/opt/snort3/etc/snort/rules \
  -v $(pwd)/logs:/opt/snort3/logs \
  snort enp0s3 -A fast

# Com modo verboso (debug)
docker run -d --name snort_ids --privileged --network host \
  -v $(pwd)/rules:/opt/snort3/etc/snort/rules \
  -v $(pwd)/logs:/opt/snort3/logs \
  snort enp0s3 -v
```

## 🔧 Gerenciamento do Container

```bash
# Ver status
docker ps -a | grep snort_ids

# Ver logs do Snort em tempo real
docker logs -f snort_ids

# Entrar no container (debug)
docker exec -it snort_ids bash

# Reiniciar após mudanças nas regras
docker restart snort_ids

# Ver estatísticas de recursos
docker stats snort_ids

# Parar
docker stop snort_ids

# Iniciar novamente
docker start snort_ids

# Remover
docker rm -f snort_ids
```

## 🧪 Testando Regras

### Workflow de Teste Completo

```bash
# 1. Criar diretório de logs
mkdir -p logs

# 2. Iniciar Snort com volumes
docker run -d --name snort_ids --privileged --network host \
  -v $(pwd)/rules:/opt/snort3/etc/snort/rules \
  -v $(pwd)/logs:/opt/snort3/logs \
  snort enp0s3

# 3. Adicionar regra de teste no arquivo específico (ex: rules/ping-flood.rules)
echo 'alert icmp any any -> any any (msg:"TESTE -> Ping Detectado"; itype:8; sid:1000099; rev:1;)' >> rules/ping-flood.rules

# 4. Testar sintaxe
docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua -T

# 5. Reiniciar para carregar a nova regra
docker restart snort_ids

# 6. Verificar se a regra está no container (confirmar volume mount)
docker exec snort_ids grep "1000099" /opt/snort3/etc/snort/rules/ping-flood.rules

# 7. Monitorar logs em tempo real (DEIXAR RODANDO)
tail -f logs/alert_full.txt

# 8. Em outro terminal, gerar tráfego de teste
ping -c 5 8.8.8.8

# 9. Verificar detecção (no primeiro terminal ou depois de parar o tail)
grep "TESTE -> Ping Detectado" logs/alert_full.txt
```

### Validando Sintaxe de Regras

```bash
# Testar configuração completa
docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua -T

# Ver regras carregadas
docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua --rule-to-text

# Contar regras ativas
docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua --rule-to-text | grep -c "alert"
```

### Diferença: Regra Carregada vs Regra Acionada

⚠️ **IMPORTANTE**: Entenda a diferença:

1. **Regra Carregada** = Regra está no Snort e pronta para detectar
   ```bash
   # Verificar se a regra foi carregada (conferir arquivo no container)
   docker exec snort_ids grep "sid:1000040" /opt/snort3/etc/snort/rules/seu-ataque.rules
   
   # Ou verificar a contagem de regras
   docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua -T | grep "total rules loaded"
   ```

2. **Regra Acionada** = Regra detectou tráfego e gerou alerta
   ```bash
   # Verificar alertas gerados (só aparece se a regra detectou algo)
   grep "sid:1000040" logs/alert_full.txt
   
   # Ou
   grep "TESTE -> Nova Regra" logs/alert_full.txt
   ```

**Exemplo prático:**
```bash
# Adicionar regra para detectar acesso à porta 8080
echo 'alert tcp any any -> any 8080 (msg:"TESTE -> Acesso porta 8080"; sid:1000040; rev:1;)' >> rules/custom-attack.rules

# Adicionar no all.rules se for novo arquivo
echo "include custom-attack.rules" >> rules/all.rules

# Verificar se foi escrita no arquivo
grep "1000040" rules/custom-attack.rules

# Reiniciar
docker restart snort_ids

# Verificar que o volume mount está funcionando
docker exec snort_ids grep "1000040" /opt/snort3/etc/snort/rules/custom-attack.rules

# Agora a regra está CARREGADA mas não ACIONADA ainda

# Para ACIONAR a regra, gerar tráfego para porta 8080:
curl http://localhost:8080
# ou de outra máquina: curl http://IP_DA_MAQUINA:8080

# Agora sim, verificar o alerta nos logs:
grep "1000040" logs/alert_full.txt
```

## 🐛 Solução de Problemas

### Regras não aplicam

```bash
# 1. Verificar se o arquivo está incluído em all.rules
grep "seu-ataque.rules" rules/all.rules

# 2. Verificar sintaxe das regras
docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua -T

# 3. Ver logs de erro
docker logs snort_ids

# 4. Verificar se o volume foi montado corretamente
docker exec snort_ids cat /opt/snort3/etc/snort/rules/seu-ataque.rules

# 5. Reiniciar forçando reload
docker restart snort_ids
```

### Erro de sintaxe nas regras

```bash
# Ver último erro
docker logs --tail 50 snort_ids

# Erros comuns:
# - SID duplicado: cada regra precisa de um SID único
# - Falta ponto-e-vírgula: todas as opções devem ter ';'
# - Parênteses não fechados: verificar '(' e ')'
# - Include faltando em all.rules: certifique-se que o arquivo está listado
```

### Logs não aparecem

```bash
# Verificar se o Snort está rodando
docker exec snort_ids ps aux | grep snort

# Verificar permissões do diretório de logs
ls -la logs/

# Gerar tráfego de teste
ping -c 10 8.8.8.8

# Ver logs em tempo real
docker logs -f snort_ids
```

### Container não inicia

```bash
# Ver erro completo
docker logs snort_ids

# Testar sem daemon
docker run --rm --privileged --network host \
  -v $(pwd)/rules:/opt/snort3/etc/snort/rules \
  snort enp0s3

# Verificar interface
ip link show enp0s3
```

### Alto uso de CPU/Memória

```bash
# Monitorar recursos
docker stats snort_ids

# Limitar recursos do container
docker update --cpus="2" --memory="2g" snort_ids

# Reduzir verbosidade (remover -v do comando)
docker stop snort_ids
docker rm snort_ids
docker run -d --name snort_ids --privileged --network host \
  -v $(pwd)/rules:/opt/snort3/etc/snort/rules \
  -v $(pwd)/logs:/opt/snort3/logs \
  snort enp0s3
```

## 📚 Documentação Adicional

- [Snort 3 Manual](https://www.snort.org/documents)
- [Snort Rules](https://www.snort.org/downloads/#rule-downloads)
- [Writing Snort Rules](https://docs.snort.org/rules/)
- [Rule Options Reference](https://docs.snort.org/rules/options/)

## 💡 Dicas de Desenvolvimento

### SIDs Recomendados

- **1000000-1000999**: Regras de teste
- **1001000-1009999**: Regras de produção customizadas
- **1010000+**: Regras experimentais

### Organização de Arquivos de Regras

- **local.rules**: Regras gerais ou customizadas que não se encaixam em nenhuma categoria
- **[tipo-ataque].rules**: Um arquivo para cada tipo/categoria de ataque
- **all.rules**: Arquivo central que inclui todos os outros com `include [arquivo].rules`

### Boas Práticas

1. **Sempre teste a sintaxe** antes de reiniciar:
   ```bash
   docker exec snort_ids snort -c /opt/snort3/etc/snort/snort.lua -T
   ```

2. **Use SIDs únicos** para cada regra

3. **Documente suas regras** com comentários descritivos

4. **Backup antes de alterações críticas**:
   ```bash
   cp rules/*.rules rules/backup/
   ```

5. **Monitore falsos positivos** e ajuste thresholds

6. **Organize por tipo de ataque**: crie um arquivo para cada categoria

### Comparação de Modos

| Aspecto | Volume Mount | Rebuild |
|---------|--------------|---------|
| **Velocidade** | ⚡ Rápido (restart) | 🐌 Lento (18 min) |
| **Uso** | 🧪 Desenvolvimento | 🏭 Produção |
| **Sincronização** | ✅ Tempo real | ❌ Manual |
| **Persistência** | ⚠️ Depende do host | ✅ Na imagem |
| **Rollback** | ✅ Fácil (git) | ⚠️ Rebuild |

## ⚠️ Notas Importantes

- **Desenvolvimento**: Use sempre com volume mount para agilidade
- **Produção**: Rebuilde a imagem para embutir regras testadas
- **Performance**: Em redes de alto tráfego, ajuste os thresholds
- **Backup**: Faça backup regular dos arquivos de regras e logs
- **Segurança**: Os logs contêm dados sensíveis - proteja adequadamente
- **SIDs Únicos**: Cada regra precisa de um SID único (1000000-1999999 para regras locais)
- **Includes**: Certifique-se de que todos os arquivo `.rules` estão listados em `all.rules`
