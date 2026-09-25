import assert from "node:assert/strict";
import { test } from "node:test";
import { entitlementActive, isPro } from "./entitlements.mjs";

const now = Date.parse("2026-09-25T12:00:00Z");

test("entitlementActive handles active, expired, lifetime and missing", () => {
  assert.equal(entitlementActive({ entitlements: { pro: { expires_date: "2026-10-25T00:00:00Z" } } }, "pro", now), true);
  assert.equal(entitlementActive({ entitlements: { pro: { expires_date: "2026-09-01T00:00:00Z" } } }, "pro", now), false);
  assert.equal(entitlementActive({ entitlements: { pro: { expires_date: null } } }, "pro", now), true);
  assert.equal(entitlementActive({ entitlements: {} }, "pro", now), false);
  assert.equal(entitlementActive(undefined), false);
});

test("isPro queries RevenueCat with the secret key and caches", async () => {
  let calls = 0;
  const fetchImpl = async (url, opts) => {
    calls++;
    assert.match(url, /\/v1\/subscribers\/user%241$/);
    assert.equal(opts.headers.authorization, "Bearer sk_test");
    return { ok: true, json: async () => ({ subscriber: { entitlements: { pro: { expires_date: null } } } }) };
  };
  assert.equal(await isPro("user$1", { secretKey: "sk_test", fetchImpl }), true);
  assert.equal(await isPro("user$1", { secretKey: "sk_test", fetchImpl }), true);
  assert.equal(calls, 1);
  assert.equal(await isPro("", { secretKey: "sk_test", fetchImpl }), false);
  assert.equal(await isPro("x", { secretKey: undefined, fetchImpl }), false);
});
