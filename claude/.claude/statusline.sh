#!/bin/bash
# Claude Code status line. Four groups of segments — session (model, effort, context, cost),
# workspace (directory, git), account (plan windows, credits) and the session id — laid out
# to the terminal width Claude Code passes in COLUMNS: a wide pane gets one line, a narrower
# one wraps between groups, and a group too wide for a line of its own is compacted and then
# wrapped between its segments. See the layout section at the end.
# Read stdin with the builtin rather than $(cat): one fork fewer on every timer run.
IFS= read -r -d '' input
# Money figures are formatted with printf/awk below; pin the decimal point so a comma locale
# can't turn "17.74" into "17,74" mid-line (LC_ALL, since it overrides LC_NUMERIC). The C
# locale also makes ${#var} count bytes, which vis_width relies on.
export LC_ALL=C
# bash 5 has EPOCHSECONDS; macOS's /bin/bash is 3.2, so fall back to date there.
NOW=${EPOCHSECONDS:-$(date +%s)}

# Claude Code runs this on events (a new message, a mode change…) and, via the statusLine
# refreshInterval in settings.json, on a timer: a terminal resize triggers nothing by itself,
# so without the timer a narrowed pane keeps the old, wider layout, truncated. On an idle
# session the timer runs repeat the last one — the payload differs only in
# cost.total_duration_ms — so reuse that render for RENDER_TTL seconds (no jq/git/stat), and
# flag the session IDLE so the usage refresh below doesn't poll the network on its behalf.
# The key includes COLUMNS, so a resize always re-lays out.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ai-status"
RENDER_TTL=10
RENDER_FILE=""; RENDER_KEY=""; IDLE=0
if [[ $input =~ \"session_id\":\"([A-Za-z0-9_-]+)\" ]]; then
    RENDER_FILE="$CACHE_DIR/render-${BASH_REMATCH[1]}"
    RENDER_KEY=$input
    [[ $input =~ (.*\"total_duration_ms\":)[0-9]+(.*) ]] && RENDER_KEY="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    RENDER_KEY="${COLUMNS-}|${RENDER_KEY//$'\n'/ }"
    if [ -f "$RENDER_FILE" ]; then
        { IFS= read -r R_TIME; IFS= read -r R_KEY; IFS= read -r -d '' R_OUT; } < "$RENDER_FILE"
        if [ "$R_KEY" = "$RENDER_KEY" ]; then
            IDLE=1
            case "$R_TIME" in ''|*[!0-9]*) ;; *)
                if [ $(( NOW - R_TIME )) -lt "$RENDER_TTL" ] && [ -n "$R_OUT" ]; then
                    printf '%s' "$R_OUT"; exit 0
                fi ;;
            esac
        fi
    fi
fi

# Parse every field we need in a single jq pass (one field per line).
# - free-text fields are stripped of control chars (gsub cntrl) so a stray newline can't
#   shift the line-based read and an ESC/OSC byte can't inject into the terminal.
# - `| numbers` + `2>/dev/null` make each floored field abort-proof: a non-numeric value
#   falls back to its default instead of erroring out and truncating the rest. `?` does the
#   same for a parent of the wrong type (e.g. "thinking": "x"), and booleans are compared to
#   true so nothing but true/false can come out.
# - rate-limit usage is -1 when the window is absent (distinguishes "absent" from a real 0%).
# - resets_at is Unix epoch seconds, floored straight into the *_RESET vars.
# - cost.total_cost_usd is present even when rate_limits is not (credit-billed sessions, e.g.
#   Fable): kept unfloored since it's a dollar figure, not a percentage.
parsed=$(jq -r '
  ((.model.display_name? | strings) // "?" | gsub("[[:cntrl:]]";"")),
  ((.workspace.current_dir? | strings) // "" | gsub("[[:cntrl:]]";"")),
  ((.session_id | strings) // "" | gsub("[[:cntrl:]]";"")),
  ((.effort.level? | strings) // "" | gsub("[[:cntrl:]]";"")), ((.thinking.enabled? // false) == true),
  ((.fast_mode // false) == true), ((.agent.name? | strings) // "" | gsub("[[:cntrl:]]";"")),
  ((.context_window.used_percentage? | numbers) // 0 | floor), ((.exceeds_200k_tokens // false) == true),
  ((.rate_limits.five_hour.used_percentage? | numbers) // -1 | floor), ((.rate_limits.five_hour.resets_at? | numbers) // 0 | floor),
  ((.rate_limits.seven_day.used_percentage? | numbers) // -1 | floor), ((.rate_limits.seven_day.resets_at? | numbers) // 0 | floor),
  ((.cost.total_cost_usd? | numbers) // 0)
' 2>/dev/null <<< "$input")
{
  IFS= read -r MODEL;  IFS= read -r DIR;          IFS= read -r SESSION_ID
  IFS= read -r EFFORT; IFS= read -r THINKING
  IFS= read -r FAST;   IFS= read -r AGENT
  IFS= read -r PCT;    IFS= read -r EXCEEDS_200K
  IFS= read -r HOURS;  IFS= read -r HOURS_RESET
  IFS= read -r WEEK;   IFS= read -r WEEK_RESET
  IFS= read -r SESSION_COST
} <<< "$parsed"

# Fill defaults when jq produced nothing (empty/invalid stdin): keep the -1 "absent" sentinel
# for rate usage so the cache logic below behaves, and avoid phantom values elsewhere.
: "${MODEL:=?}" "${PCT:=0}" "${EXCEEDS_200K:=false}" \
  "${HOURS:=-1}" "${WEEK:=-1}" "${HOURS_RESET:=0}" "${WEEK_RESET:=0}" "${SESSION_COST:=0}"

# Private per-user cache dir (CACHE_DIR, set above) — avoids predictable shared /tmp paths
# (symlink-follow clobber vector, spoofable reads on multi-user hosts).
if ! mkdir -p -m 700 "$CACHE_DIR" 2>/dev/null || ! chmod 700 "$CACHE_DIR" 2>/dev/null; then
    printf '[%s] %s%% %s\n' "$MODEL" "$PCT" "$DIR"
    exit 0
fi

# Sets AGE to the seconds since $1 was modified (large if it's missing). The stat dialect is
# picked by OS: on Linux `stat -f` is filesystem-status mode and prints a filesystem block
# even for a real path, which would break the arithmetic. Sets a variable instead of echoing
# so callers don't pay for a subshell on every render.
mtime_age() {
    local m
    case "$OSTYPE" in
        darwin*|*bsd*) m=$(stat -f %m "$1" 2>/dev/null) ;;
        *)             m=$(stat -c %Y "$1" 2>/dev/null) ;;
    esac
    case "$m" in ''|*[!0-9]*) m=0 ;; esac
    AGE=$(( NOW - m ))
}

# Git status, cached per directory so concurrent sessions in the same repo share it.
case "$OSTYPE" in
    darwin*) DIR_HASH=$(md5 -q -s "$DIR" 2>/dev/null) ;;
    *)       DIR_HASH=$(printf '%s' "$DIR" | md5sum 2>/dev/null); DIR_HASH=${DIR_HASH%% *} ;;
esac
[ -z "$DIR_HASH" ] && DIR_HASH=default
CACHE_FILE="$CACHE_DIR/statusline-git-cache-${DIR_HASH}"
CACHE_MAX_AGE=5

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] && return 0
    mtime_age "$CACHE_FILE"; [ "$AGE" -gt "$CACHE_MAX_AGE" ]
}

# Occasional cleanup (not every render): git caches older than a day, session baselines older
# than a week, renders of sessions closed for an hour (an open one rewrites its file every
# RENDER_TTL), and mktemp leftovers (*.XXXXXX) of writes or refreshes that were killed before
# their rename — including usage-hdr.* files that earlier versions wrote the OAuth token to.
if [ $((RANDOM % 20)) -eq 0 ]; then
    find "$CACHE_DIR" -type f \( \( -name "statusline-git-cache-*" -mtime +1 \) \
        -o \( -name "session-credits-*" -mtime +7 \) -o \( -name "render-*" -mmin +60 \) \
        -o \( -name '*.??????' -mmin +10 \) \) -delete 2>/dev/null
fi

# Branch goes LAST in the record (counts are integers, so a '|' in a branch name can't
# corrupt the field split); write via a temp file + atomic rename to avoid torn reads.
# Mirrors starship.toml's [git_status] categories (staged/modified/untracked/deleted/
# conflicted/ahead/behind) off one `git status --porcelain=v1 --branch` call, so a file
# that's both staged and deleted etc. gets counted the same way the prompt counts it.
if cache_is_stale; then
    if [ -n "$DIR" ] && git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=""; STAGED=0; MODIFIED=0; UNTRACKED=0; DELETED=0; CONFLICTED=0; AHEAD=0; BEHIND=0
        while IFS= read -r line; do
            case "$line" in
                "## "*)
                    branch_line="${line#"## "}"
                    BRANCH="${branch_line%%...*}"
                    BRANCH="${BRANCH#No commits yet on }"
                    BRANCH="${BRANCH#Initial commit on }"
                    [ "$BRANCH" = "HEAD (no branch)" ] && BRANCH=""
                    [[ "$branch_line" =~ ahead\ ([0-9]+) ]]  && AHEAD="${BASH_REMATCH[1]}"
                    [[ "$branch_line" =~ behind\ ([0-9]+) ]] && BEHIND="${BASH_REMATCH[1]}"
                    ;;
                "??"*) UNTRACKED=$((UNTRACKED + 1)) ;;
                "DD "*|"AU "*|"UD "*|"UA "*|"DU "*|"AA "*|"UU "*) CONFLICTED=$((CONFLICTED + 1)) ;;
                *)
                    x="${line:0:1}"; y="${line:1:1}"
                    if [ "$x" = "D" ] || [ "$y" = "D" ]; then
                        DELETED=$((DELETED + 1))
                    else
                        [ "$x" != " " ] && STAGED=$((STAGED + 1))
                        [ "$y" != " " ] && MODIFIED=$((MODIFIED + 1))
                    fi
                    ;;
            esac
        done < <(git -C "$DIR" status --porcelain=v1 --branch 2>/dev/null)
        tmp=$(mktemp "${CACHE_FILE}.XXXXXX") && printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
            "$STAGED" "$MODIFIED" "$UNTRACKED" "$DELETED" "$CONFLICTED" "$AHEAD" "$BEHIND" "$BRANCH" > "$tmp" && mv -f "$tmp" "$CACHE_FILE"
    else
        tmp=$(mktemp "${CACHE_FILE}.XXXXXX") && printf '|||||||\n' > "$tmp" && mv -f "$tmp" "$CACHE_FILE"
    fi
fi

IFS='|' read -r STAGED MODIFIED UNTRACKED DELETED CONFLICTED AHEAD BEHIND BRANCH < "$CACHE_FILE"

# credit-billed sessions (e.g. Fable) never carry a payload rate_limits key, so PCT/HOURS/WEEK
# above have nothing to draw on. The OAuth usage endpoint (same data the /usage TUI screen
# shows) fills that gap. Fetched here, cached, and merged into HOURS/WEEK below — before the
# statusline-rate-limits fallback, so a live endpoint value always wins over a stale one.
CLAUDE_USAGE_URL="${CLAUDE_USAGE_URL:-https://api.anthropic.com/api/oauth/usage}"
USAGE_CACHE="$CACHE_DIR/claude-usage.json"
USAGE_CACHE_TTL=60
USAGE_ATTEMPT="$CACHE_DIR/claude-usage-attempt"
USAGE_LOCK_DIR="$CACHE_DIR/claude-usage-refresh.lock"
USAGE_LOCK_PID_FILE="${USAGE_LOCK_DIR}.pid"
USAGE_LOCK_MAX_AGE=60

# Token lives in the OAuth credentials Claude Code itself refreshes — read-only here, never
# written. Linux keeps it in a 600-mode JSON file; macOS keeps the same JSON blob in Keychain.
get_claude_token() {
    local tok=""
    if [ -f "$HOME/.claude/.credentials.json" ]; then
        tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
    fi
    if [ -z "$tok" ] && command -v security >/dev/null 2>&1; then
        tok=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
    printf '%s' "$tok"
}

# Backgrounded, mkdir-locked refresh so the statusline never blocks on the network.
# The token reaches curl as config on stdin (`-K -`) from the printf builtin: never on argv
# (visible in `ps`) and never in a file, which a refresh killed mid-request would leave behind.
refresh_usage_cache() {
    if [ -d "$USAGE_LOCK_DIR" ]; then
        local lock_pid; lock_pid=$(cat "$USAGE_LOCK_PID_FILE" 2>/dev/null)
        if [ -z "$lock_pid" ] || ! kill -0 "$lock_pid" 2>/dev/null; then
            mtime_age "$USAGE_LOCK_DIR"
            [ "$AGE" -gt "$USAGE_LOCK_MAX_AGE" ] && { rmdir "$USAGE_LOCK_DIR" 2>/dev/null; rm -f "$USAGE_LOCK_PID_FILE"; }
        fi
    fi
    mkdir "$USAGE_LOCK_DIR" 2>/dev/null || return
    touch "$USAGE_ATTEMPT"
    (
        local token; token=$(get_claude_token)
        if [ -n "$token" ]; then
            # Escape backslash/quote so a token containing either can't break out of the
            # quoted curl -K value and inject extra config directives.
            local tok_esc="${token//\\/\\\\}"; tok_esc="${tok_esc//\"/\\\"}"
            local tmp; tmp=$(mktemp "$CACHE_DIR/claude-usage.json.XXXXXX")
            local code; code=$(printf 'header = "Authorization: Bearer %s"\nheader = "anthropic-beta: oauth-2025-04-20"\nheader = "Accept: application/json"\n' "$tok_esc" \
                | curl -sS --max-time 5 -K - -o "$tmp" -w '%{http_code}' "$CLAUDE_USAGE_URL" 2>/dev/null)
            if [ "$code" = "200" ] && jq -e '.five_hour' "$tmp" >/dev/null 2>&1; then
                mv -f "$tmp" "$USAGE_CACHE"
            else
                rm -f "$tmp"
            fi
        fi
        rm -f "$USAGE_LOCK_PID_FILE"
        rmdir "$USAGE_LOCK_DIR" 2>/dev/null
    ) >/dev/null 2>&1 &
    disown 2>/dev/null
    echo $! > "$USAGE_LOCK_PID_FILE"
}

USAGE_NO_CREDIT_MARKER="$CACHE_DIR/claude-usage-no-credit"
USAGE_NO_CREDIT_TTL=300

usage_cache_stale() {
    if [ -f "$USAGE_ATTEMPT" ]; then
        mtime_age "$USAGE_ATTEMPT"; [ "$AGE" -le "$USAGE_CACHE_TTL" ] && return 1
    fi
    [ ! -f "$USAGE_CACHE" ] && return 0
    local ttl="$USAGE_CACHE_TTL"
    # Confirmed-absent accounts (no credit balance/limit ever reported) get a much
    # longer TTL instead of polling every render — the data isn't going to appear.
    [ -f "$USAGE_NO_CREDIT_MARKER" ] && ttl="$USAGE_NO_CREDIT_TTL"
    mtime_age "$USAGE_CACHE"; [ "$AGE" -gt "$ttl" ]
}
# Idle sessions read the shared cache that active ones keep fresh, but never poll themselves.
[ "$IDLE" = 1 ] || { usage_cache_stale && refresh_usage_cache; }

# One jq pass over whatever cache exists (even stale — this round uses it as-is, the refresh
# above is for next time). Live shape on a Pro account with a monthly credit limit: spend.used/
# spend.limit are {amount_minor,currency,exponent}, spend.cap wraps the same under .money,
# spend.balance is null (prepaid balances only), and extra_usage mirrors the same figures as
# bare numbers in MINOR units (used_credits 226.0 == €2.26, scaled by decimal_places).
# `// null` (not `// empty`) on every field keeps the line count fixed so the positional
# `read`s below never desync.
E5H=-1; E5H_RESET=0; E7D=-1; E7D_RESET=0
CREDIT_BAL=""; CREDIT_USED=""; CREDIT_LIMIT=""; CREDIT_PCT=""; CREDIT_CUR=""; CREDIT_ON="false"
eparsed=""
if [ -f "$USAGE_CACHE" ]; then
    eparsed=$(jq -r '
      ((.extra_usage.decimal_places | numbers) // 2) as $dp |
      def money:
        if type == "object" and has("money") then (.money | money)
        elif type == "object" then ((.amount_minor // 0) / pow(10; (.exponent // 2)))
        elif type == "number" then .
        else empty end;
      def minor: if type == "number" then . / pow(10; ($dp // 2)) else empty end;
      # Assumes the API always returns UTC (+00:00 or Z) — any other offset fails the
      # substitution, fromdateiso8601 errors, and the reset time is dropped to 0 via catch.
      def iso2epoch: if . == null then 0
                     else (try (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) catch 0)
                     end;
      ((.spend.enabled // false) == true) as $spend_on |
      ((.extra_usage.is_enabled // false) == true) as $extra_on |
      # Every spend.* / extra_usage.* field below is gated on that own sections enabled
      # flag — spend.used in particular is a stubbed {amount_minor:0,currency:"USD"} even
      # while spend.enabled is false, so reading it unconditionally would report a false
      # "0 used, USD" instead of falling through to the last known real figures below.
      # `// null` on every leaf (not just the if/else null) is load-bearing: money/numbers
      # internally produce `empty` (zero outputs, not `null`) for a null input — e.g. a
      # balance-only account with no monthly cap has .spend.limit == null — and an if/then
      # whose chosen branch yields empty makes the WHOLE conditional yield empty too, which
      # silently drops that field and desyncs every positional `read` after it.
      ((.five_hour.utilization | numbers) // -1 | floor),
      (.five_hour.resets_at | iso2epoch),
      ((.seven_day.utilization | numbers) // -1 | floor),
      (.seven_day.resets_at | iso2epoch),
      (if $spend_on then ((.spend.balance | money) // null) else null end),
      (if $spend_on then ((.spend.used | money) // null) elif $extra_on then ((.extra_usage.used_credits | minor) // null) else null end),
      (if $spend_on then ((.spend.limit | money) // (.spend.cap | money) // null) elif $extra_on then ((.extra_usage.monthly_limit | minor) // null) else null end),
      (if $spend_on then ((.spend.percent | numbers) // null) elif $extra_on then ((.extra_usage.utilization | numbers) // null) else null end),
      (if $spend_on then (.spend.balance.currency // .spend.used.currency // null) elif $extra_on then (.extra_usage.currency // null) else null end),
      ($spend_on or $extra_on)
    ' "$USAGE_CACHE" 2>/dev/null)
    if [ -n "$eparsed" ]; then
        {
          IFS= read -r E5H;        IFS= read -r E5H_RESET
          IFS= read -r E7D;        IFS= read -r E7D_RESET
          IFS= read -r CREDIT_BAL; IFS= read -r CREDIT_USED
          IFS= read -r CREDIT_LIMIT; IFS= read -r CREDIT_PCT
          IFS= read -r CREDIT_CUR; IFS= read -r CREDIT_ON
        } <<< "$eparsed"
    fi
fi
[ "$CREDIT_BAL"   = "null" ] && CREDIT_BAL=""
[ "$CREDIT_USED"  = "null" ] && CREDIT_USED=""
[ "$CREDIT_LIMIT" = "null" ] && CREDIT_LIMIT=""
[ "$CREDIT_PCT"   = "null" ] && CREDIT_PCT=""
[ "$CREDIT_CUR"   = "null" ] && CREDIT_CUR=""
: "${E5H:=-1}" "${E5H_RESET:=0}" "${E7D:=-1}" "${E7D_RESET:=0}"

# Persist the last real billing currency across fetches: while spend/extra_usage is
# disabled the payload carries no trustworthy currency at all (see the jq comment
# above), so without this a temporarily-off account would silently read back as USD.
CREDIT_CUR_CACHE="$CACHE_DIR/credit-currency"
if [ -n "$CREDIT_CUR" ]; then
    tmp=$(mktemp "${CREDIT_CUR_CACHE}.XXXXXX") && printf '%s\n' "$CREDIT_CUR" > "$tmp" && mv -f "$tmp" "$CREDIT_CUR_CACHE"
elif [ -f "$CREDIT_CUR_CACHE" ]; then
    IFS= read -r CREDIT_CUR < "$CREDIT_CUR_CACHE"
fi
case "$CREDIT_CUR" in [A-Z][A-Z][A-Z]) ;; *) CREDIT_CUR=USD ;; esac

# Persist the last known account-wide credit balance/usage across fetches. Credits are
# account-level, shared by every session, not per-session state — and toggling the
# spend/extra_usage *reporting* off doesn't spend or reset the actual balance, it just
# stops the API returning it. CACHE_DIR is already shared account-wide (not scoped by
# session id), so this naturally applies to every concurrent session too.
CREDIT_STATE_CACHE="$CACHE_DIR/credit-state"
if [ -n "$CREDIT_BAL" ] || [ -n "$CREDIT_LIMIT" ]; then
    tmp=$(mktemp "${CREDIT_STATE_CACHE}.XXXXXX") && printf '%s|%s|%s|%s\n' \
        "$CREDIT_BAL" "$CREDIT_USED" "$CREDIT_LIMIT" "$CREDIT_PCT" > "$tmp" && mv -f "$tmp" "$CREDIT_STATE_CACHE"
elif [ -f "$CREDIT_STATE_CACHE" ]; then
    IFS='|' read -r CREDIT_BAL CREDIT_USED CREDIT_LIMIT CREDIT_PCT < "$CREDIT_STATE_CACHE"
fi

# Mark/unmark the no-credit-data circuit breaker off a real parse, not an empty/missing
# cache — a fetch failure should never look like a confirmed absence.
if [ -n "$eparsed" ]; then
    if [ "$CREDIT_ON" != "true" ] && [ -z "$CREDIT_BAL" ] && [ -z "$CREDIT_LIMIT" ]; then
        touch "$USAGE_NO_CREDIT_MARKER" 2>/dev/null
    else
        rm -f "$USAGE_NO_CREDIT_MARKER"
    fi
fi

# Precedence: payload rate_limits (still -1 here if absent) → this endpoint cache → the
# statusline-rate-limits fallback below → 0.
[ "$HOURS" -lt 0 ] 2>/dev/null && [ "$E5H" -ge 0 ] 2>/dev/null && HOURS="$E5H"
[ "${HOURS_RESET:-0}" -le 0 ] 2>/dev/null && [ "${E5H_RESET:-0}" -gt 0 ] 2>/dev/null && HOURS_RESET="$E5H_RESET"
[ "$WEEK" -lt 0 ] 2>/dev/null && [ "$E7D" -ge 0 ] 2>/dev/null && WEEK="$E7D"
[ "${WEEK_RESET:-0}" -le 0 ] 2>/dev/null && [ "${E7D_RESET:-0}" -gt 0 ] 2>/dev/null && WEEK_RESET="$E7D_RESET"

# The payload's session cost is USD-only (list price), but the account is billed in
# CREDIT_CUR. Convert with the ECB daily reference rate via Frankfurter (keyless, free),
# refreshed once a day in the background under its own lock. Anthropic's real conversion
# isn't exposed anywhere, so this is an approximation; with no rate cached the raw dollar
# figure is shown rather than a guessed constant.
FX_CUR="${CREDIT_CUR:-USD}"
# Defense in depth: FX_CUR feeds a cache filename and a URL query param below, so pin it
# to a plain 3-letter ISO code even though it currently only ever comes from a trusted
# HTTPS response.
case "$FX_CUR" in [A-Z][A-Z][A-Z]) ;; *) FX_CUR=USD ;; esac
FX_CACHE="$CACHE_DIR/fx-usd-${FX_CUR}"
FX_CACHE_TTL=86400
FX_ATTEMPT="${FX_CACHE}.attempt"
FX_LOCK_DIR="$CACHE_DIR/fx-refresh.lock"
refresh_fx_cache() {
    if [ -d "$FX_LOCK_DIR" ]; then
        mtime_age "$FX_LOCK_DIR"
        [ "$AGE" -gt "$USAGE_LOCK_MAX_AGE" ] && rmdir "$FX_LOCK_DIR" 2>/dev/null
    fi
    if [ -f "$FX_ATTEMPT" ]; then mtime_age "$FX_ATTEMPT"; [ "$AGE" -le 300 ] && return; fi
    mkdir "$FX_LOCK_DIR" 2>/dev/null || return
    touch "$FX_ATTEMPT"
    (
        local tmp; tmp=$(mktemp "${FX_CACHE}.XXXXXX")
        local code; code=$(curl -sS --max-time 5 -o "$tmp" -w '%{http_code}' "https://api.frankfurter.dev/v1/latest?base=USD&symbols=${FX_CUR}" 2>/dev/null)
        local rate=""
        [ "$code" = "200" ] && rate=$(jq -r --arg c "$FX_CUR" '.rates[$c] | numbers' "$tmp" 2>/dev/null)
        if [ -n "$rate" ]; then printf '%s\n' "$rate" > "$tmp" && mv -f "$tmp" "$FX_CACHE"; else rm -f "$tmp"; fi
        rmdir "$FX_LOCK_DIR" 2>/dev/null
    ) >/dev/null 2>&1 &
    disown 2>/dev/null
}
FX_RATE=""
if [ "$FX_CUR" != "USD" ]; then
    if [ ! -f "$FX_CACHE" ]; then refresh_fx_cache
    else mtime_age "$FX_CACHE"; [ "$AGE" -gt "$FX_CACHE_TTL" ] && refresh_fx_cache
    fi
    [ -f "$FX_CACHE" ] && IFS= read -r FX_RATE < "$FX_CACHE"
    case "$FX_RATE" in ''|*[!0-9.]*) FX_RATE="" ;; esac
fi

# Shared cache for rate limits (account-level, not per-session). The parse emits -1 for an
# absent window; fall back to the last known values only then, so a genuine 0% (e.g. right
# after a reset) is preserved instead of being clobbered by stale data. Rewritten only when
# the record changes, which saves a mktemp/mv on most renders.
RATE_CACHE="$CACHE_DIR/statusline-rate-limits"
C_HOURS=""; C_WEEK=""; C_HOURS_RESET=""; C_WEEK_RESET=""
if [ -f "$RATE_CACHE" ]; then
    IFS='|' read -r C_HOURS C_WEEK C_HOURS_RESET C_WEEK_RESET < "$RATE_CACHE"
    [ "$HOURS" -lt 0 ] 2>/dev/null && HOURS="${C_HOURS:-0}"
    [ "$WEEK"  -lt 0 ] 2>/dev/null && WEEK="${C_WEEK:-0}"
    [ "${HOURS_RESET:-0}" -le 0 ] 2>/dev/null && HOURS_RESET="${C_HOURS_RESET:-0}"
    [ "${WEEK_RESET:-0}"  -le 0 ] 2>/dev/null && WEEK_RESET="${C_WEEK_RESET:-0}"
fi
[ "$HOURS" -lt 0 ] 2>/dev/null && HOURS=0
[ "$WEEK"  -lt 0 ] 2>/dev/null && WEEK=0
if { [ "${HOURS_RESET:-0}" -gt 0 ] 2>/dev/null || [ "${WEEK_RESET:-0}" -gt 0 ] 2>/dev/null; } &&
   [ "$HOURS|$WEEK|$HOURS_RESET|$WEEK_RESET" != "$C_HOURS|$C_WEEK|$C_HOURS_RESET|$C_WEEK_RESET" ]; then
    tmp=$(mktemp "${RATE_CACHE}.XXXXXX") && printf '%s|%s|%s|%s\n' "$HOURS" "$WEEK" "$HOURS_RESET" "$WEEK_RESET" > "$tmp" && mv -f "$tmp" "$RATE_CACHE"
fi

# Force the values that feed arithmetic to plain integers: guards against jq exponential
# notation on absurd magnitudes and against a corrupted cache injecting non-numeric text.
case "$PCT"   in ''|*[!0-9]*) PCT=0 ;;   esac
case "$HOURS" in ''|*[!0-9]*) HOURS=0 ;; esac
case "$WEEK"  in ''|*[!0-9]*) WEEK=0 ;;  esac
case "$HOURS_RESET" in ''|*[!0-9]*) HOURS_RESET=0 ;; esac
case "$WEEK_RESET" in ''|*[!0-9]*) WEEK_RESET=0 ;; esac

# A window whose reset time has passed has rolled over: the remembered usage belongs to the
# previous window, so show it empty until fresh data arrives. Claude Code drops such windows
# from the payload, so this only ever applies to cached values.
[ "$HOURS_RESET" -gt 0 ] && [ "$HOURS_RESET" -le "$NOW" ] && { HOURS=0; HOURS_RESET=0; }
[ "$WEEK_RESET"  -gt 0 ] && [ "$WEEK_RESET"  -le "$NOW" ] && { WEEK=0;  WEEK_RESET=0; }

# Catppuccin Mocha (true color), matching zsh/.config/zsh/starship.toml's palette.
# RED is git-status's deleted/conflicted red (matches starship's own "bold red"). CRIT is
# the context/rate-limit critical color — back to the same vivid alarm red as RED, after
# several toned-down/pure-hue variants all read as too orange.
GREEN=$'\033[38;2;166;227;161m'; YELLOW=$'\033[38;2;249;226;175m'; RED=$'\033[1m\033[38;2;255;23;68m'
CRIT=$'\033[1m\033[38;2;255;23;68m'
MAUVE=$'\033[38;2;203;166;247m'; BLUE=$'\033[38;2;137;180;250m'; SKY=$'\033[38;2;137;220;235m'
TEXT=$'\033[38;2;205;214;244m'
OVERLAY1=$'\033[38;2;127;132;156m'; OVERLAY0=$'\033[38;2;108;112;134m'
BOLD=$'\033[1m'; RESET=$'\033[0m'

# Effort gradient + a distinct star color for thinking mode. PALE_RED is the original
# pastel Catppuccin red (#f38ba8) from before RED/CRIT became the vivid alarm color.
PALE_RED=$'\033[38;2;243;139;168m'; PINK=$'\033[38;2;245;194;231m'; LAVENDER=$'\033[38;2;180;190;254m'

# Conditional markers (fast mode, --agent name) and the group separator, which sits a step
# below OVERLAY0 so it reads as structure rather than content.
PEACH=$'\033[38;2;250;179;135m'; TEAL=$'\033[38;2;148;226;213m'; SURFACE2=$'\033[38;2;88;91;112m'

# Same glyph as starship.toml's [git_branch] symbol (U+F126), so the branch marker matches the
# shell prompt. Byte escapes because $'\u…' needs bash 4.2.
BRANCH_ICON=$'\xef\x84\xa6'

H_RESET_STR=""
if [ "$HOURS_RESET" -gt 0 ]; then
    case "$OSTYPE" in
        darwin*|*bsd*) H_RESET_TIME=$(date -r "$HOURS_RESET" "+%-I%p" 2>/dev/null) ;;
        *)             H_RESET_TIME=$(date -d "@$HOURS_RESET" "+%-I%p" 2>/dev/null) ;;
    esac
    H_RESET_TIME=${H_RESET_TIME/AM/am}; H_RESET_TIME=${H_RESET_TIME/PM/pm}
    [ -n "$H_RESET_TIME" ] && H_RESET_STR=" ${H_RESET_TIME}"
fi

# Days until the weekly reset, switching to hours inside the last day.
W_RESET_STR=""
if [ "$WEEK_RESET" -gt 0 ]; then
    W_LEFT=$(( WEEK_RESET - NOW ))
    if   [ "$W_LEFT" -ge 86400 ]; then W_RESET_STR=" $(( W_LEFT / 86400 ))d"
    elif [ "$W_LEFT" -ge 3600 ];  then W_RESET_STR=" $(( W_LEFT / 3600 ))h"
    else W_RESET_STR=" <1h"; fi
fi

# Two-tone bar of CELLS cells: filled portion in the caller's threshold color, empty portion
# dimmed to overlay0 as a track — RESET is baked in so call sites don't rewrap it. Sets BAR.
# Any usage fills at least one cell, so a 5-cell bar at 16% doesn't read as empty.
make_bar() {
    local val=${1:-0} cells=$2 color=$3 filled _fill _pad
    (( val < 0 )) && val=0; (( val > 100 )) && val=100
    filled=$(( val * cells / 100 )); (( val > 0 && filled == 0 )) && filled=1
    printf -v _fill "%${filled}s"; printf -v _pad "%$(( cells - filled ))s"
    BAR="${color}${_fill// /█}${OVERLAY0}${_pad// /░}${RESET}"
}

# The color helpers below set C (or MODEL_COLOR/SYM) instead of echoing: a $(…) call forks a
# subshell, and the status line re-renders after every assistant message.
usage_color() {
    if   [ "${1:-0}" -ge 40 ] 2>/dev/null; then C=$CRIT
    elif [ "${1:-0}" -ge 20 ] 2>/dev/null; then C=$YELLOW
    else C=$GREEN; fi
}

# Anything not in the map falls back to its ISO code followed by a space, e.g. "CHF 12.34".
currency_symbol() {
    case "$1" in
        EUR) SYM="€" ;;
        USD) SYM="\$" ;;
        GBP) SYM="£" ;;
        *)   SYM="$1 " ;;
    esac
}

# Rate-limit color: pace (burn rate vs. how much of the window has elapsed), then hard
# usage caps applied last. Args: used%  reset_epoch  window_seconds
pace_color() {
    local used=${1:-0} reset=${2:-0} win=${3:-1}
    C=$GREEN
    (( win <= 0 )) && win=1
    if [ "$reset" -gt 0 ] 2>/dev/null; then
        local left=$(( reset - NOW )); (( left < 0 )) && left=0
        local elapsed=$(( (win - left) * 100 / win ))
        (( elapsed < 0 )) && elapsed=0; (( elapsed > 100 )) && elapsed=100
        local over=$(( used - elapsed ))
        if   [ "$over" -ge 20 ]; then C=$CRIT
        elif [ "$over" -gt 0  ]; then C=$YELLOW; fi
    fi
    if   [ "$used" -gt 80 ] 2>/dev/null; then C=$CRIT
    elif [ "$used" -gt 50 ] 2>/dev/null && [ "$C" = "$GREEN" ]; then C=$YELLOW; fi
}

effort_color() {
    case "$1" in
        low)    C=$YELLOW ;;
        medium) C=$GREEN ;;
        high)   C=$PINK ;;
        xhigh)  C=$PALE_RED ;;
        max)    C=$CRIT ;;
        *)      C=$OVERLAY1 ;;
    esac
}

# Unrecognized models fall back to OVERLAY0 (same dim tone as the session-id line) and
# skip BOLD entirely — an unknown model shouldn't visually compete with a real one.
model_color() {
    MODEL_BOLD=$BOLD
    case "$1" in
        *[Oo]pus*|*OPUS*)     MODEL_COLOR=$MAUVE ;;
        *[Hh]aiku*|*HAIKU*)   MODEL_COLOR=$YELLOW ;;
        *[Ff]able*|*FABLE*)   MODEL_COLOR=$CRIT ;;
        *[Ss]onnet*|*SONNET*) MODEL_COLOR=$BLUE ;;
        *)                    MODEL_COLOR=$OVERLAY0; MODEL_BOLD="" ;;
    esac
}

