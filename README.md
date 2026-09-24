# Traccar on Railway

One-click [Traccar](https://www.traccar.org/) (open-source GPS tracking, 150+ device protocols) for Railway: the web UI/API on your Railway domain, device ingest published through a Railway TCP proxy, and MySQL persistence — all secrets auto-generated, version pinned (`traccar/traccar:6.15.3-alpine`, MySQL 8).

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.app/new?github_url=https://github.com/lNamelessl/traccar-railway-template)

## What you get

| Service | Image | Ports | Volume |
|---|---|---|---|
| `traccar` | `traccar/traccar:6.15.3-alpine` (+wait-for-db wrapper) | Web UI/API **8082** on your Railway domain; device ingest **TCP 5055** via a Railway TCP proxy (OsmAnd protocol) | `/opt/traccar/data` (logs symlinked into it) |
| `MySQL` | Railway MySQL plugin (8.x) | private network only (3306) | `/var/lib/mysql` |

Everything is pre-wired: the Traccar service runs in env-var mode (`CONFIG_USE_ENVIRONMENT_VARIABLES=true`) with `DATABASE_URL` / `DATABASE_PASSWORD` / `DB_HOST` referencing the MySQL service, so there are **no deploy-form prompts**. The database (`traccar`), the schema, and the TCP proxy are all provisioned automatically.

## After deploying

1. **Log in at your Railway domain** (web UI on port 8082): user `admin`, password `admin`.
2. **Change the admin password immediately** (menu → Account → edit password). Everyone who has ever read the Traccar docs knows the default. The UI will also nag you to change it.
3. **Add a device**: in the UI, Devices → Add → give it a name and a unique ID (e.g. `123456`). The unique ID must match what your device/app reports.
4. **Point devices at the ingest endpoint**:
   - **TCP (native protocol flow)**: open the `traccar` service → Variables tab → copy `RAILWAY_TCP_PROXY_DOMAIN` and `RAILWAY_TCP_PROXY_PORT`. That `host:port` pair is your device server address (OsmAnd protocol, TCP). It is stable for the life of the service.
   - **HTTP (easiest test, works anywhere HTTPS works)**: the OsmAnd protocol also accepts plain HTTP GET on the web port — no TCP config needed:
     ```
     https://<your-domain>/?id=123456&lat=48.137&lon=11.575
     ```
5. Watch the device move: the phone app [OsmAnd](https://www.osmand.net/) has a built-in Traccar/OsmAnd tracking plugin (set the server to your domain or `RAILWAY_TCP_PROXY_DOMAIN:PORT`, device ID matching step 3).

## Variables (reference — all pre-configured)

| Variable | Service | Value |
|---|---|---|
| `DATABASE_URL` | traccar | `jdbc:mysql://${{MySQL.RAILWAY_PRIVATE_DOMAIN}}:3306/traccar?...` (expression) |
| `DATABASE_PASSWORD` | traccar | `${{MySQL.MYSQL_ROOT_PASSWORD}}` (per-deploy generated) |
| `DB_HOST` | traccar | `${{MySQL.RAILWAY_PRIVATE_DOMAIN}}` (expression, used by the boot wait loop) |
| `CONFIG_USE_ENVIRONMENT_VARIABLES`, `DATABASE_DRIVER`, `DATABASE_USER`, `WEB_PORT`, `OSMAND_PORT` | traccar | baked into the image |
| `MYSQL_ROOT_PASSWORD` | MySQL | per-deploy generated |

## Troubleshooting

- **Deploy loops restarting** — MySQL is still initializing on first boot (~1–2 min). The Traccar entrypoint waits up to 5 minutes, then exits so Railway restarts it. Check the `MySQL` deploy logs if it persists.
- **Device not showing positions** — the device's unique ID must exactly match the ID the device/app reports; positions from unknown IDs are discarded. Check `RAILWAY_TCP_PROXY_DOMAIN`/`PORT` under the traccar service Variables tab for the TCP endpoint.
- **Web unreachable but deploy SUCCESS** — make sure you used the Railway domain (8082 is mapped for you; you never need to add `:8082` to the URL).
- **Other protocols** — this template opens exactly one ingest port (TCP 5055, OsmAnd) because Railway allows one TCP proxy per service. The OsmAnd HTTP GET fallback (step 4 above) covers many trackers that can POST/GET custom URLs; for raw proprietary protocols, self-host Traccar.

## Data & persistence

- MySQL data lives on the MySQL volume; devices, positions, and users survive restarts and redeploys.
- Traccar logs are persisted under `/opt/traccar/data/logs` (single-volume design; Railway allows one volume per service).
