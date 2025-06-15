# syntax=docker/dockerfile:1

FROM golang:1.24-alpine

WORKDIR /app

# 1) Copie des fichiers de module et génération de go.sum
COPY go.mod ./
RUN go mod tidy

# 2) Téléchargement des dépendances (cache)
RUN go mod download

# 3) Copie du reste du code + compilation
COPY . .
RUN CGO_ENABLED=0 go build -o auth .

ENV GIN_MODE=release
EXPOSE 8081
CMD ["./auth"]
