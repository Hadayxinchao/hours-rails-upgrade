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
