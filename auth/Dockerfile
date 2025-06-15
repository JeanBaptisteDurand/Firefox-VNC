# syntax=docker/dockerfile:1

FROM golang:1.24-alpine

WORKDIR /app
COPY . .

# Télécharge d'abord les dépendances (cache)
RUN go mod download

# Compile le binaire statique
RUN CGO_ENABLED=0 go build -o auth .

ENV GIN_MODE=release
EXPOSE 8081
ENTRYPOINT ["./auth"]
