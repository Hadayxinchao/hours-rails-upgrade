# Hours: Legacy Rails Rescue (Rails 5.0 → 8)

A documented, step-by-step upgrade of a real, abandoned Rails SaaS app: from **Ruby 2.4 / Rails 5.0 (both end-of-life)** to a current, secure, faster Rails 8 stack. Every step is measured, tested and tagged.

> Fork of [DefactoSoftware/Hours](https://github.com/DefactoSoftware/Hours) (MIT), a multi-tenant time-tracking app: accounts on subdomains, clients, projects, hours, mileage, reports, CSV export, billing and invitations. Last upstream commit: June 2020.
> The upgrade work, tooling and case study in this repository are by [Bui Hoang Ha](https://portfolio.hadayxinchao.com/).

[![CI](https://github.com/Hadayxinchao/hours-rails-upgrade/actions/workflows/ci.yml/badge.svg)](https://github.com/Hadayxinchao/hours-rails-upgrade/actions/workflows/ci.yml)

**Status:** ✅ Upgrade done, now on **Rails 8.1.4 / Ruby 3.4.12**. 🚧 Performance pass next (hop 6). See [Results](#results).

---

## The problem

This is what a typical "please upgrade our Rails app" client codebase looks like:

| | Before (measured) |
|---|---|
| Runtime | Ruby 2.4.2 (EOL 2020), Rails 5.0.7 (EOL 2018) |
| Known gem vulnerabilities | **167 advisories in 26 gems** (4 critical, 43 high) |
| Static security scan (Brakeman) | 8 warnings, including SQL injection ×3 and RCE ×1 |
| Fresh install | ❌ Fails: `mimemagic 0.3.2` was yanked from RubyGems |
| Production boot | ❌ Crashes: `newrelic_rpm 3.9` rejects Rails 5.0 |
| Framework defaults | Still Rails **4.2** behaviour (every 5.0 default switched off) |
| Data safety | 🔴 Any signed-in user could delete all of an account's entries with one GET request (found during the upgrade) |
| Business logic | "Download CSV" ignored report filters and always exported everything |
| CI | Travis CI, no longer usable |
| Slowest page: Reports CSV export | **34.7 s** p50 for 23k rows |
| Billables page | **2.8 s** p50 (N+1 queries) |
| Memory (single process) | 887 MB RSS |

The good news is a real safety net: **280 specs, 99.3% line coverage**.

## Approach

1. **Reproduce first.** Freeze the original environment in Docker ([`docker/legacy`](docker/legacy)) so "before" numbers are real, not guessed.
2. **Measure.** Security audit, test suite, and a [version-agnostic benchmark](script/benchmark): the same seed data (20k hour entries) and the same 9 pages, timed through the full Rack stack in production mode, on every Rails version.
3. **Upgrade one minor version at a time.** Bump → `rails app:update` → keep app-specific config → fix deprecations → specs green → tag.
4. **Replace dead dependencies** (Paperclip, Ruby Sass, CoffeeScript, Unicorn, Delayed Job, Memcached, Travis) with maintained equivalents.
5. **Performance pass** after the upgrade: fix N+1s, add indexes, stream the CSV export.
6. **Publish before/after numbers** with the same scripts.

Full plan: [`docs/case-study/UPGRADE_PLAN.md`](docs/case-study/UPGRADE_PLAN.md)

## Progress

| Hop | Tag | Status | Highlights |
|---|---|---|---|
| 0. Reproducible baseline | [`hop/0-baseline`](../../tree/hop/0-baseline) | ✅ | Docker env, benchmark, audit; unblocked the yanked gem |
| 1. Rails 5.0 → 5.1 | [`hop/1-rails-5.1`](../../tree/hop/1-rails-5.1) | ✅ | Found an association-order bug that breaks Reports/CSV on 5.1+ |
| 2. Rails 5.1 → 5.2, Ruby 2.4 → 2.6 | [`hop/2-rails-5.2`](../../tree/hop/2-rails-5.2) | ✅ | Security patch broke audit logging (89 failing specs); fixed a report-filter bug present since 2020 |
| 3. Rails 6.0, Ruby 2.7, Active Storage | [`hop/3-rails-6.0`](../../tree/hop/3-rails-6.0) | ✅ | Zeitwerk; Paperclip → Active Storage with a tenant-aware data migration; fixed CSV export ignoring filters |
| 3b. Rails 6.1, Ruby 3.0, Puma | [`hop/3b-rails-6.1`](../../tree/hop/3b-rails-6.1) | ✅ | **Found and fixed a critical bug: any user could wipe an account's data via one URL**; Unicorn → Puma |
| 4. Rails 7.0 → 7.2, Ruby 3.3 | [`hop/4-rails-7.2`](../../tree/hop/4-rails-7.2) | ✅ | Ruby Sass → Dart Sass, CoffeeScript → JS; caught a silent CSS layout regression by diffing compiled CSS; fixed a broken production cache |
| 5. Rails 8.1, Ruby 3.4 | [`hop/5-rails-8.1`](../../tree/hop/5-rails-8.1) | ✅ | Delayed Job (never used) → Solid Queue with tenant-aware jobs; Solid Cache; removed a public hardcoded Devise secret; production Docker image; GitHub Actions |
| 6. Performance pass | | ⏳ | CSV export, Billables and Dashboard N+1s, indexes |

Every finding along the way is logged in [`docs/case-study/UPGRADE_LOG.md`](docs/case-study/UPGRADE_LOG.md).

### Results

Same seed data (20k hours), same 9 pages, same script, same Postgres 9.6, production mode, single process. "Upgrade only" means no application-level performance work yet.

| Metric | Before (Rails 5.0 / Ruby 2.4) | After upgrade (Rails 8.1 / Ruby 3.4) |
|---|---:|---:|
| Known gem vulnerabilities (bundler-audit) | 167 (4 critical, 43 high) | **0** |
| Brakeman warnings | 8 (and missed 1 critical) | **0** |
| Critical app bugs found and fixed | | **4** (data wipe via URL, CSV ignoring filters, filters 500ing, public Devise secret) |
| Specs passing | 280 / 280 | **297 / 297**, 0 deprecation warnings |
| Reports CSV export p50 | 34,657 ms | 18,394 ms (1.9× faster) |
| Billables p50 | 2,793 ms | 1,767 ms (1.6×) |
| Dashboard p50 | 548 ms | 461 ms (1.2×) |
| User entries p50 | 136 ms | 74 ms (1.8×) |
| Reports p50 | 113 ms | 72 ms (1.6×) |
| Ruby objects allocated (CSV export) | 38.4 M | 12.8 M (−67%) |
| Process memory after benchmark | 887 MB | **449 MB** (−49%) |
| Inviting a user (request time) | SMTP inside the request | 0.13 s (Solid Queue) |
| Locked gems | 290 | 175 |
| Infrastructure | Postgres + memcached + idle Delayed Job worker | Postgres only (Solid Queue, Solid Cache) |
| CI | Travis (dead) | GitHub Actions: specs, Brakeman, bundler-audit, image build |

Raw data: [`baseline/`](docs/case-study/baseline) and [`after-upgrade/`](docs/case-study/after-upgrade).

Baseline details: [`docs/case-study/BASELINE.md`](docs/case-study/BASELINE.md)

## Run it yourself

Requires Docker. The app uses subdomains for accounts.

**Production image** (Puma + Solid Queue worker + Postgres + Mailpit):

```bash
docker compose up -d --build
docker compose exec web bin/rails runner script/benchmark/seed.rb
```

Open http://acme.hours.localhost:3000 and sign in as `user1@acme.test` / `benchmark-password`. Emails (invitations, password resets) appear in Mailpit at http://localhost:8025.

**Development / test environment:**

```bash
cd docker/app                     # docker/legacy = the original Ruby 2.4 environment
docker compose build app
docker compose up -d web          # http://acme.localhost:3000, seeds a demo tenant on first start
```

```bash
docker compose run --rm app bash -c "bundle exec rake db:create db:schema:load && bundle exec rspec"   # test suite
docker compose run --rm bench                                                                          # benchmark → JSON
```

To compare with the original code, check out `hop/0-baseline` and use `docker/legacy`.

## Repository layout

| Path | What |
|---|---|
| [`docs/case-study/`](docs/case-study) | Plan, baseline, upgrade log, raw audit/benchmark output |
| [`docker/app/`](docker/app) | Current upgrade-target environment (app, tests, benchmark, web) |
| [`docker/legacy/`](docker/legacy) | Frozen original Ruby 2.4 environment used for the baseline |
| [`script/benchmark/`](script/benchmark) | Deterministic seed data + request benchmark |
| [`script/compare_css.py`](script/compare_css.py) | Semantic diff used to prove the Sass migration kept the CSS identical |
| [`Dockerfile`](Dockerfile), [`docker-compose.yml`](docker-compose.yml) | Production image and stack |
| [`docs/ORIGINAL_README.md`](docs/ORIGINAL_README.md) | The upstream project's README |

## Need this for your app?

I upgrade and stabilise legacy Rails and Django applications: audit, upgrade plan, version-by-version upgrade with green tests, performance fixes, and CI/CD with Docker on AWS.
[Portfolio](https://portfolio.hadayxinchao.com/) · [LinkedIn](https://www.linkedin.com/in/hadayxinchao/)

## License

MIT, same as the upstream project. Original work © 2014 Defacto Software B.V.; see [LICENSE](LICENSE).
