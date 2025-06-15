# syntax=docker/dockerfile:1

FROM golang:1.24-alpine

WORKDIR /app

# 1) Copie des fichiers de module et téléchargement des deps
COPY go.mod ./
RUN go mod download

# 2) Copie du reste du code (main.go, login.html, etc.)
COPY . .

# 3) Re-génère go.sum après la copie (évite l’écrasement)
RUN go mod tidy

# 4) Compile
RUN CGO_ENABLED=0 go build -o auth .

ENV GIN_MODE=release
EXPOSE 8081
CMD ["./auth"]
