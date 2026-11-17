# Case study: Rescuing a legacy Rails 5.0 app → Rails 8

**App:** [DefactoSoftware/Hours](https://github.com/DefactoSoftware/Hours), a multi-tenant time-tracking SaaS (MIT, ~1k ★).
Last commit: 2020-06-06. Archived and unmaintained.

**Why this app:** it looks like a typical Upwork client's codebase: a real business app (accounts, subdomains, clients, projects, hours, mileage, reports, CSV export, invitations), small enough to finish (~1.3k LOC Ruby, 28 models, 50 specs) and full of dead dependencies.

---

## 1. Baseline (static, measured 2026-11-16)

| Metric | Before |
|---|---|
| Ruby / Rails | 2.4.2 (EOL 2020) / 5.0.7.2 (EOL 2018) |
| Known gem vulnerabilities (bundler-audit) | **167 advisories in 26 gems** (4 critical, 43 high, 59 medium) |
| Brakeman warnings | 8 (2 high, 4 medium, 2 weak): SQLi ×3, RCE ×1, XSS ×1, CSRF ×1 |
| Locked gems | 290 |
| App Ruby LOC / spec LOC | 1,348 / 2,220 |
| Views | 73 (HAML) + 7 CoffeeScript files |
| CI | Travis CI (dead for OSS) |

Raw reports: [`baseline/bundle-audit.txt`](baseline/bundle-audit.txt), [`baseline/brakeman.json`](baseline/brakeman.json).

**Runtime baseline (still to capture, needs Docker with `ruby:2.4.2`):**
- Test suite: pass/fail count, duration, SimpleCov coverage
- Boot time (`rails runner 'nil'`)
- Response time p50/p95 for 5 key pages with seeded data (1 account, 20 users, 50 projects, 20k hour entries)
- N+1 queries per page (Bullet) and SQL query count per request
- Memory (RSS) after 500 requests, Docker image size

## 2. Dead/unmaintained dependencies → replacement

| Legacy | Problem | Replacement |
|---|---|---|
| `paperclip` 6.1 | Deprecated in 2018 | Active Storage + data migration script |
| `apartment` 2.2 (schema-per-tenant) | Unmaintained | `ros-apartment` (maintained fork). Fallback: row-level `acts_as_tenant` *(decision point, see §5)* |
| `Capybara.javascript_driver = :webkit` | Configured but the gem is not installed and no spec uses `js: true` | Remove; add Cuprite only if JS feature specs are added |
| `mimemagic` 0.3.2 | **Yanked from RubyGems (2021): `bundle install` fails on a fresh machine** | Bumped to 0.3.10 in hop 0 (needs `shared-mime-info`); removed with Paperclip later |
| `newrelic_rpm` 3.9 (2014) | **Crashes production boot on Rails 5.0** ("detected unsupported rails version") | Current `newrelic_rpm`, or drop it |
| `EntryQuery::Scopes.set` | Module-level mutable state: race condition under a threaded server | Pass entry type per query instead of via a global (blocks the Unicorn → Puma move) |
| `factory_girl_rails` | Renamed in 2017 | `factory_bot_rails` |
| `coffee-rails`, `uglifier`, `jquery-rails`, `rails-assets-chartjs` | Legacy asset pipeline | ~~Propshaft + importmap~~ **Done differently:** kept Sprockets (still supported on Rails 8); CoffeeScript → plain JS, Uglifier → Terser. See UPGRADE_LOG hop 4 |
| `sass-rails`, `bourbon`/`neat`/`bitters` | Deprecated libsass | **Done:** `dartsass-sprockets`, Bourbon/Neat SCSS vendored (UI unchanged) |
| `delayed_job_active_record` | Still works, but not the Rails 8 default | Solid Queue |
| `dalli` + `memcachier` | Extra infrastructure | Solid Cache (Postgres-backed) |
| `unicorn` | Not thread-aware | Puma |
| `aws-sdk` (v2 monolith) | Huge, old | `aws-sdk-s3` |
| `shoulda-matchers` 2.7, `rspec-rails` 3.8 | Incompatible with modern Rails | Current versions |
| `rails_12factor` | Obsolete since Rails 5 | Remove |
| Travis CI | Not usable | GitHub Actions (lint, Brakeman, bundler-audit, tests) |

## 3. Upgrade path (one hop at a time, green tests each step)

Every hop: bump → `rails app:update` → fix deprecations → tests green → commit with a tag (`hop/5.1`, …).

| Hop | Ruby | Key work |
|---|---|---|
| 0. Stabilize | 2.4 | Run in Docker, replace capybara-webkit, get suite green, add Bullet + SimpleCov, record runtime baseline |
| 5.0 → 5.1 → 5.2 | 2.4 → 2.6 | `belongs_to` required by default, `credentials.yml.enc`, factory_bot |
| 5.2 → 6.0 | 2.7 | Zeitwerk autoloader, Paperclip → Active Storage |
| 6.0 → 6.1 | 2.7 → 3.0 | Ruby 3 kwargs fixes, apartment → ros-apartment |
| 6.1 → 7.0 | 3.1 | Drop Sprockets/CoffeeScript → importmap + Propshaft, Turbo |
| 7.0 → 7.1 → 7.2 | 3.3 | `config.load_defaults` stepping, Puma, Dockerfile generator |
| 7.2 → 8.0 → 8.1 | 3.4 | Solid Queue/Cache, Rails 8 auth/Kamal-ready Dockerfile, `load_defaults 8.1` |

Then a **performance pass**: fix N+1s found by Bullet (reports, entries list), add missing indexes, cache the reports page.

## 4. "After" metrics to publish (same scenarios as baseline)

- Vulnerabilities: 167 → target **0**
- Brakeman: 8 → target **0**
- Test suite: green on CI, coverage %, duration
- p95 response time on reports/entries pages, query count per request
- Gem count, Docker image size, boot time, memory

## 5. Open decisions

1. **Multi-tenancy:** keep schema-per-tenant (`ros-apartment`, smallest diff) or move to row-level (`acts_as_tenant`, more work, simpler ops). Recommendation: keep `ros-apartment` if it supports Rails 8.1 at that point; otherwise switch, and the switch becomes a section of the case study.
2. **Front-end:** keep HAML views and add Stimulus only where CoffeeScript existed (recommended), not a redesign.
3. **Demo deployment:** host the upgraded app with a public demo login. It can reuse the AWS deploy kit (portfolio project #2).

## 6. Deliverables for Upwork

- Public repo with the hop-by-hop commit history and tags
- `CASE_STUDY.md` + blog post on portfolio.hadayxinchao.com (Problem → Approach → Results table)
- Before/after screenshots and a 2-min Loom walkthrough
- Upwork Project Catalog offer: *"Upgrade your Rails app to Rails 8 — audit + upgrade plan"*
