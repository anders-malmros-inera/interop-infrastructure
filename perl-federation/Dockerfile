FROM perl:5.36-slim
LABEL maintainer="interop"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/*

# Install cpanminus and required Perl modules
RUN cpanm --notest Dancer2 DBI DBD::Pg JSON::MaybeXS Try::Tiny Plack Starman Time::Piece UUID::Tiny

WORKDIR /app
COPY . /app

ENV PLACK_ENV=production
EXPOSE 5001

CMD ["plackup", "-s", "Starman", "-Ilib", "app.psgi", "-p", "5001"]
