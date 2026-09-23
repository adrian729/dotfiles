#!/bin/bash
input=$(cat)
# Money figures are formatted with printf/awk below; pin the decimal point so a comma locale
# can't turn "17.74" into "17,74" mid-line (LC_ALL, since it overrides LC_NUMERIC).
export LC_ALL=C

# Parse every field we need in a single jq pass (one field per line).
# - free-text fields are stripped of control chars (gsub cntrl) so a stray newline can't
#   shift the line-based read and an ESC/OSC byte can't inject into the terminal.
# - `| numbers` + `2>/dev/null` make each floored field abort-proof: a non-numeric value
#   falls back to its default instead of erroring out and truncating the rest.
# - rate-limit usage is -1 when the window is absent (distinguishes "absent" from a real 0%).
# - resets_at is Unix epoch seconds, floored straight into the *_RESET vars.
# - cost.total_cost_usd is present even when rate_limits is not (credit-billed sessions, e.g.
#   Fable): kept unfloored since it's a dollar figure, not a percentage.
parsed=$(jq -r '
  (.model.display_name // "?" | gsub("[[:cntrl:]]";"")),
  (.workspace.current_dir // "" | gsub("[[:cntrl:]]";"")),
  (.session_id // "" | gsub("[[:cntrl:]]";"")),
  (.effort.level // ""), (.thinking.enabled // false),
  ((.context_window.used_percentage | numbers) // 0 | floor), (.exceeds_200k_tokens // false),
  ((.rate_limits.five_hour.used_percentage | numbers) // -1 | floor), ((.rate_limits.five_hour.resets_at | numbers) // 0 | floor),
  ((.rate_limits.seven_day.used_percentage | numbers) // -1 | floor), ((.rate_limits.seven_day.resets_at | numbers) // 0 | floor),
  ((.cost.total_cost_usd | numbers) // 0)
' 2>/dev/null <<< "$input")
{
  IFS= read -r MODEL;  IFS= read -r DIR;          IFS= read -r SESSION_ID
  IFS= read -r EFFORT; IFS= read -r THINKING
  IFS= read -r PCT;    IFS= read -r EXCEEDS_200K
  IFS= read -r HOURS;  IFS= read -r HOURS_RESET
  IFS= read -r WEEK;   IFS= read -r WEEK_RESET
  IFS= read -r SESSION_COST
} <<< "$parsed"

# Fill defaults when jq produced nothing (empty/invalid stdin): keep the -1 "absent" sentinel
# for rate usage so the cache logic below behaves, and avoid phantom values elsewhere.
: "${MODEL:=?}" "${PCT:=0}" "${EXCEEDS_200K:=false}" \
  "${HOURS:=-1}" "${WEEK:=-1}" "${HOURS_RESET:=0}" "${WEEK_RESET:=0}" "${SESSION_COST:=0}"

# Private per-user cache dir — avoids predictable shared /tmp paths (symlink-follow
# clobber vector, spoofable reads on multi-user hosts). Shared with tmux-usage-status,
# which reads RATE_CACHE; keep both scripts' paths in sync if this moves again.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ai-status"
mkdir -p -m 700 "$CACHE_DIR"
chmod 700 "$CACHE_DIR" 2>/dev/null

# Portable mtime age in seconds. GNU `stat -c %Y` tried first: on Linux `stat -f` is
# filesystem-status mode, treats %m as a file and still prints a filesystem block for
# the real path, which leaks into the substitution and breaks the arithmetic. macOS has
# no -c, so it falls through to BSD `-f %m`. 0 (and a large resulting age) if the path
# is missing.
mtime_age() {
    echo $(( $(date +%s) - $(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0) ))
}

# Git status, cached per directory so concurrent sessions in the same repo share it.
DIR_HASH=$(printf '%s' "$DIR" | md5sum 2>/dev/null | cut -d' ' -f1)
[ -z "$DIR_HASH" ] && DIR_HASH=$(md5 -q -s "$DIR" 2>/dev/null)
[ -z "$DIR_HASH" ] && DIR_HASH=default
CACHE_FILE="$CACHE_DIR/statusline-git-cache-${DIR_HASH}"
CACHE_MAX_AGE=5

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || [ "$(mtime_age "$CACHE_FILE")" -gt "$CACHE_MAX_AGE" ]
}

# clean up cache files older than 1 day (run occasionally, not every invocation)
if [ $((RANDOM % 20)) -eq 0 ]; then
    find "$CACHE_DIR" -name "statusline-git-cache-*" -mtime +1 -delete 2>/dev/null
    find "$CACHE_DIR" -name "session-credits-*" -mtime +7 -delete 2>/dev/null
fi

# Branch goes LAST in the record (counts are integers, so a '|' in a branch name can't
# corrupt the field split); write via a temp file + atomic rename to avoid torn reads.
# Mirrors starship.toml's [git_status] categories (staged/modified/untracked/deleted/
# conflicted/ahead/behind) off one `git status --porcelain=v1 --branch` call, so a file
# that's both staged and deleted etc. gets counted the same way the prompt counts it.
if cache_is_stale; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=""; STAGED=0; MODIFIED=0; UNTRACKED=0; DELETED=0; CONFLICTED=0; AHEAD=0; BEHIND=0
        while IFS= read -r line; do
            case "$line" in
                "## "*)
                    branch_line="${line#"## "}"
                    BRANCH="${branch_line%%...*}"
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
        done < <(git status --porcelain=v1 --branch 2>/dev/null)
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

# Backgrounded, mkdir-locked refresh (mirrors tmux-usage-status's OpenCode cache refresh) so
# the statusline itself never blocks on the network. The token is passed to curl via a 600
# temp config file (`-K`), not `-H` on argv, so it never shows up in `ps`; the file is removed
# immediately after the request regardless of outcome.
refresh_usage_cache() {
    if [ -d "$USAGE_LOCK_DIR" ]; then
        local lock_pid; lock_pid=$(cat "$USAGE_LOCK_PID_FILE" 2>/dev/null)
        if [ -z "$lock_pid" ] || ! kill -0 "$lock_pid" 2>/dev/null; then
            local lock_age; lock_age=$(mtime_age "$USAGE_LOCK_DIR")
            [ "$lock_age" -gt "$USAGE_LOCK_MAX_AGE" ] && { rmdir "$USAGE_LOCK_DIR" 2>/dev/null; rm -f "$USAGE_LOCK_PID_FILE"; }
        fi
    fi
    mkdir "$USAGE_LOCK_DIR" 2>/dev/null || return
    (
        local token; token=$(get_claude_token)
        if [ -n "$token" ]; then
            local hdr_file; hdr_file=$(mktemp "$CACHE_DIR/usage-hdr.XXXXXX")
            chmod 600 "$hdr_file"
            # Escape backslash/quote so a token containing either can't break out of the
            # quoted curl -K value and inject extra config directives.
            local tok_esc="${token//\\/\\\\}"; tok_esc="${tok_esc//\"/\\\"}"
            {
                printf 'header = "Authorization: Bearer %s"\n' "$tok_esc"
                printf 'header = "anthropic-beta: oauth-2025-04-20"\n'
                printf 'header = "Accept: application/json"\n'
            } > "$hdr_file"
            local tmp; tmp=$(mktemp "$CACHE_DIR/claude-usage.json.XXXXXX")
            local code; code=$(curl -sS --max-time 5 -K "$hdr_file" -o "$tmp" -w '%{http_code}' "$CLAUDE_USAGE_URL" 2>/dev/null)
            rm -f "$hdr_file"
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
    [ ! -f "$USAGE_CACHE" ] && return 0
    local ttl="$USAGE_CACHE_TTL"
    # Confirmed-absent accounts (no credit balance/limit ever reported) get a much
    # longer TTL instead of polling every render — the data isn't going to appear.
    [ -f "$USAGE_NO_CREDIT_MARKER" ] && ttl="$USAGE_NO_CREDIT_TTL"
    [ "$(mtime_age "$USAGE_CACHE")" -gt "$ttl" ]
}
usage_cache_stale && refresh_usage_cache

# One jq pass over whatever cache exists (even stale — this round uses it as-is, the refresh
# above is for next time). Live shape on a Pro account with a monthly credit limit: spend.used/
# spend.limit are {amount_minor,currency,exponent}, spend.cap wraps the same under .money,
# spend.balance is null (prepaid balances only), and extra_usage mirrors the same figures as
# bare numbers in MINOR units (used_credits 226.0 == €2.26, scaled by decimal_places).
# `// null` (not `// empty`) on every field keeps the line count fixed so the positional
# `read`s below never desync.
E5H=-1; E5H_RESET=0; E7D=-1; E7D_RESET=0
CREDIT_BAL=""; CREDIT_USED=""; CREDIT_LIMIT=""; CREDIT_PCT=""; CREDIT_CUR="USD"; CREDIT_ON="false"
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
FX_LOCK_DIR="$CACHE_DIR/fx-refresh.lock"
refresh_fx_cache() {
    if [ -d "$FX_LOCK_DIR" ]; then
        local lock_age; lock_age=$(mtime_age "$FX_LOCK_DIR")
        [ "$lock_age" -gt "$USAGE_LOCK_MAX_AGE" ] && rmdir "$FX_LOCK_DIR" 2>/dev/null
    fi
    mkdir "$FX_LOCK_DIR" 2>/dev/null || return
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
    if [ ! -f "$FX_CACHE" ] || [ "$(mtime_age "$FX_CACHE")" -gt "$FX_CACHE_TTL" ]; then
        refresh_fx_cache
    fi
    [ -f "$FX_CACHE" ] && IFS= read -r FX_RATE < "$FX_CACHE"
    case "$FX_RATE" in ''|*[!0-9.]*) FX_RATE="" ;; esac
fi

# Shared cache for rate limits (account-level, not per-session). The parse emits -1 for an
# absent window; fall back to the last known values only then, so a genuine 0% (e.g. right
# after a reset) is preserved instead of being clobbered by stale data.
RATE_CACHE="$CACHE_DIR/statusline-rate-limits"
if [ -f "$RATE_CACHE" ]; then
    IFS='|' read -r C_HOURS C_WEEK C_HOURS_RESET C_WEEK_RESET < "$RATE_CACHE"
    [ "$HOURS" -lt 0 ] 2>/dev/null && HOURS="${C_HOURS:-0}"
    [ "$WEEK"  -lt 0 ] 2>/dev/null && WEEK="${C_WEEK:-0}"
    [ "${HOURS_RESET:-0}" -le 0 ] 2>/dev/null && HOURS_RESET="${C_HOURS_RESET:-0}"
    [ "${WEEK_RESET:-0}"  -le 0 ] 2>/dev/null && WEEK_RESET="${C_WEEK_RESET:-0}"
fi
[ "$HOURS" -lt 0 ] 2>/dev/null && HOURS=0
[ "$WEEK"  -lt 0 ] 2>/dev/null && WEEK=0
if [ "${HOURS_RESET:-0}" -gt 0 ] 2>/dev/null || [ "${WEEK_RESET:-0}" -gt 0 ] 2>/dev/null; then
    tmp=$(mktemp "${RATE_CACHE}.XXXXXX") && printf '%s|%s|%s|%s\n' "$HOURS" "$WEEK" "$HOURS_RESET" "$WEEK_RESET" > "$tmp" && mv -f "$tmp" "$RATE_CACHE"
fi

WEEKLY_LOG="$HOME/.local/share/claude/weekly-usage.log"
WEEKLY_STATE="$HOME/.local/share/claude/weekly-usage-state"
if [ "${WEEK_RESET:-0}" -gt 0 ] 2>/dev/null; then
    [ ! -d "$HOME/.local/share/claude" ] && mkdir -p "$HOME/.local/share/claude"
    PREV_WEEK_RESET=""
    PREV_WEEK_PCT=""
    if [ -f "$WEEKLY_STATE" ]; then
        IFS='|' read -r PREV_WEEK_PCT PREV_WEEK_RESET < "$WEEKLY_STATE" 2>/dev/null
    fi
    if [ -n "${PREV_WEEK_RESET}" ] && [ "${WEEK_RESET}" != "${PREV_WEEK_RESET}" ]; then
        printf '%s|%s|%s\n' "$(date +%s)" "${PREV_WEEK_PCT}" "${PREV_WEEK_RESET}" >> "$WEEKLY_LOG"
    fi
    printf '%s|%s\n' "$WEEK" "$WEEK_RESET" > "${WEEKLY_STATE}.$$" && mv -f "${WEEKLY_STATE}.$$" "$WEEKLY_STATE"
    if [ $((RANDOM % 50)) -eq 0 ] && [ -f "$WEEKLY_LOG" ]; then
        CUTOFF=$(( $(date +%s) - 3024000 ))
        TMPLOG="${WEEKLY_LOG}.trim.$$"
        while IFS='|' read -r ts pct rst; do
            [ "${ts:-0}" -gt "$CUTOFF" ] 2>/dev/null && printf '%s|%s|%s\n' "$ts" "$pct" "$rst"
        done < "$WEEKLY_LOG" > "$TMPLOG" && mv -f "$TMPLOG" "$WEEKLY_LOG"
    fi
fi

# Force the values that feed arithmetic to plain integers: guards against jq exponential
# notation on absurd magnitudes and against a corrupted cache injecting non-numeric text.
case "$PCT"   in ''|*[!0-9]*) PCT=0 ;;   esac
case "$HOURS" in ''|*[!0-9]*) HOURS=0 ;; esac
case "$WEEK"  in ''|*[!0-9]*) WEEK=0 ;;  esac

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

# Same glyph as starship.toml's [git_branch] symbol, so the branch marker matches the shell prompt.
BRANCH_ICON=$''

NOW=$(date +%s)

H_RESET_STR=""
if [ "${HOURS_RESET:-0}" -gt 0 ] 2>/dev/null; then
    H_RESET_TIME=$(date -r "$HOURS_RESET" "+%-I%p" 2>/dev/null || date -d "@$HOURS_RESET" "+%-I%p" 2>/dev/null)
    H_RESET_TIME=$(echo "$H_RESET_TIME" | tr '[:upper:]' '[:lower:]')
    [ -n "$H_RESET_TIME" ] && H_RESET_STR=" ${H_RESET_TIME}"
fi

W_RESET_STR=""
if [ "${WEEK_RESET:-0}" -gt 0 ] 2>/dev/null; then
    W_RESET_DAYS=$(( (WEEK_RESET - NOW) / 86400 ))
    if [ "$W_RESET_DAYS" -le 0 ] 2>/dev/null; then
        W_RESET_STR=" <1d"
    else
        W_RESET_STR=" ${W_RESET_DAYS}d"
    fi
fi

# Two-tone bar: filled portion in the caller's threshold color, empty portion
# dimmed to overlay0 as a track — RESET is baked in so call sites don't rewrap it.
make_bar() {
    local val=${1:-0} color=$2 outvar=$3 _fill _pad bar
    (( val < 0 )) && val=0; (( val > 100 )) && val=100
    local filled=$((val / 10)) empty=$((10 - val / 10))
    printf -v _fill "%${filled}s"; printf -v _pad "%${empty}s"
    bar="${color}${_fill// /█}${OVERLAY0}${_pad// /░}${RESET}"
    eval "$outvar=\"\$bar\""
}

usage_color() {
    local val=${1:-0}
    if   [ "$val" -ge 40 ] 2>/dev/null; then echo "$CRIT"
    elif [ "$val" -ge 20 ] 2>/dev/null; then echo "$YELLOW"
    else echo "$GREEN"; fi
}

# Anything not in the map falls back to its ISO code followed by a space, e.g. "CHF 12.34".
currency_symbol() {
    case "$1" in
        EUR) echo "€" ;;
        USD) echo "\$" ;;
        GBP) echo "£" ;;
        *)   printf '%s ' "$1" ;;
    esac
}

# Rate-limit color: pace (burn rate vs. how much of the window has elapsed), then hard
# usage caps applied last. Args: used%  reset_epoch  window_seconds
pace_color() {
    local used=${1:-0} reset=${2:-0} win=${3:-1} color="$GREEN"
    (( win <= 0 )) && win=1
    if [ "$reset" -gt 0 ] 2>/dev/null; then
        local left=$(( reset - NOW )); (( left < 0 )) && left=0
        local elapsed=$(( (win - left) * 100 / win ))
        (( elapsed < 0 )) && elapsed=0; (( elapsed > 100 )) && elapsed=100
        local over=$(( used - elapsed ))
        if   [ "$over" -ge 20 ]; then color="$CRIT"
        elif [ "$over" -gt 0  ]; then color="$YELLOW"; fi
    fi
    if   [ "$used" -gt 80 ] 2>/dev/null; then color="$CRIT"
    elif [ "$used" -gt 50 ] 2>/dev/null && [ "$color" = "$GREEN" ]; then color="$YELLOW"; fi
    echo "$color"
}

effort_color() {
    case "$1" in
        low)    echo "$YELLOW" ;;
        medium) echo "$GREEN" ;;
        high)   echo "$PINK" ;;
        xhigh)  echo "$PALE_RED" ;;
        max)    echo "$CRIT" ;;
        *)      echo "$OVERLAY1" ;;
    esac
}

