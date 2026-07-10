#!/bin/bash
input=$(cat)

# Parse every field we need in a single jq pass (one field per line).
# - free-text fields are stripped of control chars (gsub cntrl) so a stray newline can't
#   shift the line-based read and an ESC/OSC byte can't inject into the terminal.
# - `| numbers` + `2>/dev/null` make each floored field abort-proof: a non-numeric value
#   falls back to its default instead of erroring out and truncating the rest.
# - rate-limit usage is -1 when the window is absent (distinguishes "absent" from a real 0%).
# - resets_at is Unix epoch seconds, floored straight into the *_RESET vars.
parsed=$(jq -r '
  (.model.display_name // "?" | gsub("[[:cntrl:]]";"")),
  (.workspace.current_dir // "" | gsub("[[:cntrl:]]";"")),
  (.session_id // "" | gsub("[[:cntrl:]]";"")),
  (.effort.level // ""), (.thinking.enabled // false),
  ((.context_window.used_percentage | numbers) // 0 | floor), (.exceeds_200k_tokens // false),
  ((.rate_limits.five_hour.used_percentage | numbers) // -1 | floor), ((.rate_limits.five_hour.resets_at | numbers) // 0 | floor),
  ((.rate_limits.seven_day.used_percentage | numbers) // -1 | floor), ((.rate_limits.seven_day.resets_at | numbers) // 0 | floor)
' 2>/dev/null <<< "$input")
{
  IFS= read -r MODEL;  IFS= read -r DIR;          IFS= read -r SESSION_ID
  IFS= read -r EFFORT; IFS= read -r THINKING
  IFS= read -r PCT;    IFS= read -r EXCEEDS_200K
  IFS= read -r HOURS;  IFS= read -r HOURS_RESET
  IFS= read -r WEEK;   IFS= read -r WEEK_RESET
} <<< "$parsed"

# Fill defaults when jq produced nothing (empty/invalid stdin): keep the -1 "absent" sentinel
# for rate usage so the cache logic below behaves, and avoid phantom values elsewhere.
: "${MODEL:=?}" "${PCT:=0}" "${EXCEEDS_200K:=false}" \
  "${HOURS:=-1}" "${WEEK:=-1}" "${HOURS_RESET:=0}" "${WEEK_RESET:=0}"

# Git status, cached per directory so concurrent sessions in the same repo share it.
DIR_HASH=$(printf '%s' "$DIR" | md5sum 2>/dev/null | cut -d' ' -f1)
[ -z "$DIR_HASH" ] && DIR_HASH=$(md5 -q -s "$DIR" 2>/dev/null)
[ -z "$DIR_HASH" ] && DIR_HASH=default
CACHE_FILE="/tmp/statusline-git-cache-${DIR_HASH}"
CACHE_MAX_AGE=5

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || \
    # stat -f %m is macOS, stat -c %Y is Linux
    [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

# clean up cache files older than 1 day (run occasionally, not every invocation)
if [ $((RANDOM % 20)) -eq 0 ]; then
    find /tmp -name "statusline-git-cache-*" -mtime +1 -delete 2>/dev/null
fi

# Branch goes LAST in the record (counts are integers, so a '|' in a branch name can't
# corrupt the field split); write via a temp file + atomic rename to avoid torn reads.
if cache_is_stale; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        printf '%s|%s|%s\n' "$STAGED" "$MODIFIED" "$BRANCH" > "${CACHE_FILE}.$$" && mv -f "${CACHE_FILE}.$$" "$CACHE_FILE"
    else
        printf '||\n' > "${CACHE_FILE}.$$" && mv -f "${CACHE_FILE}.$$" "$CACHE_FILE"
    fi
fi

IFS='|' read -r STAGED MODIFIED BRANCH < "$CACHE_FILE"

# Shared cache for rate limits (account-level, not per-session). The parse emits -1 for an
# absent window; fall back to the last known values only then, so a genuine 0% (e.g. right
# after a reset) is preserved instead of being clobbered by stale data.
RATE_CACHE="/tmp/statusline-rate-limits"
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
    printf '%s|%s|%s|%s\n' "$HOURS" "$WEEK" "$HOURS_RESET" "$WEEK_RESET" > "${RATE_CACHE}.$$" && mv -f "${RATE_CACHE}.$$" "$RATE_CACHE"
fi

# Force the values that feed arithmetic to plain integers: guards against jq exponential
# notation on absurd magnitudes and against a corrupted cache injecting non-numeric text.
case "$PCT"   in ''|*[!0-9]*) PCT=0 ;;   esac
case "$HOURS" in ''|*[!0-9]*) HOURS=0 ;; esac
case "$WEEK"  in ''|*[!0-9]*) WEEK=0 ;;  esac

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'; BLUE=$'\033[94m'; GRAY=$'\033[37m'; RESET=$'\033[0m'

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

make_bar() {
    local val=${1:-0} _fill _pad bar
    (( val < 0 )) && val=0; (( val > 100 )) && val=100
    local filled=$((val / 10)) empty=$((10 - val / 10))
    printf -v _fill "%${filled}s"; printf -v _pad "%${empty}s"
    bar="${_fill// /█}${_pad// /░}"
    eval "$2=\"\$bar\""
}

usage_color() {
    local val=${1:-0}
    if   [ "$val" -ge 40 ] 2>/dev/null; then echo "$RED"
    elif [ "$val" -ge 20 ] 2>/dev/null; then echo "$YELLOW"
    else echo "$GREEN"; fi
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
        if   [ "$over" -ge 20 ]; then color="$RED"
        elif [ "$over" -gt 0  ]; then color="$YELLOW"; fi
    fi
    if   [ "$used" -gt 80 ] 2>/dev/null; then color="$RED"
    elif [ "$used" -gt 50 ] 2>/dev/null && [ "$color" = "$GREEN" ]; then color="$YELLOW"; fi
    echo "$color"
}

make_bar "${PCT:-0}"   CTX_BAR;  CTX_COLOR=$(usage_color "${PCT:-0}")
make_bar "${HOURS:-0}" H_BAR;    H_COLOR=$(pace_color "${HOURS:-0}" "${HOURS_RESET:-0}" 18000)
make_bar "${WEEK:-0}"  W_BAR;    W_COLOR=$(pace_color "${WEEK:-0}"  "${WEEK_RESET:-0}"  604800)
H_RESET_COLOR=$H_COLOR; W_RESET_COLOR=$W_COLOR

EXCEEDS_STR=""
[ "$EXCEEDS_200K" = "true" ] && EXCEEDS_STR=" ${RED}>200k${RESET}"

THINK_MARK=""; [ "$THINKING" = "true" ] && THINK_MARK="✱"
EFFORT_SEG=""
if   [ -n "$EFFORT" ] && [ -n "$THINK_MARK" ]; then EFFORT_SEG=" ${GRAY}(${EFFORT} ${THINK_MARK})${RESET}"
elif [ -n "$EFFORT" ];                          then EFFORT_SEG=" ${GRAY}(${EFFORT})${RESET}"
elif [ -n "$THINK_MARK" ];                      then EFFORT_SEG=" ${GRAY}(${THINK_MARK})${RESET}"
fi
LINE1="${BLUE}[$MODEL]${RESET}${EFFORT_SEG} | ${CTX_COLOR}${CTX_BAR}${RESET} ${GRAY}${PCT:-0}% context${RESET}${EXCEEDS_STR}"

SHORT_DIR="${DIR/#$HOME/~}"
if [ -n "$BRANCH" ]; then
    GIT_COUNTS=""
    [ "${STAGED:-0}"   -gt 0 ] 2>/dev/null && GIT_COUNTS=" ${GREEN}+$STAGED${RESET}"
    [ "${MODIFIED:-0}" -gt 0 ] 2>/dev/null && GIT_COUNTS="${GIT_COUNTS} ${RED}~$MODIFIED${RESET}"
    LINE2="${GRAY}${SHORT_DIR}${RESET} on ${CYAN}$BRANCH${RESET}${GIT_COUNTS}"
else
    LINE2="${GRAY}${SHORT_DIR}${RESET}"
fi
LINE3="${W_COLOR}${W_BAR}${RESET} ${WEEK:-0}% weekly${W_RESET_COLOR}${W_RESET_STR}${RESET} | ${H_COLOR}${H_BAR}${RESET} ${HOURS:-0}% hourly${H_RESET_COLOR}${H_RESET_STR}${RESET}"

printf '%s\n%s\n%s\n%s%s%s\n' "$LINE1" "$LINE2" "$LINE3" "$GRAY" "$SESSION_ID" "$RESET"
