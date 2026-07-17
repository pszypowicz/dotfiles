#!/usr/bin/env bash
# Poll the Anthropic OAuth usage endpoint and refresh the rate-limit cache
# normally written by the Claude Code statusline, so the SketchyBar widget
# stays current when no session runs on this machine. Rate limits are
# account-level, so sessions on other machines show up here too. Also records
# the OAuth token expiry in the state file for the widget's token row.
#
# The endpoint is undocumented; two hard requirements: the OAuth access token
# comes from the "Claude Code-credentials*" Keychain entries, and the
# User-Agent must be claude-code/<version> or the request lands in an
# aggressively rate-limited bucket (persistent 429s).

set -u

CACHE_DIR="$HOME/.cache/claude"
CACHE_FILE="$CACHE_DIR/rate-limits.json"
STATE_FILE="$CACHE_DIR/usage-poll.json"
LOCK_DIR="$CACHE_DIR/.usage-poll.lock"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"

CHECK_INTERVAL=60      # seconds between credential checks (local, cheap)
MIN_INTERVAL=300       # seconds between network polls
FRESH_THRESHOLD=120    # skip polling while a live session's statusline feeds the cache
ERROR_BACKOFF=600      # network/server errors
RATE_LIMIT_BACKOFF=900 # floor for 429s; Retry-After can raise it
AUTH_BACKOFF=1800      # server rejected a locally-valid token; retry slowly

usage() {
  cat <<EOF
Poll the Anthropic OAuth usage endpoint into ~/.cache/claude/rate-limits.json.

Usage: fetch-usage.sh [--force] [--help]

Flags:
  --force  Poll now: skip the ${CHECK_INTERVAL}s/${MIN_INTERVAL}s throttles, error backoff, and
           the skip-when-cache-is-fresh check.
  --help   Show this help.

Example:
  fetch-usage.sh --force
EOF
}

FORCE=0
while (($#)); do
  case "$1" in
    --force) FORCE=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "fetch-usage.sh: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

mkdir -p "$CACHE_DIR"

# Single instance; steal the lock if a previous run died without cleanup.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [[ -n $(find "$LOCK_DIR" -maxdepth 0 -mmin +5 2>/dev/null) ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null
    mkdir "$LOCK_DIR" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

NOW=$(date +%s)

STATE="{}"
[[ -f "$STATE_FILE" ]] && STATE=$(cat "$STATE_FILE" 2>/dev/null || echo '{}')
state_get() { jq -r "$1 // empty" <<<"$STATE" 2>/dev/null; }

LAST_CHECKED=$(state_get '.last_checked')
LAST_POLL=$(state_get '.last_poll')
BACKOFF_UNTIL=$(state_get '.backoff_until')
STATUS=$(state_get '.status')
: "${LAST_CHECKED:=0}" "${LAST_POLL:=0}" "${BACKOFF_UNTIL:=0}" "${STATUS:=unknown}"

SERVICE=""
TOKEN=""
TOKEN_EXP=0 # epoch seconds; 0 = unknown

save_state() {
  local tmp
  tmp=$(mktemp "$CACHE_DIR/.usage-poll.XXXXXX")
  jq -cn --arg status "$STATUS" --arg service "$SERVICE" \
    --argjson now "$NOW" --argjson last_poll "$LAST_POLL" \
    --argjson backoff_until "$BACKOFF_UNTIL" --argjson token_expires_at "$TOKEN_EXP" \
    '{last_checked: $now, last_poll: $last_poll, backoff_until: $backoff_until,
      status: $status, service: $service, token_expires_at: $token_expires_at}' \
    >"$tmp" && mv "$tmp" "$STATE_FILE"
}

if ((!FORCE)); then
  ((NOW - LAST_CHECKED < CHECK_INTERVAL)) && exit 0
fi

# ── Credentials ─────────────────────────────────────────────────────
# Claude Code stores its OAuth blob in Keychain generic passwords whose
# service names start with "Claude Code-credentials" (suffixed variants
# appear alongside the plain name). The cached service is tried first to
# avoid a full keychain scan; expired entries still yield their expiry so
# the widget can show when the token died.

inspect() { # <service> - prints "<expiry-epoch-ms>\t<token>" if the entry holds an oauth blob
  local secret
  secret=$(security find-generic-password -s "$1" -w 2>/dev/null) || return 1
  jq -r 'select(.claudeAiOauth.accessToken)
         | "\(.claudeAiOauth.expiresAt // 0)\t\(.claudeAiOauth.accessToken)"' <<<"$secret" 2>/dev/null
}

