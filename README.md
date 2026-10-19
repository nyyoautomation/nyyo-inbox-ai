# Inbox AI: classify, extract, draft, and send to your Sheet or CRM

> **For non-technical clients — start here**
>
> **What it does:** Reads a customer email/ticket, tags it (lead, quote, support, complaint, billing, spam), extracts name / email / company / phone / budget / order id / amount, drafts a reply for a person to review, and flags what needs a human.
>
> **Try it in 1 click:** [**live demo**](https://nyyoautomation.github.io/nyyoautomation/demos/inbox-ai/) → click a sample → **Analyze**.
>
> **Business benefit:** faster first answers, fewer missed angry customers. From **$149** (Standard **$399** · Pro **$849**). Delivery: 3 / 5 / 10 days by tier.

![Demo](docs/demo.gif)

**Live:** https://nyyoautomation.github.io/nyyoautomation/demos/inbox-ai/

Nothing is uploaded. Production builds can plug OpenAI/Claude when you provide a key.

## 1-click install kit: inbox → AI → Google Sheet / CRM / alerts
**Included free with the Starter, Standard and Pro packages.** The same idea as the demo, running on your own computer with your own
messages: drop `.eml` or `.txt` files in a folder, run one command, get a Sheet-ready table (`leads.csv`) with the
category, fields, summary, draft reply and a `needs_human` flag. When you are ready it can add each row to your
**Google Sheet**, create leads in **HubSpot, Pipedrive or Airtable**, and alert **Slack or Telegram**.

1. Download [`dist/nyyo-crm-kit.zip`](dist/nyyo-crm-kit.zip) and unzip it.
2. Mac / Linux: `./setup.sh` · Windows: `powershell -ExecutionPolicy Bypass -File .\setup.ps1`
3. Open `output/leads.csv`. It starts with 8 made-up sample messages and the built-in rules (no AI account needed).

- **Dry run by default:** nothing is sent anywhere until you add `--live`; before that, every request it would send
  is saved in `output/outbox/` with your keys removed. It never emails or messages your customers.
- **Your keys, your bill:** OpenAI or Anthropic key in a private `.env` file on your computer, billed to you.
- **Safe to run again:** each message is analysed once, nothing is sent twice, a failed send is retried next run.
- **Careful with AI:** messages are treated as data, not orders; "ignore your instructions" text is flagged for a
  person; spreadsheet formulas in messages are neutralised.
- **Nothing to install:** Python 3.9+ standard library only, no third-party packages.

Beginner guide (Mac first) and every connection step: **[INSTALL.md](INSTALL.md)**.
Test proof: [docs/TESTING.md](docs/TESTING.md). Licence: MIT ([LICENSE](LICENSE)).

| Path | Contents |
|---|---|
| `setup.sh`, `setup.ps1` | One-command run (Mac/Linux, Windows): creates your settings once, then analyses |
| `kit/nyyo_crm.py` | The kit (one file, standard library only) |
| `config/settings.example.ini`, `.env.example` | Settings and key placeholders (your copies are never committed or shipped) |
| `samples/inbox/` | 8 made-up messages: leads, quote, complaint, billing, support, spam, a lead without email, a tricky one |
| `sheets/NyyoCrmWebhook.gs` | Small Apps Script for your Google Sheet (adds rows to a Leads tab, no duplicates) |
| `tests/`, `docs/kit-test-proof/` | Unit tests, stand-ins for every outside service, from-scratch test and its raw output |
| `scripts/build_dist.sh` | Builds the ZIP; refuses to package keys, your own settings, messages or results |
| `dist/` | The kit ZIP and its SHA-256 |

## How to order

Available on LaborX · [Profile & packages](https://github.com/nyyoautomation)

Questions? Ask in your order chat.
