# syntax=docker/dockerfile:1

FROM golang:1.24-alpine

WORKDIR /app

# 1. Copie des fichiers de module (y compris go.sum s’il existe déjà)
COPY go.mod go.sum ./

# 2. Téléchargement des dépendances
RUN go mod download

# 3. Copie du reste du code (main.go, login.html, etc.)
COPY . .

# 4. Compilation
RUN CGO_ENABLED=0 go build -o auth .

ENV GIN_MODE=release
EXPOSE 8081
CMD ["./auth"]
