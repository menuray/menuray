import Stripe from "npm:stripe@^17";

let _client: Stripe | null = null;

/** Lazy-construct the Stripe client. Throws if STRIPE_SECRET_KEY is missing. */
export function stripeClient(): Stripe {
  if (_client) return _client;
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!key) throw new Error("STRIPE_SECRET_KEY must be set");
  _client = new Stripe(key, {
    httpClient: Stripe.createFetchHttpClient(),  // Deno-friendly
  });
  return _client;
}

/** Map (tier, currency, period) → Stripe Price ID via env vars. Returns null if
 * the combination is unsupported (e.g. CNY + annual). */
export function priceIdFor(
  tier: "pro" | "growth",
  currency: "USD" | "CNY",
  period: "monthly" | "annual",
): string | null {
  if (currency === "CNY" && period === "annual") return null;       // P-4
  const envName = `STRIPE_PRICE_${tier.toUpperCase()}_${currency}_${period.toUpperCase()}`;
  return Deno.env.get(envName) ?? null;
}

/** Reverse-map a Stripe Price ID back to a tier so the webhook can decide what
 * tier to flip to. Returns 'free' if no env var matches. */
export function tierFromPriceId(priceId: string): "free" | "pro" | "growth" {
  const tiers: Array<"pro" | "growth"> = ["pro", "growth"];
  const currencies: Array<"USD" | "CNY"> = ["USD", "CNY"];
  const periods: Array<"monthly" | "annual"> = ["monthly", "annual"];
  for (const tier of tiers) {
    for (const currency of currencies) {
      for (const period of periods) {
        const envName = `STRIPE_PRICE_${tier.toUpperCase()}_${currency}_${period.toUpperCase()}`;
        if (Deno.env.get(envName) === priceId) return tier;
      }
    }
  }
  return "free";
}
