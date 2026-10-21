#!/bin/sh
# Tests tmux-osc7501.patch against a tmux binary: sh tmux-osc7501-test.sh TMUX
# The FIFO-fed pane is adapted from autonomous-low-noise/tmux@4a77824.

[ -n "$1" ] || {
	echo "usage: $0 /path/to/tmux" >&2
	exit 2
}
TEST_TMUX=$1
TMP=$(mktemp -d "${TMPDIR:-/tmp}/osc7501.XXXXXX") || exit 1
TMUX_TMPDIR=$TMP
export TMUX_TMPDIR
unset TMUX
FIFO=$TMP/fifo
STEP=0
FAILED=0

t() { "$TEST_TMUX" -L osc7501test -f/dev/null "$@"; }
# shellcheck disable=SC2329 # run by the trap
cleanup() {
	t kill-server 2>/dev/null
	rm -rf "$TMP"
}
trap cleanup EXIT

b64() { printf '%s' "$1" | base64 | tr -d '\n'; }
repeat() {
	r='' i=0
	while [ "$i" -lt "$2" ]; do r="$r$1" i=$((i + 1)); done
	printf '%s' "$r"
}
pass() { echo "ok   $1"; }
fail() {
	echo "FAIL $1"
	FAILED=1
}

wait_format() { # target format want
	i=0
	while [ "$i" -lt 50 ]; do
		got=$(t display-message -p -t "$1" "$2" 2>/dev/null)
		[ "$got" = "$3" ] && return 0
		sleep 0.1
		i=$((i + 1))
	done
	fail "timeout waiting for $2 = '$3' (got '$got')"
}

# Send raw bytes, then a title change: once the title shows, tmux parsed both.
send() {
	STEP=$((STEP + 1))
	printf '%s\033]2;step%d\033\134' "$1" "$STEP" >"$FIFO"
	wait_format ps: '#{pane_title}' "step$STEP"
}
report() { send "$(printf '\033]7501;%s\033\134' "$1")"; }
report_bel() { send "$(printf '\033]7501;%s\007' "$1")"; }

check() { # name want
	got=$(t display-message -p -t ps: '#{@ps_state}|#{@ps_kind}|#{@ps_app}|#{@ps_msg}')
	if [ "$got" = "$2" ]; then pass "$1"; else fail "$1: got '$got' want '$2'"; fi
}
reset_events() { t set -pu -t ps: @t; }
check_events() { # name want
	got=$(t show -pqv -t ps: @t)
	if [ "$got" = "$2" ]; then pass "$1"; else fail "$1: got '$got' want '$2'"; fi
	reset_events
}

mkfifo "$FIFO" || exit 1
t new-session -d -x 80 -y 10 -s ps "exec cat <>$FIFO" || exit 1
t set-hook -g pane-status-changed \
	'set -pF @t "#{@t}#{hook_old_state}>#{hook_new_state},"'

check none '|||'

# Claude Code 2.1.303, as captured on the wire.
report 'state=idle:app=claude-code'
check claude-idle 'idle||claude-code|'
report 'state=working:app=claude-code'
check claude-working 'working||claude-code|'
m='approve Bash: touch approval-fixture.txt'
report "state=blocked:app=claude-code:kind=permission:msg=$(b64 "$m")"
check claude-permission "blocked|permission|claude-code|$m"
m='answer: Which throwaway color should I use? (Blue · Green)'
report "state=blocked:app=claude-code:kind=question:msg=$(b64 "$m")"
check claude-question "blocked|question|claude-code|$m"
report 'state=done:app=claude-code'
check claude-done 'done||claude-code|'
report 'state=clear'
check claude-clear '|||'
check_events events-on-state-change-only \
	'>idle,idle>working,working>blocked,blocked>done,done>,'

