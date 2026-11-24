# Publishes an event to every active endpoint subscribed to it. The payload is
# built now (a deleted entry can't be loaded later), with one id per event
# that stays the same across retries so receivers can de-duplicate.
module WebhookEvents
  module_function

  def publish(event, data)
    endpoints = WebhookEndpoint.for_event(event).pluck(:id)
    return if endpoints.empty?

    payload = { id: SecureRandom.uuid, event: event, created_at: Time.current.iso8601, data: data }.to_json
    endpoints.each { |endpoint_id| WebhookDeliveryJob.perform_later(endpoint_id, event, payload) }
  end

  def invoice(invoice)
    { id: invoice.id, number: invoice.number, status: invoice.status, client_id: invoice.client_id,
      currency: invoice.currency, total: Money.to_input(invoice.total_cents, invoice.currency),
      issued_on: invoice.issued_on.iso8601, due_on: invoice.due_on.iso8601 }
  end
end
