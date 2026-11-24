require_relative "lib/hours_cli/version"

Gem::Specification.new do |spec|
  spec.name = "hours-cli"
  spec.version = HoursCLI::VERSION
  spec.summary = "Command-line client for the Hours time-tracking API"
  spec.description = "Log time, run timers and report from the terminal, using a personal API token."
  spec.authors = ["Bui Hoang Ha"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/Hadayxinchao/hours-rails-upgrade/tree/main/cli"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["hours"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
