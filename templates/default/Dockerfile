FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    libpq-dev \
    libssl-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY src ./src
COPY model ./model
COPY controller ./controller

RUN gcc -std=c11 -Wall -Wextra -Wpedantic -O2 \
  -I/usr/include/postgresql \
  src/main.c \
  model/*.c \
  controller/*.c \
  -o /usr/local/bin/sealion-app \
  -lpq -lcrypto

EXPOSE 8080

HEALTHCHECK --interval=3s --timeout=3s --retries=20 \
  CMD curl -fsS http://localhost:8080/health >/dev/null || exit 1

CMD ["sealion-app"]
