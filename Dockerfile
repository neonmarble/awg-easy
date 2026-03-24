FROM --platform=$BUILDPLATFORM docker.io/library/node:24-alpine AS build_node_modules

# Build args automatically set by buildx
ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM

# Update npm to latest
RUN npm install -g npm@latest

# Copy Web UI
COPY src /app
WORKDIR /app
RUN npm ci --omit=dev &&\
    mv node_modules /node_modules

# Let buildx resolve the correct manifest per arch
FROM ghcr.io/vnxme/amneziawg-go:sha-f6a9566
HEALTHCHECK CMD /usr/bin/timeout 5s /bin/sh -c "/usr/bin/wg show | /bin/grep -q interface || exit 1" --interval=1m --timeout=5s --retries=3
COPY --from=build_node_modules /app /app
COPY --from=build_node_modules /node_modules /node_modules
COPY --from=build_node_modules /app/wgpw.sh /bin/wgpw
RUN chmod +x /bin/wgpw

# Install Linux packages
RUN apk add --no-cache \
    dpkg \
    dumb-init \
    iptables \
    nodejs \
    npm

# Use iptables-legacy
RUN apk add --no-cache iptables-legacy && \
    ln -sf /sbin/iptables-legacy /sbin/iptables && \
    ln -sf /sbin/iptables-legacy-restore /sbin/iptables-restore && \
    ln -sf /sbin/iptables-legacy-save /sbin/iptables-save

# Set Environment
ENV DEBUG=Server,WireGuard

# Override the base image's ENTRYPOINT so the Web UI actually runs
ENTRYPOINT []

# Run Web UI
WORKDIR /app
CMD ["/usr/bin/dumb-init", "node", "server.js"]
