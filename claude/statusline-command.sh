#!/bin/bash

# Catppuccin Macchiato Color Palette
ROSEWATER=$'\033[38;2;244;219;214m'
PINK=$'\033[38;2;245;189;230m'
MAUVE=$'\033[38;2;198;160;246m'
RED=$'\033[38;2;237;135;150m'
PEACH=$'\033[38;2;245;169;127m'
YELLOW=$'\033[38;2;238;212;159m'
GREEN=$'\033[38;2;166;218;149m'
TEAL=$'\033[38;2;139;213;202m'
SAPPHIRE=$'\033[38;2;125;196;228m'
BLUE=$'\033[38;2;138;173;244m'
LAVENDER=$'\033[38;2;183;189;248m'
TEXT=$'\033[38;2;202;211;245m'
OVERLAY1=$'\033[38;2;128;135;162m'
RESET=$'\033[0m'

# Read JSON input
input=$(cat)

# Extract values
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Separator
SEP=" ${OVERLAY1}│${RESET} "

# Build statusline
OUTPUT=""

# Model
if [ -n "$model_name" ]; then
  OUTPUT+="${PINK}󰚩${RESET} ${ROSEWATER}${model_name}${RESET}"
fi

# Directory
if [ -n "$current_dir" ]; then
  [ -n "$OUTPUT" ] && OUTPUT+="$SEP"
  OUTPUT+="${BLUE}${RESET} ${SAPPHIRE}$(basename "$current_dir")${RESET}"
fi

# Git branch
if [ -n "$current_dir" ] && git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$current_dir" --no-optional-locks branch --show-current 2>/dev/null || echo "detached")
  [ -n "$OUTPUT" ] && OUTPUT+="$SEP"
  OUTPUT+="${MAUVE}${RESET} ${LAVENDER}${branch}${RESET}"

  # Git status
  git_status=$(git -C "$current_dir" --no-optional-locks status --porcelain 2>/dev/null)
  if [ -n "$git_status" ]; then
    changes=$(echo "$git_status" | wc -l | tr -d ' ')
    OUTPUT+="${SEP}${YELLOW}${RESET} ${YELLOW}${changes}${RESET}"
  else
    OUTPUT+="${SEP}${GREEN}${RESET} ${GREEN}clean${RESET}"
  fi
fi

# Context %
if [ -n "$remaining_pct" ] && [ "$remaining_pct" != "null" ]; then
  # Show context USED, not left - the token count beside it already covers volume.
  used_int=$((100 - $(printf '%.0f' "$remaining_pct")))
  if [ "$used_int" -ge 80 ]; then
    ctx_color="$RED"
  elif [ "$used_int" -ge 60 ]; then
    ctx_color="$YELLOW"
  else
    ctx_color="$GREEN"
  fi
  [ -n "$OUTPUT" ] && OUTPUT+="$SEP"
  OUTPUT+="${ctx_color}󰓅${RESET} ${TEXT}${used_int}%${RESET}"
fi

# Tokens
total_tokens=$((total_input + total_output))
if [ "$total_tokens" -gt 0 ]; then
  [ -n "$OUTPUT" ] && OUTPUT+="$SEP"
  if [ "$total_tokens" -ge 1000 ]; then
    tokens_display=$(echo "scale=1; $total_tokens / 1000" | bc)k
  else
    tokens_display="$total_tokens"
  fi
  OUTPUT+="${TEAL}󰔸${RESET} ${TEXT}${tokens_display}${RESET}"
fi

# Cost - reported by Claude Code, so it's right for whichever model is active.
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
  [ -n "$OUTPUT" ] && OUTPUT+="$SEP"
  OUTPUT+="${PEACH}${RESET} ${TEXT}\$$(printf '%.4f' "$cost")${RESET}"
fi

printf "%s" "$OUTPUT"
