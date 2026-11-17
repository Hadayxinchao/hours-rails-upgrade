# Feature specs exercise whole flows (sign-up, invitations), so jobs enqueued
# during them run inline. Unit specs keep the :test adapter's enqueue-only
# behaviour and can assert on enqueued jobs.
RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.around(:each, type: :feature) do |example|
    perform_enqueued_jobs { example.run }
  end
end
