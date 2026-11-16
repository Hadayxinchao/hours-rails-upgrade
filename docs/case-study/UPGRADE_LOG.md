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
