FROM ollama/ollama:latest
RUN apt-get install -y curl

COPY ./run-ollama.sh /tmp/run-ollama.sh
WORKDIR /tmp
RUN chmod +x run-ollama.sh \
  && ./run-ollama.sh

EXPOSE 11434

