-- ============================================================================
-- parse_runs diagnostic columns. Populated by OpenAI adapters (Session 2)
-- via the FactoryContext onRawResponse callback. Mock providers leave them
-- at the '{}' default. RLS unchanged — existing parse_runs_owner_rw policy
-- already covers these columns.
-- ============================================================================
ALTER TABLE parse_runs
  ADD COLUMN ocr_raw_response jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN llm_raw_response jsonb NOT NULL DEFAULT '{}'::jsonb;
