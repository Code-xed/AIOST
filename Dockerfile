FROM node:24-slim AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS builder

WORKDIR /build

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY LICENSE ./
COPY package*.json ./
COPY packages/server/package*.json ./packages/server/
COPY packages/core/package*.json ./packages/core/
COPY packages/frontend/package*.json ./packages/frontend/
COPY packages/seanime-extensions/package*.json ./packages/seanime-extensions/
COPY pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY pnpm-lock.yaml ./pnpm-lock.yaml
COPY patches ./patches

RUN pnpm install --frozen-lockfile

COPY tsconfig.*json ./
COPY packages/server ./packages/server
COPY packages/core ./packages/core
COPY packages/frontend ./packages/frontend
COPY packages/seanime-extensions ./packages/seanime-extensions
COPY scripts ./scripts
COPY resources ./resources

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

COPY --from=builder /build/packages/core/package.*json ./packages/core/
COPY --from=builder /build/packages/server/package.*json ./packages/server/

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


FROM debian:12-slim AS mimalloc

RUN apt-get update \
  && apt-get install -y --no-install-recommends libmimalloc2.0 \
  && rm -rf /var/lib/apt/lists/* \
  && cp /usr/lib/*/libmimalloc.so.2 /usr/local/lib/libmimalloc.so.2


# CHANGED: Debian runtime instead of distroless
FROM node:24-slim AS production

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     postgresql \
     postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=busybox:1.36.0-uclibc /bin/wget /bin/wget
COPY --from=mimalloc /usr/local/lib/libmimalloc.so.2 /usr/local/lib/libmimalloc.so.2

ENV LD_PRELOAD=/usr/local/lib/libmimalloc.so.2

COPY --from=runtime /runtime /app

# Our database seed
COPY aiostreams.dump /app/aiostreams.dump

# Our startup wrapper
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/node", "/app/scripts/healthcheck.js"]

EXPOSE ${PORT:-3000}

ENTRYPOINT ["/entrypoint.sh"]