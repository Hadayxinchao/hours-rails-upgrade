require Rails.root.join("config/initializers/smtp")
Hours::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like nginx, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable Rails's static asset server (Apache or nginx will already do this).
  config.public_file_server.enabled = true

  # Enable deflate / gzip compression of controller-generated responses
  config.middleware.use Rack::Deflater

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :terser
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = true

  # Generate digests for assets URLs.
  config.assets.digest = true

  # Version of your assets, change this if you want to expire all your assets.
  config.assets.version = "1.0"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # TLS is normally terminated by the load balancer; FORCE_SSL=false for local runs.
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  # Behind a TLS-terminating proxy that talks plain HTTP to Puma (for example
  # Cloudflare Tunnel), treat requests as HTTPS so force_ssl does not loop and
  # cookies stay secure.
  config.assume_ssl = ENV["ASSUME_SSL"] == "true"

  # Accounts live on subdomains. 1 = acme.example.com; 2 = acme.hours.example.com.
  config.action_dispatch.tld_length = Integer(ENV.fetch("TLD_LENGTH", "1"))

  # Set to :debug to see everything in the log.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Log to STDOUT (containers / Heroku); replaces the rails_12factor gem.
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Solid Cache (database-backed, config/cache.yml) replaces memcached.
  config.cache_store = :solid_cache_store
  config.action_controller.perform_caching = ENV["PERFORM_CACHING"].present?

  # Background jobs (mail delivery) run on Solid Queue: `bin/jobs`, or inside
  # Puma with SOLID_QUEUE_IN_PUMA=1.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets.
  # application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
  # config.assets.precompile += %w( search.js )

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = SMTP_SETTINGS
  # Links in emails (invitations, password resets) use https when the site does.
  config.action_mailer.default_url_options = {
    host: SMTP_SETTINGS[:domain],
    protocol: ENV.fetch("FORCE_SSL", "true") == "true" ? "https" : "http"
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Disable automatic flushing of the log to improve performance.
  # config.autoflush_log = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Uploaded files (client logos) on S3; see config/storage.yml.
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "amazon").to_sym

  # Keep the public demo out of search results.
  config.action_dispatch.default_headers["X-Robots-Tag"] = "noindex, nofollow" if ENV["DEMO_MODE"] == "true"
end
