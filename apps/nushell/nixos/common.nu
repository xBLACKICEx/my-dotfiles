# Shared helpers for this small NixOS/Nix toolkit.

export const default_nix_config = "/configs/nix-config"

# Keep command execution argv-based. It is more boring than string commands,
# which is exactly what we want when paths, hosts, or flags contain spaces.
export def printable-command [
  command: string
  args: list<any>
] {
  $"($command) ($args | each {|arg| $arg | into string } | str join ' ')"
}

export def print-run [
  command: string
  args: list<any>
] {
  print $"运行：(printable-command $command $args)"
}

export def print-run-raw [command: string] {
  print $"运行：($command)"
}

export def have-command [name: string] {
  not (which $name | is-empty)
}

export def ensure-non-empty [
  values: list<any>
  message: string
] {
  if ($values | is-empty) {
    error make { msg: $message }
  }
}
