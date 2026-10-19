# How the inbox → CRM kit was tested

**Status:** tested offline on Linux. Not yet tested with real accounts (OpenAI, Anthropic, Google, HubSpot, Pipedrive,
Airtable, Slack, Telegram), on a real Mac, or on Windows (PowerShell 7 on Linux was used for `setup.ps1`).

`tests/run_kit_test.sh` unzips the shipped `dist/nyyo-crm-kit.zip` into an empty folder and uses it like a buyer
would. Every outside service is played by `tests/fake_services.py` on 127.0.0.1 (it never reaches the internet):
the test sets `NYYO_TEST_BASE_URL` and a test `.env` with made-up keys pointing at it. The fake services check the
keys, answer like the real APIs (HubSpot 409 on a duplicate contact, Pipedrive person id, Apps Script 302 redirect,
a 500 outage on demand, an unreadable AI answer), and log every request so the test can count them.

Exit codes are captured right after each command and written at the end of each raw log in
[`kit-test-proof/`](kit-test-proof/). Results: [`kit-test-proof/25_checks.txt`](kit-test-proof/25_checks.txt).

| What | Result |
|---|---|
| Unit tests (17), on the repo and on the shipped copy | pass |
| First run from scratch: settings, private `.env` (600), samples, table = `tests/expected_leads.csv` | pass |
| Default settings send nothing (0 requests) | pass |
| Re-runs: only new messages analysed, nothing sent twice, failed sends retried | pass |
| Bad settings and missing keys stop before sending (exit 3) | pass |
| Dry run plan in `output/outbox/` with every key replaced by its name | pass |
| Google Sheet web app, HubSpot, Pipedrive, Airtable, Slack, Telegram request counts and contents | pass |
| Only leads / quote requests with an email address reach the CRM | pass |
| OpenAI and Anthropic formats, unreadable AI answer, refused key (exit 4) | pass |
| `setup.ps1` (PowerShell 7) gives the same table; Python 3.9 (oldest supported) gives the same table | pass |
| Build guard: same ZIP twice; refuses a `.env`, a pasted key, a real email, payment wording, a real value in `.env.example` | pass |

Run it again: `scripts/build_dist.sh && tests/run_kit_test.sh` (needs python3 and Docker; PowerShell 7 optional).
