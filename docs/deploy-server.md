# Deploy on Exora server (Docker + gateway nginx)

Matches other apps under `/srv/apps` (Sona, CRM): private port on `127.0.0.1`, TLS on the shared **gateway** container.

## 1. DNS

Point `marketing.exora.solutions` A/AAAA record to the server public IP.

## 2. Clone and configure

```bash
cd /srv/apps
git clone https://github.com/yeshwanth1127/marketing.git
cd marketing
cp .env.production.example .env
# Edit .env: POSTGRES_PASSWORD, META_APP_SECRET, EXORA_TOKEN_KEY (64 hex), META_WEBHOOK_VERIFY_TOKEN, EXORA_INITIAL_PASSWORD
mkdir -p data/local
docker compose up -d --build
```

## 3. TLS + nginx

```bash
certbot certonly --webroot -w /var/www/certbot -d marketing.exora.solutions
cp deploy/nginx/marketing.exora.solutions.conf /srv/gateway/nginx/sites/
docker exec gateway nginx -t && docker exec gateway nginx -s reload
```

## Claude Code login

The Docker image includes the native Claude Code CLI. Web and worker share the
`claude_home` Docker volume for account login state. Keep that volume when
recreating containers.

From an interactive server terminal:

```bash
cd /srv/apps/marketing
docker compose exec web claude auth login
docker compose exec web claude auth status
docker compose exec worker claude auth status
```

Open the login URL in your browser and follow the terminal instructions. Refresh
Settings after login. Set `EXORA_ROUTER_PROVIDER=claude` in `.env` and recreate
the containers to use this login for assistant routing as well. The optional
`EXORA_ROUTER_MODEL` defaults to `haiku`. This uses your Claude account; no Anthropic API key is
required. Both services use the same account and its usage allowance.

## 4. Meta App Dashboard

- **OAuth redirect:** `https://marketing.exora.solutions/api/auth/meta/callback`
- **Webhook URL:** `https://marketing.exora.solutions/api/webhooks/meta`
- **Verify token:** same as `META_WEBHOOK_VERIFY_TOKEN` in `.env`

## 5. Smoke test

```bash
curl -sS http://127.0.0.1:8108/api/health
curl -sS https://marketing.exora.solutions/api/health
```

Sign in with `admin@exora.local` and the password from `EXORA_INITIAL_PASSWORD`, then change it in Settings.

## 6. Full server checklist

See **[server-verification-checklist.md](./server-verification-checklist.md)** — DNS, TLS, Docker, `.env`, Meta OAuth, webhooks, worker, and security checks with copy-paste commands.
