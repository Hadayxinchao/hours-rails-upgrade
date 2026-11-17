require File.expand_path("boot", __dir__)

# Pick the frameworks you want:
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_storage/engine"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Hours
  class Application < Rails::Application
    require "hours"
    require "time_series_initializer"

    config.active_record.default_timezone = :utc
    # 6.1 cache format is removed in Rails 7.2; existing cache entries are
    # simply recomputed after deploy.
    config.active_support.cache_format_version = 7.1

    # Rails 5.2.8.1+ (CVE-2022-32224) safe-loads YAML columns. `audited`
    # stores changes as YAML, so allow the value types it writes.
    config.active_record.yaml_column_permitted_classes = [
      Date, Time, Symbol, BigDecimal,
      ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
      ActiveSupport::HashWithIndifferentAccess
    ]

    config.generators do |generate|
      generate.helper false
      generate.javascript_engine false
      generate.request_specs false
      generate.routing_specs false
      generate.stylesheets false
      generate.test_framework :rspec
      generate.view_specs false
    end

    config.after_initialize do |app|
      app.config.paths.add "app/presenters", eager_load: true
    end

    # config.autoload_paths += Dir[Rails.root.join('app', 'models', '{**/}')]

    # Settings in config/environments/* take precedence
    # over those specified here. Application configuration should
    # go into files in config/initializers -- all .rb files in
    # that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make
    # Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding
    # time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # Don't force available locales, i.e. in case an unsupported locale is passed
    # just silently switch to the default language (:en) instead of throwing
    # an error.
    I18n.config.enforce_available_locales = false
    I18n.config.available_locales = %i[en nl pt-BR pl]

    # The default locale is :en and all translations
    # from config/locales/*.rb,yml are auto loaded
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales',
    #                                              '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
  end
end
