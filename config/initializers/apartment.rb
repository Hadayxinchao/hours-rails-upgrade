Apartment.configure do |config|
  config.excluded_models = %w[Account SlackWorkspace]
  config.tenant_names = -> { Account.pluck(:subdomain) }
end
