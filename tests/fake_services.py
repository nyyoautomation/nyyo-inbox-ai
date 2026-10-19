#!/usr/bin/env python3
"""Test stand-in for every outside service the kit can call (AI, Google Sheet web app, HubSpot, Pipedrive,
Airtable, Slack, Telegram). Logs each request to a JSONL file. Never contacts the internet.
   python3 tests/fake_services.py PORT LOGFILE FAILFILE"""
import json, re, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT, LOG, FAIL = int(sys.argv[1]), sys.argv[2], sys.argv[3]
KEYS = {"openai": "Bearer test-openai-key-0001", "anthropic": "test-anthropic-key-0002",
        "hubspot": "Bearer test-hubspot-token-0003", "pipedrive": "test-pipedrive-token-0004",
        "airtable": "Bearer test-airtable-token-0005"}
SEEN_EMAILS, PERSON = set(), [100]


def ai_answer(text):
    t = text.lower()
    if "malformed" in t: return "Sure! Here is what I found: category lead, very nice."
    cat = ("complaint" if "unacceptable" in t else "billing" if "charged" in t else "spam" if "backlinks" in t
           else "support" if "password" in t else "quote_request" if "quote" in t else "new_lead")
    m = re.search(r"From: ([^<\n]*)<([^>]*)>", text)
    return json.dumps({"category": cat, "confidence": 0.91, "from_name": (m.group(1).strip() if m else ""),
                       "from_email": "", "company": "Fake AI Co", "phone": "", "summary": "Summary by the fake AI",
                       "budget": "", "order_id": "", "amount": "", "draft_reply": "Draft by the fake AI"})


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def reply(self, code, obj, headers=None):
        b = (obj if isinstance(obj, str) else json.dumps(obj)).encode()
        self.send_response(code)
        for k, v in (headers or {}).items(): self.send_header(k, v)
        self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b)))
        self.end_headers(); self.wfile.write(b)

    def do_GET(self):
        self.log({}); self.reply(200, {"ok": True}) if self.path.startswith("/sheet/echo") else self.reply(404, {})

    def log(self, body):
        with open(LOG, "a") as fh:
            fh.write(json.dumps({"method": self.command, "path": self.path, "headers": dict(self.headers), "body": body}) + "\n")

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0) or 0)).decode()
        try: body = json.loads(raw)
        except Exception: body = raw
        self.log(body)
        svc = self.path.strip("/").split("/")[0]
        fails = open(FAIL).read().split() if FAIL else []
        if svc in fails: return self.reply(500, {"error": "fake outage"})
        auth = self.headers.get("Authorization") or self.headers.get("x-api-key") or self.headers.get("x-api-token")
        if svc in KEYS and auth != KEYS[svc]: return self.reply(401, {"error": "bad key"})
        if svc == "openai":
            return self.reply(200, {"choices": [{"message": {"content": ai_answer(body["messages"][1]["content"])}}]})
        if svc == "anthropic":
            return self.reply(200, {"content": [{"type": "text", "text": ai_answer(body["messages"][0]["content"])}]})
        if svc == "hubspot":
            e = body["properties"]["email"]
            if e in SEEN_EMAILS: return self.reply(409, {"message": "Contact already exists"})
            SEEN_EMAILS.add(e); return self.reply(201, {"id": "1"})
        if self.path == "/pipedrive/v1/persons":
            PERSON[0] += 1; return self.reply(201, {"success": True, "data": {"id": PERSON[0]}})
        if self.path == "/pipedrive/v1/leads": return self.reply(201, {"success": True, "data": {"id": "lead"}})
        if svc == "airtable": return self.reply(200, {"records": [{"id": "rec1"}]})
        if svc == "slack": return self.reply(200, "ok")
        if svc == "telegram":
            if self.path != "/telegram/bottest-telegram-token-0006/sendMessage": return self.reply(401, {"ok": False})
            return self.reply(200, {"ok": True})
        if svc == "sheet":
            if body.get("secret") != "test-sheet-secret-0007": return self.reply(200, {"ok": False, "error": "wrong secret"})
            return self.reply(302, "", {"Location": "/sheet/echo"})   # what a real Apps Script web app does
        self.reply(404, {"error": "unknown"})


ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