usage_color "$PCT";                         CTX_COLOR=$C
pace_color "$HOURS" "$HOURS_RESET" 18000;   H_COLOR=$C
pace_color "$WEEK"  "$WEEK_RESET"  604800;  W_COLOR=$C

EXCEEDS_STR=""
[ "$EXCEEDS_200K" = "true" ] && EXCEEDS_STR=" ${CRIT}>200k${RESET}"

model_color "$MODEL"
MODEL_SEG="${MODEL_COLOR}${MODEL_BOLD}[$MODEL]${RESET}"
EFFORT_SEG=""
[ "$THINKING" = "true" ] && EFFORT_SEG="${LAVENDER}✱${RESET}"
if [ -n "$EFFORT" ]; then effort_color "$EFFORT"; EFFORT_SEG="${EFFORT_SEG}${C}${EFFORT}${RESET}"; fi
[ -n "$EFFORT_SEG" ] && MODEL_SEG="$MODEL_SEG $EFFORT_SEG"
# Fast mode bills at a premium, so it sits right next to the model while it's on.
[ "$FAST" = "true" ] && MODEL_SEG="$MODEL_SEG ${PEACH}${BOLD}fast${RESET}"

# Account credit change since this session was first observed: the account's spend.used minus the value first seen for
# this session id. The payload's total_cost_usd can't give this — it prices every token at API
# list rates, including subagent turns on models that bill to the plan windows, not credits.
# Account-level, so concurrent sessions each see the combined draw. A drop below the baseline
# means the monthly cap reset: re-baseline at zero rather than showing a negative.
# Gated on CREDIT_USED alone (not CREDIT_ON): CREDIT_USED already carries forward the last
# known value via CREDIT_STATE_CACHE above, so a temporarily-disabled reporting toggle still
# shows the account-level credit change instead of falling back to the USD list-price estimate.
SESSION_CREDITS=""
case "$SESSION_ID" in *[!A-Za-z0-9_-]*|'') ;; *)
    if [ -n "$CREDIT_USED" ]; then
        BASE_FILE="$CACHE_DIR/session-credits-${SESSION_ID}"
        BASE=""
        [ -f "$BASE_FILE" ] && IFS= read -r BASE < "$BASE_FILE"
        case "$BASE" in ''|*[!0-9.]*) BASE="" ;; esac
        if [ -z "$BASE" ] || awk -v u="$CREDIT_USED" -v b="$BASE" 'BEGIN{ exit !(u < b) }' 2>/dev/null; then
            [ -z "$BASE" ] && BASE="$CREDIT_USED" || BASE=0
            tmp=$(mktemp "${BASE_FILE}.XXXXXX") && printf '%s\n' "$BASE" > "$tmp" && mv -f "$tmp" "$BASE_FILE"
        fi
        SESSION_CREDITS=$(awk -v u="$CREDIT_USED" -v b="$BASE" 'BEGIN{ printf "%.2f", u - b }' 2>/dev/null)
    fi
