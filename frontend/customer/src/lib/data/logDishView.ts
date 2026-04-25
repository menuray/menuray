import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

const DEV_URL = 'http://127.0.0.1:54321';
const DEV_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

export async function logDishView(args: {
  menuId: string;
  dishId: string;
  sessionId: string;
  qrVariant?: string | null;
}): Promise<void> {
  const url = PUBLIC_SUPABASE_URL || DEV_URL;
  const key = PUBLIC_SUPABASE_ANON_KEY || DEV_ANON_KEY;
  try {
    await fetch(`${url}/functions/v1/log-dish-view`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: key,
      },
      body: JSON.stringify({
        menu_id: args.menuId,
        dish_id: args.dishId,
        session_id: args.sessionId,
        qr_variant: args.qrVariant ?? null,
      }),
    });
  } catch (e) {
    // Fire-and-forget; never surface to the customer.
    console.warn('logDishView failed (non-fatal)', e);
  }
}
