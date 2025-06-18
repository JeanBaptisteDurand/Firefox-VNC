FROM alpine:3.20
RUN apk add --no-cache curl jq openssl
COPY bootstrap.sh /usr/local/bin/bootstrap.sh
ENTRYPOINT ["/usr/local/bin/bootstrap.sh"]
