#!/usr/bin/env bash
# ===========================================================================
#  Sova — RESET ADMIN PASSWORD  (standalone recovery tool, NOT part of Sova)
#
#  Locked out of the Sova admin panel? Run this on the Sova server (as root)
#  to set a new password for a superadmin account straight in the database —
#  no working login required. Also re-enables the account if it was disabled.
#
#  It ONLY touches sova.admin_user (the chosen account's password_hash +
#  is_active). No site, tunnel, user or config data is read or changed.
#
#  Usage:  sudo bash sova-reset-admin-password.sh [--user NAME] [--list]
#            --user NAME   which superadmin to reset (default: the only one,
#                          or you'll be asked to pick when there are several)
#            --list        just list the superadmin accounts and exit
#
#  The new password is read from the terminal (never shown, never on the
#  command line) and stored as a bcrypt hash exactly like the app does.
# ===========================================================================
set -uo pipefail

TARGET_USER=""
LIST_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --user)    TARGET_USER="${2:-}"; shift 2 2>/dev/null || shift ;;
    --user=*)  TARGET_USER="${1#--user=}"; shift ;;
    --list|-l) LIST_ONLY=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
die()  { red "ERROR: $*"; exit 1; }

# ── preflight ──────────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || die "must run as root (use: sudo bash $0)"

PREFIX="${PREFIX:-/opt/sova}"
[ -d "$PREFIX" ] || die "no Sova install at $PREFIX"

# A python that has bcrypt — the Sova venv is the reliable one; fall back to
# the standalone runtime, then the system python. We hash exactly like the app
# (app/admin/auth.py: bcrypt.hashpw(pw, bcrypt.gensalt())).
PY=""
for c in "${Sova_PY:-}" "$PREFIX/venv/bin/python" "$PREFIX/runtime/bin/python3" python3; do
  [ -n "$c" ] && command -v "$c" >/dev/null 2>&1 || [ -x "$c" ] || continue
  if "$c" -c 'import bcrypt' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || die "no python with the 'bcrypt' module found (looked in $PREFIX/venv). Set Sova_PY=/path/to/python and re-run."

# ── locate + parse the DSN (read, never echo it) ───────────────────────────
DSN="${DATABASE_URL:-}"
if [ -z "$DSN" ]; then
  for f in ${Sova_CONF:-} /etc/sova/sova.yaml /etc/sova/api.env "$PREFIX/.env"; do
    [ -f "$f" ] || continue
    DSN="$(grep -aoE 'postgresql://[^"'"'"'[:space:]]+' "$f" | head -1)"
    [ -n "$DSN" ] && break
  done
fi
[ -n "$DSN" ] || die "could not find the PostgreSQL DSN (looked in /etc/sova/sova.yaml and /etc/sova/api.env). Set DATABASE_URL=... and re-run."

_rest="${DSN#postgresql://}"; _creds="${_rest%%@*}"; _hostdb="${_rest#*@}"
DB_USER="${_creds%%:*}"; DB_PASS="${_creds#*:}"
DB_HOST="${_hostdb%%:*}"; _portdb="${_hostdb#*:}"
DB_PORT="${_portdb%%/*}"; DB_NAME="${_portdb#*/}"; DB_NAME="${DB_NAME%%\?*}"
[ -n "$DB_NAME" ] || die "could not parse the database name from the DSN"

export PGPASSWORD="$DB_PASS"
PSQL=(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -qtA)
"${PSQL[@]}" -c 'SELECT 1' >/dev/null 2>&1 || die "cannot connect to database '$DB_NAME' on $DB_HOST:$DB_PORT"

echo
bold "Sova — reset admin password"
echo  "  install : $PREFIX"
echo  "  database: $DB_NAME @ $DB_HOST:$DB_PORT"
echo

# ── list superadmin accounts ───────────────────────────────────────────────
mapfile -t SUPERS < <("${PSQL[@]}" -F'|' -c \
  "SELECT username, CASE WHEN is_active THEN 'enabled' ELSE 'disabled' END \
     FROM sova.admin_user WHERE role='superadmin' ORDER BY id")

bold "Superadmin accounts:"
if [ ${#SUPERS[@]} -eq 0 ]; then
  die "no account has the 'superadmin' role — nothing to reset. (Roles are in sova.admin_user.role.)"
fi
for row in "${SUPERS[@]}"; do
  u="${row%%|*}"; st="${row#*|}"
  printf '  %-24s %s\n' "$u" "$st"
done
echo
[ "$LIST_ONLY" -eq 1 ] && exit 0

# ── choose the target ──────────────────────────────────────────────────────
if [ -z "$TARGET_USER" ]; then
  if [ ${#SUPERS[@]} -eq 1 ]; then
    TARGET_USER="${SUPERS[0]%%|*}"
  else
    read -r -p "Which superadmin username to reset? " TARGET_USER
  fi
fi
[ -n "$TARGET_USER" ] || die "no username given"

EXISTS="$("${PSQL[@]}" -c \
  "SELECT 1 FROM sova.admin_user WHERE username = '${TARGET_USER//\'/\'\'}' AND role='superadmin'")"
[ "$EXISTS" = "1" ] || die "'$TARGET_USER' is not a superadmin account (see the list above)"

bold "Resetting password for superadmin: $TARGET_USER"
echo

# ── read the new password (hidden, twice) ──────────────────────────────────
read -r -s -p "New password (min 4 chars): " P1; echo
[ "${#P1}" -ge 4 ] || die "password too short (min 4 characters)"
read -r -s -p "Repeat new password:        " P2; echo
[ "$P1" = "$P2" ] || die "passwords do not match"

# hash with bcrypt via stdin (never on argv), exactly like app/admin/auth.py
HASH="$(printf '%s' "$P1" | "$PY" -c \
  'import sys,bcrypt; print(bcrypt.hashpw(sys.stdin.buffer.read(), bcrypt.gensalt()).decode())')"
case "$HASH" in
  \$2*) : ;;                                   # looks like a bcrypt hash
  *) die "password hashing failed" ;;
esac

# ── apply: set the hash + re-enable the account (recovery) ─────────────────
# Values embedded as SQL literals (psql -c does NOT interpolate :'var'). The
# bcrypt hash contains no single quotes; the username's are doubled, SQL-safe.
SAFE_U="${TARGET_USER//\'/\'\'}"
OUT="$("${PSQL[@]}" -c \
  "UPDATE sova.admin_user SET password_hash = '$HASH', is_active = TRUE \
     WHERE username = '$SAFE_U' AND role='superadmin' RETURNING username")"
if [ "$OUT" = "$TARGET_USER" ]; then
  echo
  grn "Password reset for superadmin '$TARGET_USER' (account is enabled)."
  grn "Log in at the admin panel and change it again from your profile if you like."
else
  die "update did not apply — no row changed"
fi
unset P1 P2 PGPASSWORD
