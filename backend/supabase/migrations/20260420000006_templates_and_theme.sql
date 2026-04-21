-- ============================================================================
-- Templates: curated reference table selected per menu. Customization via a
-- JSONB override column on menus lets us add new dimensions (accent, font, …)
-- without another migration. See spec:
-- docs/superpowers/specs/2026-04-20-launch-templates-design.md §3.1
-- ============================================================================

-- ---------- templates ------------------------------------------------------
CREATE TABLE templates (
  id                 text PRIMARY KEY,       -- slug-style: 'minimal','grid',…
  name               text NOT NULL,
  description        text,
  preview_image_url  text,                   -- relative path under customer static/
  is_launch          boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

INSERT INTO templates (id, name, description, preview_image_url, is_launch) VALUES
  ('minimal', 'Minimal', 'Clean single column; whitespace-first for cafes, ramen, fast-casual.',
   '/templates/minimal.png', true),
  ('grid',    'Grid',    '2–3 column photo cards for menus with strong imagery (bubble tea, pizza).',
   '/templates/grid.png', true),
  ('bistro',  'Bistro',  'Editorial magazine feel. Coming soon.',
   '/templates/bistro.png', false),
  ('izakaya', 'Izakaya', 'Dense multi-section nightlife layout. Coming soon.',
   '/templates/izakaya.png', false),
  ('street',  'Street',  'Bold, high-contrast poster feel. Coming soon.',
   '/templates/street.png', false);

-- ---------- menus additions -----------------------------------------------
ALTER TABLE menus
  ADD COLUMN template_id      text NOT NULL DEFAULT 'minimal'
                              REFERENCES templates(id),
  ADD COLUMN theme_overrides  jsonb NOT NULL DEFAULT '{}'::jsonb;

-- ---------- RLS on templates ----------------------------------------------
ALTER TABLE templates ENABLE ROW LEVEL SECURITY;

-- Static reference table: everyone (anon + authenticated) can read.
CREATE POLICY templates_public_read ON templates FOR SELECT
  USING (true);
-- No INSERT/UPDATE/DELETE policies → only service_role can mutate,
-- which is exactly what we want for a curated reference table.

-- ---------- trigger to keep updated_at fresh on templates -----------------
CREATE TRIGGER templates_touch_updated_at BEFORE UPDATE ON templates
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
