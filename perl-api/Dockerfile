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

# If a cpanfile.snapshot is provided it will be used by Carton to install pinned versions.
# Otherwise install dependencies listed in cpanfile via cpanm.
COPY cpanfile /app/cpanfile
RUN if [ -f /app/cpanfile.snapshot ]; then \
      carton install --deployment --cached; \
    else \
      cpanm --notest --installdeps /app; \
    fi

WORKDIR /app
COPY . /app
ENV PLACK_ENV=production
EXPOSE 5000

# Create a non-root user for running the service
RUN useradd -m -u 1000 interop || true
USER interop

CMD ["plackup", "-s", "Starman", "-Ilib", "app.psgi", "-p", "5000"]
