#!/bin/bash

# Script para deploy de containers de ataque
# Uso: ./deploy_container.sh [OPÇÃO] [MAC_ADDRESS]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC_MANAGER="${SCRIPT_DIR}/mac_manager.sh"

# Verificar se o mac_manager.sh existe
if [ ! -f "$MAC_MANAGER" ]; then
    echo "Erro: mac_manager.sh não encontrado no diretório $SCRIPT_DIR"
    exit 1
fi

# Tornar mac_manager.sh executável se necessário
chmod +x "$MAC_MANAGER" 2>/dev/null

# Função para mostrar uso
usage() {
    echo "Uso: $0 [OPÇÃO] [MAC_ADDRESS]"
    echo ""
    echo "Opções de imagem:"
    echo "  -d, --ddos          Usar imagem ddos"
    echo "  -s, --sql           Usar imagem sql_injection"
    echo "  -p, --ping          Usar imagem ping_flood"
    echo "  -dt, --dns_t        Usar imagem dns_tunneling"
    echo "  -br, --brute        Usar imagem brute_force_ssh"
    echo ""
    echo "Opções gerais:"
    echo "  --mac MAC           Usar MAC específico (formato XX:XX:XX:XX:XX:XX)"
    echo "  --no-dhcp           Não usar DHCP (configuração manual)"
    echo "  --ip IP             IP estático para o container"
    echo "  --bridge NAME       Nome da bridge (padrão: bridge-tap)"
    echo "  -h, --help          Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 -d                          # DDoS com MAC aleatório"
    echo "  $0 -s 02:42:ac:12:34:56        # SQL injection com MAC específico"
    echo "  $0 --ddos --mac 02:11:22:33:44:55"
    echo "  $0 -p --no-dhcp --ip 10.0.0.100"
    exit 1
}

# Valores padrão
IMAGE_TYPE=""
USER_MAC=""
USE_RANDOM_MAC=true
USE_DHCP=true
STATIC_IP=""
BRIDGE_NAME="bridge-tap"
CONTAINER_NAME=""

