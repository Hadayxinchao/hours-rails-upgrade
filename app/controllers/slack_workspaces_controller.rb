class SlackWorkspacesController < ApplicationController
  include OwnerOnly

  before_action(only: :create) { redirect_to integrations_path, alert: t("demo.disabled") if Hours.demo_mode? }

  def create
    workspace = SlackWorkspace.find_or_initialize_by(subdomain: Apartment::Tenant.current)
    workspace.team_id = params.dig(:slack_workspace, :team_id).to_s.strip.upcase
    if workspace.save
      redirect_to integrations_path, notice: t("integrations.slack.connected")
    else
      redirect_to integrations_path, alert: workspace.errors.full_messages.to_sentence
    end
  end

  def destroy
    SlackWorkspace.where(subdomain: Apartment::Tenant.current).delete_all
    redirect_to integrations_path, notice: t("integrations.slack.disconnected")
  end
end
