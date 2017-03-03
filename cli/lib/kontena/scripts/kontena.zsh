#compdef kontena
#autoload

_kontena() {
  local -a compreply
  compreply=($(kontena complete ${words[*]}))
  _describe -t kontena 'kontena' compreply
  return 0
}

_kontena
