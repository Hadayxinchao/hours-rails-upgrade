# Phase 2 log

## Step 1: invoicing (tag `phase2/1-invoicing`)

Design and decisions: [PLAN.md](PLAN.md#step-1-invoicing).

### What was built

| Area | Change |
|---|---|
| Rates | `projects.hourly_rate_cents`, `mileage_rate_cents`; `clients.currency` (ISO code, 8 supported). Forms take decimals ("85.50"); `MoneyAttribute` converts to integer minor units |
| Invoices | `invoices` + `invoice_lines`; `hours.invoice_id` / `mileages.invoice_id` with foreign keys |
| Building | `InvoiceBuilder`: locks the selected entries `FOR UPDATE`, re-checks them (right client, billable, not billed, rate set), groups hours by project + category and mileage by project, snapshots unit prices, applies tax (half-up), marks entries billed, all in one transaction |
| Numbering | `YYYY-NNNN` per account and year under `pg_advisory_xact_lock`, plus a unique index |
| Lifecycle | draft → sent → paid; sent → void; drafts can be deleted. Void and delete release entries; void keeps the number |
| Locking | An entry on an invoice can't change hours, date, project, category or user, and can't be deleted. The edit and delete screens now show the reason (they used to say "deleted" or a generic error) |
| UI | "Ready to invoice" per client on Billables, with value at current rates; invoice form (issue date, payment term, tax, notes, entry selection); invoice list with overdue status; invoice page with actions |
| PDF | Prawn + prawn-table, DejaVu Sans (added `fonts-dejavu-core` to the image) so `€ £ ₫` and accented names render |
| Demo | Demo clients in USD/EUR/GBP with rates; each client has a paid and a sent (some overdue) invoice |

### Findings

- **Proving the numbering is race-free.** A spec runs four invoice creations in parallel threads, each
  on its own connection, released at the same moment. With the advisory lock all four get
  `2026-0001…0004`. With the lock commented out the same spec fails in 2 of 3 runs with
  `PG::UniqueViolation`, so the test really exercises the race. (The first version used 8 threads
  and hung: the pool has 5 connections, so threads waited for a connection forever behind the
  barrier. That was a test problem, not an app one.)
- **Prawn pins `bigdecimal` to 3.x** through `ttfunk`, which moved it from 4.1.3 to 3.3.1. That's
  fine on Ruby 3.4 (no advisories), and it's noted here so a future bump isn't a surprise.
- **Refused deletes reported success.** `EntriesController#destroy` ignored the return value of
  `destroy`, which never mattered before because nothing could block a delete. With invoice locking
  it would have said "deleted" while keeping the entry. Fixed, with feature specs.

### Result

330 examples, 0 failures (+22). Brakeman 0, bundler-audit 0, `zeitwerk:check` clean.
Verified in the browser on the demo stack: rates, "Ready to invoice", creating an invoice with
21% tax, the PDF, and the status flow.

## Step 2: timer and Hotwire (tag `phase2/2-timer`)

### What was built

| Area | Change |
|---|---|
| Hotwire | importmap-rails + turbo-rails + stimulus-rails, served by Sprockets next to the existing jQuery bundle. Turbo Drive is **off** for now: the jQuery code binds on page load and would not re-run after a Drive visit. The new features opt in with `data-turbo="true"` |
| Quarter hours | `hours.value` integer → `decimal(6,2)`, in 0.25 steps (15 min), max 24 per entry. Read back as `3` or `1.5`, never `3.0` or BigDecimal's `0.15e1`, so views, CSV, chart JSON and the audit trail keep their format |
| Timer | One running timer per user, stored on the server (survives reloads, tabs, devices). Start/stop/discard answer with Turbo Streams that replace the panel and a navbar badge; without JavaScript the same forms post and redirect. Stopping rounds up to the next quarter hour and logs an entry dated on the start day; over 24 h it refuses and keeps the timer. A Stimulus controller shows the clock |
| Live feed | New entries appear in everyone's activity feed in the same account: Action Cable over **Solid Cable** (Postgres, still no Redis), Turbo Stream `prepend`. `relative-date` Stimulus controller replaces `feed.js` (which only ran on page load, so it missed live entries) |
| Inline editing | "My Entries" rows switch to an inline form (Turbo Stream `replace`) and back on save or cancel; errors stay in the row. The classic edit page still works |

### Findings

- **Multi-tenancy, twice more.**
  - *WebSocket connections* are opened outside any controller, so Apartment is still on the public
    schema. Loading the Warden user there finds nobody, or another account's user with the same id.
    `ApplicationCable::Connection` resolves the account from the subdomain and loads the user inside
    that tenant (spec'd).
  - *Broadcast rendering* runs in a job. Turbo's `broadcast_*_later` job is a plain
    `ActiveJob::Base`, so it would render the entry from the public schema. `BroadcastActivityJob`
    is an `ApplicationJob` (tenant-aware). The spec puts an entry and a user named "Mallory" with
    the same ids in the public schema and checks that the broadcast says "Alice". The stream name
    includes the account and is signed, so a page can only subscribe to its own account's feed.
- **The single-database fallback from hop 5 never worked.** `cache`/`queue` (and now `cable`) fell
  back to `DATABASE_URL`, i.e. the primary database itself. Then `db:prepare` sees an existing
  database, only migrates, and never loads the Solid schemas. Verified on a fresh database: zero
  Solid Cache/Queue/Cable tables. It went unnoticed because every compose file set separate URLs.
  The demo only hit it because the new `cable` entry had no explicit URL, and the live feed stayed
  silent with `relation "solid_cable_messages" does not exist`. They now default to
  `<primary>_cache`, `_queue` and `_cable` on the same server (the Rails 8 layout). Re-verified:
  1, 13 and 1 tables created from `DATABASE_URL` alone.
- **`has_one` + `build_*` deletes.** `current_user.build_timer` on a user who already has a timer
  replaces it, and with `dependent: :destroy` deletes the running one. The controller checks first;
  a request spec starts twice and asserts the first start time survives.
- **`belongs_to` isn't required in this app.** The app still runs with the old framework default,
  so a timer without a category reached the database and hit `NOT NULL`. Found by the "missing
  category" feature spec; explicit validations added.
- **Audit page crashed on changes without a user** (console, imports, jobs): `link_to user_path(nil)`.
  Now shown as "System", with a spec. This surfaced because running a job inline in a feature spec
  resets `CurrentAttributes`, where `audited` keeps the acting user.
- **Account deletion rendered the navbar after dropping the schema.** It's harmless until the
  navbar queries a tenant table (the timer badge). The user is now signed out before the goodbye
  page.
- **Specs that relied on the old rules were updated, not deleted:** "hours must be integers" became
  "quarter hours are accepted, other fractions are rejected"; 100- and 1,000-hour test entries
  became realistic values.

### Not done in this step

Replacing select2, Pikaday and the other jQuery plugins, and turning Turbo Drive on. That's a
page-by-page migration better done separately; the new UI (timer, inline editing) already uses
plain `<select>` and `<input type="date">`.

### Result

352 examples, 0 failures (+21). Brakeman 0, bundler-audit 0, `zeitwerk:check` clean.
Verified in the browser on the production-mode demo stack: the timer starts and stops without a
reload (40 min → 0.75 h), the navbar badge ticks on every page, an entry created by another user in
a separate process appears in the open dashboard's feed, and inline editing saves in place.

## Step 3: budget alerts (tag `phase2/3-budget-alerts`)

### What was built

| Area | Change |
|---|---|
| Money budgets | `projects.budget_amount_cents` next to the existing hours budget, in the client's currency. "Spent" is the logged hours and kilometres at the project's current rates; it's unknown (and the amount budget is skipped) while work is logged without a rate |
| Status | Each budget shows a meter on project cards and pages: neutral below 80%, amber "almost used up" from 80%, red "over budget" from 100% (`role="meter"` with ARIA values) |
| Alerts | `BudgetMonitor` records each reached threshold (80 / 100, per hours and amount) in `budget_alerts` and emails the account owner (everyone in single-tenant mode) through Solid Queue. Each alert goes out once. Passing several thresholds at once sends one email, for the highest. Dropping back below (budget raised, entry deleted) re-arms it |
| Triggers | After hours or mileage are created, changed or deleted (both projects when an entry moves), and after a budget or rate changes: `BudgetCheckJob`, tenant-aware like the other jobs |
| Demo | Projects have amount budgets in three states (under, warning, over). Their current state is recorded without email on reset, so only new crossings alert |

### Findings

- **Exactly-once without locks.** Two entries saved at the same moment start two checks. Each
  inserts its thresholds with `INSERT … ON CONFLICT DO NOTHING RETURNING threshold` on the unique
  index, and only the check that actually inserted a row sends the email. A spec pre-inserts the
  row ("the other check won") and asserts no email.
- **`saved_changes` outlives the save it describes.** The "re-check when a budget or rate changes"
  condition first read `saved_changes` in `after_update_commit`. A project created and then touched
  by an entry in the same flow still carried the create's changes, so it checked twice. The change
  is now noted in `after_update` and acted on at commit; a spec checks that a touch doesn't trigger.
- **`Project#reload` kept stale totals.** `total_hours_spent` and friends are memoized (part of
  the hop 6 performance work), and `reload` only refreshes attributes. Harmless in requests and
  jobs, which load fresh objects, but wrong for any caller that reloads. `reload` now clears them.
  The monitor spec caught it.

### Result

366 examples, 0 failures (+14). Brakeman 0, `zeitwerk:check` clean.
Verified on the demo stack: cutting a project's amount budget from $46,000 to $40,000 in the form
sent "Webshop relaunch has used 83% of its budget" to the owner through Solid Queue (seen in
Mailpit), with the amounts and a link into the account.
