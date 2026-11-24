require "json"
require "fileutils"

module HoursCLI
  # Account URL and token. Precedence: --url/--token flags, then HOURS_URL /
  # HOURS_TOKEN, then the config file written by `hours login`
  # ($XDG_CONFIG_HOME/hours/config.json, readable by the owner only, like gh).
  class Config
    attr_reader :url, :token, :path

    def self.default_path(env = ENV)
      base = env["XDG_CONFIG_HOME"].to_s.empty? ? File.join(Dir.home, ".config") : env["XDG_CONFIG_HOME"]
      File.join(base, "hours", "config.json")
    end

    def initialize(path: self.class.default_path, env: ENV, url: nil, token: nil)
      @path = path
      saved = File.exist?(path) ? JSON.parse(File.read(path)) : {}
      @url = presence(url) || presence(env["HOURS_URL"]) || saved["url"]
      @token = presence(token) || presence(env["HOURS_TOKEN"]) || saved["token"]
    end

    def save(url:, token:)
      FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
      File.write(path, JSON.pretty_generate("url" => url, "token" => token))
      File.chmod(0o600, path)
    end

    def delete
      File.delete(path) if File.exist?(path)
    end

    def require!
      raise ConfigError, "Not logged in. Run: hours login --url https://ACCOUNT.example.com --token hrs_..." unless url && token
    end

    private

    def presence(value)
      value.to_s.strip.empty? ? nil : value.to_s.strip
    end
  end
end
