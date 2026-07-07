use ./common.nu [default_nix_config print-run]

def lock-path [flake: path] {
  $flake | path join "flake.lock"
}

def read-lock [flake: path] {
  let file = (lock-path $flake)

  if not ($file | path exists) {
    error make { msg: $"找不到 flake.lock: ($file)" }
  }

  open --raw $file | from json
}

# Complete inputs from the default nix-config flake.lock.
export def complete-flake-inputs [] {
  try {
    let lock = (read-lock $default_nix_config)
    $lock.nodes.root.inputs
    | columns
    | sort
    | each {|name|
      { value: $name, description: "nix flake input" }
    }
  } catch {
    []
  }
}

def complete-nfu-targets [] {
  [
    { value: "list", description: "List inputs from flake.lock." }
  ] ++ (complete-flake-inputs)
}

def default-inputs [] {
  let configured = ($env.NFU_DEFAULT_INPUTS? | default [dotfiles])

  if (($configured | describe) =~ "^list") {
    $configured | each {|input| $input | into string | str trim } | where {|input| not ($input | is-empty) }
  } else {
    $configured | into string | split row "," | each {|input| $input | str trim } | where {|input| not ($input | is-empty) }
  }
}

def input-source [node: record] {
  let locked = ($node.locked? | default {})
  let original = ($node.original? | default {})
  let type = ($locked.type? | default ($original.type? | default ""))

  if $type == "github" {
    $"($locked.owner? | default $original.owner?)/($locked.repo? | default $original.repo?)"
  } else if $type == "gitlab" {
    $"($locked.owner? | default $original.owner?)/($locked.repo? | default $original.repo?)"
  } else if $type == "path" {
    $locked.path? | default $original.path? | default ""
  } else if $type == "git" {
    $locked.url? | default $original.url? | default ""
  } else {
    $locked.url? | default $original.url? | default ""
  }
}

def list-inputs [flake: path] {
  let lock = (read-lock $flake)

  $lock.nodes.root.inputs
  | transpose input node
  | each {|row|
    let node = ($lock.nodes | get $row.node)
    let locked = ($node.locked? | default {})
    {
      input: $row.input
      type: ($locked.type? | default ($node.original?.type? | default ""))
      source: (input-source $node)
    }
  }
  | sort-by input
}

def nfu-args [
  flake: path
  inputs: list<string>
  options: record
] {
  mut args = [flake update]

  $args = ($args | append $inputs)
  $args = ($args | append [--flake $flake])

  if $options.accept_flake_config {
    $args = ($args | append "--accept-flake-config")
  }

  if $options.commit_lock_file {
    $args = ($args | append "--commit-lock-file")
  }

  $args
}

# Update nix-config flake.lock inputs.
export def nfu [
  ...inputs: string@complete-nfu-targets # Input names. Empty updates the configured default input.
  --flake (-f): path = $default_nix_config # Flake directory containing flake.lock.
  --all (-a) # Update all inputs.
  --commit-lock-file # Ask nix to commit flake.lock after updating it.
  --accept-flake-config # Accept flake configuration prompts.
  --dry-run (-n) # Print the command without changing flake.lock.
] {
  if (($inputs | length) == 1) and (($inputs | first) == "list") {
    print $"读取：($flake | path join 'flake.lock') root inputs"
    return (list-inputs $flake)
  }

  let update_inputs = if $all {
    []
  } else if ($inputs | is-empty) {
    default-inputs
  } else {
    $inputs
  }

  if (($update_inputs | is-empty) and (not $all)) {
    error make { msg: "默认 flake input 为空。设置 $env.NFU_DEFAULT_INPUTS，或直接指定 input，例如: nfu nixpkgs" }
  }

  let args = (nfu-args $flake $update_inputs {
    accept_flake_config: $accept_flake_config
    commit_lock_file: $commit_lock_file
  })

  print-run nix $args

  if not $dry_run {
    ^nix ...$args
  }
}
