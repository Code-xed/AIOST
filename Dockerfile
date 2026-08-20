FROM node:24-slim AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN corepack enable

FROM base AS builder

WORKDIR /build

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     ca-certificates \
     git \
     python3 \
     make \
     g++ \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch v2.32.1 \
    https://github.com/Viren070/AIOStreams.git .

RUN pnpm install --frozen-lockfile

RUN pnpm run build

RUN rm -rf node_modules
RUN rm -rf packages/core/node_modules
RUN rm -rf packages/server/node_modules
RUN rm -rf packages/frontend/node_modules
RUN rm -rf packages/seanime-extensions/node_modules

RUN pnpm install --prod --frozen-lockfile


FROM builder AS runtime

WORKDIR /runtime

COPY --from=builder /build/package*.json /build/LICENSE ./
COPY --from=builder /build/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=builder /build/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=builder /build/patches ./patches

COPY --from=builder /build/packages/core/package*.json ./packages/core/
COPY --from=builder /build/packages/server/package*.json ./packages/server/

COPY --from=builder /build/packages/core/dist ./packages/core/dist
COPY --from=builder /build/packages/frontend/dist ./packages/frontend/dist
COPY --from=builder /build/packages/server/dist ./packages/server/dist
COPY --from=builder /build/packages/server/src/static ./packages/server/dist/static
COPY --from=builder /build/packages/seanime-extensions/dist ./packages/seanime-extensions/dist

COPY --from=builder /build/resources ./resources
COPY --from=builder /build/scripts ./scripts

COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/packages/core/node_modules ./packages/core/node_modules
COPY --from=builder /build/packages/server/node_modules ./packages/server/node_modules


FROM node:24-slim AS production

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     postgresql \
     postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=runtime /runtime /app

COPY aiostreams.dump /app/aiostreams.dump
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENV PORT=7860

EXPOSE 7860

ENTRYPOINT ["/entrypoint.sh"]