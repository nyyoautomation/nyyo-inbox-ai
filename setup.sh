#!/usr/bin/env bash
# Nyyo inbox -> CRM kit - sort your messages with AI into a Sheet-ready table (Mac / Linux).
# Free 1-click install kit, MIT licence. Nyyo Automation.
#
#   ./setup.sh             first run: creates your settings and .env, copies the 8 sample messages, runs a dry run
#   ./setup.sh --check     check settings and keys, process nothing
#   ./setup.sh --live      really send to your Sheet / CRM / alerts (only what your settings switch on)
#
# Options: --reprocess (analyse every message again), --no-open, --help
# Safe to run again: your settings, .env and messages are never overwritten, each message is analysed once,
# and in --live mode nothing that was already sent is sent twice.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 3; }
usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

OPEN=1; PASS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --live|--check|--reprocess) PASS+=("$1") ;;
    --no-open) OPEN=0 ;;
    -h|--help) usage ;;
    *) die "Unknown option: $1 (see ./setup.sh --help)" ;;
  esac; shift
done
[ -f "$KIT_DIR/kit/nyyo_crm.py" ] && [ -f "$KIT_DIR/config/settings.example.ini" ] || die "Kit files missing: run this script from the unzipped kit folder."
cd "$KIT_DIR"

# ---- 1. Python 3.9+ (standard library only: nothing to download) ----
PY=""
for c in python3.13 python3.12 python3.11 python3.10 python3.9 python3; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then PY="$c"; break; fi
done
[ -n "$PY" ] || die "Python 3.9 or newer is needed. See INSTALL.md, Step 1."

# ---- 2. Your files (created once, never overwritten) ----
if [ ! -f config/settings.ini ]; then
  cp config/settings.example.ini config/settings.ini
  say "Created config/settings.ini (AI: built-in rules, nothing switched on). Edit it later, then run ./setup.sh again."
fi
if [ ! -f .env ]; then
  (umask 077; cp .env.example .env)
  say "Created .env for your keys (only you can read it). Fill it only when you switch something on."
fi
chmod 600 .env 2>/dev/null || true
if [ ! -d inbox ]; then
  mkdir -p inbox && cp samples/inbox/* inbox/
  say "Created inbox/ with 8 made-up sample messages. Replace them with your own .eml or .txt files."
fi

# ---- 3. Run ----
set +e; "$PY" kit/nyyo_crm.py --config config/settings.ini --env .env ${PASS[@]+"${PASS[@]}"}; RC=$?; set -e
echo
case "$RC" in
  0) say "Finished. Your table: $KIT_DIR/output/leads.csv" ;;
  1) warn "Finished with warnings (see [!] lines above). Your table: $KIT_DIR/output/leads.csv" ;;
  3) warn "Fix config/settings.ini or .env (see the message above) and run ./setup.sh again." ;;
  4) warn "A key was refused: check it in .env (INSTALL.md, Troubleshooting)." ;;
  *) warn "The kit stopped with an error (code $RC). See INSTALL.md, Troubleshooting." ;;
esac
if [ "$OPEN" = 1 ] && [ -t 1 ] && [ "$RC" -le 1 ]; then
  if [ "$(uname -s)" = Darwin ]; then open "$KIT_DIR/output"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$KIT_DIR/output" >/dev/null 2>&1 || true; fi
fi
exit "$RC"