# Unrecognized models fall back to OVERLAY0 (same dim tone as the session-id line) and
# skip BOLD entirely — an unknown model shouldn't visually compete with a real one.
model_color() {
    local m; m=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$m" in
        *opus*)   echo "$MAUVE" ;;
        *haiku*)  echo "$YELLOW" ;;
        *fable*)  echo "$CRIT" ;;
        *sonnet*) echo "$BLUE" ;;
        *)        echo "$OVERLAY0" ;;
    esac
}

model_bold() {
    local m; m=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$m" in
        *opus*|*haiku*|*fable*|*sonnet*) echo "$BOLD" ;;
        *)                               echo "" ;;
    esac
}

CTX_COLOR=$(usage_color "${PCT:-0}");                                    make_bar "${PCT:-0}"   "$CTX_COLOR" CTX_BAR
H_COLOR=$(pace_color "${HOURS:-0}" "${HOURS_RESET:-0}" 18000);           make_bar "${HOURS:-0}" "$H_COLOR"   H_BAR
W_COLOR=$(pace_color "${WEEK:-0}"  "${WEEK_RESET:-0}"  604800);          make_bar "${WEEK:-0}"  "$W_COLOR"   W_BAR

EXCEEDS_STR=""
[ "$EXCEEDS_200K" = "true" ] && EXCEEDS_STR=" ${CRIT}>200k${RESET}"

