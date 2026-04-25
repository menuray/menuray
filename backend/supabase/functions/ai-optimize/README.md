# ai-optimize Edge Function

Batched description rewrite. Takes `{ menu_id }`; reads dishes; calls
the configured `OptimizeProvider`; updates each dish's
`source_description` in place. Logs the call to `ai_runs` (kind=`optimize`).

## Local smoke

```bash
supabase functions serve ai-optimize --env-file ./supabase/.env.local

curl -X POST http://localhost:54321/functions/v1/ai-optimize \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"menu_id":"<uuid>"}'
```

## Tests

```bash
deno task test
```

4 tests cover: 401 no-auth, 400 missing menu_id, 429 over monthly
quota, 200 happy path with `MockOptimizeProvider`.

## Provider switch

Default is `MockOptimizeProvider` (deterministic stub). Set
`MENURAY_LLM_PROVIDER=openai` + `OPENAI_API_KEY` for `gpt-4o-mini`.
