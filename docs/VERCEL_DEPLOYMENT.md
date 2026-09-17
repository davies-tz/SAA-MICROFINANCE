# Deploying to Vercel — Step-by-Step Guide

This is a complete, self-contained walkthrough for taking this project from a fresh checkout on a new computer to a live Vercel deployment. It assumes no prior context beyond having the project files.

The codebase is already Vercel-ready ([`api/index.ts`](../api/index.ts) exports the Express app as a serverless function, [`vercel.json`](../vercel.json) routes requests to it, and rate-limiting/OTP state lives in the database instead of in memory). What's described below is everything Vercel itself does **not** provide for you: a database, secrets, and the deploy/configure steps.

---

## What you'll need before starting

- **The project files** on this computer (see Step 1)
- **Node.js 20+** installed ([nodejs.org](https://nodejs.org/))
- **A free [Vercel](https://vercel.com) account**
- **A free [Neon](https://neon.tech) account** (or any other managed PostgreSQL provider — Supabase, RDS, etc. work too; this guide uses Neon since it's free and Vercel's own "Vercel Postgres" is powered by it)

Vercel does **not** host a database for you, and does **not** run a persistent process — this guide covers wiring up both.

---

## Step 1: Get the code onto this computer

If you have a Git remote (e.g. GitHub) for this project, clone it:
```bash
git clone <your-repo-url>
cd microfinance-management-system
```

Otherwise, copy the project folder over directly (zip/USB/cloud drive — whatever's convenient). Either way, do **not** copy your old `.env` file along with real secrets in it if you're setting up fresh credentials for this deployment — you'll generate new ones below.

## Step 2: Install dependencies

```bash
npm install
```

This is needed locally even though the app itself will run on Vercel — you'll use your local `npm run db:push` in Step 4 to set up the remote database, since Vercel has no way to run that for you.

## Step 3: Create the PostgreSQL database (Neon)

1. Go to [neon.tech](https://neon.tech) and sign up / log in.
2. Click **New Project**. Pick any name and region (pick a region close to where you'll set Vercel's region, if you care about latency — not required to get it running).
3. Once created, open the project's **Connection Details** panel. You'll see a connection string like:
   ```
   postgresql://<user>:<password>@<host>/<dbname>?sslmode=require
   ```
4. Neon gives you two hostnames: a **direct** connection and a **pooled** connection (the pooled one has `-pooler` in the hostname, e.g. `ep-xxx-pooler.region.aws.neon.tech`). **Use the pooled one for Vercel** — a serverless platform can spin up many concurrent function instances, each opening its own small connection pool, and the pooled endpoint (backed by PgBouncer) handles that gracefully; the direct endpoint can run out of connections under concurrent load.
5. From that connection string, note down these four values (you'll need them in Step 5):
   - `SQL_HOST` = the pooled host (the part after `@`, before `/`)
   - `SQL_DB_NAME` = the database name (after the `/`)
   - `SQL_ADMIN_USER` = the user
   - `SQL_ADMIN_PASSWORD` = the password

## Step 4: Create the database tables

The app never auto-creates tables — this is a one-time step you run from your own machine, pointed at the new Neon database.

Create a `.env` file in the project root (copy `.env.example` if you don't have one) and fill in the values from Step 3, plus enable SSL:

```
SQL_HOST=<your-neon-pooled-host>
SQL_DB_NAME=<your-db-name>
SQL_ADMIN_USER=<your-user>
SQL_ADMIN_PASSWORD=<your-password>
SQL_SSL=true
```

Then run:
```bash
npm run db:push
```

You should see a list of `CREATE TABLE` statements followed by `[✓] Changes applied`. This only needs to be done once (and again in the future only if `src/db/schema.ts` changes).

> Demo data (branches, staff, chart of accounts, etc.) does **not** need a separate seeding step — the app seeds itself automatically the first time it receives a request against an empty database, once it's deployed and live.

## Step 5: Generate secrets

Run this twice to get two different random values:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Save the two outputs — you'll use the first as `JWT_SECRET` and the second as `MOMO_WEBHOOK_SECRET` in Step 7. These sign session tokens and verify mobile-money webhook signatures; the app refuses to start in production without them, on purpose.

## Step 6: Deploy to Vercel

### Option A — Vercel CLI (works even without a GitHub repo)

```bash
npx vercel login
```
Follow the prompt (opens a browser to authenticate).

```bash
npx vercel
```
This will ask a few questions the first time (link to an existing project or create a new one — choose "create new" if this is the first deploy; accept the detected settings). This creates a **preview** deployment.

Once you've set the environment variables (Step 7), deploy to production:
```bash
npx vercel --prod
```

### Option B — Vercel Dashboard (requires the code to be pushed to GitHub/GitLab/Bitbucket first)

1. Push this project to a GitHub repository if it isn't already there.
2. Go to [vercel.com/new](https://vercel.com/new) and import that repository.
3. Vercel should auto-detect the settings from `vercel.json` — leave the build/output settings as detected.
4. Don't click Deploy yet — set the environment variables first (Step 7), then deploy.

## Step 7: Set environment variables in Vercel

In the Vercel dashboard: **your project → Settings → Environment Variables**. Add each of these (tick **Production**, and also **Preview**/**Development** if you want preview deployments to work too):

| Name | Value |
| --- | --- |
| `SQL_HOST` | From Step 3 (the pooled host) |
| `SQL_DB_NAME` | From Step 3 |
| `SQL_ADMIN_USER` | From Step 3 |
| `SQL_ADMIN_PASSWORD` | From Step 3 |
| `SQL_SSL` | `true` |
| `JWT_SECRET` | First random value from Step 5 |
| `MOMO_WEBHOOK_SECRET` | Second random value from Step 5 |

If you used the CLI instead of the dashboard, you can add these the same way through the dashboard's UI (easiest), or via `npx vercel env add <NAME>` once per variable.

After adding/changing environment variables, you must **redeploy** for them to take effect — either push a new commit, or run `npx vercel --prod` again, or use the "Redeploy" button in the dashboard's Deployments tab.

## Step 8: Verify it's working

Once deployed, Vercel gives you a URL like `https://your-project.vercel.app`. Check:

1. **Health check**: open `https://your-project.vercel.app/api/health` — should return `{"status":"ok","database":"connected",...}`. If this fails, see Troubleshooting below.
2. **Login**: open the app itself and sign in with any seeded demo account (see the login screen's demo picker), password `Imara@2025`.

The very first request may be a little slow (serverless cold start + one-time database seeding) — that's expected.

---

## Troubleshooting

**`/api/health` returns an error, or every request 500s.**
Check the function's logs: Vercel dashboard → your project → **Deployments** → click the latest deployment → **Functions** tab → click the function to see its logs. Common causes:
- `JWT_SECRET environment variable must be set in production` — an env var from Step 7 is missing or wasn't set for the "Production" environment; add it and redeploy.
- A Postgres connection error — double check `SQL_HOST`/`SQL_DB_NAME`/`SQL_ADMIN_USER`/`SQL_ADMIN_PASSWORD` match Step 3 exactly, and that `SQL_SSL=true` is set (Neon requires SSL; without it the connection is refused outright).

**Login works but every request is slow.**
You're likely using Neon's *direct* connection host instead of the *pooled* (`-pooler`) one from Step 3 — under concurrent Vercel invocations that can queue on connection limits. Switch `SQL_HOST` to the pooled host and redeploy.

**Mobile money "Simulate Payment" button in the UI doesn't do what you expect.**
That's expected and correct — it calls `/api/mobile-money/simulate`, which is a *staff-authenticated* test action, separate from `/api/mobile-money/webhook`, which is the real endpoint a mobile money provider would call and requires a valid HMAC signature computed with `MOMO_WEBHOOK_SECRET`. Wiring up a real provider integration is a separate task from this deployment guide.

**I changed `src/db/schema.ts` after deploying.**
Run `npm run db:push` again from your local machine (pointed at the same remote database via your `.env`) before/after deploying the code change — schema changes are never applied automatically.

---

## Alternative: skip all of this

If an external database provider and serverless-specific configuration is more than you want to deal with, the same [Dockerfile](../Dockerfile) used for local testing deploys unchanged to any host that runs a plain long-running container — Render, Railway, Fly.io, Google Cloud Run, or a VPS — with a normal Postgres you fully control, no pooled-connection-string caveats, and no per-serverless-instance connection limits to think about. See the main [README](../README.md#deploying-elsewhere-containers--vps).
