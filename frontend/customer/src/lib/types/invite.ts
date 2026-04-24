export type InviteErrorCode =
  | 'invalid_or_expired_invite'
  | 'invite_expired'
  | 'must_be_signed_in'
  | 'internal_error';

export type AcceptInviteResult =
  | { ok: true; storeId: string }
  | { ok: false; code: InviteErrorCode };
