FROM alpine:3.20

RUN apk add --no-cache busybox-extras

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
COPY www /app/www

RUN chmod +x /app/entrypoint.sh

EXPOSE 8989

ENTRYPOINT ["/app/entrypoint.sh"]
