# Public demo deployment

Everything needed to put a live demo of Hours at **`https://hoursdemo.hadayxinchao.com`** (or any
subdomain you choose) on one small server. It is ready to run but **not deployed**: nothing here
costs money until you rent a server and start it.

```
visitor ──HTTPS──▶ Cloudflare ──tunnel──▶ cloudflared ──HTTP──▶ web (Puma + Solid Queue) ──▶ Postgres
                                                                     └──SMTP──▶ Mailpit (internal)
```

## What demo mode does (`DEMO_MODE=true`)

| | |
|---|---|
| Demo account | Created on first boot: a small agency with 6 people, 4 clients, 7 projects and ~120 days of hours and mileage, dated relative to today |
| Sign-in page | Shows and pre-fills the demo login (`demo@example.com` / `hours-demo`) |
| Nightly reset | `DemoResetJob` rebuilds the account at 03:00 (server time) through Solid Queue's recurring tasks |
| Guard rails | Deleting the account and changing the demo login's email/password are refused, so one visitor can't lock out the next |
| Email | Goes to an internal Mailpit; nothing is sent to real addresses |
| Search engines | `X-Robots-Tag: noindex, nofollow` on every response |

Why one subdomain level (`hoursdemo.hadayxinchao.com`, not `acme.hours.hadayxinchao.com`): the app reads
the account from the first label, which works with Rails' default `TLD_LENGTH=1`, and Cloudflare's free
certificate covers `*.hadayxinchao.com` but not a second level. Signing up new accounts needs the
apex domain, which belongs to the portfolio, so the demo is the single pre-built account. For a
deployment with sign-ups on its own domain, set `TLD_LENGTH` accordingly.

## Requirements

- A Linux server with Docker and **≥ 2 GB RAM** (the app uses ~360 MB, Postgres the rest). Any
  small VPS works (Hetzner, DigitalOcean, Vultr, Lightsail…). No ports need to be opened.
- The domain on Cloudflare (it already is for the portfolio).

## Go live

1. **Create the tunnel.** Cloudflare dashboard → Zero Trust → Networks → Tunnels → *Create a tunnel*
   → Cloudflared. Name it `hours-demo` and copy the token from the install command.
2. **Add the public hostname** to the tunnel: subdomain `hoursdemo`, domain `hadayxinchao.com`,
   service `HTTP` → `web:3000`. Cloudflare creates the DNS record.
3. **On the server:**
   ```bash
   git clone https://github.com/Hadayxinchao/hours-rails-upgrade.git && cd hours-rails-upgrade
   cp deploy/demo/.env.example deploy/demo/.env
   # fill in SECRET_KEY_BASE (openssl rand -hex 64), POSTGRES_PASSWORD, TUNNEL_TOKEN
   docker compose -f deploy/demo/compose.yml --env-file deploy/demo/.env --profile tunnel up -d --build
   ```
   The first boot prepares the databases and builds the demo account (about a minute).
4. Open `https://hoursdemo.hadayxinchao.com`, sign in with the pre-filled login.

## Operating it

```bash
cd hours-rails-upgrade
alias demo='docker compose -f deploy/demo/compose.yml --env-file deploy/demo/.env --profile tunnel'
demo logs -f web                                  # app + job logs
demo exec web bin/rails demo:reset                # reset the demo data now
git pull && demo up -d --build                    # deploy a new version
ssh -L 8025:localhost:8025 <server>               # then http://localhost:8025 for demo emails
demo down                                         # stop (data kept); add -v to wipe it
```

To take the demo offline, stop the stack and delete the tunnel's public hostname in Cloudflare.

## Try it locally first (no Cloudflare)

Without the `tunnel` profile the stack runs as-is on your machine, over plain HTTP:

```bash
cat > deploy/demo/.env <<ENV
SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=local
FORCE_SSL=false
ASSUME_SSL=false
WEB_PORT=3100
ENV
docker compose -f deploy/demo/compose.yml --env-file deploy/demo/.env up -d --build
```

Open http://hoursdemo.hours.localhost:3100. The browser resolves `*.localhost` to your machine, and with
`TLD_LENGTH=1` the first label is the account. (`hoursdemo.localhost` has no subdomain under that rule.)
When done: `docker compose -f deploy/demo/compose.yml --env-file deploy/demo/.env down -v`.
