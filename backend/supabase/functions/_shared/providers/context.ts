// ============================================================================
// FactoryContext — optional, threaded through the provider factory so real
// providers can persist per-run diagnostics. Mock providers ignore it.
// ============================================================================
import type { SupabaseClient } from "@supabase/supabase-js";

export interface FactoryContext {
  runId: string;
  supabase: SupabaseClient; // service-role client
}
