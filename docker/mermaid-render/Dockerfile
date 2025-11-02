FROM node:18

# Install libraries needed by headless Chromium / Puppeteer
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    gconf-service \
    libasound2 \
    libatk1.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgcc1 \
    libgconf-2-4 \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    ca-certificates \
    fonts-liberation \
    libgbm1 \
    xdg-utils \
    wget \
    libxkbcommon0 \
    libxinerama1 \
    libdrm2 \
    libepoxy0 \
    libwayland-client0 \
    libwayland-egl1 \
    libwayland-cursor0 \
    libwayland-server0 \
  && rm -rf /var/lib/apt/lists/*

# Install mermaid-cli (includes puppeteer which will download Chromium)
RUN npm install -g @mermaid-js/mermaid-cli@8.14.0

WORKDIR /workspace

# Create a non-root user to run Chromium (Chromium doesn't like running as root without --no-sandbox)
RUN useradd -m mermaid \
  && mkdir -p /home/mermaid/.local-chromium \
  && chown -R mermaid:mermaid /home/mermaid /usr/local/lib/node_modules /usr/local/bin /workspace || true

USER mermaid
ENV HOME=/home/mermaid

# Provide mmdc as the container entrypoint so we can run it as:
# docker run --rm -v $(pwd):/workspace interop-mermaid -i diagram.mmd -o admin-web/public/diagram.svg
ENTRYPOINT ["mmdc"]
