# Upgrade log

Running notes per hop, used as raw material for the final case study.

## Hop 0: baseline (tag `hop/0-baseline`)

- Fresh install failed: `mimemagic 0.3.2` was yanked from RubyGems. Bumped to 0.3.10.
- Production boot crashed: `newrelic_rpm 3.9` rejects Rails 5.0.
- The app still ran on **Rails 4.2 framework defaults**: `new_framework_defaults.rb` turned off every 5.0 default (`belongs_to` required, per-form CSRF tokens, origin check, timezone-preserving `to_time`).
- 280 specs green, 99.3% coverage. See [BASELINE.md](BASELINE.md).

## Hop 1: Rails 5.0.7.2 → 5.1.7 (tag `hop/1-rails-5.1`)

| Finding | Impact | Fix |
|---|---|---|
| `has_one :client, through: :project` declared before `belongs_to :project` in `Entry` | `HasManyThroughOrderError` on any `entry.client`, which **breaks Reports and CSV export** | Reordered associations (caught by `entry_query_spec`) |
| `has_many ..., -> { uniq }` on `User#projects`, `Tag#projects/users` | `Relation#uniq` removed in 5.1; not covered by specs | `distinct` |
| `loofah 2.21` pulled in by the resolver needs `Nokogiri::HTML4` (nokogiri ≥ 1.12, Ruby ≥ 2.5) | App fails to boot | Temporary pin `loofah ~> 2.19.1`, `rails-html-sanitizer ~> 1.4.4` until the Ruby upgrade |
| `serve_static_files`, `halt_callback_chains_on_return_false`, `raise_on_unfiltered_parameters` | Removed/deprecated | Replaced or removed (verified no callback returns `false`) |

Result: 280 examples, 0 failures. Production boot and `assets:precompile` OK.
Remaining deprecation: `schema_migrations_table_name` (from `apartment`), to handle in the 5.2 hop.

### Manual smoke test on 5.1 (`docker compose up web`)

Logged in as `user1@acme.test`: Dashboard, Reports, Billables, Team, Project, Clients and User entries all return 200.
Pre-existing bug found: `GET /entries` (route with no `user_id`) raises `NoMethodError` on `nil.hours`. It is not linked anywhere in the UI and fails the same way on 5.0; the fix is to remove the orphan route.

## Hop 2: Rails 5.1.7 → 5.2.8.1, Ruby 2.4.2 → 2.6.10 (tag `hop/2-rails-5.2`)

| Finding | Impact | Fix |
|---|---|---|
| Rails 5.2.8.1 security release (CVE-2022-32224) safe-loads YAML columns | Every `audited` write/read raised `Psych::DisallowedClass: Date`: **89 of 280 specs failed**, and creating or editing hours would have failed in production | `config.active_record.yaml_column_permitted_classes` |
| That fix needs `YAML.safe_load(permitted_classes:)`, which Psych 2.2 on Ruby 2.4 does not support | Allow-list silently ignored on Ruby 2.4 | Moved to Ruby 2.6 (Psych 3.1) in the same hop |
| `database_cleaner 1.3` calls `Migrator.schema_migrations_table_name` (removed in 5.2) | Suite could not start | `database_cleaner` 2.1 |
| `image_tag` no longer derives `alt` from the filename | Client logos and team photos lost their alt text (accessibility) | Explicit `alt:`; spec now checks attributes instead of HTML string order |
| `order("lower(name)")` and similar raw SQL (5 places) | Deprecated in 5.2, **raises in 6.0** | `Arel.sql(...)` |
| `:dalli_store` cache | Deprecated in favour of Rails' built-in store | `:mem_cache_store` |
| Ruby 2.6 Docker base: Debian buster is gone from mirrors, bullseye security moved to archive.debian.org | Image would not build | New `docker/app` image on bullseye with archive security repo |

**Pre-existing bug fixed:** `ReportsController#entry_filter_params` used `params.permit(:entry_filter)` on a hash. Every report filter raised `UnpermittedParameters` in development, and in production the filter form forgot the chosen values. Fixed with `params.fetch(:entry_filter, {}).permit(...)` and a regression spec, which fails without the fix and passes with it.

