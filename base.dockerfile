FROM debian:12 as base
# WIP!!!
# using a multi-stage container file
# https://docs.docker.com/build/building/multi-stage/

# setting up os env
USER root
RUN groupadd -r nonroot && useradd -r -g nonroot -d /home/nonroot -s /bin/bash nonroot

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y build-essential software-properties-common curl sudo wget git && \
    apt clean && rm -rf /var/lib/apt/lists/*

# devika backend-engine
FROM base as engine

# setting up build variables
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV TOKENIZERS_PARALLELISM false

# install python
RUN apt-get update && \
  apt-get install --no-install-recommends -y python3 python3-pip && \
  apt clean && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://astral.sh/uv/install.sh | sudo -E bash -

WORKDIR /home/nonroot  
## create env
RUN $HOME/.cargo/bin/uv venv
## install requirements
COPY requirements.txt /home/nonroot/
RUN UV_HTTP_TIMEOUT=100000 $HOME/.cargo/bin/uv pip install -r requirements.txt 
RUN playwright install 
RUN playwright install-deps

## copy devika python engine only
COPY src /home/nonroot/src
COPY config.toml /home/nonroot/
COPY devika.py /home/nonroot/
RUN chown -R nonroot:nonroot /home/nonroot

USER nonroot

ENV PATH="/home/nonroot/.venv/bin:$HOME/.cargo/bin:$PATH"
RUN mkdir /home/nonroot/db

ENTRYPOINT [ "python3", "-m", "devika" ]

# devika frontend-app
FROM base as app

# setting up build variable
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

WORKDIR /home/nonroot

# install node js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
RUN apt-get install nodejs

# copying devika app client only
COPY ui /home/nonroot/ui
COPY src /home/nonroot/src
COPY config.toml /home/nonroot/

RUN cd ui && npm install && npm install -g npm && npm install -g bun
RUN chown -R nonroot:nonroot /home/nonroot

USER nonroot
WORKDIR /home/nonroot/ui

ENTRYPOINT [ "npx", "bun", "run", "dev", "--", "--host" ]