// Request validation for the AstraAI proxy. Kept separate so it can be unit-tested
// without network access.

export const MODEL = "claude-haiku-4-5";
export const MAX_OUTPUT_TOKENS = 2000;
const MAX_MESSAGES = 40;
const MAX_MESSAGE_CHARS = 8_000;
const MAX_SYSTEM_CHARS = 40_000;

/** Returns { ok: true, params } with sanitized Messages API params, or { ok: false, error }. */
export function validateRequest(body) {
  if (!body || typeof body !== "object") return fail("body must be a JSON object");

  const { messages, system } = body;
  if (!Array.isArray(messages) || messages.length === 0) return fail("messages must be a non-empty array");
  if (messages.length > MAX_MESSAGES) return fail(`at most ${MAX_MESSAGES} messages`);
  for (const m of messages) {
    if (!m || (m.role !== "user" && m.role !== "assistant")) return fail("message role must be user or assistant");
    if (typeof m.content !== "string" || m.content.length === 0) return fail("message content must be a non-empty string");
    if (m.content.length > MAX_MESSAGE_CHARS) return fail("message too long");
  }
  if (messages[0].role !== "user" || messages.at(-1).role !== "user") {
    return fail("conversation must start and end with a user message");
  }

  // Accept a plain string or the app's cacheable [{type:"text", text, cache_control}] form.
  let systemBlocks;
  if (typeof system === "string") {
    systemBlocks = [{ type: "text", text: system, cache_control: { type: "ephemeral" } }];
  } else if (Array.isArray(system) && system.every((b) => b && b.type === "text" && typeof b.text === "string")) {
    systemBlocks = system.map((b) => ({ type: "text", text: b.text, cache_control: { type: "ephemeral" } })).slice(0, 2);
  } else {
    return fail("system must be a string or an array of text blocks");
  }
  if (systemBlocks.reduce((n, b) => n + b.text.length, 0) > MAX_SYSTEM_CHARS) return fail("system prompt too long");

  const requested = Number.isInteger(body.max_tokens) ? body.max_tokens : 1200;
  return {
    ok: true,
    params: {
      model: MODEL, // clients can't pick a pricier model
      max_tokens: Math.min(Math.max(requested, 64), MAX_OUTPUT_TOKENS),
      system: systemBlocks,
      messages: messages.map(({ role, content }) => ({ role, content })),
    },
  };
}

function fail(error) {
  return { ok: false, error };
}

/** Fixed-window daily counter per device. In-memory: swap for Redis/KV when scaling out. */
export class DailyLimiter {
  constructor(limit, now = () => new Date()) {
    this.limit = limit;
    this.now = now;
    this.day = "";
    this.counts = new Map();
  }

  take(deviceId) {
    const today = this.now().toISOString().slice(0, 10);
    if (today !== this.day) {
      this.day = today;
      this.counts.clear();
    }
    const used = this.counts.get(deviceId) ?? 0;
    if (used >= this.limit) return false;
    this.counts.set(deviceId, used + 1);
    return true;
  }
}
