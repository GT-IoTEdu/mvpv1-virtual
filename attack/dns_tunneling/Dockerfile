FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    apache2-utils \
    curl \
    wget \
    python3 \
    python3-pip \
    isc-dhcp-client\
    iproute2\
    iputils-ping\
    && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y dnsutils && rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

