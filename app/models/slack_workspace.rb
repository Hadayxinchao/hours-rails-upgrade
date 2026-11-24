# Maps a Slack workspace (team) to the Hours account it logs time into.
# Public schema (Apartment excluded model): Slack requests arrive on one URL
# with no subdomain, so this is how the account is found.
class SlackWorkspace < ApplicationRecord
  validates :team_id, presence: true, uniqueness: true, format: { with: /\AT[A-Z0-9]{6,}\z/ }
  validates :subdomain, presence: true, uniqueness: true
end
