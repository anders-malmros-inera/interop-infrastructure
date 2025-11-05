FROM node:18.20.1-slim AS builder

# Install production dependencies in a builder stage for deterministic, cached installs
WORKDIR /src/admin-web
COPY admin-web/package.json admin-web/package-lock.json* ./
RUN npm ci --only=production

FROM node:18.20.1-slim

# Create runtime workspace
WORKDIR /workspace

# Copy production node_modules from builder
COPY --from=builder /src/admin-web/node_modules ./admin-web/node_modules

# Copy only the runtime files for admin-web (server, public assets, test runner)
COPY admin-web/server.js admin-web/test-runner.js admin-web/package.json ./admin-web/
COPY admin-web/public ./admin-web/public

# Copy repository README and component READMEs that the admin UI may render
COPY README.md ./
COPY perl-api/README.md ./perl-api/README.md
COPY java-api/README.md ./java-api/README.md
COPY perl-federation/README.md ./perl-federation/README.md
COPY openapi ./openapi
# Copy pre-rendered docs/images so admin-web can serve README-linked assets
COPY perl-api/docs ./perl-api/docs
COPY java-api/docs ./java-api/docs
COPY perl-federation/docs ./perl-federation/docs

EXPOSE 3000

WORKDIR /workspace/admin-web
# Create and use a non-root user for runtime
RUN useradd -m -u 1002 nodeuser || true
USER nodeuser

CMD ["node", "server.js"]
