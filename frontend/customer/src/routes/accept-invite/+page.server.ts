import type { PageServerLoad } from './$types';
import type { AcceptInviteResult, InviteErrorCode } from '$lib/types/invite';

export const load: PageServerLoad = async ({ url }) => {
  const token = url.searchParams.get('token');
  if (!token) {
    return { result: { ok: false, code: 'invalid_or_expired_invite' as InviteErrorCode } satisfies AcceptInviteResult };
  }
  // SSR does not attempt acceptance — no user session is available server-side.
  // Pass the token to the client which will POST to the Edge Function if the
  // user signs in, else show copy instructions.
  return { token };
};
