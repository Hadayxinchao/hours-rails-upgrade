# Builds the account behind the public demo (DEMO_MODE=true): a small agency
# with a few months of realistic, current-looking time and mileage entries.
#
#   DemoAccount.reset!          # drop and rebuild (nightly job, rake demo:reset)
#   DemoAccount.seed_if_missing # first boot (rake demo:seed)
class DemoAccount
  SUBDOMAIN = ENV.fetch("DEMO_SUBDOMAIN", "hoursdemo").freeze
  EMAIL = "demo@example.com".freeze
  PASSWORD = "hours-demo".freeze
  DAYS = 120

  PEOPLE = [
    ["Demo", "User"], ["Linh", "Tran"], ["Sam", "Becker"], ["Maya", "Patel"], ["Tom", "de Vries"], ["Ana", "Costa"]
  ].freeze
  # name => [description, currency]
  CLIENTS = {
    "Northwind Traders" => ["Wholesale food distributor", "USD"],
    "Blue Harbor Studio" => ["Architecture and interior design", "EUR"],
    "Greenleaf Health" => ["Network of physiotherapy clinics", "USD"],
    "Atlas Logistics" => ["Regional freight and warehousing", "GBP"]
  }.freeze
  # [name, client, budget (hours), billable, hourly rate, rate per km]
  PROJECTS = [
    ["Webshop relaunch", "Northwind Traders", 600, true, "95", "0.65"],
    ["Order API", "Northwind Traders", 500, true, "110", "0.65"],
    ["Portfolio site", "Blue Harbor Studio", 300, true, "85", "0.30"],
    ["Booking app", "Greenleaf Health", 650, true, "100", "0.65"],
    ["Patient portal discovery", "Greenleaf Health", 450, false, nil, nil],
    ["Fleet dashboard", "Atlas Logistics", 550, true, "90", "0.45"],
    ["Internal tooling", nil, 400, false, nil, nil]
  ].freeze
  CATEGORIES = ["Development", "Design", "Meetings", "Project management", "Testing", "Support"].freeze
  TAGS = %w[frontend backend bugfix research deploy clientcall].freeze
  TASKS = ["Sprint planning", "Code review", "Checkout flow", "Search filters", "Accessibility fixes",
           "Performance tuning", "Wireframes", "Release", "Stakeholder demo", "Data import"].freeze

  def self.reset!
    new.reset!
  end

  def self.seed_if_missing
    return false if Apartment::Tenant.switch("public") { Account.exists?(subdomain: SUBDOMAIN) }

    reset!
    true
  end

  def reset!
    @random = Random.new(2026)
    Apartment::Tenant.switch("public") do
      Account.where(subdomain: SUBDOMAIN).delete_all
      drop_tenant
      Apartment::Tenant.create(SUBDOMAIN)
      owner = Apartment::Tenant.switch(SUBDOMAIN) { build_data }
      Account.create!(subdomain: SUBDOMAIN, owner: owner)
    end
  end

  private

  attr_reader :random

  # Check first: a failed DROP SCHEMA would abort a surrounding transaction.
  def drop_tenant
    Apartment::Tenant.drop(SUBDOMAIN) if ActiveRecord::Base.connection.schema_exists?(SUBDOMAIN)
  end

  def build_data
    users = PEOPLE.each_with_index.map do |(first, last), i|
      email = i.zero? ? EMAIL : "#{first.downcase}@example.com"
      User.new(first_name: first, last_name: last, email: email, password: PASSWORD,
               password_confirmation: PASSWORD).tap do |user|
        user.skip_confirmation!
        user.save!
      end
    end
    clients = CLIENTS.to_h do |name, (description, currency)|
      [name, Client.create!(name: name, description: description, currency: currency)]
    end
    projects = PROJECTS.map do |name, client, budget, billable, hourly_rate, mileage_rate|
      Project.create!(name: name, client: clients[client], budget: budget, billable: billable,
                      hourly_rate: hourly_rate, mileage_rate: mileage_rate,
                      description: "#{name} for #{client || 'our own team'}.")
    end
    categories = CATEGORIES.map { |name| Category.create!(name: name) }
    tags = TAGS.map { |name| Tag.create!(name: name) }
    insert_entries(users, projects, categories, tags)
    create_invoices(clients.values)
    users.first
  end

  def insert_entries(users, projects, categories, tags)
    hours = []
    taggings = []
    workdays.each do |date|
      users.each do |user|
        random.rand(1..3).times do
          tag = tags.sample(random: random) if random.rand < 0.35
          hours << { project_id: projects.sample(random: random).id,
                     category_id: categories.sample(random: random).id,
                     user_id: user.id, value: random.rand(1..4), date: date,
                     description: [TASKS.sample(random: random), tag && "##{tag.name}"].compact.join(" "),
                     billed: billed?(date), **logged_at(date) }
          taggings << [tag.id, hours.size] if tag
        end
      end
    end
    ids = Hour.insert_all!(hours, returning: :id).rows.flatten
    Tagging.insert_all!(taggings.map { |tag_id, n| { tag_id: tag_id, hour_id: ids[n - 1] } }) if taggings.any?

    mileages = workdays.select { random.rand < 0.15 }.map do |date|
      { project_id: projects.sample(random: random).id, user_id: users.sample(random: random).id,
        value: random.rand(8..90), date: date, billed: billed?(date), **logged_at(date) }
    end
    Mileage.insert_all!(mileages) if mileages.any?
  end

  def workdays
    @workdays ||= ((Date.current - DAYS)..Date.current).reject { |date| date.saturday? || date.sunday? }
  end

  # Entries are logged at the end of the working day, so the activity feed
  # (ordered by created_at) shows the most recent work first.
  def logged_at(date)
    time = date.in_time_zone.change(hour: 16) + random.rand(0..120).minutes
    time = [time, Time.current].min
    { created_at: time, updated_at: time }
  end

  # Work from before the invoicing feature counts as billed elsewhere; the last
  # three months are invoiced below or still waiting on Billables.
  def billed?(date)
    date < Date.current - 90
  end

  # Per client: a paid invoice for 3–2 months ago and a sent one for 2–1
  # months ago (overdue for some), so the Invoices page shows every status.
  def create_invoices(clients)
    clients.each_with_index do |client, i|
      [[90, 60, :paid], [60, 30, :sent]].each do |from, to, status|
        range = (Date.current - from)...(Date.current - to)
        scope = { project: client.projects.where(billable: true), date: range, billed: false }
        issued_on = range.end + 1
        invoice = InvoiceBuilder.new(client, hour_ids: Hour.where(scope).ids, mileage_ids: Mileage.where(scope).ids,
                                             issued_on: issued_on, due_in_days: [14, 30, 45, 21][i],
                                             tax_rate: client.currency == "USD" ? 0 : 20).call.invoice
        next unless invoice

        invoice.mark_sent!
        invoice.update!(sent_at: issued_on.in_time_zone.change(hour: 10))
        invoice.mark_paid! if status == :paid
      end
    end
  end
end
