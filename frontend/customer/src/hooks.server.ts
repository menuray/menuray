import type { Handle } from '@sveltejs/kit';
import { createSupabaseClient } from '$lib/supabase';

export const handle: Handle = async ({ event, resolve }) => {
  event.locals.supabase = createSupabaseClient();
  return resolve(event);
};
