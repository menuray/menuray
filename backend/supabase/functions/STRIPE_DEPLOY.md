# Stripe deployment runbook

Six prerequisites before billing flips on in production.

## 1. Create products + prices in Stripe Dashboard (test + live)

| Product | Currency | Period | Amount | Price ID env var |
|---|---|---|---|---|
| Pro    | USD | Monthly | $19    | `STRIPE_PRICE_PRO_USD_MONTHLY`     |
| Pro    | USD | Annual  | $192   | `STRIPE_PRICE_PRO_USD_ANNUAL`      |
| Pro    | CNY | Monthly | ¥138   | `STRIPE_PRICE_PRO_CNY_MONTHLY`     |
| Growth | USD | Monthly | $49    | `STRIPE_PRICE_GROWTH_USD_MONTHLY`  |
| Growth | USD | Annual  | $504   | `STRIPE_PRICE_GROWTH_USD_ANNUAL`   |
| Growth | CNY | Monthly | ¥358   | `STRIPE_PRICE_GROWTH_CNY_MONTHLY`  |

CNY annual is intentionally absent (P-4: WeChat/Alipay don't natively support recurring annual yet).

## 2. Enable WeChat Pay + Alipay (Stripe Dashboard → Settings → Payment methods)

Required for CNY checkout flow. May require business verification.

## 3. Configure webhook endpoint (Dashboard → Developers → Webhooks)

URL: `https://<your-project>.supabase.co/functions/v1/handle-stripe-webhook`
Events: `checkout.session.completed`, `customer.subscription.updated`,
        `customer.subscription.deleted`, `invoice.payment_failed`
Copy signing secret → `STRIPE_WEBHOOK_SECRET` Edge Function secret.

## 4. Set Edge Function secrets

```
supabase secrets set \
  STRIPE_SECRET_KEY=sk_live_… \
  STRIPE_WEBHOOK_SECRET=whsec_… \
  STRIPE_PRICE_PRO_USD_MONTHLY=price_… \
  STRIPE_PRICE_PRO_USD_ANNUAL=price_… \
  STRIPE_PRICE_PRO_CNY_MONTHLY=price_… \
  STRIPE_PRICE_GROWTH_USD_MONTHLY=price_… \
  STRIPE_PRICE_GROWTH_USD_ANNUAL=price_… \
  STRIPE_PRICE_GROWTH_CNY_MONTHLY=price_… \
  PUBLIC_APP_URL=https://app.menuray.com
```

## 5. Local dev with Stripe CLI

```
stripe listen --forward-to http://127.0.0.1:54321/functions/v1/handle-stripe-webhook
```

Copy the printed signing secret to `.env.local`.

## 6. Manual smoke (test mode)

1. Open `/upgrade` in the merchant app.
2. Tap **Subscribe to Pro**, currency USD.
3. On Stripe Checkout: card `4242 4242 4242 4242`, any future expiry, any CVC.
4. Wait for redirect; webhook should flip `subscriptions.tier` and the user's owned `stores.tier`.
5. Open the customer view for any of those stores' published menus → MenuRay badge gone.
6. Repeat with currency CNY + WeChat Pay test method (Stripe test mode supports it).
7. **Manage billing → Cancel subscription** → wait for `customer.subscription.deleted` webhook → tier flips back to `free`.
