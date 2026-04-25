FROM ubuntu:24.04

WORKDIR /API_IoT_EDU

# Install system dependencies
RUN apt-get update && apt-get install -y \
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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /frontend
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Manifests primeiro → install vira layer cached enquanto package.json
# e requirements.txt não mudarem. Depois o COPY do código e o build,
# que re-rodam só quando source muda.
COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY package.json package-lock.json* ./
RUN npm install --legacy-peer-deps

COPY . /frontend
RUN npm run build

CMD ["/bin/bash","/frontend/start.sh"]
