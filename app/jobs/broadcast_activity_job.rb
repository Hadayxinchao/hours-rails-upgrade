# Pushes a new hours entry to the activity feed of everyone in the same
# account who has the dashboard open.
#
# Rendering happens in a job, and jobs run outside the request. This one is
# an ApplicationJob, so TenantAwareJob runs it in the entry's account schema;
# Turbo's own broadcast_*_later job is a plain ActiveJob::Base and would load
# the entry (and its user and project) from the wrong schema.
class BroadcastActivityJob < ApplicationJob
  def perform(hour)
    Turbo::StreamsChannel.broadcast_prepend_to(
      self.class.stream(tenant), target: "activity-feed-list",
                                 partial: "application/entry", locals: { entry: hour }
    )
  end

  # The stream name includes the account, and Turbo signs it, so a browser
  # can only subscribe to the feed of the account it was rendered for.
  def self.stream(tenant)
    [tenant.presence || Apartment.default_tenant, "activity"]
  end
end
