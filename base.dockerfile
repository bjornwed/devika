# using multi-stage container file
# https://docs.docker.com/build/building/multi-stage/

# ============ setting up base os env ============
FROM debian:12 as base

## create and add nonroot user
USER root
WORKDIR /home/nonroot
RUN groupadd -r nonroot && useradd -r -g nonroot -d /home/nonroot -s /bin/bash nonroot

## update os
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y build-essential software-properties-common curl sudo wget git && \
    apt clean && rm -rf /var/lib/apt/lists/*

# ============ devika backend-engine ============
FROM base as engine
WORKDIR /home/nonroot  

## setting up build variables
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV TOKENIZERS_PARALLELISM false

## install python
RUN apt-get update && \
  apt-get install --no-install-recommends -y python3 python3-pip && \
  apt clean && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://astral.sh/uv/install.sh | sudo -E bash -

## create venv
RUN $HOME/.cargo/bin/uv venv
ENV PATH="/home/nonroot/.venv/bin:$HOME/.cargo/bin:$PATH"

## install dependencies
COPY requirements.txt /home/nonroot/
RUN UV_HTTP_TIMEOUT=100000 $HOME/.cargo/bin/uv pip install -r requirements.txt 
RUN playwright install 
RUN playwright install-deps

## change owner on folder to nonroot user
RUN chown -R nonroot:nonroot /home/nonroot
## switch user
USER nonroot

## copy devika python engine only
COPY src /home/nonroot/src
COPY config.toml /home/nonroot/
COPY devika.py /home/nonroot/

## install playwright for nonroot
RUN python3 -m playwright install

## start devika
ENTRYPOINT [ "python3", "-m", "devika" ]

# ============ devika frontend-app ============
FROM base as app
WORKDIR /home/nonroot

## setting up build variables
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

## install node js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
RUN apt-get install nodejs

## copying devika app client only
COPY ui /home/nonroot/ui
COPY src /home/nonroot/src
COPY config.toml /home/nonroot/

RUN cd ui && npm install && npm install -g npm && npm install -g bun
RUN chown -R nonroot:nonroot /home/nonroot

USER nonroot
WORKDIR /home/nonroot/ui

ENTRYPOINT [ "npx", "bun", "run", "dev", "--", "--host" ]