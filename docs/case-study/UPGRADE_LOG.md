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
