# syntax=docker/dockerfile:1
# Production image (Rails 8 style). Build:  docker build -t hours .
# Run:   docker compose up   (see docker-compose.yml)

ARG RUBY_VERSION=3.4.12
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails
RUN apt-get update -qq \
  && apt-get install --no-install-recommends -y curl imagemagick libjemalloc2 libpq5 postgresql-client shared-mime-info \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="1" \
    LD_PRELOAD="libjemalloc.so.2"

# --- build: gems + precompiled assets ------------------------------------
FROM base AS build

RUN apt-get update -qq \
  && apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev nodejs pkg-config \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v "$(tail -1 Gemfile.lock | tr -d ' ')" --no-document \
  && bundle install \
  && rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

# Precompile assets without real secrets or services (Terser needs Node here,
# not at runtime).
RUN SECRET_KEY_BASE_DUMMY=1 APARTMENT_DISABLE_INIT=1 SMTP_ADDRESS=x SMTP_DOMAIN=x SMTP_USERNAME=x SMTP_PASSWORD=x \
    S3_BUCKET_NAME=x AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=x DATABASE_URL=postgres://x@localhost/x \
    bundle exec rails assets:precompile \
  && rm -rf tmp/cache node_modules

# --- runtime ------------------------------------------------------------
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails \
  && useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash \
  && mkdir -p db log storage tmp \
  && chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
