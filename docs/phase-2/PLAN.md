# Phase 2: from upgraded to useful

Phase 1 (tags `hop/*`) brought the app from Rails 5.0 to 8.1 without changing what it does. Phase 2 is
the follow-up work a client typically asks for next: features that make the product competitive
with today's time-tracking tools. It works the same way as phase 1: small steps, specs green, one
tag per step, and every decision written down.

| Step | Tag | What | Why |
|---|---|---|---|
| 1 | `phase2/1-invoicing` | Hourly and mileage rates, invoices built from billable entries, PDF, draft → sent → paid / void, entries locked once invoiced | The app tracks billable hours but stops before the part that makes money |
| 2 | `phase2/2-timer` | Hotwire: running timer, inline entry editing, live feed; replace select2 and jQuery plugins | A modern Rails 8 front end; timers are table stakes for time trackers |
| 3 | `phase2/3-budget-alerts` | Budgets in money as well as hours, email alerts at 80% / 100% via Solid Queue | Overruns are found when invoicing, which is too late |
| 4 | `phase2/4-api` | REST API with personal tokens, OpenAPI docs, webhooks, a Slack `/hours` command | Integrations are what keep a tool in daily use |
| 5 | `phase2/5-ai` | Natural-language time entry, weekly client summary (Claude API), with human confirmation | Faster entry and better client communication, with a narrow scope |
| 6 | `phase2/6-ops` | Kamal deploy, error tracking, OpenTelemetry, tested Postgres backups | Running it for real |

## Step 1: invoicing

### Decisions

- **Money is stored as integer minor units** (`*_cents`, bigint) plus an ISO currency code. There's no
  float, and no money gem: formatting and parsing are one small module with a fixed currency list.
- **Currency belongs to the client.** You invoice a client in one currency, so project rates are in
  the client's currency. Projects without a client aren't invoiceable (they're internal work anyway).
- **Rates live on the project** (hourly and per-kilometre). Rates per person or per category are
  common extensions but add a resolution order that this step doesn't need.
- **Invoice lines snapshot the rate.** Changing a project's rate later never changes an issued
  invoice. Lines are grouped by project + category (hours) and by project (mileage).
- **Numbering:** `YYYY-NNNN`, sequential per account and year. A transaction-scoped Postgres
  advisory lock serialises number allocation; a unique index is the backstop.
- **Double invoicing is impossible:** entries are selected `FOR UPDATE` inside the transaction that
  creates the invoice, and must still be unbilled and un-invoiced at that point.
- **Invoiced entries are locked.** Changing hours, date, project, category or user, or deleting the
  entry, is refused while it is on an invoice. Deleting a draft or voiding an invoice releases its
  entries. A voided invoice keeps its number (no gaps in the sequence).
- **Tax:** one rate per invoice (VAT/GST), rounded half-up on the subtotal.
- **PDF:** Prawn (pure Ruby, no headless browser in the image), with DejaVu Sans so non-Latin
  client names and currency symbols render.
- The existing "Bill selected entries" (mark as billed without an invoice) stays, for teams that
  invoice elsewhere.
