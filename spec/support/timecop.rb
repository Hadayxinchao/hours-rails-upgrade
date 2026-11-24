# Some specs freeze or scale time with Timecop and never undo it. Scaled time
# (600x) leaked into every later spec in the process and made time-sensitive
# specs (the API rate limit, whose counter expires after a minute) fail
# depending on test order.
RSpec.configure do |config|
  config.after { Timecop.return }
end
