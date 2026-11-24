namespace :demo do
  desc "Create the demo account if it does not exist (run on boot when DEMO_MODE=true)"
  task seed: :environment do
    puts DemoAccount.seed_if_missing ? "demo account '#{DemoAccount::SUBDOMAIN}' created" : "demo account present"
  end

  desc "Drop and rebuild the demo account"
  task reset: :environment do
    DemoAccount.reset!
    puts "demo account '#{DemoAccount::SUBDOMAIN}' reset"
  end
end
