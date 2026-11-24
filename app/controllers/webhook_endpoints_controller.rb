class WebhookEndpointsController < ApplicationController
  include OwnerOnly

  # In the public demo every visitor is the owner; don't let them make this
  # server POST to arbitrary URLs.
  before_action(only: %i[create ping]) { redirect_to integrations_path, alert: t("demo.disabled") if Hours.demo_mode? }

  def create
    endpoint = WebhookEndpoint.new(params.require(:webhook_endpoint).permit(:url, events: []))
    if endpoint.save
      redirect_to integrations_path, notice: t("integrations.webhooks.created")
    else
      redirect_to integrations_path, alert: endpoint.errors.full_messages.to_sentence
    end
  end

  def destroy
    WebhookEndpoint.find(params[:id]).destroy
    redirect_to integrations_path, notice: t("integrations.webhooks.deleted")
  end

  # Sends a "ping" event so the receiver can be checked from the UI.
  def ping
    endpoint = WebhookEndpoint.find(params[:id])
    endpoint.update!(active: true, consecutive_failures: 0)
    payload = { id: SecureRandom.uuid, event: "ping", created_at: Time.current.iso8601, data: {} }.to_json
    WebhookDeliveryJob.perform_later(endpoint.id, "ping", payload)
    redirect_to integrations_path, notice: t("integrations.webhooks.pinged")
  end
end
