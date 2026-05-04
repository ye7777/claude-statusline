#!/usr/bin/env bash

input=$(cat)

# --- Data extraction ---
five_pct=$(echo  "$input" | jq -r '.rate_limits.five_hour.used_percentage  // empty')
five_at=$(echo   "$input" | jq -r '.rate_limits.five_hour.resets_at        // empty')
week_pct=$(echo  "$input" | jq -r '.rate_limits.seven_day.used_percentage  // empty')
week_at=$(echo   "$input" | jq -r '.rate_limits.seven_day.resets_at        // empty')
cwd=$(echo       "$input" | jq -r '.workspace.current_dir // .cwd          // empty')
model=$(echo     "$input" | jq -r '.model.display_name                     // empty')
ctx_pct=$(echo   "$input" | jq -r '.context_window.used_percentage         // empty')
effort=$(echo    "$input" | jq -r '.effort.level                           // empty')

# --- Colors (ANSI) ---
reset='\033[0m'
dim='\033[2m'
cyan='\033[36m'
yellow='\033[33m'
magenta='\033[35m'
white='\033[37m'
sep="${dim} | ${reset}"

# --- Helper: format remaining time until epoch ---
fmt_remaining() {
    local target=$1
    local now=$(date +%s)
    local diff=$((target - now))
    [ "$diff" -le 0 ] && { echo "now"; return; }
    if [ "$diff" -ge 86400 ]; then
        local d=$((diff / 86400))
        local h=$(((diff % 86400) / 3600))
        if [ "$h" -gt 0 ]; then echo "${d}d${h}h"; else echo "${d}d"; fi
    elif [ "$diff" -ge 3600 ]; then
        local h=$((diff / 3600))
        local m=$(((diff % 3600) / 60))
        if [ "$m" -gt 0 ]; then echo "${h}h${m}m"; else echo "${h}h"; fi
    else
        echo "$((diff / 60))m"
    fi
}

# --- Field: model ---
if [ -n "$model" ]; then
    f_model="${magenta}${model}${reset}"
else
    f_model="${dim}no model${reset}"
fi

# --- Field: thinking effort (appended to model) ---
if [ -n "$effort" ]; then
    f_effort="${white}:${effort}${reset}"
else
    f_effort=""
fi

# --- Field: context usage % ---
if [ -n "$ctx_pct" ]; then
    ctx_int=$(printf '%.0f' "$ctx_pct")
    f_context="${white}context:${ctx_int}%${reset}"
else
    f_context="${dim}context:--${reset}"
fi

# --- Field: working directory ---
f_path="${cyan}${cwd}${reset}"

# --- Field: 5-hour session limit ---
if [ -n "$five_pct" ]; then
    five_int=$(printf '%.0f' "$five_pct")
    f_5h="${yellow}5h:${five_int}%${reset}"
    if [ -n "$five_at" ]; then
        f_5h="${f_5h}${dim}(reset in $(fmt_remaining "$five_at"))${reset}"
    fi
else
    f_5h="${dim}5h:--${reset}"
fi

# --- Field: weekly limit ---
if [ -n "$week_pct" ]; then
    week_int=$(printf '%.0f' "$week_pct")
    f_weekly="${yellow}weekly:${week_int}%${reset}"
    if [ -n "$week_at" ]; then
        f_weekly="${f_weekly}${dim}(reset in $(fmt_remaining "$week_at"))${reset}"
    fi
else
    f_weekly="${dim}weekly:--${reset}"
fi

printf '%b\n' "${f_model}${f_effort}${sep}${f_context}${sep}${f_path}${sep}${f_5h}${sep}${f_weekly}"
