# Baseline: Hours on Ruby 2.4.2 / Rails 5.0.7.2

Measured 2026-11-16 in Docker (`docker/legacy/`), Postgres 9.6, single process.
Reproduce: `cd docker/legacy && docker compose build app && docker compose run --rm bench`.

## Could it even run?

A fresh checkout of the 2020 code did **not** install or boot without intervention:

| Blocker | Symptom | Hop-0 fix |
|---|---|---|
| `mimemagic 0.3.2` yanked from RubyGems (2021) | `bundle install` fails | Bumped to 0.3.10 (+ `shared-mime-info` system package) |
| Debian jessie base image archived | `apt-get` fails, keys expired | Point apt at archive.debian.org |
| `newrelic_rpm 3.9` (2014) | Production boot crashes: *detected unsupported rails version 5.0.7.2* | Benchmark runs with `NEW_RELIC_FRAMEWORK=ruby`; replaced during the upgrade |

## Security

| Check | Result |
|---|---|
| bundler-audit | **167 advisories in 26 gems**: 4 critical, 43 high, 59 medium, 9 low, 52 unrated |
| Brakeman | 8 warnings: 2 high, 4 medium, 2 weak (SQL injection ×3, RCE ×1, XSS ×1, CSRF ×1) |

Raw: [`baseline/bundle-audit.txt`](baseline/bundle-audit.txt), [`baseline/brakeman.json`](baseline/brakeman.json)

## Test suite

| Metric | Result |
|---|---|
| Examples | **280, 0 failures** |
| Line coverage (SimpleCov) | **99.3%** (835 / 841) |
| Duration | 44 s |

A green, high-coverage suite is the safety net for the whole upgrade.

## Performance

Seed: tenant `acme`, 20 users, 50 projects, 20,000 hours, 3,000 mileages (`script/benchmark/seed.rb`).
Method: signed-in requests through the full Rack stack in production mode, 3 warm-ups, then 30 samples (3 for pages over 5 s) (`script/benchmark/run.rb`).
Process RSS after the run: **887 MB**.

| Page | p50 | p95 | SQL queries | Allocations |
|---|---:|---:|---:|---:|
| Reports CSV export (23k rows) | **34,657 ms** | 36,166 ms | 96 | 38.4 M |
| Billables | **2,793 ms** | 3,148 ms | 248 | 3.4 M |
| Dashboard (projects + activity) | 548 ms | 614 ms | 201 | 702 k |
| Client detail | 279 ms | 359 ms | 137 | 316 k |
| Project detail | 146 ms | 162 ms | 96 | 147 k |
| User entries | 136 ms | 201 ms | 85 | 110 k |
| Reports | 113 ms | 152 ms | 74 | 97 k |
| Tag detail | 89 ms | 120 ms | 78 | 51 k |
| Team | 8 ms | 13 ms | 4 | 8 k |

Raw: [`baseline/benchmark.json`](baseline/benchmark.json). SQL counts exclude query-cache hits.

### First observations (to confirm in the performance pass)

- **CSV export:** only 96 real SQL queries but 38 M object allocations. The per-row cost is in Ruby: lazy association loads served from the query cache, plus model `to_s` and `CSV` row building for 23k rows. Candidates: `includes(:user, :category, project: :client)`, pluck-based rows, streaming the response.
- **Billables:** `Project#has_billable_entries?` runs two `EXISTS` queries per project, then each row loads `hour.category` and `hour.user` (classic N+1).
- **Dashboard:** 201 queries for 7 projects + 30 activity rows → N+1 in the activity feed and the project cards.
- **Thread safety:** `EntryQuery::Scopes.set(entry_type)` keeps the entry type in module-level state. That is fine under Unicorn (one request per process) but a race condition under Puma, so it has to be fixed before the server switch.
