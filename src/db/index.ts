import { drizzle } from 'drizzle-orm/node-postgres';
import pg from 'pg';
import * as schema from './schema.ts';
import * as dotenv from 'dotenv';

dotenv.config();

const { Pool } = pg;

let poolInstance: pg.Pool | null = null;
let dbInstance: ReturnType<typeof drizzle<typeof schema>> | null = null;

export function getDb() {
  if (!dbInstance) {
    const host = process.env.SQL_HOST;
    const user = process.env.SQL_USER || process.env.SQL_ADMIN_USER;
    const password = process.env.SQL_PASSWORD || process.env.SQL_ADMIN_PASSWORD;
    const database = process.env.SQL_DB_NAME;

    if (!host || !user || !password || !database) {
      throw new Error('Database credentials (SQL_HOST, SQL_USER, SQL_PASSWORD, SQL_DB_NAME) are missing.');
    }

    // Managed Postgres providers (Neon, Supabase, RDS, etc.) require SSL for
    // external connections; local/Docker Postgres does not support it at
    // all. Default off for localhost/docker hosts, on otherwise - override
    // explicitly with SQL_SSL=true|false if a host needs the opposite.
    const isLocalHost = host === 'localhost' || host === '127.0.0.1' || host === 'db';
    const sslEnv = process.env.SQL_SSL;
    const useSSL = sslEnv !== undefined ? sslEnv === 'true' : !isLocalHost;

    // On Vercel (and other serverless platforms), each concurrent function
    // instance gets its own pool - a max of 10 per instance can exhaust a
    // normal Postgres's connection limit under load. Use a serverless-sized
    // pool there (pair with your provider's pooled/pgbouncer connection
    // string) and the normal size for a long-running process (Docker/VPS).
    const isServerless = !!process.env.VERCEL;

    poolInstance = new Pool({
      host,
      user,
      password,
      database,
      max: isServerless ? 1 : 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
      ssl: useSSL ? { rejectUnauthorized: false } : false,
    });

    dbInstance = drizzle(poolInstance, { schema });
  }

  return { db: dbInstance, pool: poolInstance! };
}
