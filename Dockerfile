FROM ghcr.io/viren070/aiostreams:lastest

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY aiostreams.dump /app/aiostreams.dump
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENV PORT=7860

EXPOSE 7860

ENTRYPOINT ["/entrypoint.sh"]