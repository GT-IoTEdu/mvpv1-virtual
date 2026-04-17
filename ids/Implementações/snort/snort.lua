-- /opt/snort3/etc/snort/snort.lua
-- Configuração Otimizada para GT-IoTEdu (Snort 3.9.7.0)

---------------------------------------------------------------------------
-- 1. Definições Iniciais
---------------------------------------------------------------------------
include 'snort_defaults.lua'

-- 2. Variáveis de Rede
network = { checksum_eval = 'none' }
HOME_NET = 'any'
EXTERNAL_NET = 'any'

-- Definição de Portas dos Serviços
HTTP_PORTS = '80 8080'
SSH_PORTS = '22 2222'
TELNET_PORTS = '23 2323'
MQTT_PORTS = '1883'
SSL_PORTS = '443 8443'
SMB_PORTS = '139 445'

---------------------------------------------------------------------------
-- 2. Configuração de Inspetores
---------------------------------------------------------------------------
-- Inspetores básicos necessários para remontagem de pacotes
stream = { }
stream_tcp = { }
stream_udp = { }
stream_icmp = { }
port_scan = { protos = 'all'}

-- Ativa o Wizard para detecção dinâmica (Crucial para portas não padrão)
wizard = { }

-- Inspetores de Protocolo específicos
http_inspect = { }
ssh = { } -- Necessário para detectar o brute force na 2222

-- Nota: Telnet e SSL removidos como módulos diretos para evitar erro de bind,
-- o Snort usará o 'wizard' para analisá-los nestas portas.

---------------------------------------------------------------------------
-- 3. Binder (Onde ligamos a porta ao protocolo)
---------------------------------------------------------------------------
binder =
{
    -- Liga portas HTTP ao inspetor de HTTP
    { when = { proto = 'tcp', ports = HTTP_PORTS }, use = { type = 'http_inspect' } },
    
    -- Liga portas SSH ao inspetor de SSH
    { when = { proto = 'tcp', ports = SSH_PORTS }, use = { type = 'ssh' } },
    
    -- Para as demais portas (Telnet, SSL, MQTT, etc), usamos o wizard.
    -- O wizard identifica o protocolo pelo payload, evitando erros de inicialização.
    { when = { proto = 'tcp', ports = TELNET_PORTS .. ' ' .. SSL_PORTS .. ' ' .. MQTT_PORTS }, use = { type = 'wizard' } },
    
    -- Fallback padrão
    { use = { type = 'wizard' } }
}

---------------------------------------------------------------------------
-- 4. Módulo IPS e Regras
---------------------------------------------------------------------------
ips =
{
    variables =
    {
        nets = { HOME_NET = HOME_NET, EXTERNAL_NET = EXTERNAL_NET },
        ports = { 
            HTTP_PORTS = HTTP_PORTS, 
            SSH_PORTS = SSH_PORTS 
        }
    },
    -- Caminho para as suas regras
    rules = [[
        include rules/all.rules
    ]]
}

---------------------------------------------------------------------------
-- 5. Configuração de Alertas e Saída
---------------------------------------------------------------------------
-- Habilita o modo de alerta rápido (fast)
alert_fast = { file = true, packet = false }
alert_full = { file = true }

-- Configurações de decodificação e inspeção
decode = { }
active = { }
