// AstraAI proxy: the iOS app talks to this server, which holds the Anthropic key.
//
//   cp .env.example .env   # then paste your key into .env
//   npm start
//
// Env: PORT (8787), APP_TOKEN (must match the app's ASTRA_APP_TOKEN), DAILY_LIMIT (150 requests/device/day),
//      REVENUECAT_SECRET_KEY (optional): when set, only users with an active "pro" entitlement
//      get Claude; everyone else gets 402 and the app falls back to the free AI.
// Response: Server-Sent Events in the same wire format as the Messages API.
import http from "node:http";
import Anthropic from "@anthropic-ai/sdk";
import { DailyLimiter, validateRequest } from "./validate.mjs";
import { isPro } from "./entitlements.mjs";

const PORT = Number(process.env.PORT ?? 8787);
const APP_TOKEN = process.env.APP_TOKEN ?? "";
const limiter = new DailyLimiter(Number(process.env.DAILY_LIMIT ?? 150));
if (!process.env.ANTHROPIC_API_KEY?.startsWith("sk-ant-")) {
  console.error("Missing ANTHROPIC_API_KEY. Put it in server/.env (see .env.example), then run: npm start");
  process.exit(1);
}
const client = new Anthropic(); // reads ANTHROPIC_API_KEY

function sendJSON(res, status, message) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify({ type: "error", error: { type: "proxy_error", message } }));
}

async function readBody(req, maxBytes = 200_000) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw new Error("payload too large");
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    return res.end(JSON.stringify({ status: "ok" }));
  }
  if (req.method !== "POST" || req.url !== "/v1/messages") return sendJSON(res, 404, "not found");
  if (APP_TOKEN && req.headers["x-astra-token"] !== APP_TOKEN) return sendJSON(res, 401, "unauthorized");

  if (process.env.REVENUECAT_SECRET_KEY) {
    const appUserId = String(req.headers["x-rc-app-user-id"] ?? "").slice(0, 128);
    try {
      if (!(await isPro(appUserId))) return sendJSON(res, 402, "AstraAI Pro required");
    } catch (err) {
      console.error(`entitlement check failed: ${err.message}`);
      return sendJSON(res, 503, "Couldn't verify your subscription. Please try again.");
    }
  }

  const deviceId = String(req.headers["x-device-id"] ?? req.socket.remoteAddress ?? "unknown").slice(0, 64);
  if (!limiter.take(deviceId)) return sendJSON(res, 429, "Daily limit reached. The stars will be back tomorrow.");

  let body;
  try {
    body = await readBody(req);
  } catch {
    return sendJSON(res, 400, "invalid JSON body");
  }
  const checked = validateRequest(body);
  if (!checked.ok) return sendJSON(res, 400, checked.error);

  const stream = client.messages.stream(checked.params);
  req.on("close", () => stream.abort());
  try {
    let started = false;
    for await (const event of stream) {
      if (!started) {
        res.writeHead(200, { "content-type": "text/event-stream", "cache-control": "no-cache" });
        started = true;
      }
      res.write(`event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`);
    }
    res.end();
  } catch (err) {
    if (err instanceof Anthropic.APIUserAbortError) return res.end(); // client went away
    const status = err instanceof Anthropic.RateLimitError ? 429
      : err instanceof Anthropic.AuthenticationError ? 502
      : err instanceof Anthropic.APIError ? (err.status ?? 502)
      : 502;
    if (err instanceof Anthropic.APIError) console.error(`upstream ${err.status}: ${err.message}`);
    else console.error(err);
    if (!res.headersSent) return sendJSON(res, status, "The stars are cloudy right now. Please try again.");
    res.write(`event: error\ndata: ${JSON.stringify({ type: "error", error: { message: "stream interrupted" } })}\n\n`);
    res.end();
  }
});

server.listen(PORT, () => console.log(`AstraAI proxy listening on :${PORT} (model claude-haiku-4-5)`));
