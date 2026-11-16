# In-process request benchmark for the upgrade case study.
# Signs in as a seeded user and replays real page requests through the full
# Rack stack (routing, tenancy switch, Devise, controllers, views).
# Records latency, SQL queries and Ruby object allocations per page.
#
#   RAILS_ENV=production bin/rails runner script/benchmark/run.rb > result.json
#
# Same script on every Rails version → comparable "before" and "after" numbers.
require "json"

ITERATIONS = Integer(ENV.fetch("ITERATIONS", 30))
WARMUP = 3
HOST = "acme.hours.test".freeze

ActionController::Base.allow_forgery_protection = false
Rails.logger.level = Logger::WARN
ActiveRecord::Base.logger = nil

Apartment::Tenant.switch!("acme")
user = User.find_by!(email: "user1@acme.test")
project = Project.order(:id).first
client = Client.order(:id).first
tag = Tag.order(:id).first
Apartment::Tenant.reset

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! HOST
session.https!
session.post "/users/sign_in", params: { user: { email: "user1@acme.test", password: "benchmark-password" } }
raise "sign in failed: #{session.response.status}" unless session.response.status == 302

pages = {
  "Dashboard (projects + activity)" => "/",
  "Project detail" => "/projects/#{project.slug}",
  "Reports" => "/reports",
  "Reports CSV export (23k rows)" => "/reports.csv",
  "User entries" => "/users/#{user.slug}/entries",
  "Client detail" => "/clients/#{client.id}",
  "Team" => "/users",
  "Billables" => "/billables",
  "Tag detail" => "/tags/#{tag.slug}"
}

queries = 0
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  queries += 1 unless %w[SCHEMA CACHE].include?(payload[:name]) || payload[:cached]
end

def percentile(sorted, pct)
  sorted[((sorted.length - 1) * pct).round]
end

only = ENV["ONLY"] && Regexp.new(ENV["ONLY"], Regexp::IGNORECASE)
pages = pages.select { |label, _| label =~ only } if only

results = pages.map do |label, path|
  t_page = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  session.get(path)
  first_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_page) * 1000).round
  warn "#{label}: first request #{first_ms} ms"
  (WARMUP - 1).times { session.get(path) }
  status = session.response.status
  raise "#{path} returned #{status}" unless status == 200

  # Pages slower than 5s get fewer samples so a full run stays under ~10 minutes.
  iterations = first_ms > 5_000 ? 3 : ITERATIONS
  times = []
  query_counts = []
  allocs = []
  iterations.times do
    queries = 0
    a0 = GC.stat(:total_allocated_objects)
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    session.get(path)
    times << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000
    allocs << GC.stat(:total_allocated_objects) - a0
    query_counts << queries
  end
  sorted = times.sort
  {
    page: label, path: path, samples: iterations,
    p50_ms: percentile(sorted, 0.5).round(1),
    p95_ms: percentile(sorted, 0.95).round(1),
    queries: query_counts.max,
    allocations: allocs.sort[allocs.length / 2]
  }
end

rss_kb = File.read("/proc/self/status")[/VmRSS:\s+(\d+)/, 1].to_i

puts JSON.pretty_generate(
  ruby: RUBY_VERSION, rails: Rails.version, iterations: ITERATIONS,
  measured_at: Time.now.utc.iso8601, rss_mb: (rss_kb / 1024.0).round(1),
  pages: results
)
