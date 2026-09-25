import assert from "node:assert/strict";
import { test } from "node:test";
import { DailyLimiter, MAX_OUTPUT_TOKENS, MODEL, validateRequest } from "./validate.mjs";

const valid = { system: "You are Astra.", messages: [{ role: "user", content: "Hi" }] };

test("accepts a minimal request and forces the model", () => {
  const r = validateRequest({ ...valid, model: "claude-opus-5" });
  assert.equal(r.ok, true);
  assert.equal(r.params.model, MODEL);
  assert.equal(r.params.system[0].cache_control.type, "ephemeral");
});

test("clamps max_tokens", () => {
  assert.equal(validateRequest({ ...valid, max_tokens: 999_999 }).params.max_tokens, MAX_OUTPUT_TOKENS);
  assert.equal(validateRequest({ ...valid, max_tokens: 1 }).params.max_tokens, 64);
});

test("accepts the app's block-array system prompt", () => {
  const r = validateRequest({ ...valid, system: [{ type: "text", text: "ctx", cache_control: { type: "ephemeral" } }] });
  assert.equal(r.ok, true);
});

test("rejects bad shapes", () => {
  assert.equal(validateRequest(null).ok, false);
  assert.equal(validateRequest({ ...valid, messages: [] }).ok, false);
  assert.equal(validateRequest({ ...valid, messages: [{ role: "system", content: "x" }] }).ok, false);
  assert.equal(validateRequest({ ...valid, messages: [{ role: "assistant", content: "x" }] }).ok, false);
  assert.equal(validateRequest({ ...valid, messages: [{ role: "user", content: "x".repeat(9000) }] }).ok, false);
  assert.equal(validateRequest({ ...valid, system: 42 }).ok, false);
});

test("daily limiter resets each day", () => {
  let now = new Date("2026-09-24T10:00:00Z");
  const l = new DailyLimiter(2, () => now);
  assert.equal(l.take("a"), true);
  assert.equal(l.take("a"), true);
  assert.equal(l.take("a"), false);
  assert.equal(l.take("b"), true);
  now = new Date("2026-09-25T00:00:01Z");
  assert.equal(l.take("a"), true);
});