THINK_MARK=""; [ "$THINKING" = "true" ] && THINK_MARK="✱"
EFFORT_COLOR=$(effort_color "$EFFORT")
EFFORT_SEG=""
if   [ -n "$EFFORT" ] && [ -n "$THINK_MARK" ]; then EFFORT_SEG=" ${LAVENDER}${THINK_MARK}${RESET}${EFFORT_COLOR}${EFFORT}${RESET}"
elif [ -n "$EFFORT" ];                          then EFFORT_SEG=" ${EFFORT_COLOR}${EFFORT}${RESET}"
elif [ -n "$THINK_MARK" ];                      then EFFORT_SEG=" ${LAVENDER}${THINK_MARK}${RESET}"
fi
MODEL_COLOR=$(model_color "$MODEL"); MODEL_BOLD=$(model_bold "$MODEL")

# Credits this session actually drew: the account's spend.used minus the value first seen for
# this session id. The payload's total_cost_usd can't give this — it prices every token at API
# list rates, including subagent turns on models that bill to the plan windows, not credits.
# Account-level, so concurrent sessions each see the combined draw. A drop below the baseline
# means the monthly cap reset: re-baseline at zero rather than showing a negative.
# Gated on CREDIT_USED alone (not CREDIT_ON): CREDIT_USED already carries forward the last
# known value via CREDIT_STATE_CACHE above, so a temporarily-disabled reporting toggle still
# shows the real credits figure instead of falling back to the USD list-price estimate.
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

