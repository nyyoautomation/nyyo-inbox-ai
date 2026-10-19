# Inbox → AI → Sheet / CRM kit: one-command install (Mac, Windows, Linux)

> **Status:** tested offline on Linux with stand-ins for every outside service (AI, Google Sheet, HubSpot, Pipedrive, Airtable, Slack, Telegram); see [docs/TESTING.md](docs/TESTING.md). Not yet tested with real accounts of those services, on a real Mac, or on Windows.

This free kit sorts your incoming messages with one AI step. For each message it finds the **category** (new lead,
quote request, support, complaint, billing, spam, other), pulls out **name, email, company, phone, budget, order
number, amount**, writes a short **summary**, prepares a **draft reply** for a person to review, and flags what
**needs a human**. Everything lands in one table you can open in Excel or import into Google Sheets.

When you are ready, it can also add each row to **your Google Sheet**, create the lead in **your CRM** (HubSpot,
Pipedrive or Airtable) and send an **alert to Slack or Telegram**.

**Safe by default:**
- It starts with **8 made-up sample messages** and the **built-in rules** (no AI account, no cost, nothing online).
- **Nothing is sent anywhere** unless you add `--live`. Before that, every request it *would* send is saved in
  `output/outbox/` (with your keys removed) so you can read it first.
- It **never emails or messages your customers**. Draft replies stay in the table for a person to send.
- Your keys stay in one private file on your computer (`.env`). The kit never prints them.

You don't need to know how to code: copy and paste the commands below.

---

## Step 1. Check you have Python (2 minutes)

The kit needs **Python 3.9 or newer**. Nothing else is downloaded.

**Mac**
1. Open **Terminal** (press `Cmd + Space`, type `Terminal`, press Enter).
2. Paste this and press Enter:
   ```bash
   python3 --version
   ```
3. If you see `Python 3.9` or higher, go to Step 2. If a window asks to install "command line developer tools",
   click **Install**, wait until it finishes, then run the command again. You can also install Python from
   python.org (Downloads → macOS).

**Windows**
1. Install Python from python.org (Downloads → Windows). On the first installer screen, tick
   **Add python.exe to PATH**.
2. Open **PowerShell** (Start menu → type `PowerShell`) and check: `py -3 --version`

**Linux:** `python3 --version` (Ubuntu / Debian already have it).

## Step 2. Unzip the kit

Download `nyyo-crm-kit.zip` and double-click it. You get a folder called `nyyo-crm-kit`.
Move it somewhere easy, for example your **Documents** folder.

## Step 3. Run it once with the samples (1 minute)

**Mac / Linux** (in Terminal):
```bash
cd ~/Documents/nyyo-crm-kit
./setup.sh
```
Tip: type `cd ` (with a space) and drag the folder into the Terminal window instead of typing the path.

**Windows** (in PowerShell):
```powershell
cd $HOME\Documents\nyyo-crm-kit
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

The first run creates three things for you, once (they are never overwritten later):

| Created | What it is |
|---|---|
| `config/settings.ini` | Your settings (what to switch on). Open it with any text editor. |
| `.env` | Your private keys, empty for now. Only you can read it. |
| `inbox/` | Your messages. It starts with 8 made-up samples. |

You should see one line per message, then `Finished`. The folder `output` opens with:

| File | What it is |
|---|---|
| `leads.csv` | The table: one row per message (opens in Excel; import into Google Sheets with File → Import). |
| `leads.json` | The same rows for other tools. |
| `outbox/` | What would be sent to your Sheet / CRM / alerts, once you switch them on (dry run). |

Look at the `needs_human` column: in the samples, the complaint, the lead without an email address and the
message that tries to give the AI orders are flagged.

## Step 4. Use your own messages

1. Delete the sample files in `inbox/`.
2. Put your messages there: in Apple Mail or Outlook, drag an email to the folder (it becomes a `.eml` file), or
   save one as a `.txt` file. A website form can be pasted as text too.
3. Run `./setup.sh` again (Windows: the same `setup.ps1` command).

Each message is analysed **once**. Run again any time: only new files are read. To analyse everything again
(after changing settings), add `--reprocess` (Windows: `-Reprocess`).

## Step 5. Switch on the real AI (optional)

The built-in rules are fine for testing. For real messages, an AI model reads them better.

1. Create an API key with your own account: OpenAI (platform.openai.com → API keys) or Anthropic
   (console.anthropic.com → API keys). Usage is billed by them directly to you.
2. Open `.env` in a text editor (Mac: in Finder press `Cmd + Shift + .` to see files starting with a dot;
   Windows: open it with Notepad) and replace `your-openai-key` (or `your-anthropic-key`) with your key. Save.
3. In `config/settings.ini`, under `[ai]`, set `provider = openai` (or `anthropic`). Save.
4. Run setup again with `--reprocess`.

The AI is told that messages are data, not orders: text like "ignore your instructions" is flagged
`needs_human`, and the AI can only fill in the table; it cannot send anything or change where results go.

## Step 6. Connect your Google Sheet, CRM and alerts (optional)

Switch on only what you need in `config/settings.ini` under `[send]`, and fill the matching lines in `.env`.
Then run once **without** `--live` and read the files in `output/outbox/`: that is exactly what will be sent.

**Google Sheet** (`google_sheet = yes`)
1. Open your Google Sheet → **Extensions → Apps Script**.
2. Delete what is there, paste the whole file `sheets/NyyoCrmWebhook.gs`, and on the line `var SECRET = ...` replace
   the text between quotes with a long random phrase of your own. Save.
3. **Deploy → New deployment** → type **Web app** → Execute as **Me**, Who has access **Anyone** → **Deploy**.
   Google asks you to allow access to this spreadsheet only: click **Allow** (if you see "Google hasn't verified
   this app", click **Advanced → Go to ... (unsafe)**: it is your own script).
4. Copy the **Web app URL**. In `.env`, paste it after `GOOGLE_SHEET_WEBHOOK_URL=` and put the same secret phrase
   after `GOOGLE_SHEET_WEBHOOK_SECRET=`.
   Rows go to a tab called **Leads** (created automatically). A row already there is never added twice.

**CRM** (`crm = hubspot`, `pipedrive` or `airtable`): only **new leads and quote requests with an email address**
are sent; complaints, support, billing and spam never go to the CRM.
- **HubSpot:** Settings → Integrations → Private apps → create one with the scope `crm.objects.contacts.write`
  → copy the token to `HUBSPOT_TOKEN`. A contact that already exists is not duplicated.
- **Pipedrive:** your name (top right) → Personal preferences → API → copy the token to `PIPEDRIVE_API_TOKEN`.
  The kit creates a person, then a lead linked to it.
- **Airtable:** create a table (default name **Leads**) with the columns Name, Email, Company, Phone, Category,
  Summary, Budget, Needs human, Message ID. Create a personal access token (airtable.com/create/tokens) with
  `data.records:write` on that base. Fill `AIRTABLE_TOKEN`, `AIRTABLE_BASE_ID` (starts with `app`, in the base URL)
  and `AIRTABLE_TABLE`.

**Alerts** (`alerts = slack`, `telegram` or `both`; `alert_on = needs_human`, `leads` or `all`)
- **Slack:** api.slack.com/apps → Create app → Incoming Webhooks → On → Add to a channel → copy the URL to
  `SLACK_WEBHOOK_URL`.
- **Telegram:** talk to **@BotFather** in Telegram → `/newbot` → copy the token to `TELEGRAM_BOT_TOKEN`. Add the bot to
  your group, send it a message, then open `https://api.telegram.org/bot<your token>/getUpdates` in a browser and
  copy the `chat` → `id` number to `TELEGRAM_CHAT_ID`.

