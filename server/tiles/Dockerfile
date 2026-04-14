FROM alpine:3.20

RUN apk add --no-cache python3

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
COPY www /app/www

RUN chmod +x /app/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]
