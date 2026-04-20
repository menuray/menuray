import type { SupabaseClient } from '@supabase/supabase-js';

declare global {
  namespace App {
    interface Locals {
      supabase: SupabaseClient;
    }
    interface PageData {
      lang?: string;
    }
    interface Error {
      code?: string;
    }
  }
}

export {};