;; esac

# Session money segment: the approximate session credit draw when available, colored the same
# way as the credits-left segment (red = a live reading this render, dim gray = a carried-over
# last-known figure while reporting is currently disabled — see the CREDIT_SEG comment below);
# otherwise the list-price estimate converted to the billing currency when a rate is cached,
# dimmed to mark it as an estimate. Non-numeric guard first so a bad payload value can't abort
# printf/awk and blank the whole line.
if [ -n "$SESSION_CREDITS" ]; then
    SESSION_CREDITS_COLOR="$OVERLAY0"; [ "$CREDIT_ON" = "true" ] && SESSION_CREDITS_COLOR="$CRIT"
    currency_symbol "${CREDIT_CUR:-USD}"
    COST_SEG="${SESSION_CREDITS_COLOR}~${SYM}${SESSION_CREDITS}${RESET}"
else
    case "$SESSION_COST" in ''|*[!0-9.]*) SESSION_COST=0 ;; esac
    COST_CUR="USD"; COST_VAL="$SESSION_COST"
    if [ -n "$FX_RATE" ]; then
        COST_VAL=$(awk -v c="$SESSION_COST" -v r="$FX_RATE" 'BEGIN{ printf "%.4f", c * r }' 2>/dev/null) && COST_CUR="$FX_CUR"
    fi
    printf -v COST_FMT '%.2f' "$COST_VAL" 2>/dev/null || COST_FMT="0.00"
    # A credit-billed account (we know a balance/limit, even from cache) with no known used
    # figure yet still gets the credits gray, not the generic dim estimate tone below — this
    # is that account's own currency estimate, not a genuinely separate USD estimate.
    ESTIMATE_COLOR="$OVERLAY1"
    { [ -n "$CREDIT_BAL" ] || [ -n "$CREDIT_LIMIT" ]; } && ESTIMATE_COLOR="$OVERLAY0"
    currency_symbol "$COST_CUR"
    COST_SEG="${ESTIMATE_COLOR}${SYM}${COST_FMT}${RESET}"
