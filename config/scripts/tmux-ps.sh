# Claude Code status for tmux: hooks (claude-code.nix) write the @ps_* pane
# options the status line and trees render. No hook fires when an approved
# tool starts or on Esc, so those show blocked/working until the next event.

pane=${TMUX_PANE:-}
app=claude
title=""
# agent|tool the pane is blocked on; only that tool's completion releases it
block=""

usage() {
  echo "usage: tmux-ps hook | set <state> [kind] [msg] | clear | visited <pane>" >&2
  exit 2
}

gopt() { tmux show -gqv "$1"; }
pget() { tmux show -pqv -t "$pane" "$1"; }

# one line without control chars (LC_ALL=C: UTF-8 locales class continuation
# bytes as cntrl), truncated, # and % doubled: every view expands the value
# once more as a format with strftime (#{T:...}, display-message)
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

# on screen (current window, not behind a zoomed sibling) in a client whose
# terminal has focus
seen() {
  local vis sess flags
  read -r vis sess < <(tmux display -p -t "$pane" '#{&&:#{window_active},#{||:#{pane_active},#{!:#{window_zoomed_flag}}}} #{session_id}')
  [ "$vis" = 1 ] || return 1
  while read -r flags; do
    case ",$flags," in *,focused,*) return 0 ;; esac
  done < <(tmux list-clients -t "$sess" -F '#{client_flags}')
  return 1
}

notify() { # state msg
  case ",$(gopt @ps-notify)," in
    *",$1,"*) ;;
    *) return 0 ;;
  esac
  if seen; then return 0; fi
  tmux display-message -C -t "$pane" -d 5000 \
    "$(icon "$1") $app $1 $2 (#{session_name}:#{window_index})" 2>/dev/null || true
}

set_state() { # state [kind] [msg]
  local state=$1 kind=${2:-} msg prev label
  local -a cmd
  msg=$(sanitize "${3:-}")
  prev=$(pget @ps_state)
  label=$(render "$state" "$kind" "$msg")
  cmd=(set -p -t "$pane" @ps_state "$state" \;
    set -p -t "$pane" @ps_kind "$kind" \;
    set -p -t "$pane" @ps_app "$app" \;
    set -p -t "$pane" @ps_msg "$msg" \;
    set -p -t "$pane" @ps_label "$label" \;
    set -p -t "$pane" @ps_block "$block")
  if [ -n "$title" ]; then cmd+=(\; set -p -t "$pane" @ps_title "$(sanitize "$title" 80)"); fi
  tmux "${cmd[@]}"
  if [ "$state" != "$prev" ]; then notify "$state" "$msg"; fi
}

clear_state() {
  tmux set -pu -t "$pane" @ps_state \; \
    set -pu -t "$pane" @ps_kind \; \
    set -pu -t "$pane" @ps_app \; \
    set -pu -t "$pane" @ps_msg \; \
    set -pu -t "$pane" @ps_label \; \
    set -pu -t "$pane" @ps_block \; \
    set -pu -t "$pane" @ps_title
}

