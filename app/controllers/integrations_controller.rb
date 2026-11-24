class IntegrationsController < ApplicationController
  include OwnerOnly

  def show
    @endpoints = WebhookEndpoint.order(:created_at)
    @endpoint = WebhookEndpoint.new(events: WebhookEndpoint::EVENTS)
    @slack = SlackWorkspace.find_by(subdomain: Apartment::Tenant.current)
    @slack_command_url = "#{request.protocol}#{request.domain}#{request.port_string}/integrations/slack/commands"
  end
end
