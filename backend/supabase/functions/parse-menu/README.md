# parse-menu — Edge Function

Turns `{ run_id }` into a completed draft menu by running the OCR → structuring pipeline. P0 uses mock adapters; real OCR / LLM providers are a future session.

## Contract

- **Method:** `POST`
- **Auth:** user JWT in `Authorization: Bearer <token>`.
- **Body:** `{ "run_id": "<uuid>" }`. The `parse_runs` row must already exist and belong to the caller (enforced by RLS).
- **Response:** `{ "run_id": "<uuid>", "status": "succeeded" | "failed" }`.
- **Idempotency:** re-invoking with the same `run_id` after terminal status returns the existing status without reprocessing.

## Local test

After `supabase start` + `supabase db reset`, the seed has a pre-completed run `22222222-...`. Smoke-test by creating a fresh pending run:

```bash
# Obtain the seed user's JWT via email/password.
ANON_KEY=$(supabase status --output env | grep ANON_KEY | cut -d= -f2- | tr -d '"')
curl -s -X POST "http://localhost:54321/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"seed@menuray.app","password":"demo1234"}' \
  | jq -r .access_token > /tmp/seed_jwt.txt
JWT=$(cat /tmp/seed_jwt.txt)

# Insert a fresh pending parse_runs row.
DB=$(docker ps --format '{{.Names}}' | grep supabase_db | head -1)
docker exec "$DB" psql -U postgres -d postgres -c \
  "INSERT INTO parse_runs (store_id, source_photo_paths, status)
   SELECT id, ARRAY[id || '/smoke-test.jpg']::text[], 'pending'
   FROM stores WHERE owner_id = '11111111-1111-1111-1111-111111111111';"

NEW_RUN=$(docker exec "$DB" psql -U postgres -d postgres -Atc \
  "SELECT id FROM parse_runs WHERE status='pending' ORDER BY created_at DESC LIMIT 1;")

curl -s -X POST "http://localhost:54321/functions/v1/parse-menu" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"run_id\":\"$NEW_RUN\"}"
# Expect: {"run_id":"<uuid>","status":"succeeded"}
```

Verify the resulting menu was inserted:

```bash
docker exec "$DB" psql -U postgres -d postgres -c \
  "SELECT name, status FROM menus ORDER BY created_at DESC LIMIT 2;"
```

## Swapping providers

Two env vars control which provider runs:
- `MENURAY_OCR_PROVIDER` (default `mock`)
- `MENURAY_LLM_PROVIDER` (default `mock`)

Add a new provider by:
1. Implementing `OcrProvider` or `LlmProvider` (see `../_shared/providers/types.ts`).
2. Dropping the file in `../_shared/providers/`.
3. Adding one `case` in `../_shared/providers/factory.ts`.
4. Setting the env var in the Supabase dashboard (or `supabase/.env` locally).
