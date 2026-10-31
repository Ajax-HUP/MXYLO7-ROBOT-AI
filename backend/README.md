# FR3DDY AI Advanced — backend setup

This folder contains a Cloudflare Worker that calls the OpenAI Responses API from a server, verifies a Supabase login, and checks Premium membership before answering.

## Required adult-managed setup
An adult project owner must set up and supervise any paid API account or billing. Do not paste API keys, passwords, or service-role keys into chat or commit them to Git.

1. Create/configure a Supabase project and deploy the existing website authentication. Set the site's allowed redirect URL to https://ajax-hup.github.io/MXYLO7-ROBOT-AI/.
2. Run supabase-premium.sql in the Supabase SQL editor.
3. Deploy worker.js as a Cloudflare Worker.
4. Set Worker secrets/variables: OPENAI_API_KEY (secret), SUPABASE_SERVICE_ROLE_KEY (secret), SUPABASE_ANON_KEY, SUPABASE_URL, ALLOWED_ORIGIN=https://ajax-hup.github.io. Optionally set OPENAI_MODEL.
5. Add Premium membership rows only after an administrator has verified eligibility/payment outside this starter project. This repository does not process payments.
6. Configure the frontend to call the Worker with the signed-in user's Supabase access token.

## Important
The website is static GitHub Pages. It cannot safely store an OpenAI API key. This Worker is a backend scaffold and is not active until deployed and configured. Premium access is checked server-side; do not rely on a browser-only Premium toggle. Apply rate limits and usage budgets before public launch. Forex answers are educational only; no live trade signals or order execution.
