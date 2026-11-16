ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
# concurrent-ruby >= 1.3.5 no longer loads Logger; Rails < 7.1 expects it.
require "logger"