**Check, then send for real:**
```bash
./setup.sh --check      # settings and keys look right, nothing processed
./setup.sh --live       # sends what output/outbox/ showed
```
Windows: `-Check`, then `-Live`.

`--live` keeps a record of what was sent (`output/.state.json`): running it again never sends the same row,
contact or alert twice. If a service is down, the kit retries a few times, reports it, and tries again on the next
run.

---

## Safe to run again

- `config/settings.ini`, `.env` and your messages are never overwritten or changed.
- `leads.csv` is replaced in one step (never left half-written), and keeps every message analysed so far.
- Cells starting with `=`, `+`, `-` or `@` get a leading `'` so a spreadsheet shows them as text and never runs them
  as a formula (a phone number like `+1 415...` shows as `'+1 415...` in a plain text viewer).

## Exit codes (for schedulers)

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | Done, with warnings (a file could not be read, or a send failed and will be retried) |
| 3 | Settings or `.env` need fixing (nothing was sent) |
| 4 | A key was refused by the AI provider |

## Run it every day (optional)

**Mac / Linux:** `crontab -e`, then add (change the path):
`0 8 * * * cd "$HOME/Documents/nyyo-crm-kit" && ./setup.sh --live --no-open >> output/run.log 2>&1`
**Windows:** Task Scheduler → Create Basic Task → Daily → Program `powershell`, arguments
`-ExecutionPolicy Bypass -File "C:\Users\you\Documents\nyyo-crm-kit\setup.ps1" -Live -NoOpen`.

## Troubleshooting

| You see | Do this |
|---|---|
| `Python 3.9 or newer is needed` | Step 1. On Windows, re-run the installer and tick **Add python.exe to PATH**. |
| `permission denied: ./setup.sh` | Run `chmod +x setup.sh` once, or `bash setup.sh`. |
| Mac: "cannot be opened because it is from an unidentified developer" | Run it from Terminal as shown, not by double-clicking. |
| `Missing in .env: ...` | Fill those lines in `.env` (Steps 5–6), or switch that option off in `settings.ini`. |
| `key was refused (HTTP 401)` | The key was copied with a missing character or has expired. Create a new one. |
| `the Sheet refused the row` | The secret in `.env` and in the Sheet script are different. Make them the same. |
| A message gets the wrong category | Switch on the real AI (Step 5). With rules only, short or unusual messages are flagged `needs_human`. |
| `0 new message(s)` | Each file is read once. Add `--reprocess` to read all of them again. |

## Limits (honest)

- Messages are read from files you put in `inbox/`; the kit does not log into your mailbox.
- The AI makes mistakes: check the `needs_human` rows and every draft reply before using it.
- The built-in rules (no AI) are a demo; use your own AI key for real messages.
- Very long messages are cut to the first 8,000 characters for the AI.

## Run the kit's own tests (optional)

```bash
python3 -m unittest -v tests/unit_test.py
```

## Remove everything

Delete the `nyyo-crm-kit` folder. The kit installs nothing else on your computer. If you connected a Google Sheet,
you can also remove the deployment in Apps Script → Deploy → Manage deployments.

Questions? Ask in your order chat.
