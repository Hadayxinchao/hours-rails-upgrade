# Connects a Slack user to the signed-in Hours user, from the one-time link
# /hours sends. The link is signed, expires after 15 minutes and is only
# valid on the account the Slack workspace is connected to.
class SlackLinksController < ApplicationController
  before_action :load_code

  def show; end

  def create
    current_user.update!(slack_user_id: @slack_user_id)
    redirect_to root_path, notice: t("slack.linked")
  end

  private

  def load_code
    data = Rails.application.message_verifier(:slack_link).verified(params[:code].to_s, purpose: :slack_link)
    workspace = data && SlackWorkspace.find_by(team_id: data["team_id"])
    unless workspace && workspace.subdomain == Apartment::Tenant.current
      return redirect_to(root_path, alert: t("slack.invalid_link"))
    end

    @slack_user_id = data["user_id"]
  end
end
