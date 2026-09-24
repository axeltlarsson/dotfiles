_ferry() {
  local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
  local opts="ship fetch dock status"
  case ${COMP_WORDS[1]} in
    ship|fetch)
      case $COMP_CWORD in
        2) opts="eu us" ;;
        3) COMPREPLY=( $(compgen -f -- "$cur") ); return ;;
        *) opts="--force --tag=" ;;
      esac ;;
    dock) opts="north south east ro rw" ;;
    status) opts="--json" ;;
  esac
  mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
}
complete -o filenames -F _ferry ferry