# Claude outside tmux (VS Code terminal, ssh): a toast on tmux's current client
outside() { # event notification_type
  local state text
  case $1/$2 in
    Stop/*) state='done' text="✓ claude done (outside tmux)" ;;
    Notification/permission_prompt) state=blocked text="! claude needs permission (outside tmux)" ;;
    *) return 0 ;;
  esac
  case ",$(gopt @ps-notify 2>/dev/null)," in *",$state,"*) ;; *) return 0 ;; esac
  tmux display-message -C -d 5000 "$text" 2>/dev/null || true
}

hook() { # Claude Code hook JSON on stdin
  local ev tool ntype question message err interrupt word arg src agent bg cur key
  # US-separated: read collapses runs of tabs, which would shift empty fields
  IFS=$'\x1f' read -r -d '' ev tool ntype question message err interrupt word title arg src agent bg < <(jq -j '
    [ .hook_event_name, .tool_name, .notification_type,
      (try .tool_input.questions[0].question catch null), .message, .error,
      .is_interrupt, ((.prompt // "") | tostring | split(" ")[0]), .session_title,
      (try (.tool_input | .command // .file_path // .notebook_path // .url // .pattern // "" | tostring | split("\n")[0]) catch null),
      .source, .agent_id, (try (.background_tasks | length) catch 0) ]
    | map((. // "") | tostring | gsub("\u0000"; "") | gsub("\u001f"; "")) | join("\u001f")') || true
  if [ -z "$pane" ]; then
    outside "$ev" "$ntype"
    return 0
  fi
  read -r cur key < <(tmux display -p -t "$pane" '#{@ps_state} #{@ps_block}')
  case $ev in
    SessionStart) if [ "$src" != compact ]; then set_state idle; fi ;;
    # /command: may never start a turn (skills fire UserPromptExpansion);
    # a leading path such as /Users/... is an ordinary prompt
    UserPromptSubmit) case $word in /*/* | [!/]* | '') set_state working ;; esac ;;
    UserPromptExpansion) set_state working ;;
    PreToolUse)
      if [ "$tool" = AskUserQuestion ]; then
        block="$agent|$tool"
        set_state blocked question "$question"
      fi ;;
    PermissionRequest)
      block="$agent|$tool"
      case $tool in
        AskUserQuestion) ;;
        ExitPlanMode) set_state blocked question "approve plan" ;;
        *)
          case $tool in Edit | Write | Read | NotebookEdit) arg=${arg##*/} ;; esac
          set_state blocked permission "${tool#mcp__}${arg:+ $arg}" ;;
      esac ;;
    Notification)
      case $ntype in
        permission_prompt)
          # PermissionRequest carries the tool; this is the fallback and a reminder
          if [ "$cur" != blocked ]; then set_state blocked permission ""
          else notify blocked "$(pget @ps_msg)"; fi
          # hooks have no tty; Claude Code writes this for us (BEL is allowed)
          printf '{"terminalSequence":"\\u0007"}\n' ;;
        elicitation_dialog | elicitation_url_dialog) set_state blocked question "$message" ;;
        elicitation_complete | elicitation_response) if [ "$cur" = blocked ]; then set_state working; fi ;;
        idle_prompt) case $cur in working | blocked) set_state idle ;; esac ;;
      esac ;;
    PostToolUse | PostToolUseFailure | PermissionDenied)
      if [ "$interrupt" = true ]; then set_state idle
      elif [ "$cur" = blocked ]; then
        if [ -z "$key" ] || [ "$key" = "$agent|$tool" ]; then set_state working; fi
      elif [ "$cur" != working ]; then set_state working; fi ;;
    # pending background tasks wake Claude again; a mark only matters for
    # panes nobody is looking at
    Stop)
      if [ "$bg" != 0 ]; then
        if [ "$cur" != working ]; then set_state working; fi
      elif seen; then set_state idle
      else set_state 'done'; fi ;;
    StopFailure) if seen; then set_state idle; else set_state error "" "${err:-error}"; fi ;;
    SessionEnd) clear_state ;;
  esac
}

case ${1:-} in
  hook)
    # claude -p and SDK children inherit TMUX_PANE but aren't the pane's session
    case ${CLAUDE_CODE_ENTRYPOINT:-} in
      sdk-*) cat > /dev/null ;;
      *) hook ;;
    esac ;;
  visited)
    [ $# -ge 2 ] || usage
    pane=$2
    set_state idle ;;
  set | clear)
    if [ -z "$pane" ]; then exit 0; fi
    if [ "$1" = clear ]; then clear_state
    else
      [ $# -ge 2 ] || usage
      set_state "$2" "${3:-}" "${4:-}"
    fi ;;
  *) usage ;;
esac
