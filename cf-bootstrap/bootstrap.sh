#!/bin/sh
set -eu

api() {  # petit helper cURL
  curl -sf -H "Authorization: Bearer $CF_API_TOKEN" \
       -H "Content-Type: application/json" "$@"
}

# 1) Récupère la ZONE_ID depuis le nom de domaine
ZONE_ID=$(api "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
          | jq -r '.result[0].id')
echo "🔎 ZONE_ID = $ZONE_ID"

# 2) Crée le tunnel s’il n’existe pas déjà
TUNNEL_NAME="auto-tunnel"
TUNNEL=$(api "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel" \
        | jq -r --arg n "$TUNNEL_NAME" '.result[]?|select(.name==$n)')

if [ -z "$TUNNEL" ]; then
  echo "🆕  Création du tunnel…"
  TUNNEL=$(api -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel" \
    --data "{\"name\":\"$TUNNEL_NAME\"}")
fi

TUNNEL_ID=$(echo "$TUNNEL" | jq -r '.result.id // .id')
echo "✅ TUNNEL_ID = $TUNNEL_ID"

# 3) Récupère le SERVICE TOKEN (« Run tunnel »)
TOKEN_JSON=$(api "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token")
TUNNEL_TOKEN=$(echo "$TOKEN_JSON" | jq -r '.result.token')
echo "TUNNEL_TOKEN=$TUNNEL_TOKEN" >> /shared/env

# 4) CNAME proxifié vers le tunnel
CNAME_PAYLOAD=$(jq -n \
  --arg name "$DOMAIN" \
  --arg content "$TUNNEL_ID.cfargotunnel.com" \
  '{type:"CNAME",name:$name,content:$content,ttl:1,proxied:true}')

# Cherche un éventuel record existant
REC_ID=$(api "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=$DOMAIN" \
         | jq -r '.result[0].id // empty')

if [ -n "$REC_ID" ]; then
  echo "🔄  Mise à jour du CNAME…"
  api -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$REC_ID" \
      --data "$CNAME_PAYLOAD" >/dev/null
else
  echo "🆕  Création du CNAME…"
  api -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      --data "$CNAME_PAYLOAD"  >/dev/null
fi
echo "🌐  $DOMAIN → $TUNNEL_ID.cfargotunnel.com (proxied)"

# 5) Construit config.yml + credentials file attendus par cloudflared
mkdir -p /shared/cf
cat > /shared/cf/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: /etc/cloudflared/creds.json
ingress:
  - hostname: $DOMAIN
    service: http://caddy:80
  - service: http_status:404
EOF
echo "$TOKEN_JSON" | jq -r '.result.credentials_file' > /shared/cf/creds.json

echo "🎉 Bootstrap terminé"
