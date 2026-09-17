#<div align="center">
# <img width="1200" height="475" alt="GHBanner" src="MASTERMINDNETM 🧠<img width="250" height="280" alt="despicablememinionsGIF" src="https://github.com/user-attachments/assets/7f9200b1-b823-4bf2-ac06-ad92d636ceee" />
.png" />
</div>

# Imara Finance — Microfinance Management System

A modular-monolith microfinance core banking platform (customer/KYC, group lending, loan origination with maker-checker approval, repayment allocation, savings, double-entry general ledger, mobile money integration, offline field sync, and audit trail) built with React + Vite on the frontend and an Express + PostgreSQL (Drizzle ORM) backend.

There are two ways to run it locally: **Docker** (recommended — no local Postgres install needed) or a **native Node.js + local PostgreSQL** setup. A launcher script (`start.bat`) is included for both, on Windows.

---

## Quick Start (Windows)

Double-click **`start.bat`** (or run it from a terminal) and pick an option:

```
1. Run locally (Node.js + local PostgreSQL)
2. Run with Docker (docker compose)
3. Stop Docker containers
4. Exit
```

It handles creating `.env` from `.env.example`, installing dependencies, building/starting the containers, and applying the database schema for you.

---

## Option A: Docker (recommended)

**Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/)

```bash
# 1. Copy the example env file (defaults work out of the box for local Docker use)
cp .env.example .env

# 2. Build and start the app + PostgreSQL containers
docker compose up -d --build

# 3. First run only: create the database tables (tables are never auto-migrated)
docker compose exec -T app npm run db:push
```

The app is now running at **http://localhost:3000**.

> If port `3000` or `5433` is already in use by something else on your machine, set `HOST_APP_PORT` / `HOST_DB_PORT` in `.env` to different values and re-run `docker compose up -d --build`. These only affect the host-side port mapping; the app always reaches Postgres internally as `db:5432`.

Other useful commands:

```bash
docker compose logs app -f     # tail the app's logs
docker compose down            # stop and remove the containers (data volume is kept)
docker compose down -v         # also wipe the database volume
```

See [Dockerfile](Dockerfile) and [docker-compose.yml](docker-compose.yml) for details. The Postgres data persists in a named Docker volume (`db_data`) across restarts.

## Option B: Run locally with Node.js

**Prerequisites:** Node.js 20+, a running local PostgreSQL instance

1. Install dependencies:
   ```bash
   npm install
   ```
2. Copy `.env.example` to `.env` and point `SQL_HOST` / `SQL_DB_NAME` / `SQL_ADMIN_USER` / `SQL_ADMIN_PASSWORD` at your local PostgreSQL instance (create the database first, e.g. `createdb imara_mfi`).
3. Create the database tables (first run only, and whenever `src/db/schema.ts` changes):
   ```bash
   npm run db:push
   ```
4. Run the app:
   ```bash
   npm run dev
   ```

The app is now running at **http://localhost:3000**.

---

## Environment Variables

See [.env.example](.env.example) for the full list with descriptions. The important ones:

| Variable | Required | Purpose |
| --- | --- | --- |
| `SQL_HOST`, `SQL_DB_NAME`, `SQL_ADMIN_USER`, `SQL_ADMIN_PASSWORD` | Yes | PostgreSQL connection |
| `JWT_SECRET` | Yes in production | Signs session tokens. The server refuses to start in production without it. |
| `MOMO_WEBHOOK_SECRET` | Yes in production | Verifies inbound mobile money provider webhook signatures. |
| `PORT` | No (default `3000`) | HTTP port the server listens on |
| `GEMINI_API_KEY` | No | Not currently used by any code path in this app |

## Demo Login

The database is auto-seeded with demo branches, staff, customers, and a chart of accounts on first run. Sign in with any seeded account (see the login screen's demo account picker) using the password:

```
Imara@2025
```

## Available Scripts

| Script | Description |
| --- | --- |
| `npm run dev` | Start the dev server (Vite + Express, with HMR) |
| `npm run build` | Build the frontend and bundle the server for production |
| `npm start` | Run the production build (`dist/server.cjs`) |
| `npm run db:push` | Apply `src/db/schema.ts` to the configured PostgreSQL database |
| `npm run lint` | Type-check with `tsc --noEmit` |

## Deploying to Vercel

The app ships with a Vercel-compatible setup: [`api/index.ts`](api/index.ts) exposes the Express app as a single serverless function, [`vercel.json`](vercel.json) routes `/api/*` to it and serves the built frontend as static output, rate-limiting/OTP state lives in the database instead of in-memory (so it's consistent across serverless instances), and the DB pool auto-adjusts for serverless (see [src/db/index.ts](src/db/index.ts)).

Vercel doesn't host a database or run a persistent process for you, so there are a few things to set up by hand first (an external Postgres, secrets, environment variables). **See [docs/VERCEL_DEPLOYMENT.md](docs/VERCEL_DEPLOYMENT.md) for the full step-by-step guide** — written to be followed on a fresh checkout with no prior context, including troubleshooting for the most common first-deploy issues.

Verified locally: the app builds successfully with the production Docker image (proving the `server.ts` → `api/index.ts` export path works under bundling), and `api/index.ts` imports cleanly and exports a valid Express handler. An actual Vercel deployment/account was not available to test end-to-end from here, so treat the first deploy as a smoke test.

## Deploying Elsewhere (containers / VPS)

For a simpler deploy with no database-provider hunting or serverless caveats, the same [Dockerfile](Dockerfile) used for local testing runs unchanged on any host that supports a long-running container — Render, Railway, Fly.io, Google Cloud Run, or a plain VPS. This avoids the external-Postgres and serverless-state requirements above entirely.
