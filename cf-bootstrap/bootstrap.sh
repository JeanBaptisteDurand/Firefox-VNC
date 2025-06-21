#!/bin/sh
set -eu

api() {
	curl -sf -H "Authorization: Bearer $CF_API_TOKEN" \
	     -H "Content-Type: application/json" "$@"
}

# 1) Zone Cloudflare
ZONE_ID=$(api "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
	      | jq -r '.result[0].id')
echo "🔎 ZONE_ID = $ZONE_ID"

# 2) Tunnel « auto-tunnel » (création si besoin)
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

# 3) Jeton « run tunnel » ---- (renvoie une chaine brute)
TOKEN_RAW=$(api "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token")

# on enlève éventuels guillemets + retour-chariot puis on écrit sans newline
printf '%s' "$(echo "$TOKEN_RAW" | tr -d '"\n')" > /shared/token

# 4) CNAME proxifié domaine → tunnel
CNAME_PAYLOAD=$(jq -n \
  --arg name "$DOMAIN" \
  --arg content "$TUNNEL_ID.cfargotunnel.com" \
  '{type:"CNAME",name:$name,content:$content,ttl:1,proxied:true}')

REC_ID=$(api "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=$DOMAIN" \
         | jq -r '.result[0].id // empty')

if [ -n "$REC_ID" ]; then
	api -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$REC_ID" \
	    --data "$CNAME_PAYLOAD" >/dev/null
else
	api -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
	    --data "$CNAME_PAYLOAD" >/dev/null
fi
echo "🌐  $DOMAIN → $TUNNEL_ID.cfargotunnel.com (proxied)"

# 5) config.yml minimal
cat > /shared/config.yml <<EOF
tunnel: $TUNNEL_ID
ingress:
  - hostname: $DOMAIN
    service: http://caddy:80
  - service: http_status:404
EOF

echo "🎉 Bootstrap terminé"
