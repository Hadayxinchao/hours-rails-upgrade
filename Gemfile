source "https://rubygems.org"

ruby "3.4.12"

gem "ros-apartment", "~> 3.1", require: "apartment"
gem "audited"
gem "csv" # no longer a default gem in Ruby 3.4; used for report exports
gem "aws-sdk-s3", require: false
gem "brakeman"
gem "solid_queue" # Active Job backend (Rails 8 default); replaces delayed_job
gem "solid_cache" # replaces memcached (dalli/memcachier)
gem "devise", "~> 5.0"
gem "devise_invitable", "~> 2.0" # 3.x moves invitations to a new table + changes semantics; see UPGRADE_LOG
gem "email_validator"
gem "flutie"
gem "haml-rails"
gem "haml", "~> 6.3" # 6.x is the Hamlit-based rewrite; several times faster than 5.x
gem "hashtel", "~> 0.0.2"
gem "high_voltage"
gem "holidays"
gem "http_accept_language"
gem "jquery-atwho-rails", "~> 1.3.2" # autocomplete
gem "jquery-rails", "~> 4.6"
gem "kaminari"
gem "momentjs-rails"
gem "normalize-rails"
gem "image_processing", "~> 1.12"
gem "pg"
gem "pikaday-gem", "~> 1.2.0.0"
gem "rack-timeout"
gem "rails", "~> 8.1.0"
gem "recipient_interceptor"
gem "redcarpet"
gem "dartsass-sprockets" # Dart Sass in Sprockets; replaces sass-rails / Ruby Sass
gem "select2-rails"
gem "simple_form"
gem "sprockets-rails", "~>3.0"
gem "sprockets", "~> 4.4" # 3.x cannot read its manifest with json 3
gem "title"
gem "twitter-text" # hashtag parsing
gem "terser"
gem "puma", "~> 7.2"

source "https://rails-assets.org" do
  gem "rails-assets-chartjs", "~> 4.5.1" # Chart.js 1.x API; replaced in the Rails 7 hop
end

# caching

group :development do
  gem "better_errors"
  gem "binding_of_caller"
  gem "foreman"
  gem "pry"
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
