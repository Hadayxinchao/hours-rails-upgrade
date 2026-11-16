# Current upgrade-target environment. RUBY_IMAGE moves forward with each hop.
ARG RUBY_IMAGE=ruby:3.3.10-bookworm
FROM ${RUBY_IMAGE}

# Older Debian bases (bullseye) moved security updates to archive.debian.org.
RUN [ ! -f /etc/apt/sources.list ] || sed -i -e 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' -e 's|deb.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list; \
  apt-get update -yqq \
  && apt-get install -yqq --no-install-recommends postgresql-client nodejs shared-mime-info imagemagick \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v "$(tail -1 Gemfile.lock | tr -d ' ')" --no-document \
  && bundle install --jobs 4 --retry 3
COPY . .
RUN cp -n config/database.yml.example config/database.yml && cp -n .sample.env .env
