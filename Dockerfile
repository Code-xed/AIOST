FROM ghcr.io/viren070/aiostreams:latest

USER root

RUN apk add --no-cache postgresql postgresql-client

COPY aiostreams.dump /app/aiostreams.dump
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENV PORT=7860

EXPOSE 7860

ENTRYPOINT ["/entrypoint.sh"]