FROM perl:5.36-slim
LABEL maintainer="interop"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/*

# Install cpanminus and Carton (Carton allows pinning via cpanfile.snapshot)
RUN cpanm --notest Carton || true

# Copy cpanfile and install dependencies: prefer pinned snapshot, otherwise install from cpanfile
COPY cpanfile /app/cpanfile
RUN if [ -f /app/cpanfile.snapshot ]; then \
      carton install --deployment --cached; \
    else \
      cpanm --notest --installdeps /app; \
    fi

WORKDIR /app
COPY . /app
ENV PLACK_ENV=production
EXPOSE 5001

# Run as non-root user
RUN useradd -m -u 1001 interop || true
USER interop

CMD ["plackup", "-s", "Starman", "-Ilib", "app.psgi", "-p", "5001"]