# Line-1 money segment: the real credits draw when available, colored the same way as the
# line-3 total (red = a live reading this render, dim gray = a carried-over last-known figure
# while reporting is currently disabled — see the CREDIT_SEG comment above); otherwise the
# list-price estimate converted to the billing currency when a rate is cached, dimmed to mark
# it as an estimate. Non-numeric guard first so a bad payload value can't abort printf/awk and
# blank the whole line.
if [ -n "$SESSION_CREDITS" ]; then
    SESSION_CREDITS_COLOR="$OVERLAY0"; [ "$CREDIT_ON" = "true" ] && SESSION_CREDITS_COLOR="$CRIT"
    COST_SEG=" ${SESSION_CREDITS_COLOR}$(currency_symbol "${CREDIT_CUR:-USD}")${SESSION_CREDITS}${RESET}"
else
    case "$SESSION_COST" in ''|*[!0-9.]*) SESSION_COST=0 ;; esac
    COST_CUR="USD"; COST_VAL="$SESSION_COST"
    if [ -n "$FX_RATE" ]; then
        COST_VAL=$(awk -v c="$SESSION_COST" -v r="$FX_RATE" 'BEGIN{ printf "%.4f", c * r }' 2>/dev/null) && COST_CUR="$FX_CUR"
    fi
    COST_FMT=$(printf '%.2f' "$COST_VAL" 2>/dev/null) || COST_FMT="0.00"
    # A credit-billed account (we know a balance/limit, even from cache) with no known used
    # figure yet still gets the credits gray, not the generic dim estimate tone below — this
    # is that account's own currency estimate, not a genuinely separate USD estimate.
    ESTIMATE_COLOR="$OVERLAY1"
    { [ -n "$CREDIT_BAL" ] || [ -n "$CREDIT_LIMIT" ]; } && ESTIMATE_COLOR="$OVERLAY0"
    COST_SEG=" ${ESTIMATE_COLOR}$(currency_symbol "$COST_CUR")${COST_FMT}${RESET}"