Temporary `loofah`/`rails-html-sanitizer` pins from hop 1 removed: nokogiri 1.10.9 → 1.13.10, loofah 2.25.2.

Result: 280 examples, 0 failures, **0 deprecation warnings**. Production boot and `assets:precompile` OK. All main pages return 200 in the browser.
Known vulnerabilities: 167 → **138** (critical 4 → 3, high 43 → 25).

## Hop 3: Ruby 2.7.8 + Rails 6.0.6.1 + Paperclip → Active Storage (tag `hop/3-rails-6.0`)

Three commits: Ruby 2.7 on Rails 5.2, then Rails 6.0 with Zeitwerk, then the Paperclip → Active Storage move.

### Ruby 2.6 → 2.7

| Finding | Fix |
|---|---|
| `shoulda-matchers 2.7` calls `BigDecimal.new` (removed in Ruby 2.7), so nothing loaded | shoulda-matchers 4.5 |
| The stricter matchers showed the uniqueness specs never checked case-insensitivity, though the models enforce it | Specs now assert `.case_insensitive` |

### Rails 5.2 → 6.0

| Finding | Impact | Fix |
|---|---|---|
| `apartment 2.2` is unmaintained and capped below Rails 6 | Blocks the upgrade | `ros-apartment` 2.11 (maintained fork, same API) |
| Bundler 1.16 resolver picked an `ffi` build that needs Ruby 3 | `bundle update` failed | Bundler 2.4 |
| `concurrent-ruby` ≥ 1.3.5 no longer requires `logger`; Rails < 7.1 assumes it | Boot crash: `uninitialized constant ...LoggerThreadSafeLevel::Logger` | `require "logger"` in `config/boot.rb` |
| Resolver jumped `rails-assets-chartjs` 1.0 → 4.5 (different API) | **Every page with charts raised** (97 failing specs) | Pin Chart.js 1.x until the Rails 7 asset hop |
| Sprockets 4 requires `manifest.js` | Boot failure | Keep Sprockets 3 until Propshaft |
| Zeitwerk: `csv_download.rb` → `CsvDownload`, not `CSVDownload` | `NameError` on eager load | Zeitwerk inflections; `zeitwerk:check` passes |
| `update_attributes` (4 controllers), `coffee-rails`/`haml-rails` deprecations | Removed in 6.1 | `update`, coffee-rails 5, haml-rails 3 |

### Paperclip → Active Storage

