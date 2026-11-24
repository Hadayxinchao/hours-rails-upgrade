# Slack slash command endpoint (POST /integrations/slack/commands).
#
# Slack calls one URL for every workspace, so this sits outside the subdomain
# routes. Trust comes from Slack's request signature (HMAC-SHA256 of
# "v0:<timestamp>:<raw body>" with the app's signing secret, at most 5 minutes
# old); the account comes from the team_id via SlackWorkspace; the Hours user
# from the Slack user id linked on the user.
class SlackCommandsController < ActionController::API
  MAX_AGE = 5.minutes

  before_action :verify_slack_signature

  def create
    workspace = SlackWorkspace.find_by(team_id: params[:team_id])
    return reply(I18n.t("slack.unknown_workspace")) unless workspace

    Apartment::Tenant.switch(workspace.subdomain) do
      user = User.find_by(slack_user_id: params[:user_id])
      return reply(I18n.t("slack.link_first", url: link_url(workspace))) unless user

      reply(SlackCommand.new(user, params[:text]).run)
    end
  end

  private

  def verify_slack_signature
    secret = ENV["SLACK_SIGNING_SECRET"].presence
    return head(:service_unavailable) unless secret

    timestamp = request.headers["X-Slack-Request-Timestamp"].to_i
    return head(:unauthorized) if (Time.current.to_i - timestamp).abs > MAX_AGE

    expected = "v0=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "v0:#{timestamp}:#{request.raw_post}")}"
    head(:unauthorized) unless ActiveSupport::SecurityUtils.secure_compare(expected, request.headers["X-Slack-Signature"].to_s)
  end

  def link_url(workspace)
    code = Rails.application.message_verifier(:slack_link)
                .generate({ "team_id" => workspace.team_id, "user_id" => params[:user_id] },
                          purpose: :slack_link, expires_in: 15.minutes)
    url_for(controller: "/slack_links", action: :show, code: code, subdomain: workspace.subdomain,
            host: request.host, protocol: request.protocol, port: request.port)
  end

  # Ephemeral: only the person who typed the command sees the answer.
  def reply(text)
    render json: { response_type: "ephemeral", text: text }
  end
end
