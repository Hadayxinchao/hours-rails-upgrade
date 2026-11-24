require "net/http"

# POSTs one signed event to one endpoint. Tenant-aware (ApplicationJob), so it
# reads the endpoint and its secret from the right account.
class WebhookDeliveryJob < ApplicationJob
  class Failed < StandardError; end

  TIMEOUT = 5
  queue_as :default
  retry_on Failed, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(endpoint_id, event, payload)
    endpoint = WebhookEndpoint.find(endpoint_id) # deleted endpoint: discarded, not retried
    attempt(endpoint, event, payload) if endpoint.active?
  end

  def self.signature(secret, timestamp, body)
    "t=#{timestamp},v1=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}")}"
  end

  private

  def attempt(endpoint, event, payload)
    status = deliver(endpoint, event, payload)
    endpoint.record_delivery(status: status)
    return if status.between?(200, 299)
    # 4xx other than 408/429 means the receiver rejected it; retrying won't help.
    raise Failed, "HTTP #{status}" if status >= 500 || [408, 429].include?(status)
  rescue WebhookUrlGuard::Blocked => error
    endpoint.record_delivery(error: "URL #{error.message}") # not retried: it won't get better
  rescue Failed
    raise
  rescue StandardError => error # timeouts, refused connections, TLS errors
    endpoint.record_delivery(error: "#{error.class}: #{error.message}")
    raise Failed, error.message
  end

  def deliver(endpoint, event, payload)
    uri, ip = WebhookUrlGuard.check!(endpoint.url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = ip # connect to the address that was checked, not a fresh lookup
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = http.read_timeout = http.write_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri.request_uri)
    timestamp = Time.current.to_i
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "Hours-Webhooks/1.0"
    request["Hours-Event"] = event
    request["Hours-Delivery"] = JSON.parse(payload)["id"]
    request["Hours-Signature"] = self.class.signature(endpoint.secret, timestamp, payload)
    request.body = payload
    http.request(request).code.to_i
  end
end