take_if_usable() { # <service> <inspect-line> - adopts the entry when its expiry beats the current best
  local exp=${2%%$'\t'*}
  exp=$((${exp%.*} / 1000))
  ((exp > TOKEN_EXP)) || return 1
  TOKEN_EXP=$exp
  if ((exp > NOW + 60)); then
    SERVICE=$1
    TOKEN=${2#*$'\t'}
  fi
}

KEYCHAIN_HAS_ENTRY=0
CACHED_SERVICE=$(state_get '.service')
if [[ -n "$CACHED_SERVICE" ]] && LINE=$(inspect "$CACHED_SERVICE") && [[ -n "$LINE" ]]; then
  KEYCHAIN_HAS_ENTRY=1
  take_if_usable "$CACHED_SERVICE" "$LINE"
fi
if [[ -z "$TOKEN" ]]; then
  while IFS= read -r svc; do
    [[ -z "$svc" ]] && continue
    LINE=$(inspect "$svc") || continue
    [[ -z "$LINE" ]] && continue
    KEYCHAIN_HAS_ENTRY=1
    take_if_usable "$svc" "$LINE"
  done < <(security dump-keychain 2>/dev/null \
    | grep -oE '"svce"<blob>="Claude Code-credentials[^"]*"' \
    | sed -E 's/.*="([^"]*)"/\1/' | sort -u)
fi

if [[ -z "$TOKEN" ]]; then
  if ((KEYCHAIN_HAS_ENTRY)); then STATUS=token_expired; else STATUS=no_token; fi
  save_state
  exit 0
fi

# Token is usable again; a leftover auth status would keep the widget dark.
[[ "$STATUS" == token_expired || "$STATUS" == no_token ]] && STATUS=ok

# ── Poll gates ──────────────────────────────────────────────────────
if ((!FORCE)); then
  if [[ -f "$CACHE_FILE" ]]; then
    CACHE_TS=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null)
    CACHE_TS=${CACHE_TS%.*}
    if ((NOW - ${CACHE_TS:-0} < FRESH_THRESHOLD)); then
      save_state
      exit 0
    fi
  fi
  if ((NOW < BACKOFF_UNTIL || NOW - LAST_POLL < MIN_INTERVAL)); then
    save_state
    exit 0
  fi
fi

# ── Poll ────────────────────────────────────────────────────────────
LAST_POLL=$NOW

UA_VERSION=$(claude --version 2>/dev/null | awk '{print $1; exit}')
if [[ -z "$UA_VERSION" ]]; then
  STATUS=error
  BACKOFF_UNTIL=$((NOW + ERROR_BACKOFF))
  save_state
  exit 0
fi

HDR_FILE=$(mktemp)
BODY_FILE=$(mktemp)
trap 'rmdir "$LOCK_DIR" 2>/dev/null; rm -f "$HDR_FILE" "$BODY_FILE"' EXIT

HTTP_CODE=$(curl -sS --max-time 15 -o "$BODY_FILE" -D "$HDR_FILE" -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "User-Agent: claude-code/$UA_VERSION" \
  "$USAGE_URL" 2>/dev/null) || HTTP_CODE=000

case "$HTTP_CODE" in
  200)
    if jq -e '(.five_hour.utilization != null) or (.seven_day.utilization != null)' "$BODY_FILE" >/dev/null 2>&1; then
      TMP=$(mktemp "$CACHE_DIR/.rate-limits.XXXXXX")
      jq -c '
        def iso2epoch: try (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) catch null;
        {
          timestamp: now,
          source: "poll",
          five_hour: {used_percentage: .five_hour.utilization, resets_at: (.five_hour.resets_at | iso2epoch)},
          seven_day: {used_percentage: .seven_day.utilization, resets_at: (.seven_day.resets_at | iso2epoch)}
        }' "$BODY_FILE" >"$TMP" && mv "$TMP" "$CACHE_FILE"
      STATUS=ok
      BACKOFF_UNTIL=0
    else
      STATUS=error
      BACKOFF_UNTIL=$((NOW + ERROR_BACKOFF))
    fi
    ;;
  401 | 403)
    # Rejected despite passing the local expiry check: rescan next time.
    SERVICE=""
    STATUS=token_expired
    BACKOFF_UNTIL=$((NOW + AUTH_BACKOFF))
    ;;
  429)
    RETRY_AFTER=$(grep -i '^retry-after:' "$HDR_FILE" | tr -dc '0-9' | head -c 6)
    BACKOFF=$RATE_LIMIT_BACKOFF
    [[ -n "$RETRY_AFTER" ]] && ((RETRY_AFTER > BACKOFF)) && BACKOFF=$RETRY_AFTER
    STATUS=rate_limited
    BACKOFF_UNTIL=$((NOW + BACKOFF))
    ;;
  *)
    STATUS=error
    BACKOFF_UNTIL=$((NOW + ERROR_BACKOFF))
    ;;
esac

save_state
