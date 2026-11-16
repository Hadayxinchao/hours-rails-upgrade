# Hours: Legacy Rails Rescue (Rails 5.0 → 8)

A documented, step-by-step upgrade of a real, abandoned Rails SaaS app: from **Ruby 2.4 / Rails 5.0 (both end-of-life)** to a current, secure, faster Rails 8 stack. Every step is measured, tested and tagged.

> Fork of [DefactoSoftware/Hours](https://github.com/DefactoSoftware/Hours) (MIT), a multi-tenant time-tracking app: accounts on subdomains, clients, projects, hours, mileage, reports, CSV export, billing and invitations. Last upstream commit: June 2020.
> The upgrade work, tooling and case study in this repository are by [Bui Hoang Ha](https://portfolio.hadayxinchao.com/).

**Status:** 🚧 In progress, at **Rails 5.2.8 / Ruby 2.6** (hop 2 of 7). See [Progress](#progress).

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
| CI | Travis CI, no longer usable |
| Slowest page: Reports CSV export | **34.7 s** p50 for 23k rows |
| Billables page | **2.8 s** p50 (N+1 queries) |
| Memory (single process) | 887 MB RSS |

The good news is a real safety net: **280 specs, 99.3% line coverage**.

## Approach

1. **Reproduce first.** Freeze the original environment in Docker ([`docker/legacy`](docker/legacy)) so "before" numbers are real, not guessed.
2. **Measure.** Security audit, test suite, and a [version-agnostic benchmark](script/benchmark): the same seed data (20k hour entries) and the same 9 pages, timed through the full Rack stack in production mode, on every Rails version.
3. **Upgrade one minor version at a time.** Bump → `rails app:update` → keep app-specific config → fix deprecations → specs green → tag.
4. **Replace dead dependencies** (Paperclip, CoffeeScript/Sprockets, Unicorn, Delayed Job, Memcached, Travis) with their Rails 8 equivalents.
5. **Performance pass** after the upgrade: fix N+1s, add indexes, stream the CSV export.
6. **Publish before/after numbers** with the same scripts.

Full plan: [`docs/case-study/UPGRADE_PLAN.md`](docs/case-study/UPGRADE_PLAN.md)

## Progress

| Hop | Tag | Status | Highlights |
|---|---|---|---|
| 0. Reproducible baseline | [`hop/0-baseline`](../../tree/hop/0-baseline) | ✅ | Docker env, benchmark, audit; unblocked the yanked gem |
| 1. Rails 5.0 → 5.1 | [`hop/1-rails-5.1`](../../tree/hop/1-rails-5.1) | ✅ | Found an association-order bug that breaks Reports/CSV on 5.1+ |
| 2. Rails 5.1 → 5.2, Ruby 2.4 → 2.6 | [`hop/2-rails-5.2`](../../tree/hop/2-rails-5.2) | ✅ | Security patch broke audit logging (89 failing specs); fixed a report-filter bug present since 2020 |
| 3. Rails 6.0 / 6.1, Ruby 2.7 → 3.0 | | ⏳ | Zeitwerk, Paperclip → Active Storage, Ruby 3 kwargs |
| 4. Rails 7.0 → 7.2, Ruby 3.3 | | ⏳ | Propshaft + importmap, CoffeeScript → JS, Puma |
| 5. Rails 8.x, Ruby 3.4 | | ⏳ | Solid Queue, Solid Cache, GitHub Actions CI |
| 6. Performance + security pass | | ⏳ | CSV streaming, N+1 fixes, 0 known vulnerabilities |

Every finding along the way is logged in [`docs/case-study/UPGRADE_LOG.md`](docs/case-study/UPGRADE_LOG.md).

### Results (filled in as hops land)

| Metric | Before | After |
|---|---:|---:|
| Known vulnerabilities | 167 | 138 (on 5.2) |
| Brakeman warnings | 8 | – |
| Specs passing | 280 / 280 | 280 / 280 (on 5.2) |
| Reports CSV export p50 | 34,657 ms | – |
| Billables p50 | 2,793 ms | – |
| Dashboard p50 | 548 ms | – |
| Process memory | 887 MB | – |

Baseline details: [`docs/case-study/BASELINE.md`](docs/case-study/BASELINE.md)

## Run it yourself

Requires Docker. The app uses subdomains for accounts, so open it on `acme.localhost`.

```bash
cd docker/app                     # current upgrade state (docker/legacy = original Ruby 2.4 environment)
docker compose build app
docker compose up -d web          # seeds a demo tenant on first start
```

Open http://acme.localhost:3000 and sign in as `user1@acme.test` / `benchmark-password`.

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
| [`docs/ORIGINAL_README.md`](docs/ORIGINAL_README.md) | The upstream project's README |

## Need this for your app?

I upgrade and stabilise legacy Rails and Django applications: audit, upgrade plan, version-by-version upgrade with green tests, performance fixes, and CI/CD with Docker on AWS.
[Portfolio](https://portfolio.hadayxinchao.com/) · [LinkedIn](https://www.linkedin.com/in/hadayxinchao/)

## License

MIT, same as the upstream project. Original work © 2014 Defacto Software B.V.; see [LICENSE](LICENSE).