# Parsing.
report_bel 'state=working'
check bel-terminator 'working|||'
report ' state = idle : app = demo '
check spaces 'idle||demo|'
report 'state=working:state=done:app=a'
check last-wins 'done||a|'
report 'state=working:junk:=x:BAD=1:app=ok'
check malformed-pairs-skipped 'working||ok|'
report 'state=working:app=a!b'
check value-outside-charset 'working|||'
report 'state=working:app=a,b'
check app-invalid 'working|||'
report 'state=blocked:kind=nope'
check unknown-kind 'blocked|||'
report 'state=working:kind=question'
check kind-only-when-blocked 'working|||'
report 'state=error:msg=QQ'
check unpadded-2 'error|||A'
report 'state=error:msg=QUI'
check unpadded-3 'error|||AB'
report "state=error:msg=$(repeat YWFh 682)YWE"
check msg-at-limit "error|||$(repeat aaa 682)aa"
reset_events

# Rejected reports leave the record alone.
report 'state=done:app=keep'
for c in \
	'unknown-state|state=sleeping' \
	'missing-state|app=other' \
	'bad-id|state=idle:id=bad!' \
	'deep-id|state=idle:id=a/b/c/d/e/f/g/h/i' \
	"newline|state=idle:msg=$(b64 "$(printf 'a\nb')")" \
	'c1|state=idle:msg=eMKFeQ==' \
	"del|state=idle:msg=$(printf 'a\177b' | base64)" \
	'bad-base64|state=idle:msg=QQ=Q' \
	'length-1-mod-4|state=idle:msg=QUJDR' \
	'partial-padding|state=idle:msg=QQ=' \
	'long-key|state=idle:abcdefghijklmnopq=1' \
	"long-app|state=idle:app=$(repeat a 33)" \
	"msg-too-long|state=idle:msg=$(repeat YWFh 683)" \
	"sequence-too-long|state=idle:x=$(repeat a 4100)"; do
	report "${c#*|}"
	check "rejects-${c%%|*}" 'done||keep|'
done

# Child records are checked and ignored.
report "state=working:id=sub1:title=$(b64 'Sleep 25 seconds')"
check child-ignored 'done||keep|'
report 'state=clear:id=sub1'
check child-clear-ignored 'done||keep|'
reset_events

# A message change alone redraws but fires no event.
report "state=done:app=keep:msg=$(b64 later)"
check msg-only-change 'done||keep|later'
check_events msg-only-no-event ''

# Lifetimes.
report 'state=blocked:app=a'
send "$(printf '\033]133;A\033\134')"
check prompt-drops-blocked '|||'
report 'state=done:app=a'
send "$(printf '\033]133;A\033\134')"
check prompt-keeps-done 'done||a|'
send "$(printf '\033c')"
check ris-drops-all '|||'

# Program text is stored as sent and never run.
m="#(touch $TMP/pwn) %Y #[fg=red] ;"
report "state=error:msg=$(b64 "$m")"
check injection-stored-raw "error|||$m"
t display-message -p -t ps: '#{@ps_msg}' >/dev/null
if [ -e "$TMP/pwn" ]; then fail injection-not-run; else pass injection-not-run; fi

# The probe reply arrives before the DA1 reply, with the probe's terminator.
cat >"$TMP/probe.sh" <<'EOF'
stty raw -echo min 0 time 10
printf "$1"
cat >"$2"
EOF
probe() { # name probe want-prefix
	t new-session -d -s "$1" "sh $TMP/probe.sh '$2' $TMP/$1.out"
	i=0
	while [ "$i" -lt 50 ] && t has-session -t "$1" 2>/dev/null; do
		sleep 0.1
		i=$((i + 1))
	done
	got=$(cat -v "$TMP/$1.out")
	case $got in
	"$3"'^[[?1;2c' | "$3"'^[[?1;2;4c') pass "$1" ;;
	*) fail "$1: got '$got'" ;;
	esac
}
reply='^[]7501;?:states=idle,working,done,blocked,error:kinds=permission,question,auth'
probe probe-bel '\033]7501;?\007\033[c' "$reply^G"
probe probe-st '\033]7501;?\033\\\\\033[c' "$reply^[\\"

if t has-session -t ps 2>/dev/null; then pass server-alive; else fail server-alive; fi
[ "$FAILED" -eq 0 ] && echo "all passed"
exit "$FAILED"
