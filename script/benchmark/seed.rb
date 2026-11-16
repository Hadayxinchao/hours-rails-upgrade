# Deterministic benchmark dataset for the upgrade case study.
# Written to run unchanged on every Rails version in the upgrade path (5.0 → 8.x).
#
#   bin/rails runner script/benchmark/seed.rb
#
# Tenant "acme": 20 users, 10 clients, 50 projects, 12 categories, 40 tags,
# 20,000 hour entries (30% tagged) and 3,000 mileage entries over 365 days.

SUBDOMAIN = "acme".freeze
srand(42)

conn = ActiveRecord::Base.connection
Apartment::Tenant.reset
begin
  Apartment::Tenant.drop(SUBDOMAIN)
rescue StandardError
  nil
end
Account.where(subdomain: SUBDOMAIN).delete_all
Apartment::Tenant.create(SUBDOMAIN)
Apartment::Tenant.switch!(SUBDOMAIN)

t0 = Time.now
password = "benchmark-password"
ActionMailer::Base.delivery_method = :test
users = (1..20).map do |i|
  user = User.new(first_name: "User#{i}", last_name: "Bench",
                  email: "user#{i}@acme.test",
                  password: password, password_confirmation: password)
  user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
  user.save!
  user
end
Apartment::Tenant.reset
Account.create!(subdomain: SUBDOMAIN, owner: users.first)
Apartment::Tenant.switch!(SUBDOMAIN)

clients = (1..10).map { |i| Client.create!(name: "Client #{i}", description: "Client #{i} description") }
projects = (1..50).map do |i|
  Project.create!(name: "Project #{i}", budget: 200 + i * 10,
                  client: clients[i % 10], billable: i.even?,
                  description: "Benchmark project #{i}")
end
categories = (1..12).map { |i| Category.create!(name: "Category #{i}") }
tags = (1..40).map { |i| Tag.create!(name: "tag#{i}") }

today = Date.new(2026, 11, 1) # fixed so every run produces identical data
now = conn.quote(Time.utc(2026, 11, 1))

rows = []
tagging_rows = []
20_000.times do |n|
  id = n + 1
  date = today - rand(365)
  tagged = rand < 0.3
  tag = tags.sample
  desc = tagged ? "Worked on ##{tag.name}" : "Worked on feature #{rand(1000)}"
  rows << "(#{id}, #{projects.sample.id}, #{categories.sample.id}, #{users.sample.id}, " \
          "#{rand(1..8)}, '#{date}', #{conn.quote(desc)}, #{rand < 0.2}, #{now}, #{now})"
  tagging_rows << "(#{tag.id}, #{id}, #{now}, #{now})" if tagged
end
rows.each_slice(2_000) do |slice|
  conn.execute("INSERT INTO hours (id, project_id, category_id, user_id, value, date, " \
               "description, billed, created_at, updated_at) VALUES #{slice.join(',')}")
end
tagging_rows.each_slice(2_000) do |slice|
  conn.execute("INSERT INTO taggings (tag_id, hour_id, created_at, updated_at) VALUES #{slice.join(',')}")
end
conn.execute("SELECT setval(pg_get_serial_sequence('hours', 'id'), (SELECT MAX(id) FROM hours))")

mileage_rows = (1..3_000).map do
  "(#{projects.sample.id}, #{users.sample.id}, #{rand(5..120)}, '#{today - rand(365)}', " \
  "#{rand < 0.2}, #{now}, #{now})"
end
mileage_rows.each_slice(1_000) do |slice|
  conn.execute("INSERT INTO mileages (project_id, user_id, value, date, billed, created_at, updated_at) " \
               "VALUES #{slice.join(',')}")
end
conn.execute("ANALYZE")

puts "Seeded tenant '#{SUBDOMAIN}': #{User.count} users, #{Project.count} projects, " \
     "#{Hour.count} hours, #{Mileage.count} mileages, #{conn.select_value('SELECT COUNT(*) FROM taggings')} " \
     "taggings in #{(Time.now - t0).round(1)}s"
