export const nixos_rebuild_actions = [
  switch
  boot
  test
  build
  dry-build
]

export def complete-nixos-rebuild-actions [context: string] {
  if ($context | str starts-with "path:") {
    let partial_path = ($context | str substring 5..)
    return (
      glob --no-file $"($partial_path)*"
      | each {|match| $"path:($match)" }
    )
  }

  let actions = [
    { value: "switch", description: "Build, activate, and make boot default" }
    { value: "boot", description: "Build and make boot default, but do not activate" }
    { value: "test", description: "Build and activate, but do not make boot default" }
    { value: "build", description: "Only build the configuration" }
    { value: "dry-build", description: "Show what would be built" }
  ]

  if $context == "" {
    return $actions
  }

  $actions | where $it.value starts-with $context
}

# Complete input names and local `path:` URLs for nrb's `--override-input` pairs.
export def complete-nixos-input-name [] {
  open --raw /configs/nix-config/flake.lock
  | from json
  | get nodes.root.inputs
  | columns
}

export def complete-nrb-override-input [spans: list<string>] {
  let flag_index = (
    $spans
    | enumerate
    | where item == "--override-input"
    | get index
    | last
    | default null
  )

  if $flag_index == null {
    let current = ($spans | last | default "")
    let before_current = if $current == "" {
      ($spans | skip 1 | drop)
    } else {
      ($spans | skip 1 | drop 1)
    }
    let should_complete_action = (($before_current | length) == 1) or (($before_current | is-empty) and ($current != ""))
    if $should_complete_action {
      return (complete-nixos-rebuild-actions $current)
    }
    return null
  }

  let values = ($spans | skip ($flag_index + 1))
  let current = ($values | last | default "")
  let completed_values = if $current == "" {
    ($values | drop)
  } else {
    ($values | drop 1)
  }

  if (($completed_values | length) mod 2) == 0 {
    let inputs = (complete-nixos-input-name)
    if $current == "" {
      return $inputs
    }
    return ($inputs | where $it starts-with $current)
  }

  if not ($current | str starts-with "path:") {
    return null
  }

  let partial_path = ($current | str substring 5..)
  let matches = (glob --no-file $"($partial_path)*")

  $matches | each {|match| $"path:($match)" }
}

export def complete-wipe-older-than [] {
  [
    { value: "7d", description: "Keep the last seven days" }
    { value: "14d", description: "Keep the last fourteen days" }
    { value: "30d", description: "Keep the last thirty days" }
    { value: "90d", description: "Keep the last ninety days" }
  ]
}
