use ./common.nu [default_nix_config]

export const nixos_rebuild_actions = [
  switch
  boot
  test
  build
  dry-build
]

# Local flake URLs refer to directories. Keep the path: prefix in suggestions.
def complete-local-flake-path [current: string] {
  if not ($current | str starts-with "path:") {
    return null
  }
  let partial_path = ($current | str substring 5..)
  glob --no-file $"($partial_path)*"
  | each {|directory| $"path:($directory)" }
}

export def complete-nixos-rebuild-actions [context: string] {
  if ($context | str starts-with "path:") {
    return (complete-local-flake-path $context)
  }

  let actions = [
    { value: "switch", description: "Build, activate, and make boot default" }
    { value: "boot", description: "Build and make boot default, but do not activate" }
    { value: "test", description: "Build and activate, but do not make boot default" }
    { value: "build", description: "Only build the configuration" }
    { value: "dry-build", description: "Show what would be built" }
  ]

  $actions | where $it.value starts-with $context
}

# Complete input names and local `path:` URLs for nrb's `--override-input` pairs.
export def complete-nixos-input-name [] {
  open --raw ($default_nix_config | path join "flake.lock")
  | from json
  | get nodes.root.inputs
  | columns
}

export def complete-nrb-override-input [spans: list<string>] {
  # The final span is the word being completed, including an empty word after space.
  let current = ($spans | last | default "")
  let preceding_words = ($spans | drop 1)
  let override_flags = (
    $preceding_words
    | enumerate
    | where item == "--override-input"
  )

  if ($override_flags | is-empty) {
    let positional_words = ($preceding_words | skip 1)
    let after_host = (($positional_words | length) == 1)
    let typing_action_first = ($positional_words | is-empty) and ($current != "")
    if $after_host or $typing_action_first {
      return (complete-nixos-rebuild-actions $current)
    }
    return null
  }

  let flag_index = ($override_flags | last | get index)
  let completed_values = ($preceding_words | skip ($flag_index + 1))
  # Each pair is an input name followed by a URL: even positions expect names.
  let expects_input_name = (($completed_values | length) mod 2) == 0
  if $expects_input_name {
    complete-nixos-input-name | where $it starts-with $current
  } else {
    complete-local-flake-path $current
  }
}

export def complete-wipe-older-than [] {
  [
    { value: "7d", description: "Keep the last seven days" }
    { value: "14d", description: "Keep the last fourteen days" }
    { value: "30d", description: "Keep the last thirty days" }
    { value: "90d", description: "Keep the last ninety days" }
  ]
}
