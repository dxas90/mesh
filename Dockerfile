# ---------- Base ----------
FROM node:24-alpine AS base

WORKDIR /app

ENV NODE_ENV=production \
    PORT=8080 \
    COREPACK_HOME=/app/.cache/corepack

ARG CI=false
ENV CI=${CI}

# Enable pnpm once
RUN corepack enable && corepack prepare pnpm@10 --activate

# ---------- Dependencies ----------
FROM base AS deps

# Copy only dependency descriptors
COPY package.json pnpm-lock.yaml* ./

# Install deps (cached if lockfile unchanged)
RUN pnpm install --frozen-lockfile

# ---------- Runtime ----------
FROM base AS production

# Copy node_modules from deps stage
COPY --from=deps /app/node_modules /app/node_modules
COPY --from=deps /app/package.json /app/package.json

# Copy application source last (least cache-friendly layer)
COPY . .

# Don't create .mesh directory - it will be mounted as emptyDir by k8s
# This avoids permission conflicts when mesh build tries to clean it
RUN chown -R node:node /app

# Switch to node user for security
USER node

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/graphql?query={health{status}}', (r) => {let body='';r.on('data',d=>body+=d);r.on('end',()=>process.exit(body.includes('healthy')?0:1))})"

CMD ["sh", "-c", "pnpm mesh build && pnpm mesh start"]
