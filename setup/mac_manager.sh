#!/bin/bash

# Script para gerenciar MAC addresses
# Uso: ./mac_manager.sh [generate|validate|list|random] [MAC]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAC_FILE="${SCRIPT_DIR}/.mac_addresses.txt"

# Função para gerar MAC address aleatório
generate_random_mac() {
    local prefix=${1:-"02"}
    # Garantir que o prefixo seja um número par (locally administered)
    if [[ $prefix =~ ^([0-9A-Fa-f]{2})$ ]]; then
        local first_hex=$(printf "%02x" $((0x$prefix & 0xFE | 0x02)))
        echo "$first_hex:$(hexdump -n 5 -ve '1/1 "%.2x:"' /dev/random | sed 's/:$//')"
    else
        # Gerar MAC completamente aleatório
        hexdump -n 6 -ve '1/1 "%.2x "' /dev/random | awk -v a="2,6,a,e" -v r="$RANDOM" 'BEGIN{srand(r);}NR==1{split(a,b,",");r=int(rand()*4+1);printf "%s%s:%s:%s:%s:%s:%s\n",substr($1,0,1),b[r],$2,$3,$4,$5,$6}'
    fi
}

# Função para validar MAC address
validate_mac() {
    local mac=$1
    if [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        echo "Formato válido"
        return 0
    else
        echo "Erro: MAC address inválido. Formato esperado: XX:XX:XX:XX:XX:XX"
        return 1
    fi
}


# Main
case $1 in
    generate)
        if [ -n "$2" ]; then
            generate_random_mac "$2"
        else
            generate_random_mac
        fi
        ;;
    validate)
        if [ -n "$2" ]; then
            validate_mac "$2"
        else
            echo "Uso: $0 validate XX:XX:XX:XX:XX:XX"
            exit 1
        fi
        ;;
    list)
        list_macs
        ;;
    save)
        if [ -n "$2" ] && [ -n "$3" ]; then
            save_mac "$2" "$3"
        else
            echo "Uso: $0 save NOME_CONTAINER MAC_ADDRESS"
            exit 1
        fi
        ;;
    get)
        if [ -n "$2" ]; then
            get_mac "$2"
        else
            echo "Uso: $0 get NOME_CONTAINER"
            exit 1
        fi
        ;;
    cleanup)
        cleanup_macs
        ;;
    container)
        if [ -n "$2" ]; then
            generate_mac_for_container "$2"
        else
            echo "Uso: $0 container NOME_CONTAINER"
            exit 1
        fi
        ;;
    *)
        echo "Uso: $0 {generate|validate|list|save|get|cleanup|container} [argumentos]"
        echo ""
        echo "Comandos:"
        echo "  generate [prefix]     - Gerar MAC aleatório (prefixo opcional em hex)"
        echo "  validate MAC          - Validar formato do MAC"
        echo "  list                  - Listar MACs salvos"

        echo ""
        echo "Exemplos:"
        echo "  $0 generate"
        echo "  $0 generate 02"
        echo "  $0 validate 02:42:ac:12:34:56"
        echo "  $0 container atacante_ddos"
        exit 1
        ;;
esac