# Parse dos argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--ddos)
            IMAGE_TYPE="ddos"
            CONTAINER_NAME="ddos_$(date +%s)"
            shift
            ;;
        -s|--sql)
            IMAGE_TYPE="sql_injection"
            CONTAINER_NAME="sql_$(date +%s)"
            shift
            ;;
        -p|--ping)
            IMAGE_TYPE="ping_flood"
            CONTAINER_NAME="ping_$(date +%s)"
            shift
            ;;
        -dt|--dns_t)
            IMAGE_TYPE="dns_tunneling"
            CONTAINER_NAME="dns_$(date +%s)"
            shift
            ;;
        -br|--brute)
            IMAGE_TYPE="brute_force_ssh"
            CONTAINER_NAME="brute_$(date +%s)"
            shift
            ;;
        --mac)
            USER_MAC="$2"
            USE_RANDOM_MAC=false
            shift 2
            ;;
        --no-dhcp)
            USE_DHCP=false
            shift
            ;;
        --ip)
            STATIC_IP="$2"
            USE_DHCP=false
            shift 2
            ;;
        --bridge)
            BRIDGE_NAME="$2"
            shift 2
            ;;
        --name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            # Verificar se o argumento parece um MAC address
            if [[ $1 =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                USER_MAC="$1"
                USE_RANDOM_MAC=false
                shift
            else
                echo "Erro: Argumento inválido '$1'"
                usage
            fi
            ;;
    esac
done

# Verificar se uma imagem foi selecionada
if [ -z "$IMAGE_TYPE" ]; then
    echo "Erro: Nenhuma imagem selecionada"
    usage
fi

# Verificar se a bridge existe
if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
    echo "Bridge $BRIDGE_NAME não encontrada. Criando..."
    sudo ip link add "$BRIDGE_NAME" type bridge
    sudo ip link set "$BRIDGE_NAME" up
fi

# Determinar o MAC a ser usado
if [ "$USE_RANDOM_MAC" = true ]; then
    MAC=$($MAC_MANAGER generate)
    echo "MAC address gerado aleatoriamente: $MAC"
else
    if $MAC_MANAGER validate "$USER_MAC" &>/dev/null; then
        MAC="$USER_MAC"
        echo "MAC address fornecido pelo usuário: $MAC"
    else
        echo "Erro: MAC address inválido"
        exit 1
    fi
fi

# Limpar container antigo se existir
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Removendo container antigo: $CONTAINER_NAME"
    docker rm -f "$CONTAINER_NAME" 2>/dev/null
fi

# Obter IP do servidor alvo
get_server_ip() {
    local ip=$(ip a | grep -E -A3 -B2 'scope global dynamic noprefixroute|mtu 1500 qdisc fq_codel state UP' | \
               grep 'inet' | grep -Eo '(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\.((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\.((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\.((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)))' | \
               sort | uniq | grep -v '255' | head -1)

    if [ -z "$ip" ]; then
        echo "Aviso: Não foi possível detectar IP automaticamente"
        read -p "Digite o IP do servidor alvo: " ip
    fi
    echo "$ip"
}

SERVER_ALVO=$(get_server_ip)
echo "IP do servidor alvo: $SERVER_ALVO"

# Gerar nomes dinâmicos para interfaces
TIMESTAMP=$(date +%s%N| tail -c 5)
VETH_HOST="veth-host-${TIMESTAMP}"
VETH_CONT="veth-cont-${TIMESTAMP}"

# Verificar se a imagem existe
if ! docker image inspect "$IMAGE_TYPE":latest &>/dev/null; then
    echo "Erro: Imagem $IMAGE_TYPE:latest não encontrada"
    echo "Construa a imagem primeiro com: docker build --target $IMAGE_TYPE -t ${IMAGE_TYPE}:latest ."
    exit 1
fi

# Configurar variáveis de ambiente para o container
DOCKER_ENV=(
    -e "SERVER_IP=$SERVER_ALVO"
    -e "VETH_CONT_NAME=$VETH_CONT"
    -e "MAC_ADDRESS=$MAC"
    -e "USE_DHCP=$USE_DHCP"
    -e "STATIC_IP=$STATIC_IP"
)

# Iniciar container
echo "Iniciando container $CONTAINER_NAME com MAC $MAC"
docker run -d --name "$CONTAINER_NAME" --hostname "$IMAGE_TYPE" \
    --network none \
    --cap-add NET_ADMIN --cap-add NET_RAW \
    "${DOCKER_ENV[@]}" \
    "$IMAGE_TYPE":latest sleep infinity

# Aguardar o container iniciar
sleep 2

# Configurar rede
sudo ip link add $VETH_HOST type veth peer name $VETH_CONT
sudo ip link set $VETH_CONT address $MAC
sudo ip link set $VETH_HOST master "$BRIDGE_NAME"
sudo ip link set $VETH_HOST up

# Obter PID do container
CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME")
if [ -z "$CONTAINER_PID" ] || [ "$CONTAINER_PID" -eq 0 ]; then
    echo "Erro: Não foi possível obter PID do container"
    exit 1
fi

# Mover interface para o namespace do container
sudo ip link set $VETH_CONT netns "${CONTAINER_PID}"

# Configurar rede dentro do container
configure_container_network() {
    local container=$1
    local veth_name=$2
    local use_dhcp=$3
    local static_ip=$4

    if [ "$use_dhcp" = true ]; then
        docker exec "$container" bash -c "
            ip link set lo up
            sleep 1
            IFACE=\$(ip link show | grep -o 'veth-cont-[0-9]*' | head -1)
            if [ -n \"\$IFACE\" ]; then
                ip link set \$IFACE name eth0
                ip link set eth0 up
                timeout 10 dhclient -v eth0 || echo 'DHCP falhou'
            fi
        "
    else
        if [ -n "$static_ip" ]; then
            docker exec "$container" bash -c "
                ip link set lo up
                sleep 1
                IFACE=\$(ip link show | grep -o 'veth-cont-[0-9]*' | head -1)
                if [ -n \"\$IFACE\" ]; then
                    ip link set \$IFACE name eth0
                    ip link set eth0 up
                    ip addr add ${static_ip}/24 dev eth0
                fi
            "
        else
            docker exec "$container" bash -c "
                ip link set lo up
                sleep 1
                IFACE=\$(ip link show | grep -o 'veth-cont-[0-9]*' | head -1)
                if [ -n \"\$IFACE\" ]; then
                    ip link set \$IFACE name eth0
                    ip link set eth0 up
                fi
            "
        fi
    fi
}

configure_container_network "$CONTAINER_NAME" "$VETH_CONT" "$USE_DHCP" "$STATIC_IP"

# Salvar MAC address
$MAC_MANAGER save "$CONTAINER_NAME" "$MAC"

# Executar entrypoint ou shell
if docker exec "$CONTAINER_NAME" test -f ./entrypoint.sh; then
    echo "Executando entrypoint.sh..."
    docker exec -it "$CONTAINER_NAME" ./entrypoint.sh
else
    echo "Aviso: entrypoint.sh não encontrado"
    echo "Iniciando shell interativo..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
fi

# Exibir informações finais
echo ""
echo "=== Container Deployed Successfully ==="
echo "Nome: $CONTAINER_NAME"
echo "Tipo: $IMAGE_TYPE"
echo "MAC: $MAC"
echo "IP do Alvo: $SERVER_ALVO"
echo "Bridge: $BRIDGE_NAME"
echo ""
echo "Comandos úteis:"
echo "  docker logs $CONTAINER_NAME"
echo "  docker exec -it $CONTAINER_NAME /bin/bash"
echo "  docker stop $CONTAINER_NAME"
echo "  docker rm -f $CONTAINER_NAME"
echo "  $MAC_MANAGER get $CONTAINER_NAME  # Ver MAC salvo"
