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
