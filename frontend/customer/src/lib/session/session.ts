/** Returns a stable UUID scoped to the browser tab (sessionStorage). Falls back
 *  to a fresh random UUID when sessionStorage is unavailable (SSR or privacy
 *  browsers). */
export function getOrCreateSessionId(): string {
  const KEY = 'menuray.session_id';
  if (typeof sessionStorage === 'undefined') return crypto.randomUUID();
  let v = sessionStorage.getItem(KEY);
  if (!v) {
    v = crypto.randomUUID();
    sessionStorage.setItem(KEY, v);
  }
  return v;
}
