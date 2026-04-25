# translate-menu Edge Function

Batched per-menu translation. Takes `{ menu_id, target_locale }`; reads
categories + dishes; calls the configured `TranslateProvider`; upserts
`category_translations` + `dish_translations`; bumps
`menus.available_locales`. Logs the call to `ai_runs`.

## Local smoke

```bash
supabase functions serve translate-menu --env-file ./supabase/.env.local

curl -X POST http://localhost:54321/functions/v1/translate-menu \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"menu_id":"<uuid>", "target_locale":"ja"}'
```

## Tests

```bash
deno task test
```

5 tests cover: 401 no-auth, 400 missing fields, 402 over locale cap,
429 over monthly quota, 200 happy path with `MockTranslateProvider`.

## Provider switch

Default is `MockTranslateProvider` (deterministic stub used in CI). Set
`MENURAY_LLM_PROVIDER=openai` + `OPENAI_API_KEY` in the function's
secrets to use real `gpt-4o-mini`.
