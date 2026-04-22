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
    git\
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git /sqlmap
WORKDIR /sqlmap
COPY  entrypoint.sh  entrypoint.sh
RUN chmod +x  entrypoint.sh