fi

# Mirrors starship.toml's directory/git_branch/git_status segments, same order as its format
# string: $ahead_behind$staged$modified$untracked$deleted$conflicted. The compact forms are
# for narrow panes: the last two path components, and the branch cut at 24 characters (ASCII
# names only — a byte cut could split a multibyte character in the C locale).
# Not ${DIR/#$HOME/~}: bash 5 tilde-expands that replacement straight back to $HOME.
SHORT_DIR=$DIR
if [ -n "$HOME" ]; then
    case "$DIR" in "$HOME"|"$HOME"/*) DIR_REST=${DIR#"$HOME"}; SHORT_DIR="~$DIR_REST" ;; esac
fi
COMPACT_DIR=$SHORT_DIR
DIR_PARENT=${SHORT_DIR%/*}
if [ "$DIR_PARENT" != "$SHORT_DIR" ] && [ "${DIR_PARENT%/*}" != "$DIR_PARENT" ] && [ -n "${DIR_PARENT%/*}" ]; then
    COMPACT_DIR="…/${DIR_PARENT##*/}/${SHORT_DIR##*/}"
fi
GIT_COUNTS=""
add_count() { GIT_COUNTS="${GIT_COUNTS:+$GIT_COUNTS }$1"; }
if [ -n "$BRANCH" ]; then
    SHORT_BRANCH=$BRANCH
    case "$BRANCH" in *[!\ -~]*) ;; *) [ "${#BRANCH}" -gt 24 ] && SHORT_BRANCH="${BRANCH:0:23}…" ;; esac
    if   [ "${AHEAD:-0}" -gt 0 ] 2>/dev/null && [ "${BEHIND:-0}" -gt 0 ] 2>/dev/null; then
        add_count "${SKY}${BOLD}⇡${AHEAD}⇣${BEHIND}${RESET}"
    elif [ "${AHEAD:-0}"  -gt 0 ] 2>/dev/null; then add_count "${SKY}${BOLD}⇡${AHEAD}${RESET}"
    elif [ "${BEHIND:-0}" -gt 0 ] 2>/dev/null; then add_count "${SKY}${BOLD}⇣${BEHIND}${RESET}"
    fi
    [ "${STAGED:-0}"     -gt 0 ] 2>/dev/null && add_count "${GREEN}${BOLD}+$STAGED${RESET}"
    [ "${MODIFIED:-0}"   -gt 0 ] 2>/dev/null && add_count "${YELLOW}${BOLD}●$MODIFIED${RESET}"
    [ "${UNTRACKED:-0}"  -gt 0 ] 2>/dev/null && add_count "${TEXT}${BOLD}?$UNTRACKED${RESET}"
    [ "${DELETED:-0}"    -gt 0 ] 2>/dev/null && add_count "${RED}✘$DELETED${RESET}"
    [ "${CONFLICTED:-0}" -gt 0 ] 2>/dev/null && add_count "${RED}⚡$CONFLICTED${RESET}"
