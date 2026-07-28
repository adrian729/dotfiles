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

# Private per-user cache dir — avoids predictable shared /tmp paths (symlink-follow
# clobber vector, spoofable reads on multi-user hosts). Shared with tmux-usage-status,
# which reads RATE_CACHE; keep both scripts' paths in sync if this moves again.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ai-status"
mkdir -p -m 700 "$CACHE_DIR"
chmod 700 "$CACHE_DIR" 2>/dev/null

# Git status, cached per directory so concurrent sessions in the same repo share it.
DIR_HASH=$(printf '%s' "$DIR" | md5sum 2>/dev/null | cut -d' ' -f1)
[ -z "$DIR_HASH" ] && DIR_HASH=$(md5 -q -s "$DIR" 2>/dev/null)
[ -z "$DIR_HASH" ] && DIR_HASH=default
CACHE_FILE="$CACHE_DIR/statusline-git-cache-${DIR_HASH}"
CACHE_MAX_AGE=5

cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || \
    # stat -f %m is macOS, stat -c %Y is Linux
    [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

# clean up cache files older than 1 day (run occasionally, not every invocation)
if [ $((RANDOM % 20)) -eq 0 ]; then
    find "$CACHE_DIR" -name "statusline-git-cache-*" -mtime +1 -delete 2>/dev/null
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
LINE1="${MODEL_COLOR}${MODEL_BOLD}[$MODEL]${RESET}${EFFORT_SEG} ${CTX_BAR} ${CTX_COLOR}${PCT:-0}%${RESET}${EXCEEDS_STR}"

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

printf '%s\n%s\n%s\n%s%s%s\n' "$LINE1" "$LINE2" "$LINE3" "$OVERLAY0" "$SESSION_ID" "$RESET"
