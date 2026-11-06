#!/bin/zsh
# Tool launcher with fzf history completion for tmux popup
# Single-popup solution using --expect flag
# Usage: tool-launcher.sh <pane_current_path>

PANE_PATH="$1"

# Change to the pane's directory
cd "$PANE_PATH" || exit 1

# Read zsh history, deduplicate, reverse order (most recent first)
history_items=$(tac ~/.zsh_history 2>/dev/null | \
  sed 's/^: [0-9]*:[0-9]*;//' | \
  awk '!seen[$0]++' | \
  head -500)

# Stage 1: Show fzf selector with --expect to capture key pressed
# --expect outputs: first line = key pressed, second line = selection
result=$(echo "$history_items" | \
  fzf --prompt="Command: " \
      --height=100% \
      --preview='echo "Will run: {}"' \
      --preview-window=down:3:wrap \
      --header="Enter=tool (auto-close) | Alt-Enter=command (see output)" \
      --expect=enter,alt-enter)

# Parse result: first line is the key, rest is the selection
key=$(echo "$result" | head -1)
cmd=$(echo "$result" | tail -1)

# Exit if no selection made
if [ -z "$cmd" ]; then
  exit 0
fi

# Clear screen and show what we're running
clear
echo "Running: $cmd"
echo ""

# Execute based on which key was pressed
if [ "$key" = "alt-enter" ]; then
  # Command mode: run and wait for keypress
  eval "$cmd"
  echo ""
  echo "Press any key to close..."
  read -k1
else
  # Tool mode (Enter or no specific key): run and auto-close
  # This is for TUI applications like vim, lazygit, etc.
  eval "$cmd"
fi
