source "https://rubygems.org"

ruby "3.3.10"

gem "ros-apartment", "~> 3.1", require: "apartment"
gem "audited"
gem "aws-sdk-s3", require: false
gem "brakeman"
gem "delayed_job_active_record"
gem "devise", "~> 5.0"
gem "devise_invitable"
gem "email_validator"
gem "flutie"
gem "haml-rails"
gem "hashtel", "~> 0.0.2"
gem "high_voltage"
gem "holidays"
gem "http_accept_language"
gem "jquery-atwho-rails", "~> 1.3.2" # autocomplete
gem "jquery-rails", "~> 4.6"
# json 3 removed the quirks_mode option that ActiveSupport (<= 7.2) passes; re-test on Rails 8.
gem "json", "~> 2.10"
gem "kaminari"
gem "momentjs-rails"
gem "normalize-rails"
gem "image_processing", "~> 1.12"
gem "pg"
gem "pikaday-gem", "~> 1.2.0.0"
gem "rack-timeout"
gem "rails", "~> 7.2.0"
gem "recipient_interceptor"
gem "redcarpet"
gem "dartsass-sprockets" # Dart Sass in Sprockets; replaces sass-rails / Ruby Sass
gem "select2-rails"
gem "simple_form"
gem "sprockets-rails", "~>3.0"
# Sprockets 4 needs a manifest.js rewrite; the asset pipeline moves to Propshaft in the Rails 7 hop.
gem "sprockets", "< 4"
gem "title"
gem "twitter-text" # hashtag parsing
gem "terser"
gem "puma", "~> 7.2"

source "https://rails-assets.org" do
  gem "rails-assets-chartjs", "~> 1.0.1" # Chart.js 1.x API; replaced in the Rails 7 hop
end

# caching

gem "dalli" # memcached
# connection_pool 3 takes keyword args; Rails <= 7.2 MemCacheStore passes a hash
# (ArgumentError the moment the cache is used). Re-test on Rails 8.
gem "connection_pool", "~> 2.5"
gem "memcachier"

group :development do
  gem "better_errors"
  gem "binding_of_caller"
  gem "foreman"
  gem "pry"
  gem "spring"
  gem "spring-commands-rspec"
end

group :development, :test do
  gem "annotate"
  gem "dotenv-rails"
  gem "email_spec"
  gem "factory_bot_rails"
  gem "letter_opener"
  gem "pry-rails"
  gem "rspec-rails", "~> 7.1"
end

group :test do
  gem "capybara"
  gem "database_cleaner"
  gem "launchy"
  gem "shoulda-matchers", "~> 5.3"
  gem "simplecov", require: false
  gem "timecop"
  gem "webmock"
end
