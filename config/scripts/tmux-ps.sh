# Claude Code status for tmux: hooks (claude-code.nix) feed the @ps_* pane
# options that the status line renders. Same contract a future OSC 7501
# source (tmux patch or pty shim) would write.
# Limits: Claude Code only, no progress/subagent records; an Esc during
# streaming (no tool running) stays working until idle_prompt fires.

pane=${TMUX_PANE:-}
app=claude
title=""

usage() {
  echo "usage: tmux-ps hook | set <state> [kind] [msg] | clear" >&2
  exit 2
}

gopt() { tmux show -gqv "$1"; }
state_of() { tmux show -pqv -t "$pane" @ps_state; }
redraw() { tmux refresh-client -S 2>/dev/null || true; }

# one line, no control chars, truncated, then # and % doubled: every view
# expands these values once more as a format with strftime (#{T:...},
# display-message), so a message can never act as a format or a date.
# LC_ALL=C on tr: in UTF-8 locales [:cntrl:] matches UTF-8 continuation bytes
sanitize() { # text [max]
  local max s
  max=${2:-$(gopt @ps-label-max)}
  s=$(printf '%s' "$1" | tr '\n\t\r' '   ' | LC_ALL=C tr -d '[:cntrl:]')
  s=${s:0:${max:-30}}
  s=${s//#/##}
  printf '%s' "${s//%/%%}"
}

# replacements quoted: bash 5.2+ expands & in an unquoted one to the match
render() { # state kind msg
  local fmt
  fmt=$(gopt "@ps-format-$1")
  fmt=${fmt//\{app\}/"$app"}
  fmt=${fmt//\{kind\}/"$2"}
  printf '%s' "${fmt//\{msg\}/"$3"}"
}

icon() {
  case $1 in
    blocked) printf '!' ;;
    error) printf '✗' ;;
    done) printf '✓' ;;
    working) printf '●' ;;
    *) printf '·' ;;
  esac
}

# the pane is on screen in a client whose terminal has focus
seen() {
  local vis sess flags
  read -r vis sess < <(tmux display -p -t "$pane" '#{&&:#{pane_active},#{window_active}} #{session_id}')
  [ "$vis" = 1 ] || return 1
  while read -r flags; do
    case ",$flags," in *,focused,*) return 0 ;; esac
  done < <(tmux list-clients -t "$sess" -F '#{client_flags}')
  return 1
}

notify() { # state msg
  local want
  want=$(gopt @ps-notify)
  case ",$want," in
    *",$1,"*) ;;
    *) return 0 ;;
  esac
  if seen; then return 0; fi
  tmux display-message -t "$pane" -d 5000 \
    "$(icon "$1") $app $1 $2 (#{session_name}:#{window_index})" 2>/dev/null || true
}

set_state() { # state [kind] [msg]
  local state=$1 kind=${2:-} msg prev label
  local -a cmd
  msg=$(sanitize "${3:-}")
  prev=$(state_of)
  label=$(render "$state" "$kind" "$msg")
  cmd=(set -p -t "$pane" @ps_state "$state" \;
    set -p -t "$pane" @ps_kind "$kind" \;
    set -p -t "$pane" @ps_app "$app" \;
    set -p -t "$pane" @ps_msg "$msg" \;
    set -p -t "$pane" @ps_label "$label")
  if [ -n "$title" ]; then cmd+=(\; set -p -t "$pane" @ps_title "$(sanitize "$title" 80)"); fi
  tmux "${cmd[@]}"
  redraw
  if [ "$state" != "$prev" ]; then notify "$state" "$msg"; fi
}

clear_state() {
  tmux set -pu -t "$pane" @ps_state \; \
    set -pu -t "$pane" @ps_kind \; \
    set -pu -t "$pane" @ps_app \; \
    set -pu -t "$pane" @ps_msg \; \
    set -pu -t "$pane" @ps_label \; \
    set -pu -t "$pane" @ps_title
  redraw
}

hook() { # Claude Code hook JSON on stdin
  local ev tool ntype question message err interrupt lead arg
  # US-separated: read collapses runs of tabs, which would shift empty fields
  IFS=$'\x1f' read -r -d '' ev tool ntype question message err interrupt lead title arg < <(jq -j '
    [ .hook_event_name, .tool_name, .notification_type,
      ((.tool_input.questions? // [])[0] // {}).question?, .message, .error,
      .is_interrupt, (.prompt // "")[0:1], .session_title,
      ((.tool_input | objects) // {} | (.command // .file_path // .notebook_path // .url // .pattern // "") | tostring | split("\n")[0]) ]
    | map((. // "") | tostring | gsub("\u0000"; "") | gsub("\u001f"; "")) | join("\u001f")') || true
  case $ev in
    SessionStart) set_state idle ;;
    # a /command may never start a turn; the expansion or tool events will
    UserPromptSubmit) if [ "$lead" != / ]; then set_state working; fi ;;
    UserPromptExpansion) set_state working ;;
    PreToolUse)
      if [ "$tool" = AskUserQuestion ]; then set_state blocked question "$question"; fi ;;
    PermissionRequest)
      case $tool in Edit | Write | Read | NotebookEdit) arg=${arg##*/} ;; esac
      set_state blocked permission "${tool#mcp__}${arg:+ $arg}" ;;
    Notification)
      case $ntype in
        permission_prompt)
          # PermissionRequest carries the tool; this is the fallback and the bell
          if [ "$(state_of)" != blocked ]; then set_state blocked permission ""; fi
          # hooks have no tty; Claude Code writes this for us (BEL is allowed)
          printf '{"terminalSequence":"\\u0007"}\n' ;;
        elicitation_dialog | elicitation_url_dialog) set_state blocked question "$message" ;;
        idle_prompt) if [ "$(state_of)" = working ]; then set_state idle; fi ;;
      esac ;;
    PostToolUseFailure)
      if [ "$interrupt" = true ]; then set_state idle
      elif [ "$(state_of)" != working ]; then set_state working; fi ;;
    PostToolUse | PermissionDenied)
      if [ "$(state_of)" != working ]; then set_state working; fi ;;
    # a mark only matters for panes nobody is looking at
    Stop) if seen; then set_state idle; else set_state 'done'; fi ;;
    StopFailure) set_state error "" "${err:-error}" ;;
    SessionEnd) clear_state ;;
  esac
}

if [ -z "$pane" ]; then
  if [ "${1:-}" = hook ]; then cat > /dev/null; fi
  exit 0
fi

case ${1:-} in
  hook) hook ;;
  set)
    [ $# -ge 2 ] || usage
    set_state "$2" "${3:-}" "${4:-}" ;;
  clear) clear_state ;;
  *) usage ;;
esac
