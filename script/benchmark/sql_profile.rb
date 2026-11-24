# Groups the SQL one request runs (including query-cache hits, which the
# benchmark leaves out) to find N+1 patterns. Uses the benchmark seed data.
#
#   RAILS_ENV=production bin/rails runner script/benchmark/sql_profile.rb /billables /reports.csv
require "benchmark"

ActionController::Base.allow_forgery_protection = false
Rails.logger.level = Logger::WARN

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! "acme.hours.test"
session.https!
session.post "/users/sign_in", params: { user: { email: "user1@acme.test", password: "benchmark-password" } }
raise "sign in failed (#{session.response.status})" unless session.response.status == 302

def normalize(sql)
  sql.gsub(/\$\d+|\b\d+\b|'[^']*'/, "?").gsub(/\s+/, " ").strip
end

paths = ARGV.presence || ["/"]
paths.each do |path|
  session.get(path) # warm up
  counts = Hash.new { |h, k| h[k] = { total: 0, cached: 0, ms: 0.0 } }
  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
    next if payload[:name] == "SCHEMA"

    entry = counts[normalize(payload[:sql])]
    entry[:total] += 1
    entry[:cached] += 1 if payload[:cached]
    entry[:ms] += (finish - start) * 1000
  end
  a0 = GC.stat(:total_allocated_objects)
  wall = Benchmark.realtime { session.get(path) } * 1000
  allocs = GC.stat(:total_allocated_objects) - a0
  ActiveSupport::Notifications.unsubscribe(sub)

  total = counts.values.sum { |c| c[:total] }
  cached = counts.values.sum { |c| c[:cached] }
  sql_ms = counts.values.sum { |c| c[:ms] }
  puts "== #{path}  status=#{session.response.status}  #{wall.round} ms  " \
       "sql=#{total} (#{cached} cached, #{sql_ms.round} ms)  allocations=#{allocs}"
  counts.sort_by { |_, c| -c[:total] }.first(8).each do |sql, c|
    puts format("  %6d x (%5d cached) %7.1f ms  %s", c[:total], c[:cached], c[:ms], sql[0, 150])
  end
end
