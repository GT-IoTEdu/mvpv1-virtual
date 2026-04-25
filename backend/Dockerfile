FROM ubuntu:24.04

WORKDIR /API_IoT_EDU

RUN apt-get update && apt-get install -y ethtool iproute2 net-tools
# Install system dependencies
RUN  apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    dos2unix \
    pkg-config \
    libmariadb-dev \
    build-essential \
    npm \
    default-mysql-client \
    iputils-ping \
    php-curl\
    isc-dhcp-client\
    iproute2\
    iputils-ping\
    curl\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /backend
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Manifests primeiro → pip install vira layer cached enquanto
# requirements.txt não mudar. Mudanças em código Python re-rodam
# só o COPY (instantâneo).
COPY requirements.txt ./
RUN pip install --upgrade pip \
 && pip install mysql-connector-python \
 && pip install -r requirements.txt

COPY . /backend

CMD ["/bin/bash","/backend/start.sh"]
