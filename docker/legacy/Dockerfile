# Frozen "before" environment: Ruby 2.4 / Rails 5.0, as the app shipped in 2020.
FROM ruby:2.4.2

# Debian jessie is archived: point apt at archive.debian.org and accept its expired keys.
RUN echo "deb http://archive.debian.org/debian jessie main" > /etc/apt/sources.list \
  && apt-get -o Acquire::Check-Valid-Until=false update -yqq \
  && apt-get install -yqq --allow-unauthenticated --no-install-recommends postgresql-client nodejs shared-mime-info \
  && rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v 1.16.6 --no-document
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle _1.16.6_ install --jobs 4 --retry 3
COPY . .
RUN cp -n config/database.yml.example config/database.yml && cp -n .sample.env .env
