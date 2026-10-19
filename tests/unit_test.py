"""Unit tests for kit/nyyo_crm.py (standard library unittest).   python3 -m unittest -v tests/unit_test.py"""
import os, sys, tempfile, unittest
HERE = os.path.dirname(os.path.abspath(__file__)); KIT = os.path.join(HERE, "..")
sys.path.insert(0, os.path.join(KIT, "kit"))
import nyyo_crm as k

S = k.load_settings(os.path.join(KIT, "config", "settings.example.ini"))
def msg(name): return k.read_message(os.path.join(KIT, "samples", "inbox", name))
def row(name, **over): return k.analyse(msg(name), dict(S, **over), {})


class Extraction(unittest.TestCase):
    def test_lead_fields(self):
        r = row("01_website_lead.eml")
        self.assertEqual((r["category"], r["from_name"], r["from_email"], r["company"], r["phone"], r["budget"], r["needs_human"]),
                         ("new_lead", "Maya Chen", "maya.chen@example.com", "Brightleaf Studio", "+1 415 555 0142", "$4,000", "no"))
    def test_quote(self):
        r = row("02_quote_request.eml"); self.assertEqual((r["category"], r["company"]), ("quote_request", "Tallpine Logistics"))
    def test_complaint_needs_human(self):
        r = row("03_complaint.eml")
        self.assertEqual((r["category"], r["order_id"], r["amount"], r["phone"], r["needs_human"]), ("complaint", "A19-7742", "$290", "", "yes"))
        self.assertIn("A19-7742", r["draft_reply"])
    def test_billing(self):
        r = row("04_billing.txt"); self.assertEqual((r["category"], r["order_id"], r["amount"], r["received"]), ("billing", "INV-8821", "$79", "2026-10-14 15:30"))
    def test_support_and_spam(self):
        self.assertEqual(row("05_support.txt")["category"], "support")
        sp = row("06_spam.txt"); self.assertEqual((sp["category"], sp["draft_reply"]), ("spam", ""))
    def test_lead_without_email(self):
        r = row("07_lead_no_email.txt")
        self.assertEqual((r["from_name"], r["from_email"], r["phone"], r["budget"], r["needs_human"]), ("Tom", "", "0161 496 0718", "$1,500", "yes"))
    def test_injection_flagged(self):
        r = row("08_tricky_lead.eml"); self.assertEqual(r["needs_human"], "yes"); self.assertIn("instructions", r["needs_human_reason"])
    def test_no_drafts_option(self):
        self.assertEqual(row("01_website_lead.eml", draft_replies="no")["draft_reply"], "")
    def test_threshold(self):
        self.assertEqual(row("01_website_lead.eml", confidence_threshold=0.99)["needs_human"], "yes")


class Safety(unittest.TestCase):
    def test_sheet_safe(self):
        for v in ("=1+1", "+cmd", "-2", "@SUM(A1)"): self.assertTrue(k.sheet_safe(v).startswith("'"))
        self.assertEqual(k.sheet_safe("Brightleaf"), "Brightleaf")
    def test_clean_ai_rejects_bad_values(self):
        r = k.clean_ai({"category": "send_everything", "confidence": "high", "from_email": "not an email", "summary": "x" * 500})
        self.assertEqual((r["category"], r["confidence"], r["from_email"], len(r["summary"])), ("other", 0.0, "", 140))
    def test_redact(self):
        env = {"HUBSPOT_TOKEN": "abc123secret", "TELEGRAM_BOT_TOKEN": "12:AB/CD"}
        self.assertEqual(k.redact("x abc123secret y 12:AB/CD z 12%3AAB/CD", env), "x <HUBSPOT_TOKEN> y <TELEGRAM_BOT_TOKEN> z <TELEGRAM_BOT_TOKEN>")
    def test_crm_only_leads_with_email(self):
        s = dict(S, crm="hubspot", alerts="slack", alert_on="needs_human")
        dest = lambda n: [r[0] for r in k.plan_requests(row(n), s, {})]
        self.assertEqual(dest("01_website_lead.eml"), ["crm"])
        self.assertEqual(dest("06_spam.txt"), [])
        self.assertEqual(dest("07_lead_no_email.txt"), ["slack"])
        self.assertEqual(dest("03_complaint.eml"), ["slack"])
    def test_pipedrive_two_steps(self):
        reqs = k.plan_requests(row("01_website_lead.eml"), dict(S, crm="pipedrive"), {"PIPEDRIVE_API_TOKEN": "t"})
        self.assertEqual([r[2].rsplit("/", 1)[1] for r in reqs], ["persons", "leads"])


class Settings(unittest.TestCase):
    def write(self, text):
        f = tempfile.NamedTemporaryFile("w", suffix=".ini", delete=False); f.write(text); f.close(); return f.name
    def test_bad_values(self):
        p = self.write("[ai]\nprovider = magic\n[send]\ncrm = salesforce\n")
        with self.assertRaises(k.ConfigError) as c: k.load_settings(p)
        self.assertIn("salesforce", str(c.exception)); self.assertIn("magic", str(c.exception))
    def test_defaults_and_secrets(self):
        p = self.write("[ai]\nprovider = openai\n[send]\ncrm = airtable\nalerts = both\n")
        s = k.load_settings(p)
        self.assertEqual(s["ai_model"], "gpt-4.1-mini")
        self.assertEqual(k.required_secrets(s), ["OPENAI_API_KEY", "AIRTABLE_TOKEN", "AIRTABLE_BASE_ID", "AIRTABLE_TABLE",
                                                 "SLACK_WEBHOOK_URL", "TELEGRAM_BOT_TOKEN", "TELEGRAM_CHAT_ID"])
    def test_env_file(self):
        f = tempfile.NamedTemporaryFile("w", delete=False); f.write("# c\nHUBSPOT_TOKEN='q1w2e3'\n\nAIRTABLE_TABLE=Leads\n"); f.close()
        self.assertEqual(k.load_env(f.name)["HUBSPOT_TOKEN"], "q1w2e3")
        self.assertTrue(k.placeholder("your-hubspot-private-app-token")); self.assertFalse(k.placeholder("q1w2e3"))


if __name__ == "__main__":
    unittest.main()
