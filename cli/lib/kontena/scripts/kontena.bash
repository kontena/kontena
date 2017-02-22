_kontena_complete() {
  COMPREPLY=()
  local word="${COMP_WORDS[COMP_CWORD]}"
  local completions="$(kontena complete ${COMP_WORDS[*]})"
  COMPREPLY=( $(compgen -W "$completions" -- "$word") )
}

which kontena > /dev/null && complete -F _kontena_complete kontena
