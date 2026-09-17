// Vercel serverless entry point. Vercel builds every file under /api into
// its own function and invokes the default export per-request - it does
// NOT run `node server.ts` or call app.listen() the way Docker/local dev
// does. This file re-exports the same Express app server.ts builds; the
// isMainModule guard in server.ts keeps app.listen() and the Vite/static
// serving middleware from running here, since Vercel serves the built
// frontend as static output and only routes /api/* to this function (see
// vercel.json).
import { app } from '../server.ts';

export default app;
