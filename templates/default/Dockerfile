FROM golang:1.26-bookworm AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY src ./src
COPY model ./model
COPY controller ./controller

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags "-s -w" -o /out/carbide-app ./src

FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/carbide-app /usr/local/bin/carbide-app

EXPOSE 8080

HEALTHCHECK --interval=3s --timeout=3s --retries=20 \
  CMD curl -fsS http://localhost:8080/health >/dev/null || exit 1

CMD ["carbide-app"]
