#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
EFFORT=$(jq -r '.effortLevel // "default"' ~/.claude/settings.json 2>/dev/null)

DIR_HASH=$(echo "$DIR" | md5sum 2>/dev/null | cut -d' ' -f1 || md5 -q -s "$DIR" 2>/dev/null)
CACHE_FILE="/tmp/statusline-git-cache-${DIR_HASH}"
CACHE_MAX_AGE_SECONDS=5

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
HOURS_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0' | cut -d. -f1)
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0')

# shared cache for rate limits (account-level, not per-session)
RATE_CACHE="/tmp/statusline-rate-limits"
if [ -n "$HOURS" ] && [ -n "$WEEK" ]; then
    echo "$HOURS|$WEEK|$HOURS_RESET|$WEEK_RESET" > "$RATE_CACHE"
elif [ -f "$RATE_CACHE" ]; then
    IFS='|' read -r HOURS WEEK HOURS_RESET WEEK_RESET < "$RATE_CACHE"
fi

# hourly reset time
H_RESET_STR=""
if [ -n "$HOURS_RESET" ] && [ "$HOURS_RESET" -gt "$(date +%s)" ] 2>/dev/null; then
    H_RESET_TIME=$(date -r "$HOURS_RESET" "+%-I%p" 2>/dev/null | tr '[:upper:]' '[:lower:]')
    H_RESET_STR=" resets ${H_RESET_TIME}"
fi

# weekly reset time
W_RESET_STR=""
if [ -n "$WEEK_RESET" ] && [ "$WEEK_RESET" -gt "$(date +%s)" ] 2>/dev/null; then
    W_RESET_DAYS=$(( ($WEEK_RESET - $(date +%s)) / 86400 ))
    W_RESET_STR=" resets ${W_RESET_DAYS}d"
fi

GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; CYAN='\033[36m'; BLUE='\033[94m'; GRAY='\033[37m'; RESET='\033[0m'

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
LINE3="${W_COLOR}${W_BAR}${RESET} weekly ${WEEK:-–}%${GRAY}${W_RESET_STR}${RESET} | ${H_COLOR}${H_BAR}${RESET} hourly ${HOURS:-–}%${GRAY}${H_RESET_STR}${RESET}"

echo -e "$LINE1\n$LINE2\n$LINE3\n${GRAY}${SESSION_ID}${RESET}"
