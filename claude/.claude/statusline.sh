#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
EFFORT=$(jq -r '.effortLevel // "default"' ~/.claude/settings.json 2>/dev/null)

DIR_HASH=$(echo "$DIR" | md5sum 2>/dev/null | cut -d' ' -f1 || md5 -q -s "$DIR" 2>/dev/null)
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

if cache_is_stale; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        echo "$BRANCH|$STAGED|$MODIFIED" > "$CACHE_FILE"
    else
        echo "||" > "$CACHE_FILE"
    fi
fi

IFS='|' read -r BRANCH STAGED MODIFIED < "$CACHE_FILE"

PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
EXCEEDS_200K=$(echo "$input" | jq -r '.exceeds_200k_tokens')
HOURS=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
HOURS_RESET_RAW=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0' | cut -d. -f1)
WEEK_RESET_RAW=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0')

# convert ISO 8601 or epoch to epoch seconds
to_epoch() {
    local raw="$1"
    if [ -z "$raw" ] || [ "$raw" = "0" ] || [ "$raw" = "null" ]; then echo 0; return; fi
    if [[ "$raw" =~ ^[0-9]+$ ]]; then echo "$raw"; return; fi
    # ISO 8601 string — macOS uses -j -f, Linux uses -d
    if date -j -f "%Y-%m-%dT%H:%M:%S" "${raw:0:19}" "+%s" 2>/dev/null; then :
    elif date -d "${raw:0:19}" "+%s" 2>/dev/null; then :
    else echo 0; fi
}

HOURS_RESET=$(to_epoch "$HOURS_RESET_RAW")
WEEK_RESET=$(to_epoch "$WEEK_RESET_RAW")

# shared cache for rate limits (account-level, not per-session)
RATE_CACHE="/tmp/statusline-rate-limits"
if [ -f "$RATE_CACHE" ]; then
    IFS='|' read -r C_HOURS C_WEEK C_HOURS_RESET C_WEEK_RESET < "$RATE_CACHE"
    [ "$HOURS_RESET" -le 0 ] 2>/dev/null && HOURS_RESET="${C_HOURS_RESET:-0}"
    [ "$WEEK_RESET" -le 0 ] 2>/dev/null && WEEK_RESET="${C_WEEK_RESET:-0}"
    [ "${HOURS:-0}" -eq 0 ] 2>/dev/null && HOURS="${C_HOURS:-0}"
    [ "${WEEK:-0}" -eq 0 ] 2>/dev/null && WEEK="${C_WEEK:-0}"
fi
if [ "$HOURS_RESET" -gt 0 ] 2>/dev/null || [ "$WEEK_RESET" -gt 0 ] 2>/dev/null; then
    echo "$HOURS|$WEEK|$HOURS_RESET|$WEEK_RESET" > "$RATE_CACHE"
fi

GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; CYAN='\033[36m'; BLUE='\033[94m'; GRAY='\033[37m'; RESET='\033[0m'

NOW=$(date +%s)

# hourly reset time
H_RESET_STR=""
H_RESET_COLOR="$GRAY"
if [ "$HOURS_RESET" -gt 0 ] 2>/dev/null; then
    H_RESET_TIME=$(date -r "$HOURS_RESET" "+%-I%p" 2>/dev/null || date -d "@$HOURS_RESET" "+%-I%p" 2>/dev/null)
    H_RESET_TIME=$(echo "$H_RESET_TIME" | tr '[:upper:]' '[:lower:]')
    H_RESET_STR=" ${H_RESET_TIME}"
    if [ "${HOURS:-0}" -ge 40 ] 2>/dev/null; then
        H_REMAINING=$(( HOURS_RESET - NOW ))
        if [ "$H_REMAINING" -lt 3600 ] 2>/dev/null; then H_RESET_COLOR="$GREEN"
        elif [ "$H_REMAINING" -gt 7200 ] 2>/dev/null; then H_RESET_COLOR="$RED"
        else H_RESET_COLOR="$YELLOW"; fi
    fi
fi

# weekly reset time
W_RESET_STR=""
W_RESET_COLOR="$GRAY"
if [ "$WEEK_RESET" -gt 0 ] 2>/dev/null; then
    W_RESET_DAYS=$(( (WEEK_RESET - NOW) / 86400 ))
    if [ "$W_RESET_DAYS" -le 0 ] 2>/dev/null; then
        W_RESET_STR=" <1d"
    else
        W_RESET_STR=" ${W_RESET_DAYS}d"
    fi
    if [ "${WEEK:-0}" -ge 40 ] 2>/dev/null; then
        if [ "$W_RESET_DAYS" -le 0 ] 2>/dev/null; then W_RESET_COLOR="$GREEN"
        elif [ "$W_RESET_DAYS" -gt 3 ] 2>/dev/null; then W_RESET_COLOR="$RED"
        else W_RESET_COLOR="$YELLOW"; fi
    fi
fi

# builds a colored bar: make_bar <value> <bar_var> <color_var>
make_bar() {
    local val=${1:-0}
    local filled=$((val / 10)) empty=$((10 - val / 10))
    printf -v _fill "%${filled}s"; printf -v _pad "%${empty}s"
    local bar="${_fill// /█}${_pad// /░}"
    local color="$GREEN"
    if [ "$val" -ge 40 ]; then color="$RED"
    elif [ "$val" -ge 20 ]; then color="$YELLOW"; fi
    eval "$2=\"\$bar\""; eval "$3=\"\$color\""
}

make_bar "${PCT:-0}" CTX_BAR CTX_COLOR
make_bar "${HOURS:-0}" H_BAR H_COLOR
make_bar "${WEEK:-0}" W_BAR W_COLOR

EXCEEDS_STR=""
[ "$EXCEEDS_200K" = "true" ] && EXCEEDS_STR=" ${RED}>200k${RESET}"
LINE1="${BLUE}[$MODEL]${RESET} ${GRAY}($EFFORT)${RESET} | ${CTX_COLOR}${CTX_BAR}${RESET} ${GRAY}${PCT:-–}% context${RESET}${EXCEEDS_STR}"
SHORT_DIR="${DIR/#$HOME/~}"
if [ -n "$BRANCH" ]; then
    LINE2="${GRAY}${SHORT_DIR}${RESET} on ${CYAN}$BRANCH${RESET} ${GREEN}+$STAGED${RESET} ${RED}~$MODIFIED${RESET}"
else
    LINE2="${GRAY}${SHORT_DIR}${RESET}"
fi
LINE3="${W_COLOR}${W_BAR}${RESET} ${WEEK:-–}% weekly${W_RESET_COLOR}${W_RESET_STR}${RESET} | ${H_COLOR}${H_BAR}${RESET} ${HOURS:-–}% hourly${H_RESET_COLOR}${H_RESET_STR}${RESET}"

echo -e "$LINE1\n$LINE2\n$LINE3\n${GRAY}${SESSION_ID}${RESET}"
