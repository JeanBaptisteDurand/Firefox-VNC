#!/bin/sh
set -eu

api() {
	curl -sf -H "Authorization: Bearer $CF_API_TOKEN" \
	     -H "Content-Type: application/json" "$@"
}

# ── 1) ZONE_ID à partir du domaine ───────────────────────────
ZONE_ID=$(api "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
	      | jq -r '.result[0].id')
echo "🔎 ZONE_ID = $ZONE_ID"

# ── 2) Tunnel “auto-tunnel” (création ou récupération) ───────
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

# ── 3) Récupération du jeton (JSON OU chaîne brute) ──────────
TOKEN_RAW=$(api "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token")

# Essaye d’extraire .result.token ; en cas d’échec, garde la chaîne
TUNNEL_TOKEN=$(echo "$TOKEN_RAW" | jq -r '.result.token' 2>/dev/null || true)
[ -z "$TUNNEL_TOKEN" ] && TUNNEL_TOKEN="$TOKEN_RAW"

# Stocke la valeur brute dans le volume partagé
echo "$TUNNEL_TOKEN" > /shared/token

# ── 4) CNAME proxifié domaine → tunnel ───────────────────────
CNAME_PAYLOAD=$(jq -n \
  --arg name "$DOMAIN" \
  --arg content "$TUNNEL_ID.cfargotunnel.com" \
  '{type:"CNAME",name:$name,content:$content,ttl:1,proxied:true}')

REC_ID=$(api "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=$DOMAIN" \
         | jq -r '.result[0].id // empty')

if [ -n "$REC_ID" ]; then
	echo "🔄  Mise à jour du CNAME…"
	api -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$REC_ID" \
	    --data "$CNAME_PAYLOAD" >/dev/null
else
	echo "🆕  Création du CNAME…"
	api -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
	    --data "$CNAME_PAYLOAD" >/dev/null
fi
echo "🌐  $DOMAIN → $TUNNEL_ID.cfargotunnel.com (proxied)"

# ── 5) Fichiers attendus par cloudflared ─────────────────────
cat > /shared/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: /etc/cloudflared/creds.json
ingress:
  - hostname: $DOMAIN
    service: http://caddy:80
  - service: http_status:404
EOF

# credentials_file (JSON) : toujours fourni par l’API
echo "$TOKEN_RAW" | jq -r '.result.credentials_file // empty' > /shared/creds.json || true

echo "🎉 Bootstrap terminé"
