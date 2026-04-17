FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y software-properties-common && \
    add-apt-repository ppa:oisf/suricata-stable && \
    apt update && \
    apt install -y suricata iproute2 python3 python3-yaml && \
    apt clean

# Variáveis padrão (podem ser sobrescritas em runtime)
ENV SURICATA_IFACE=enp0s3
ENV SURICATA_HOME_NET=any
ENV SURICATA_ARGS=""

COPY etc/ /etc/suricata/
COPY rules/ /var/lib/suricata/rules/
COPY start_suricata.sh /opt/suricata/start_suricata.sh

RUN chmod +x /opt/suricata/start_suricata.sh

WORKDIR /opt/suricata

ENTRYPOINT ["/opt/suricata/start_suricata.sh"]
CMD []