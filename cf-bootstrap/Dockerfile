# syntax=docker/dockerfile:1

FROM alpine:3.20

# Outils indispensables à l’intérieur du bootstrap
RUN apk add --no-cache curl jq openssl

# Copie du script
COPY bootstrap.sh /usr/local/bin/bootstrap.sh

# ────────────────────────────────────────────────
#  Correctif : on rend le script exécutable
# ────────────────────────────────────────────────
RUN chmod +x /usr/local/bin/bootstrap.sh

# Exécution du bootstrap (sortie attendue → le conteneur s’arrête)
ENTRYPOINT ["/usr/local/bin/bootstrap.sh"]
