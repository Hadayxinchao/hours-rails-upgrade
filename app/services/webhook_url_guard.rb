require "resolv"

# SSRF protection for user-supplied webhook URLs. Without it, anyone who can
# add a webhook can make the server POST to its own network: the database,
# Mailpit, internal admin pages, or the cloud metadata service at
# 169.254.169.254 (which hands out credentials).
#
# The host is resolved once and every address must be public. The delivery
# then connects to that checked IP (with the original Host header and TLS
# name), so a DNS answer that changes between check and connect
# ("DNS rebinding") can't redirect it.
module WebhookUrlGuard
  class Blocked < StandardError; end

  BLOCKED_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
    192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/3
    ::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 fc00::/7 fe80::/10 ff00::/8
  ].map { |cidr| IPAddr.new(cidr) }.freeze

  module_function

  # Returns [uri, ip]. Raises Blocked with a user-facing reason.
  def check!(url, resolve: true)
    uri = URI.parse(url.to_s.strip)
    raise Blocked, "must be an http(s) URL" unless uri.is_a?(URI::HTTP) && uri.host.present?
    raise Blocked, "must use https" if uri.scheme != "https" && !allow_private?
    raise Blocked, "must not contain a username or password" if uri.userinfo

    host = uri.hostname
    literal = ip_literal(host)
    raise Blocked, "points to a private or reserved address" if literal && blocked?(literal)
    return [uri, literal&.to_s] unless resolve

    addresses = literal ? [literal] : Resolv.getaddresses(host).map { |a| IPAddr.new(a) }
    raise Blocked, "host can't be resolved" if addresses.empty?
    raise Blocked, "points to a private or reserved address" if addresses.any? { |a| blocked?(a) }

    [uri, addresses.first.to_s]
  rescue URI::InvalidURIError, IPAddr::InvalidAddressError
    raise Blocked, "is not a valid URL"
  end

  def blocked?(ip)
    return false if allow_private?

    BLOCKED_RANGES.any? { |range| range.include?(ip) }
  end

  def ip_literal(host)
    IPAddr.new(host.delete_prefix("[").delete_suffix("]"))
  rescue IPAddr::InvalidAddressError
    nil
  end

  # Development only (e.g. a local test receiver); never in production.
  def allow_private?
    !Rails.env.production? && ENV["WEBHOOKS_ALLOW_PRIVATE"] == "1"
  end
end
