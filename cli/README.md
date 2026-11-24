# hours-cli

Command-line client for [Hours](../README.md): log time, run a timer and get reports from the
terminal. It uses the [REST API](../docs/api/openapi.yaml) with a personal token, needs Ruby ≥ 3.1,
and depends only on the standard library.

```bash
cd cli && gem build hours-cli.gemspec && gem install ./hours-cli-1.0.0.gem
# or without installing: ruby cli/exe/hours help
```

## Log in

Create a token in Hours (your name → **API tokens**), then:

```bash
hours login --url https://acme.example.com --token hrs_...
```

`login` checks the token before saving it to `~/.config/hours/config.json` (mode 600, like `gh`).
`HOURS_URL` / `HOURS_TOKEN`, or `--url` / `--token`, take precedence, which suits CI and scripts.
`hours logout` removes the file; revoke the token in Hours to disable it.

## Commands

```text
$ hours log 1.5h book dev "Reminder emails #backend" --date yesterday
Logged 1.5 h of Development on Booking app (2026-11-23, #1047)

$ hours log 50m fleet design
Logged 1 h of Design on Fleet dashboard (2026-11-24, #1048) - rounded up to the next quarter hour

$ hours list --me --limit 3
  ID  DATE        HOURS  PROJECT           CATEGORY     DESCRIPTION
1049  2026-11-24      1  Order API         Development
1048  2026-11-24      1  Fleet dashboard   Design
1046  2026-11-24   0.25  Webshop relaunch  Testing      Smoke tests

$ hours start webshop testing Smoke tests
Timer started on Webshop relaunch (Testing). Stop it with: hours stop
$ hours status
Today: 14 h logged.
Timer running on Webshop relaunch: 0:12 - Smoke tests
$ hours stop
Logged 0.25 h (#1050, rounded up to the next quarter hour)

$ hours report --week --me
PROJECT           CATEGORY            HOURS
Fleet dashboard   Development             4
Booking app       Development             3
...
Total 2026-11-23..2026-11-24: 17.75 h

$ hours projects
SLUG              NAME              CLIENT             BUDGETS
fleet-dashboard   Fleet dashboard   Atlas Logistics    hours 80% (warning), amount 108% (over)
...
```

Also: `hours edit ID --hours 45m --description "..." [--date] [--project] [--category]`,
`hours delete ID`, `hours discard`, `hours categories`, `hours whoami`, `hours help`.

- **Durations:** `2h`, `1.5h`, `45m`, `1h30m`, or a plain number of hours, rounded up to the
  next quarter hour (Hours stores 15-minute steps).
- **Dates:** `today`, `yesterday`, `-3` (days ago) or `YYYY-MM-DD`.
- **Projects and categories:** slug, full name or a unique prefix (`book` → Booking app). An
  ambiguous prefix lists the matches instead of guessing.

## Scripting

Every command takes `--json` and prints the API's JSON:

```bash
hours --json list --me --from -7 | jq '[.[].hours] | add'
hours --json report --month | jq -r '.rows[] | "\(.project)\t\(.hours)"'
```

Exit codes: `0` ok · `1` usage · `2` not logged in / bad token · `3` not found ·
`4` rejected by the server (validation, invoiced entry, timer conflict) · `5` network · `6` rate limited.
Errors go to stderr, with the server's reason, for example
`hours: This entry is on invoice 2026-0003; void the invoice before changing it`.

## Tests

`spec/cli/hours_cli_spec.rb` in the main app runs the CLI end to end: WebMock routes its HTTP
requests into the Rails app in-process, so every command goes through the real API, token checks,
tenant selection and database.
