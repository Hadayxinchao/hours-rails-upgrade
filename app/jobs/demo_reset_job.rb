# Rebuilds the public demo account every night (see config/recurring.yml).
class DemoResetJob < ApplicationJob
  def perform
    DemoAccount.reset! if Hours.demo_mode?
  end
end
