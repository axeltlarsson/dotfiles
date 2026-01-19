# Tmux buffer manager
# Usage: tmux-buffer-manager [target-pane] [working-dir]
# If target-pane is provided, paste will go to that pane

TARGET_PANE="${1:-}"
WORK_DIR="${2:-.}"

list_buffers() {
  tmux list-buffers -F "#{buffer_name} | #{buffer_sample}"
}

# Extract buffer name from fzf selection (first field, trim trailing space)
get_buffer_name() {
  echo "$1" | cut -d'|' -f1 | sed 's/ *$//'
}

# File picker for loading files into buffers
pick_file() {
  fd --type f --hidden --follow --exclude .git --exclude node_modules . "$WORK_DIR" 2>/dev/null | fzf \
    --prompt="file> " \
    --header="Enter: select | Esc: cancel" \
    --layout=reverse \
    --height=100% \
    --preview='bat --style=plain --color=always {} 2>/dev/null | head -200' \
    --preview-window='down,60%,wrap'
}

# Main loop - allows delete/save/load to return to picker
while true; do
  # Select buffer with fzf (--expect captures which key was pressed)
  result=$(list_buffers | fzf \
    --prompt="buffer> " \
    --header="Enter: paste | Ctrl-D: delete | Ctrl-S: save | Ctrl-O: load file | Tab: multi-select | Esc: close" \
    --layout=reverse \
    --height=100% \
    --delimiter=' \| ' \
    --with-nth='1,2' \
    --preview='tmux show-buffer -b {1} | bat --style=plain --color=always --language=txt' \
    --preview-window='down,60%,wrap' \
    --multi \
    --expect='ctrl-d,ctrl-s,ctrl-o' \
  ) || exit 0

  # First line is the key pressed, remaining lines are selections
  key=$(echo "$result" | head -1)
  selections=$(echo "$result" | tail -n +2)

  # Handle load file (doesn't need a buffer selection)
  if [[ "$key" == "ctrl-o" ]]; then
    file=$(pick_file)
    if [[ -n "$file" ]]; then
      printf "Buffer name (optional): "
      read -r bufname </dev/tty
      if [[ -n "$bufname" ]]; then
        tmux load-buffer -b "$bufname" "$file"
      else
        tmux load-buffer "$file"
      fi
    fi
    continue
  fi

  # Other actions require at least one buffer selected
  if [[ -z "$selections" ]]; then
    exit 0
  fi

  case "$key" in
    ctrl-d)
      # Delete selected buffers and loop back to picker
      while IFS= read -r line; do
        buffer_name=$(get_buffer_name "$line")
        if [[ -n "$buffer_name" ]]; then
          tmux delete-buffer -b "$buffer_name"
        fi
      done <<< "$selections"
      continue
      ;;
    ctrl-s)
      # Save selected buffers to files, then return to picker
      while IFS= read -r line; do
        buffer_name=$(get_buffer_name "$line")
        if [[ -n "$buffer_name" ]]; then
          printf "Save '%s' to file: " "$buffer_name"
          read -r filepath </dev/tty
          if [[ -n "$filepath" ]]; then
            tmux save-buffer -b "$buffer_name" "$filepath"
          fi
        fi
      done <<< "$selections"
      continue
      ;;
    *)
      # Enter: paste first selected buffer
      buffer_name=$(get_buffer_name "$(echo "$selections" | head -1)")
      if [[ -n "$buffer_name" ]]; then
        if [[ -n "$TARGET_PANE" ]]; then
          tmux paste-buffer -t "$TARGET_PANE" -b "$buffer_name"
        else
          tmux paste-buffer -b "$buffer_name"
        fi
      fi
      exit 0
      ;;
  esac
done
