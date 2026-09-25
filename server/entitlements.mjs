// Server-side Pro check: asks RevenueCat whether an app user has an active "pro"
// entitlement, so a modified app can't get Claude without paying.
// Needs REVENUECAT_SECRET_KEY (a *secret* v1 API key, sk_..., from RevenueCat › API keys).

const CACHE_MS = 10 * 60 * 1000;
const cache = new Map(); // appUserId -> { isPro, at }

/** Pure helper: is the entitlement active at `now`? (expires_date null = lifetime) */
export function entitlementActive(subscriber, id = "pro", now = Date.now()) {
  const ent = subscriber?.entitlements?.[id];
  if (!ent) return false;
  if (ent.expires_date == null) return true;
  return Date.parse(ent.expires_date) > now;
}

export async function isPro(appUserId, { secretKey = process.env.REVENUECAT_SECRET_KEY, fetchImpl = fetch } = {}) {
  if (!appUserId || !secretKey) return false;
  const hit = cache.get(appUserId);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.isPro;
  const res = await fetchImpl(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`, {
    headers: { authorization: `Bearer ${secretKey}` },
  });
  if (!res.ok) throw new Error(`RevenueCat ${res.status}`);
  const body = await res.json();
  const result = entitlementActive(body.subscriber);
  cache.set(appUserId, { isPro: result, at: Date.now() });
  return result;
}