fi

# Credits segment is the amount LEFT, bare (no label): a prepaid balance as-is, otherwise
# limit minus used for a monthly credit cap. Hidden entirely when credits are off and nothing
# is reported. Color signals live-ness, not the amount: CREDIT_ON reflects the *current* fetch
# (see the spend_on/extra_on gating above), not whether a figure is showing at all — a figure
# can still show while off, via CREDIT_STATE_CACHE/credit-currency, as last-known data. Red
# whole-number = a live reading this render; dim gray + a red dot = a carried-over last-known
# figure while reporting is currently disabled.
CREDIT_SEG=""
if [ "$CREDIT_ON" = "true" ] || [ -n "$CREDIT_BAL" ] || [ -n "$CREDIT_LIMIT" ]; then
    currency_symbol "${CREDIT_CUR:-USD}"
    LEFT=""
    if [ -n "$CREDIT_BAL" ]; then
        LEFT="$CREDIT_BAL"
    elif [ -n "$CREDIT_USED" ] && [ -n "$CREDIT_LIMIT" ]; then
        LEFT=$(awk -v u="$CREDIT_USED" -v l="$CREDIT_LIMIT" 'BEGIN{ r = l - u; if (r < 0) r = 0; printf "%.2f", r }' 2>/dev/null)
    fi
    printf -v LEFT_FMT '%.2f' "${LEFT:-x}" 2>/dev/null || LEFT_FMT=""
    if [ -n "$LEFT_FMT" ]; then
        if [ "$CREDIT_ON" = "true" ]; then
            CREDIT_SEG="${CRIT}${SYM}${LEFT_FMT}${RESET}"
        else
            CREDIT_SEG="${CRIT}●${OVERLAY0}${SYM}${LEFT_FMT}${RESET}"
        fi
    fi