fi

LINE1="${MODEL_COLOR}${MODEL_BOLD}[$MODEL]${RESET}${EFFORT_SEG} ${CTX_BAR} ${CTX_COLOR}${PCT:-0}%${RESET}${EXCEEDS_STR}${COST_SEG}"

# Mirrors starship.toml's directory/git_branch/git_status segments exactly, same order as
# its format string: $ahead_behind$staged$modified$untracked$deleted$conflicted.
SHORT_DIR="${DIR/#$HOME/~}"
if [ -n "$BRANCH" ]; then
    GIT_COUNTS=""
    if   [ "${AHEAD:-0}" -gt 0 ] 2>/dev/null && [ "${BEHIND:-0}" -gt 0 ] 2>/dev/null; then
        GIT_COUNTS="${SKY}${BOLD}⇡${AHEAD}⇣${BEHIND} ${RESET}"
    elif [ "${AHEAD:-0}"  -gt 0 ] 2>/dev/null; then
        GIT_COUNTS="${SKY}${BOLD}⇡${AHEAD} ${RESET}"
    elif [ "${BEHIND:-0}" -gt 0 ] 2>/dev/null; then
        GIT_COUNTS="${SKY}${BOLD}⇣${BEHIND} ${RESET}"
    fi
    [ "${STAGED:-0}"     -gt 0 ] 2>/dev/null && GIT_COUNTS="${GIT_COUNTS}${GREEN}${BOLD}+$STAGED ${RESET}"
    [ "${MODIFIED:-0}"   -gt 0 ] 2>/dev/null && GIT_COUNTS="${GIT_COUNTS}${YELLOW}${BOLD}●$MODIFIED ${RESET}"
    [ "${UNTRACKED:-0}"  -gt 0 ] 2>/dev/null && GIT_COUNTS="${GIT_COUNTS}${TEXT}${BOLD}?$UNTRACKED ${RESET}"
    [ "${DELETED:-0}"    -gt 0 ] 2>/dev/null && GIT_COUNTS="${GIT_COUNTS}${RED}✘$DELETED ${RESET}"
    [ "${CONFLICTED:-0}" -gt 0 ] 2>/dev/null && GIT_COUNTS="${GIT_COUNTS}${RED}⚡$CONFLICTED ${RESET}"
    LINE2="${SKY}${SHORT_DIR}${RESET} ${MAUVE}${BOLD}${BRANCH_ICON} ${BRANCH}${RESET} ${GIT_COUNTS}"
