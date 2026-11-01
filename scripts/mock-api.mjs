// Dev-only stand-in for the real API. Stores links in memory. Never deployed.
import { createServer } from "node:http";
import { randomBytes } from "node:crypto";

const PORT = 3001;
const links = new Map();
const cors = {
  "Access-Control-Allow-Origin": "http://localhost:3000",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function send(res, status, body, headers = {}) {
  res.writeHead(status, { "Content-Type": "application/json", ...cors, ...headers });
  res.end(body === undefined ? "" : JSON.stringify(body));
}

createServer((req, res) => {
  if (req.method === "OPTIONS") return send(res, 204);

  if (req.method === "POST" && req.url === "/links") {
    let raw = "";
    req.on("data", (chunk) => (raw += chunk));
    req.on("end", () => {
      let url;
      try {
        url = new URL(JSON.parse(raw).url);
      } catch {
        return send(res, 400, { error: "URL must start with http:// or https://" });
      }
      if (!["http:", "https:"].includes(url.protocol)) {
        return send(res, 400, { error: "URL must start with http:// or https://" });
      }
      const code = randomBytes(5).toString("base64url").slice(0, 7);
      links.set(code, url.href);
      send(res, 201, { code, short_url: `http://localhost:${PORT}/${code}`, long_url: url.href });
    });
    return;
  }

  const code = (req.url ?? "").slice(1);
  if (req.method === "GET" && links.has(code)) {
    return send(res, 302, undefined, { Location: links.get(code) });
  }
  send(res, 404, { error: "Link not found" });
}).listen(PORT, () => console.log(`Mock API running on http://localhost:${PORT}`));