fi

# ---------------------------------------------------------------------------------------
# Layout. Claude Code captures the script's output, so `tput cols` can't see the terminal;
# it exports COLUMNS instead (tput is only the fallback for running the script by hand).
# LAYOUT_MARGIN keeps lines clear of Claude Code's own padding and of the notifications it
# shows on the right of the status line row.
LAYOUT_MARGIN=4
COLS=${COLUMNS:-}
case "$COLS" in ''|0|*[!0-9]*) COLS=$(tput cols 2>/dev/null) ;; esac
case "$COLS" in ''|0|*[!0-9]*) COLS=80 ;; esac
AVAIL=$(( COLS - LAYOUT_MARGIN )); [ "$AVAIL" -lt 20 ] && AVAIL=20

# vis_width TEXT → VW, the terminal cells TEXT occupies: SGR escapes dropped, then UTF-8
# continuation bytes skipped (LC_ALL=C makes ${#} count bytes). Every glyph used here is one
# cell wide except ⚡, which has emoji presentation and takes two.
vis_width() {
    local s=$1 t
    while [[ $s == *$'\e['* ]]; do s=${s%%$'\e['*}${s#*$'\e['*m}; done
    t=${s//[$'\x80'-$'\xbf']/}; VW=${#t}
    case "$s" in *⚡*) t=${s//⚡/}; VW=$(( VW + (${#s} - ${#t}) / 3 )) ;; esac
}

# seg GROUP TEXT [COMPACT]: append a segment to GROUP. COMPACT is the narrower form used when
# the whole group can't fit on a line of its own.
NSEG=0
seg() {
    SEG_G[NSEG]=$1
    SEG_F[NSEG]=$2; vis_width "$2"; SEG_FW[NSEG]=$VW
    if [ $# -ge 3 ]; then SEG_C[NSEG]=$3; vis_width "$3"; SEG_CW[NSEG]=$VW
    else SEG_C[NSEG]=$2; SEG_CW[NSEG]=${SEG_FW[NSEG]}; fi
    NSEG=$(( NSEG + 1 ))
}

# Group 1, session: model + effort, agent, context, money. Narrow panes get 5-cell bars.
seg 1 "$MODEL_SEG"
[ -n "$AGENT" ] && seg 1 "${TEAL}@${AGENT}${RESET}"
make_bar "$PCT" 10 "$CTX_COLOR"; CTX_FULL="$BAR ${CTX_COLOR}${PCT}%${RESET}${EXCEEDS_STR}"
make_bar "$PCT" 5 "$CTX_COLOR";  seg 1 "$CTX_FULL" "$BAR ${CTX_COLOR}${PCT}%${RESET}${EXCEEDS_STR}"
seg 1 "$COST_SEG"

# Group 2, workspace: directory, branch, git counts.
[ -n "$SHORT_DIR" ] && seg 2 "${SKY}${SHORT_DIR}${RESET}" "${SKY}${COMPACT_DIR}${RESET}"
if [ -n "$BRANCH" ]; then
    seg 2 "${MAUVE}${BOLD}${BRANCH_ICON} ${BRANCH}${RESET}" "${MAUVE}${BOLD}${BRANCH_ICON} ${SHORT_BRANCH}${RESET}"
    [ -n "$GIT_COUNTS" ] && seg 2 "$GIT_COUNTS"
fi

# Group 3, account: weekly and 5-hour windows, credits left.
make_bar "$WEEK" 10 "$W_COLOR";  W_FULL="$BAR ${W_COLOR}w${WEEK}%${W_RESET_STR}${RESET}"
make_bar "$WEEK" 5 "$W_COLOR";   seg 3 "$W_FULL" "$BAR ${W_COLOR}w${WEEK}%${W_RESET_STR}${RESET}"
make_bar "$HOURS" 10 "$H_COLOR"; H_FULL="$BAR ${H_COLOR}h${HOURS}%${H_RESET_STR}${RESET}"
make_bar "$HOURS" 5 "$H_COLOR";  seg 3 "$H_FULL" "$BAR ${H_COLOR}h${HOURS}%${H_RESET_STR}${RESET}"
[ -n "$CREDIT_SEG" ] && seg 3 "$CREDIT_SEG"

# Group 4: the session id, cut to its first 8 characters only when even that line is too narrow.
[ -n "$SESSION_ID" ] && seg 4 "${OVERLAY0}${SESSION_ID}${RESET}" "${OVERLAY0}${SESSION_ID:0:8}${RESET}"

# Greedy fill, group by group: a group joins the current line (after a separator) when it
# fits there whole, otherwise it starts a new line. A group wider than a whole line switches
# to its compact form and, if still too wide, wraps between its own segments.
SEP=" ${SURFACE2}│${RESET} "; SEP_W=3
OUT=(); LINE=""; LW=0
flush() { [ "$LW" -gt 0 ] && OUT[${#OUT[@]}]=$LINE; LINE=""; LW=0; }
i=0
while [ "$i" -lt "$NSEG" ]; do
    g=${SEG_G[i]}; j=$i; gw=-1; cw=-1
    while [ "$j" -lt "$NSEG" ] && [ "${SEG_G[j]}" = "$g" ]; do
        gw=$(( gw + 1 + SEG_FW[j] )); cw=$(( cw + 1 + SEG_CW[j] )); j=$(( j + 1 ))
    done
    room=$AVAIL; [ "$LW" -gt 0 ] && room=$(( AVAIL - LW - SEP_W ))
    compact=0
    if   [ "$gw" -le "$room" ];  then :
    elif [ "$gw" -le "$AVAIL" ]; then flush
    else compact=1; [ "$cw" -le "$room" ] || flush
    fi
    jn=$SEP; jw=$SEP_W
    while [ "$i" -lt "$j" ]; do
        if [ "$compact" = 1 ]; then t=${SEG_C[i]}; w=${SEG_CW[i]}; else t=${SEG_F[i]}; w=${SEG_FW[i]}; fi
        [ "$LW" -gt 0 ] && [ $(( LW + jw + w )) -gt "$AVAIL" ] && flush
        if [ "$LW" -eq 0 ]; then LINE=$t; LW=$w; else LINE="$LINE$jn$t"; LW=$(( LW + jw + w )); fi
        jn=" "; jw=1; i=$(( i + 1 ))
    done
done
flush
printf -v RENDERED '%s\n' "${OUT[@]}"
printf '%s' "$RENDERED"

# Save the render for the timer runs' fast path at the top. The temp name doesn't need mktemp:
# CACHE_DIR is private and $$ is unique among live processes.
if [ -n "$RENDER_FILE" ]; then
    printf '%s\n%s\n%s' "$NOW" "$RENDER_KEY" "$RENDERED" > "$RENDER_FILE.$$" 2>/dev/null &&
        mv -f "$RENDER_FILE.$$" "$RENDER_FILE"
fi