- `Client#logo`: `has_one_attached`, content-type validation, `logo_thumbnail` variant (`resize_to_fill: [100, 100]`, same crop as Paperclip's `100x100#`).
- Storage: Disk (dev/test), S3 (production, `aws-sdk-s3` instead of the monolithic `aws-sdk` v2).
- **Data migration:** `bin/rails paperclip:migrate_logos` walks every tenant schema and copies each legacy file (local `public/system` or S3) into Active Storage. It is idempotent, reports missing files, and leaves the legacy files and columns in place for rollback. Covered by 5 specs plus a dev run: `migrated=2 missing=1`, then `skipped=2` on re-run.
- New end-to-end spec: upload a logo through the form, then see it on the client page. Previously no test exercised uploads.
- Verified in the browser: the variant is generated by ImageMagick (100×100 PNG).
- Gems: 291 → **171** (Paperclip, mimemagic and the full AWS SDK v2 removed).

### Pre-existing bug fixed: CSV export ignored report filters

`download_csv_params` permitted the filter keys at the top level, but the filters are nested under `entry_filter`, so **"Download CSV" always exported every entry, whatever the user filtered**. For a time-tracking app used for invoicing, that is a business bug, not a cosmetic one. Fixed, with a regression spec that fails without the fix. With a client + not-billed filter the export goes from 23k rows to 1,840.

Result: **289 examples, 0 failures, 0 deprecation warnings**, `zeitwerk:check` clean.
Known vulnerabilities: 138 → **99** (critical 3 → 1, high 25 → 9).

## Hop 3b: Rails 6.1.7 + Ruby 3.0.7 + Puma (tag `hop/3b-rails-6.1`)

### Rails 6.0 → 6.1

| Finding | Fix |
|---|---|
| Rails 6.1 needs `pg ~> 1.1`; app had pg 0.18 | pg 1.6 |
| `add_template_helper` removed: **every mailer (signup, invitations) raised** | `helper EmailHelper` |
| `ActiveModel::Errors` became objects: `each { |attr, msg| }`, `errors[:x] <<`, `errors.keys` | `error.attribute/message`, `errors.add`, `attribute_names` |
| Active Storage 6.1 schema | `service_name` + variant records migrations |
| `airbrake` and `newrelic_rpm` had **no configuration files**: they never reported anything, and New Relic 3.9 crashed production boot | Removed; error tracking/APM is a deployment decision (Sentry, current New Relic, …) |
| `rails_12factor` obsolete | `RAILS_LOG_TO_STDOUT` logger in production |

### Ruby 2.7 → 3.0

| Finding | Impact | Fix |
|---|---|---|
| `gravatar_image_tag` (last release 2014) calls `URI.escape`, removed in Ruby 3 | **91 specs failed: every page with an avatar raised** | 15-line `AvatarHelper` with specs; keeps the old `d=blank` default so the coloured initials still show |
| `CSV.generate(options)`: positional hash vs keyword args in Ruby 3 | **CSV export broken** | `CSV.generate(**options)` |
| `binding_of_caller`, `debug_inspector`, `capybara` native/kwargs issues | Bundle would not install | Updated (dev/test only) |
| `ros-apartment` 3.x needs Ruby ≥ 3.0 | Was stuck on 2.11 | ros-apartment 3.1 |
| WEBrick no longer ships with Ruby 3 | `rails server` had no server | Puma (see below) |

### 🔴 Critical: any signed-in user could delete or rewrite all of an account's data with one GET request

`EntryQuery#filter` took each key of `params[:entry_filter]` and called it as a method on the `Hour`/`Mileage` relation (`public_send(filter, value)`). The keys came straight from the URL:

```
GET /reports?entry_filter[delete_by]=1=1          → Hour.delete_by("1=1")
GET /reports?entry_filter[update_all]=value=0     → Hour.update_all("value=0")
```

The 2020 code shipped with this, and **Brakeman did not flag it**. Confirmed with a regression spec (hours count went from 2 to 0 before the fix). Fixed in three layers:
1. `EntryQuery` only applies keys in `EntryFilter::KEYS` (8 known filters).
2. `ReportsController` passes permitted params (`entry_filter_params`) instead of raw `params[:entry_filter]`.
3. Filter scopes use hash/Arel conditions instead of string SQL.

Verified on the running app: the exploit URL no longer changes data (20,000 hours before and after).

### Thread safety → Unicorn to Puma

`EntryQuery::Scopes.set(entry_type)` stored the table name in module-level state, which is a race condition under a threaded server. Replaced with the relation's own `arel_table`, with a spec. With that fixed, **Unicorn → Puma** (`Procfile`, `config/puma.rb`).

### Other security fixes

- `cookies_serializer :marshal` (Brakeman: possible RCE) → `:hybrid`, which migrates existing cookies to JSON. Switch to `:json` in a later hop.
- `EntryStats` string-built SQL → explicit column map.

Result: **294 examples, 0 failures, 0 deprecation warnings, 0 Ruby warnings**.
Brakeman: 8 → **3** (remaining: EOL Ruby/Rails, `:hybrid` cookies).
Known vulnerabilities: 99 → **93**. Gems: 171 → **163**.
Note: the repo-root `Dockerfile` and `docker-compose.yml` are the upstream 2020 files (Ruby 2.4, Unicorn). They are replaced in the Rails 8 hop by a production Dockerfile.

## Hop 4: Rails 7.0 → 7.2, Ruby 3.3, modern Sass/JS toolchain (tag `hop/4-rails-7.2`)

Four commits: Rails 7.0 → Ruby 3.3 + front-end toolchain → Rails 7.1 → Rails 7.2 + security patch round.

### Rails 6.1 → 7.0 → 7.1 → 7.2

Mostly configuration: `legacy_connection_handling` (removed), `Time#to_s(:number)` → `to_fs`, `show_exceptions :none`, `fixture_paths` (rspec-rails 4.1 → 7.1), `to_time_preserves_timezone = true`, `cache_format_version 7.1`, and the Active Storage 7.0 migration. Rails 7.2 went green with no code changes, because the earlier hops had already cleared every deprecation.

### Ruby 3.0 → 3.3

| Finding | Fix |
|---|---|
| `File.exists?` removed in Ruby 3.2: `dotenv 0.11`, Ruby `sass 3.2` | dotenv 3.2; Ruby Sass removed (below) |
| `pry 0.11` crashes on Ruby 3.3 | pry 0.16 |
| `execjs` pulled `json 3.1`, which dropped the `quirks_mode` option ActiveSupport still passes (**156 failing specs**; still true on 7.2) | Pin `json ~> 2.10`, re-test on Rails 8 |
| Redcarpet allocator warning | redcarpet 3.6 |

### Front-end toolchain (forced by Ruby 3.3: Ruby Sass no longer runs)

| Before | After |
|---|---|
| `sass-rails` + Ruby Sass/libsass | `dartsass-sprockets` (Dart Sass 1.108) |
| `bourbon 3.2` / `neat 1.5` / `bitters 0.10` gems | SCSS vendored in `vendor/assets/stylesheets` |
| CoffeeScript (7 files) + `coffee-rails` | Plain JavaScript (compiled once with the CoffeeScript compiler, then committed) |
| Uglifier (ES5 only; failed on `const` in a bundled library) | Terser |
| `factory_girl` | `factory_bot` 6 (13 static attributes → blocks) |

**Subtle CSS regression caught by diffing the compiled output.** Neat 1.5 targeted Sass 3.2, where assigning a variable inside a mixin overwrote the global. Since Sass 3.4 that creates a local instead, so under Dart Sass every `row(table)` / `media()` layout silently compiled to floats (Billables, Reports and Projects columns). Nothing failed. Found by comparing the new CSS rule by rule with a build from the original 2020 environment, and fixed with `!global` in the vendored Neat (what Neat 1.6 did upstream). After the fix the stylesheets are equivalent: 1,474 identical declarations, and the rest are formatting differences. The old build had emitted **invalid** select2 gradients (`linear, to bottom, …`); the new one is correct.

**Plan change:** Sprockets stays. It is still supported on Rails 8, and moving to Propshaft + importmap means replacing six gem-packaged jQuery plugins, with no benefit to users. The compile chain is now modern (Dart Sass, Terser, no CoffeeScript).

### Security patch round

addressable 2.7 → 2.9, dalli 2.7 → 5.3, loofah, rails-html-sanitizer, net-imap, jquery-rails 4.6, Puma 6 → 7.2.

**Production cache was broken (since the Rails 7.1 commit).** `connection_pool` 3.0 takes keyword arguments, but Rails ≤ 7.2's `MemCacheStore` passes a hash, so the app raises `ArgumentError` as soon as caching is enabled. The specs run with caching off and could not see it; found by exercising the store against a real memcached container. Pinned `connection_pool ~> 2.5` (verified: write/read/fetch/increment against memcached) and added a spec that builds the production cache store.

Result: **295 examples, 0 failures, 0 deprecation warnings, 0 Ruby warnings**. All pages and compiled assets return 200 in the browser.
Known vulnerabilities: 93 → **30** (all remaining ones are in Rails 7.2 itself, now EOL, plus Devise 4; next hop).
Brakeman: 3 → **2** (EOL Rails 7.2, `:hybrid` cookies).

## Hop 5: Rails 8.1, Ruby 3.4, Solid Queue/Cache, Docker + CI (tag `hop/5-rails-8.1`)

### Rails 7.2 → 8.0 → 8.1, Ruby 3.3 → 3.4

| Finding | Fix |
|---|---|
| `resources :hours, only: [... :patch]` (a verb, not an action) | Rails 8 raises on boot; removed (it never did anything) |
| `to_time_preserves_timezone` | `:zone` on 8.0, option gone on 8.1 |
| `json` / `connection_pool` pins from hop 4 | **Both removable on Rails 8.1**; MemCacheStore re-verified against memcached before it was replaced |
| `csv` is no longer a default gem in Ruby 3.4 | Added to the Gemfile (report exports) |

### Devise 4.9 → 5.0, and a public secret

- Devise 5 patches the remaining Devise advisories. `devise_invitable` stays on 2.0.14: 3.x moves invitations to a new table through an **irreversible** data migration and changes when invited users are created (only on acceptance, while the Team page currently lists pending invitees). That is a product decision for the app owner, so it is documented and left undone.
- **`config/initializers/devise.rb` contained a hardcoded `secret_key`, public on GitHub since 2014.** Devise now derives its keys from `secret_key_base` (environment). `DEVISE_SECRET_KEY` can carry an old key during a transition, because changing it invalidates outstanding reset, confirmation and invitation links.
- Removed `config/secrets.yml`, the `secret_token` initializer and `config.secret_token` (unused since Rails 7.2).

### Delayed Job → Solid Queue, memcached → Solid Cache

- **Delayed Job was installed but never used.** Nothing in the app enqueued a job, every email (confirmations, password resets, invitations) went out over SMTP *inside the web request*, and the `worker` process in the Procfile ran with nothing to do.
- Now: Active Job on **Solid Queue** (`bin/jobs`, or in Puma with `SOLID_QUEUE_IN_PUMA=1`), and Devise emails use `deliver_later`.
- **Multi-tenancy trap:** jobs run outside a request, so they don't know the account schema. A Devise mail job would look up its user in the wrong schema, which either fails or finds *another account's* user with the same id. `TenantAwareJob` stores the Apartment tenant when the job is enqueued and wraps the whole `perform_now` in it (Active Job deserializes GlobalID arguments before `around_perform` runs, so a callback is too late). A spec reproduces `Couldn't find User with 'id'=1` without it.
- **Solid Cache** replaces dalli + memcachier. Cache keys already include the subdomain.
- `config/database.yml` is now committed and env-driven, with `primary` / `cache` / `queue` databases in production. ~~cache and queue fall back to `DATABASE_URL`, so a single-database deploy still works~~ **Correction (phase 2):** that fallback never worked: `db:prepare` doesn't load the Solid schemas into an existing database. They now default to separate `<primary>_cache` / `_queue` / `_cable` databases; see [phase 2 log](../phase-2/LOG.md).
- `delayed_jobs` table dropped (per tenant, via Apartment's migration hook).

Verified in production mode: job enqueued with `tenant=acme`, processed by `bin/jobs`, and the email received by a real SMTP server (Mailpit). Solid Cache read/write OK.

### Production Docker image + CI

- **Dockerfile** (repo root, replacing the 2020 Ruby 2.4/Unicorn file): multi-stage `ruby:3.4.12-slim`, non-root user, jemalloc, assets precompiled at build time, and `bin/docker-entrypoint` runs `db:prepare` for all three databases.
- **docker-compose.yml**: web (Puma) + worker (Solid Queue) + Postgres 17 + Mailpit.
- Two production-only failures found by actually running the image:
  1. Apartment opens a DB connection at boot, which breaks `assets:precompile` in a build with no database. Fixed with `APARTMENT_DISABLE_INIT=1` for that step.
  2. **Sprockets 3.7 cannot read its own precompiled manifest with json 3** (`unknown keyword: create_additions`). Specs and development never load the manifest, so only production crashed. Fixed with Sprockets 4.4 and `app/assets/config/manifest.js`. The compiled CSS was re-verified with `script/compare_css.py`: 1,484 identical declarations, and the rest are a newer select2, the fixed gradients and asset digests.
- End to end on the production stack: every page returns 200; inviting a user from the UI returns in **0.13 s** (no SMTP in the request) and the invitation email arrives through the worker.
- **GitHub Actions** replaces Travis: specs + `zeitwerk:check` on Postgres 17, Brakeman (`--exit-on-warn`), bundler-audit, and a production image build. Dependabot changed from daily/10 PRs to weekly and grouped.
- Brakeman 4.7 (2019) → 8.1. `protect_from_forgery` → `with: :exception`. The `:hybrid` cookie serializer is kept for this release so existing `:marshal` cookies are migrated, and recorded in `config/brakeman.ignore` with a note to switch to `:json` afterwards.

Result: **297 examples, 0 failures, 0 deprecation warnings, 0 Ruby warnings. bundler-audit: 0 advisories. Brakeman: 0 warnings.**

## Hop 6: performance pass (tag `hop/6-performance`)

### Finding the real problem

The benchmark's SQL counts left out query-cache hits, so the CSV export looked harmless at 96 queries. `script/benchmark/sql_profile.rb` counts every statement:

| Page | Statements (cache hits) | Pattern |
|---|---:|---|
| CSV export | **89,006** (88,908) | 4 lookups per row (user, project, client, category) × 23k rows |
| Dashboard | 1,769 (1,557) | 2 `SUM` per category, recomputed 3× per project by the presenter |
| Billables | 1,405 (1,190) | `EXISTS` ×2 per project in the controller *and again in the view*, user per row |

Cache hits are cheap in SQL time but each one still instantiates an Active Record object. That is where the 38 M allocations of the CSV export came from.

### Fixes

| Page | Change | Queries | Verified |
|---|---|---|---|
| CSV export | `EntryCSVGenerator` preloads `user`, `category`, `project: :client` (covers both export endpoints) | 89,006 → **13** | Exports byte-identical to the old code (3 exports, 26k lines) |
| Billables | All unbilled entries in two queries grouped by project; memoized user links and date labels for the ~10k rows | 1,405 → **13** | Rendered HTML byte-identical |
| Dashboard | `Project#sorted_categories` from one `GROUP BY category_id` per project (memoized, same rounding and sort key); presenter memoizes its category list; `project.users` loaded once; client and activity feed preloaded | 1,769 → **66** | DOM identical |
| All pages | HAML 5.1 → 6.4 (Hamlit-based): about 40% less view time on render-heavy pages | | DOM of 18 pages compared |

### A regression from the upgrade itself, found here

Comparing HAML 5 and HAML 6 output showed that, on HAML 5.1 with the newer Rails output buffer, **the project form re-emitted its whole content as escaped text** after the custom `SwitchInput`. Users would have seen raw `<div class=...>` markup under the billable switch on "New/Edit project". Rendering the same form on the original 2020 stack shows no such text, so the regression came in during the Rails 7.x hops. The specs missed it because the real inputs were still present. HAML 6 fixes it, and a feature spec now asserts that the form has no escaped markup and that each input appears once (it fails on HAML 5.1).

### Result (same session, all three versions rebuilt from their commits)

| Page | Before | Upgrade only | Optimized |
|---|---:|---:|---:|
| CSV export | 37,997 ms | 20,002 ms | **1,735 ms (21.9×)** |
| Billables | 3,318 ms | 2,114 ms | **540 ms (6.1×)** |
| Dashboard | 655 ms | 543 ms | **165 ms (4.0×)** |
| Client detail | 374 ms | 240 ms | **120 ms (3.1×)** |
| Memory | 833 MB | 453 MB | **358 MB** |

Full table and method: [`final/README.md`](final/README.md). 298 examples, 0 failures.

Not done (product decisions): Billables still renders every unbilled entry on one page (≈2.4 MB of HTML on the benchmark account); paginating or collapsing per project would make it instant, but changes how people bill. Fragment caching (`localized_cache`) already exists in the views and helps further in production with `PERFORM_CACHING=1`; the benchmark keeps it off, as the baseline did.
