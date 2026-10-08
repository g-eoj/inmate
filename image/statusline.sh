#!/bin/bash
# Claude Code status line. Claude pipes session JSON on stdin on every update;
# whatever this prints is shown under the prompt.
set -euo pipefail

input=$(jq -c . 2>&1) && [ -n "$input" ] || { printf 'inmate-statusline: bad stdin: %s\n' "${input:-empty}" >&2; exit 1; }

eval "$(jq -r '
  @sh "model=\(.model.display_name // "-")",
  @sh "effort=\(.effort.level // "-")",
  @sh "pct=\(.context_window.used_percentage // 0 | floor)",
  @sh "size=\(.context_window.context_window_size // 200000)",
  @sh "tokens=\((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0))",
  @sh "vim=\(.vim.mode // "")"
' <<< "$input") "

reset=$'\e[0m'
dim=$'\e[2m'
bold=$'\e[1m'
cyan=$'\e[36m'
green=$'\e[32m'
yellow=$'\e[33m'
red=$'\e[31m'
magenta=$'\e[35m'
sep=" ${dim}|${reset} "

# Context usage bar
width=10
filled=$(( pct * width / 100 ))
[ "$filled" -gt "$width" ] && filled=$width
bar=""
for ((i = 0; i < width; i++ )); do
  if [ "$i" -lt "$filled" ]; then bar+="▓"; else bar+="░"; fi
done
if [ "$pct" -ge 90 ]; then bar_color=$red
elif [ "$pct" -ge 20 ] || [ "$tokens" -ge 200000 ]; then bar_color=$yellow
else bar_color=$green; fi

# 66k or 1.2M, integer math only
fmt_tokens() {
  if [ "$1" -ge 1000000 ]; then printf '%d.%dM' $(( $1 / 1000000 )) $(( $1 % 1000000 / 100000 ))
  elif [ "$1" -ge 1000 ]; then printf '%dk' $(( $1 / 1000 ))
  else printf '%d' "$1"; fi
}

line="${cyan}inmate: ${reset}${bold}${magenta}${model}${reset}"
line+="${sep}${effort}${reset}"
line+="${sep}${bar_color}${bar}${reset} ${pct}%"
line+="${sep}$(fmt_tokens "$tokens")/$(fmt_tokens "$size") tok"
if [ -n "$vim" ]; then
  case "$vim" in
    INSERT) vim_color=$green ;;
    NORMAL) vim_color=$cyan ;;
    *) vim_color=$magenta ;;
  esac
  line+="${sep}${vim_color}${vim}${reset}"
fi

printf '%s\n' "$line"
