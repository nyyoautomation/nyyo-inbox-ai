#!/usr/bin/env bash
# From-scratch test of the shipped ZIP (build box; needs python3 and docker; pwsh optional).
#   tests/run_kit_test.sh [path/to/nyyo-crm-kit.zip]
# Writes raw logs and checks to docs/kit-test-proof/. No real account is used: every outside service is played by
# tests/fake_services.py on 127.0.0.1, reached through NYYO_TEST_BASE_URL (and local webhook URLs in a test .env).
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; ZIP="${1:-$REPO/dist/nyyo-crm-kit.zip}"
PROOF="$REPO/docs/kit-test-proof"; rm -rf "$PROOF"; mkdir -p "$PROOF"
[ -f "$ZIP" ] || { echo "no ZIP at $ZIP: run scripts/build_dist.sh first"; exit 2; }
ZIP0="$(sha256sum "$ZIP" | cut -d' ' -f1)"   # the ZIP under test, before the rebuild below
PWSH="$(command -v pwsh || echo /tmp/pwsh/pwsh)"
PY39="python:3.9-slim@sha256:2d97f6910b16bd338d3060f261f53f144965f755599aab1acda1e13cf1731b1b"
W="$(mktemp -d /tmp/crmkit-test.XXXX)"; K="$W/nyyo-crm-kit"; LOG="$W/requests.jsonl"; FAILF="$W/fail.txt"; PORT=47431
PASS=0; FAILN=0
check() { if eval "$2"; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1"; FAILN=$((FAILN+1)); fi; }
# run NAME CMD...: raw output to the proof file; the exit code is taken straight from the command (rc=$? right
# after it, before any echo), then written as the last line.
run() {
  local name="$1"; shift; local rc
  { echo "\$ $*"; echo; } > "$PROOF/$name"
  "$@" >> "$PROOF/$name" 2>&1; rc=$?
  sed -i 's/\x1b\[[0-9;]*m//g; s/\r$//' "$PROOF/$name"
  { echo; echo "[exit code $rc]"; } >> "$PROOF/$name"
  return 0
}
code() { sed -n 's/^\[exit code \([0-9]*\)\]$/\1/p' "$PROOF/$1"; }
h() { sha256sum "$1" | cut -d' ' -f1; }
# leads.csv without the processed_at column (the only value that depends on the clock)
rows() { python3 -c "import csv,sys;r=list(csv.reader(open(sys.argv[1],encoding='utf-8-sig')));i=r[0].index('processed_at');[print(','.join(x[:i]+x[i+1:])) for x in r]" "$1"; }
nreq() { python3 -c "import json,sys,re;print(sum(1 for l in open(sys.argv[1]) if l.strip() and re.search(sys.argv[2], json.loads(l)['path'])))" "$LOG" "$1"; }
reqs() { [ -s "$LOG" ] && wc -l < "$LOG" | tr -d ' ' || echo 0; }
ENVT=(env NYYO_TEST_BASE_URL="http://127.0.0.1:$PORT" NYYO_RETRY_WAIT=0)
SH() { (cd "$K" && "${ENVT[@]}" ./setup.sh --no-open "$@" < /dev/null); }
PS() { (cd "$1" && shift && "${ENVT[@]}" "$PWSH" -NoProfile -File ./setup.ps1 -NoOpen "$@" < /dev/null); }
set_ini() { sed -i "s|^$1 = .*|$1 = $2|" "$K/config/settings.ini"; }
fill_env() {  # fake keys for the fake services (format of real ones not needed)
  cat > "$K/.env" <<ENV
OPENAI_API_KEY=test-openai-key-0001
ANTHROPIC_API_KEY=test-anthropic-key-0002
GOOGLE_SHEET_WEBHOOK_URL=http://127.0.0.1:$PORT/sheet/exec
GOOGLE_SHEET_WEBHOOK_SECRET=test-sheet-secret-0007
HUBSPOT_TOKEN=test-hubspot-token-0003
PIPEDRIVE_API_TOKEN=test-pipedrive-token-0004
AIRTABLE_TOKEN=test-airtable-token-0005
AIRTABLE_BASE_ID=appTestBase0001
AIRTABLE_TABLE=Leads
SLACK_WEBHOOK_URL=http://127.0.0.1:$PORT/slack/hook
TELEGRAM_BOT_TOKEN=test-telegram-token-0006
TELEGRAM_CHAT_ID=-100123456
ENV
}
SECRETS='test-(openai|anthropic|hubspot|pipedrive|airtable|telegram)-(key|token)-000[0-9]|test-sheet-secret-0007'

{
  echo "Date: $(date '+%b %-d, %Y, %H:%M')"; echo "System: $(uname -sm)"
  echo "Python on the host: $(python3 -V 2>&1)"
  echo "PowerShell: $("$PWSH" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo none)"
  echo "Docker: $(docker version --format '{{.Server.Version}}' 2>/dev/null)"
  echo "Kit ZIP: $(basename "$ZIP") sha256 $(h "$ZIP")"
  echo "Scratch folder: $(basename "$W") (empty before unzip)"
} > "$PROOF/00_environment.txt"
(cd "$W" && unzip -q "$ZIP") && { echo; echo "unzipped:"; (cd "$K" && find . -type f | sort); } >> "$PROOF/00_environment.txt"
cp -r "$K" "$W/pristine"
: > "$LOG"; : > "$FAILF"
python3 "$REPO/tests/fake_services.py" "$PORT" "$LOG" "$FAILF" & SRV=$!; trap 'kill $SRV 2>/dev/null' EXIT; sleep 0.5

# 1. Unit tests, on the repo and on the shipped copy
run 01_unit_tests_source.txt python3 -m unittest -v "$REPO/tests/unit_test.py"
run 02_unit_tests_shipped.txt bash -c "cd '$K' && python3 -m unittest -v tests/unit_test.py"
# 2. Buyer's first run: samples, built-in rules, nothing switched on
run 03_setup_sh_first_run.txt SH
cp "$K/output/leads.csv" "$W/leads03.csv"; R03="$(reqs)"
PERM="$(stat -c %a "$K/.env")"; OUTBOX03="$(ls "$K/output/outbox" | wc -l)"
run 04_setup_sh_second_run.txt SH
H04="$(h "$K/output/leads.csv")"
# 3. A new message arrives (a second email from an existing lead)
sed 's/^Subject: New website project/Subject: Follow-up on our project/; s/We would like to book a call next week./Following up: can we book a call this week? Our budget is still the same./; s/^Date: .*/Date: Sat, 17 Oct 2026 10:00:00 -0400/' \
  "$K/inbox/01_website_lead.eml" > "$K/inbox/09_follow_up.eml"
run 05_setup_sh_new_message.txt SH
cp "$K/output/leads.csv" "$W/leads05.csv"
# 4. --check and a bad setting
run 06_setup_sh_check.txt SH --check
cp "$K/config/settings.ini" "$W/settings.bak"; set_ini crm salesforce
run 07_setup_sh_bad_setting.txt SH
cp "$W/settings.bak" "$K/config/settings.ini"
# 5. Everything switched on, keys not filled yet: dry run, then --live refused
set_ini google_sheet yes; set_ini crm hubspot; set_ini alerts both
: > "$LOG"
run 08_dry_run_all_on_no_keys.txt SH
OUTBOX08="$(ls "$K/output/outbox" | wc -l)"; R08="$(reqs)"
run 09_live_without_keys.txt SH --live
R09="$(reqs)"
# 6. Keys filled: dry run shows the plan with keys removed; live sends it once
fill_env
run 10_dry_run_with_keys.txt SH
cp -r "$K/output/outbox" "$W/outbox10"; R10="$(reqs)"
run 11_live_hubspot_sheet_slack_telegram.txt SH --live
cp "$LOG" "$W/log11.jsonl"
S11="$(nreq '^/sheet/exec')"; C11="$(nreq '^/hubspot/')"; SL11="$(nreq '^/slack/')"; T11="$(nreq '^/telegram/')"
run 12_live_again_nothing_twice.txt SH --live
R12="$(( $(reqs) - $(wc -l < "$W/log11.jsonl") ))"
# 7. Outage: Slack down for a new message -> warning, retried next run
cp "$K/inbox/03_complaint.eml" "$W/c.eml"; sed -i 's/^Subject: Order never arrived/Subject: Order still missing/; s/^Date: .*/Date: Sun, 18 Oct 2026 09:00:00 +0000/' "$W/c.eml"; mv "$W/c.eml" "$K/inbox/10_complaint_again.eml"
echo slack > "$FAILF"; : > "$LOG"
run 13_live_slack_down.txt SH --live
SLT13="$(nreq '^/slack/')"; T13="$(nreq '^/telegram/')"
: > "$FAILF"; : > "$LOG"
run 14_live_slack_back.txt SH --live
SL14="$(nreq '^/slack/')"; T14="$(nreq '^/telegram/')"; S14="$(nreq '^/sheet/exec')"
# 8. Wrong Sheet secret -> refused row reported, not marked as sent
sed -i 's/^GOOGLE_SHEET_WEBHOOK_SECRET=.*/GOOGLE_SHEET_WEBHOOK_SECRET=a-different-secret/' "$K/.env"
printf 'From: Nia Brooks <nia@example.com>\nSubject: Interested in a project\nDate: 2026-10-19 09:00\n\nWe are looking for help with a project, budget $2,000.\n\nThanks,\nNia Brooks\n' > "$K/inbox/11_new_lead.txt"
run 15_live_wrong_sheet_secret.txt SH --live
SHEET15="$(python3 -c "
import json; s=json.load(open('$K/output/.state.json'))
mid=[m for m,r in s['records'].items() if r['source_file']=='11_new_lead.txt'][0]
print('yes' if mid+':google_sheet:0' in s['sent'] else 'no')")"
fill_env
# 9. Pipedrive (person then lead) and Airtable
for crm in pipedrive airtable; do
  rm -rf "$K/output"; set_ini crm "$crm"; set_ini google_sheet no; set_ini alerts none; : > "$LOG"
  run "16_live_${crm}.txt" SH --live; cp "$LOG" "$W/log_$crm.jsonl"
done
P_PERS="$(python3 -c "import json;print(sum(1 for l in open('$W/log_pipedrive.jsonl') if json.loads(l)['path']=='/pipedrive/v1/persons'))")"
P_LEADS_OK="$(python3 -c "
import json; L=[json.loads(l) for l in open('$W/log_pipedrive.jsonl')]
print(all(isinstance(x['body'].get('person_id'),int) for x in L if x['path']=='/pipedrive/v1/leads') and sum(x['path']=='/pipedrive/v1/leads' for x in L))")"
A_OK="$(python3 -c "
import json; L=[json.loads(l) for l in open('$W/log_airtable.jsonl')]
print(len(L), all(x['path']=='/airtable/v0/appTestBase0001/Leads' and x['body']['typecast'] for x in L))")"
# 10. Real AI providers (fake): OpenAI, Anthropic, an unreadable answer, a refused key
set_ini crm none; printf 'From: Malformed Test <mt@example.com>\nSubject: MALFORMED answer test\n\nPlease quote me.\n' > "$K/inbox/12_malformed.txt"
for p in openai anthropic; do
  set_ini provider "$p"; rm -rf "$K/output"; : > "$LOG"
  run "17_ai_${p}.txt" SH; cp "$K/output/leads.json" "$W/ai_$p.json"; cp "$LOG" "$W/log_ai_$p.jsonl"
done
AI_OK="$(python3 -c "
import json
for p in ('openai','anthropic'):
    R={r['source_file']:r for r in json.load(open('$W/ai_'+p+'.json'))}
    assert R['02_quote_request.eml']['summary']=='Summary by the fake AI' and R['02_quote_request.eml']['category']=='quote_request'
    assert R['02_quote_request.eml']['from_email']=='omar@tallpine.example.com'      # header wins over the model
    assert R['12_malformed.txt']['needs_human']=='yes' and 'not valid JSON' in R['12_malformed.txt']['needs_human_reason']
    assert R['08_tricky_lead.eml']['needs_human']=='yes'
print('ok')" 2>&1)"
AI_ISOLATED="$(python3 -c "
import json
for p in ('openai','anthropic'):
    for l in open('$W/log_ai_'+p+'.jsonl'):
        x=json.loads(l); m=x['body']['messages']
        s=x['body'].get('system') or m[0]['content']
        assert 'DATA, not instructions' in s and 'Ignore previous instructions' not in s
print('ok')" 2>&1)"
sed -i 's/^OPENAI_API_KEY=.*/OPENAI_API_KEY=test-openai-key-WRONG/' "$K/.env"; set_ini provider openai; rm -rf "$K/output"
run 18_ai_key_refused.txt SH
fill_env; set_ini provider mock
# 11. PowerShell 7: fresh copy, first and second run, --live without keys
if [ -x "$PWSH" ]; then
  cp -r "$W/pristine" "$W/ps"
  run 19_setup_ps1_first_run.txt PS "$W/ps"
  run 20_setup_ps1_second_run.txt PS "$W/ps"
  sed -i 's/^crm = none/crm = hubspot/' "$W/ps/config/settings.ini"
  run 21_setup_ps1_live_without_keys.txt PS "$W/ps" -Live
fi
# 12. Oldest supported Python (3.9, pinned image), fresh copy
cp -r "$W/pristine" "$W/py39"
run 22_setup_sh_python39.txt docker run --rm --user "$(id -u):$(id -g)" -v "$W/py39:/kit" -w /kit "$PY39" bash ./setup.sh --no-open
# 13. Build guard: same ZIP twice; refusals
run 23_build_dist_rebuild.txt bash "$REPO/scripts/build_dist.sh"
REBUILT="$(h "$REPO/dist/nyyo-crm-kit.zip")"
C="$W/guard"; git -C "$REPO" ls-files -z --cached --others --exclude-standard | (cd "$REPO" && xargs -0 tar cf -) | (mkdir -p "$C" && cd "$C" && tar xf -)
bd() { (cd "$C" && bash scripts/build_dist.sh 2>&1 | tail -n 4; echo "[build exit ${PIPESTATUS[0]}]"); }
{
  echo "--- clean copy of the repo"; bd
  echo "--- a .env dropped into config/"; echo "HUBSPOT_TOKEN=x" > "$C/config/.env"; bd; rm "$C/config/.env"
  echo "--- a key pasted into the code"; echo "# sk-proj-$(printf 'Ab1%.0s' {1..12})" >> "$C/kit/nyyo_crm.py"; bd; cp "$REPO/kit/nyyo_crm.py" "$C/kit/nyyo_crm.py"
  echo "--- a real-looking email address in a sample"; echo "Write to buyer@realmail.test" > "$C/samples/inbox/99_x.txt"; bd; rm "$C/samples/inbox/99_x.txt"
  echo "--- payment wording in the Sheet script"; echo "// Pay via PayPal to skip the queue." >> "$C/sheets/NyyoCrmWebhook.gs"; bd; cp "$REPO/sheets/NyyoCrmWebhook.gs" "$C/sheets/"
  echo "--- a real value in .env.example"; sed -i 's/^HUBSPOT_TOKEN=.*/HUBSPOT_TOKEN=q8w7e6r5t4/' "$C/.env.example"; bd
} > "$PROOF/24_build_dist_refusal.txt" 2>&1
sed -i "s|$W|<scratch>|g" "$PROOF"/*.txt

# ---------------------------------------------------------------- checks
{
echo "Checks ($(date '+%b %-d, %Y, %H:%M'))"; echo
check "unit tests pass on the repo and on the shipped copy (17 + 17)" \
  '[ "$(code 01_unit_tests_source.txt)" = 0 ] && [ "$(code 02_unit_tests_shipped.txt)" = 0 ] && grep -q "Ran 17 tests" "$PROOF/02_unit_tests_shipped.txt"'
check "first run: settings.ini, .env (mode 600) and inbox/ with 8 samples created, exit 0" \
  '[ "$(code 03_setup_sh_first_run.txt)" = 0 ] && [ -f "$K/config/settings.ini" ] && [ "$PERM" = 600 ] && [ "$(ls "$W/pristine/samples/inbox" | wc -l)" = 8 ]'
check "first run: leads.csv = tests/expected_leads.csv (8 rows, every field), 3 flagged needs_human" \
  '[ "$(rows "$W/leads03.csv")" = "$(rows "$REPO/tests/expected_leads.csv")" ] && [ "$(grep -c ",yes," "$W/leads03.csv")" = 3 ]'
check "default settings: nothing sent (0 requests reached the fake services), empty outbox" '[ "$R03" = 0 ] && [ "$OUTBOX03" = 0 ]'
check "second run: 0 new, leads.csv byte for byte the same, exit 0" \
  '[ "$(code 04_setup_sh_second_run.txt)" = 0 ] && grep -q "^==> 0 new message" "$PROOF/04_setup_sh_second_run.txt" && [ "$H04" = "$(h "$W/leads03.csv")" ]'
check "new message: only it is analysed (1 new, 9 rows), the 8 earlier rows unchanged" \
  'grep -q "^==> 1 new message(s) analysed, 9 in" "$PROOF/05_setup_sh_new_message.txt" && [ -z "$(diff <(rows "$W/leads03.csv") <(rows "$W/leads05.csv") | grep "^<")" ]'
check "--check: exit 0, settings OK, nothing processed" \
  '[ "$(code 06_setup_sh_check.txt)" = 0 ] && grep -q "Settings OK. 9 message file" "$PROOF/06_setup_sh_check.txt"'
check "bad setting (crm = salesforce): exit 3, names the value and the allowed ones" \
  '[ "$(code 07_setup_sh_bad_setting.txt)" = 3 ] && grep -q "crm = salesforce: use none, hubspot, pipedrive or airtable" "$PROOF/07_setup_sh_bad_setting.txt"'
check "all destinations on, no keys, dry run: exit 0, plan saved in outbox, 0 requests sent" \
  '[ "$(code 08_dry_run_all_on_no_keys.txt)" = 0 ] && [ "$OUTBOX08" -gt 9 ] && [ "$R08" = 0 ]'
check "--live with keys missing: exit 3 before anything, lists the missing keys, 0 requests" \
  '[ "$(code 09_live_without_keys.txt)" = 3 ] && grep -q "Missing in .env: GOOGLE_SHEET_WEBHOOK_URL, GOOGLE_SHEET_WEBHOOK_SECRET, HUBSPOT_TOKEN, SLACK_WEBHOOK_URL" "$PROOF/09_live_without_keys.txt" && [ "$R09" = 0 ]'
check "dry run with keys: 0 requests; outbox shows URL / headers / body with every key replaced by <NAME>" \
  '[ "$R10" = 0 ] && ! grep -rEq "$SECRETS" "$W/outbox10" && grep -q "<HUBSPOT_TOKEN>" "$W/outbox10/01_website_lead.eml.crm.1.json" && grep -q "<TELEGRAM_BOT_TOKEN>" "$W/outbox10"/03_complaint.eml.telegram.*.json'
check "--live: 9 Sheet rows (302 redirect followed), HubSpot only the 3 leads/quotes with email + follow-up (4), alerts only for the 3 needs_human" \
  '[ "$(code 11_live_hubspot_sheet_slack_telegram.txt)" = 0 ] && [ "$S11" = 9 ] && [ "$C11" = 4 ] && [ "$SL11" = 3 ] && [ "$T11" = 3 ]'
check "--live: spam, complaint, support, billing and the lead without email never reach the CRM; duplicate contact (409) not an error" \
  'python3 -c "import json;E=[json.loads(l)[\"body\"][\"properties\"][\"email\"] for l in open(\"$W/log11.jsonl\") if \"/hubspot/\" in l];assert sorted(E)==sorted([\"maya.chen@example.com\",\"maya.chen@example.com\",\"omar@tallpine.example.com\",\"alex.m@example.com\"]),E" && grep -q "Sent: 19 · failed: 0" "$PROOF/11_live_hubspot_sheet_slack_telegram.txt"'
check "--live again: 0 requests, nothing sent twice, exit 0" '[ "$(code 12_live_again_nothing_twice.txt)" = 0 ] && [ "$R12" = 0 ]'
check "Slack down: exit 1 with a clear warning after 3 tries, Telegram still sent; next run sends only the Slack alert" \
  '[ "$(code 13_live_slack_down.txt)" = 1 ] && [ "$SLT13" = 3 ] && [ "$T13" = 1 ] && grep -q "slack: HTTP 500 (will retry next run)" "$PROOF/13_live_slack_down.txt" && [ "$(code 14_live_slack_back.txt)" = 0 ] && [ "$SL14" = 1 ] && [ "$T14" = 0 ] && [ "$S14" = 0 ]'
check "wrong Sheet secret: exit 1, the row is reported refused, not marked as sent" \
  '[ "$(code 15_live_wrong_sheet_secret.txt)" = 1 ] && grep -q "the Sheet refused the row" "$PROOF/15_live_wrong_sheet_secret.txt" && [ "$SHEET15" = no ]'
check "Pipedrive: one person per lead with email (5), then 5 leads each linked to the person id returned, exit 0" '[ "$P_PERS" = 5 ] && [ "$P_LEADS_OK" = 5 ] && [ "$(code 16_live_pipedrive.txt)" = 0 ]'
check "Airtable: 5 records to the right base/table, typecast on, exit 0" '[ "$A_OK" = "5 True" ] && [ "$(code 16_live_airtable.txt)" = 0 ]'
check "OpenAI + Anthropic: AI fields used, email header wins, unreadable answer -> rules + needs_human, injection flagged" '[ "$AI_OK" = ok ]'
check "AI requests: fixed instructions say messages are data; message text only in the user turn" '[ "$AI_ISOLATED" = ok ]'
check "AI key refused: exit 4 with a clear message" '[ "$(code 18_ai_key_refused.txt)" = 4 ] && grep -q "key was refused (HTTP 401)" "$PROOF/18_ai_key_refused.txt"'
if [ -x "$PWSH" ]; then
check "setup.ps1 (PowerShell 7): fresh copy gives the same leads.csv as setup.sh; second run 0 new; -Live without keys exit 3" \
  '[ "$(code 19_setup_ps1_first_run.txt)" = 0 ] && [ "$(rows "$W/ps/output/leads.csv")" = "$(rows "$W/leads03.csv")" ] && grep -q "^==> 0 new" "$PROOF/20_setup_ps1_second_run.txt" && [ "$(code 21_setup_ps1_live_without_keys.txt)" = 3 ]'
fi
check "Python 3.9 (oldest supported): same leads.csv, exit 0" \
  '[ "$(code 22_setup_sh_python39.txt)" = 0 ] && [ "$(rows "$W/py39/output/leads.csv")" = "$(rows "$W/leads03.csv")" ]'
check "build_dist.sh: rebuild gives the same ZIP; refuses a .env, a pasted key, a real email, payment wording, a real .env.example value" \
  '[ "$REBUILT" = "$ZIP0" ] && [ "$(grep -c "^\[build exit 0\]" "$PROOF/24_build_dist_refusal.txt")" = 1 ] && [ "$(grep -c "^\[build exit 1\]" "$PROOF/24_build_dist_refusal.txt")" = 5 ]'
check "shipped ZIP holds no .env, settings.ini, inbox/ or output/; no test key in any output file" \
  '! unzip -l "$ZIP" | grep -Eq " nyyo-crm-kit/((\.env|config/settings\.ini)$|(inbox|output)/)" && ! grep -rEq "$SECRETS" "$K/output" "$W/ps/output" "$W/py39/output"'
echo; echo "$PASS passed, $FAILN failed"
} | tee "$PROOF/25_checks.txt"
[ "$FAILN" = 0 ]