else
    LINE2="${SKY}${SHORT_DIR}${RESET}"
fi
LINE3="${W_BAR} ${W_COLOR}w${WEEK:-0}%${W_RESET_STR}${RESET} ${H_BAR} ${H_COLOR}h${HOURS:-0}%${H_RESET_STR}${RESET}"

# Credits segment is the amount LEFT, bare (no label): a prepaid balance as-is, otherwise
# limit minus used for a monthly credit cap. Hidden entirely when credits are off and nothing
# is reported. Color signals live-ness, not the amount: CREDIT_ON reflects the *current* fetch
# (see the spend_on/extra_on gating above), not whether a figure is showing at all — a figure
# can still show while off, via CREDIT_STATE_CACHE/credit-currency, as last-known data. Red
# whole-number = a live reading this render; dim gray + a red dot = a carried-over last-known
# figure while reporting is currently disabled.
CREDIT_SEG=""
if [ "$CREDIT_ON" = "true" ] || [ -n "$CREDIT_BAL" ] || [ -n "$CREDIT_LIMIT" ]; then
    CUR_SYM=$(currency_symbol "${CREDIT_CUR:-USD}")
    LEFT=""
    if [ -n "$CREDIT_BAL" ]; then
        LEFT="$CREDIT_BAL"
    elif [ -n "$CREDIT_USED" ] && [ -n "$CREDIT_LIMIT" ]; then
        LEFT=$(awk -v u="$CREDIT_USED" -v l="$CREDIT_LIMIT" 'BEGIN{ r = l - u; if (r < 0) r = 0; printf "%.2f", r }' 2>/dev/null)
    fi
    LEFT_FMT=$(printf '%.2f' "${LEFT:-x}" 2>/dev/null) || LEFT_FMT=""
    if [ -n "$LEFT_FMT" ]; then
        if [ "$CREDIT_ON" = "true" ]; then
            CREDIT_SEG=" ${CRIT}${CUR_SYM}${LEFT_FMT}${RESET}"
        else
            CREDIT_SEG=" ${CRIT}●${OVERLAY0}${CUR_SYM}${LEFT_FMT}${RESET}"
        fi
    fi
fi
LINE3="${LINE3}${CREDIT_SEG}"

printf '%s\n%s\n%s\n%s%s%s\n' "$LINE1" "$LINE2" "$LINE3" "$OVERLAY0" "$SESSION_ID" "$RESET"
