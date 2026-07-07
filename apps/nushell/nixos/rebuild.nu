use ./completions.nu [complete-nixos-rebuild-actions nixos_rebuild_actions]
use ./common.nu [default_nix_config have-command print-run-raw printable-command]

const system_profile_dir = "/nix/var/nix/profiles"

def host-name [] {
  sys host | get hostname
}

def ensure-action [action: string] {
  if ($action not-in $nixos_rebuild_actions) {
    error make {
      msg: $"无效的 nixos-rebuild action: ($action). 可用值: ($nixos_rebuild_actions | str join ', ')"
    }
  }
}

def resolve-rebuild-target [
  target?: string
  action?: string
] {
  let current_host = (host-name)

  if $target == null {
    return { host: $current_host, action: "test" }
  }

  if ($target in $nixos_rebuild_actions) {
    let legacy_action = $target
    let legacy_host = ($action | default $current_host)

    return { host: $legacy_host, action: $legacy_action }
  }

  let resolved_action = ($action | default "test")
  ensure-action $resolved_action

  { host: $target, action: $resolved_action }
}

def rebuild-args [
  action: string
  flake_ref: string
  options: record
] {
  mut args = [$action --flake $flake_ref]

  if $options.specialisation != null {
    $args = ($args | append [--specialisation $options.specialisation])
  }

  if $options.build_host != null {
    $args = ($args | append [--build-host $options.build_host])
  }

  if $options.target_host != null {
    $args = ($args | append [--target-host $options.target_host])
  }

  if $options.use_remote_sudo {
    $args = ($args | append "--use-remote-sudo")
  }

  if $options.fast {
    $args = ($args | append "--fast")
  }

  if $options.accept_flake_config {
    $args = ($args | append "--accept-flake-config")
  }

  if $options.impure {
    $args = ($args | append "--impure")
  }

  $args
}

def current-system-generation [] {
  let row = (
    ls -la $system_profile_dir
    | where name == ($system_profile_dir | path join "system")
    | first
  )

  $row.target | parse "system-{generation}-link" | get 0.generation | into int
}

def system-generations [] {
  let current = (current-system-generation)

  ls -la $system_profile_dir
  | where type == symlink
  | where name =~ "system-[0-9]+-link$"
  | each {|row|
    let base = ($row.name | path basename)
    let gen = ($base | parse "system-{generation}-link" | get 0.generation | into int)
    {
      generation: $gen
      current: ($gen == $current)
      created: $row.created
      path: $row.name
      target: $row.target
    }
  }
  | sort-by generation
}

def previous-system-generation [] {
  let current = (current-system-generation)
  let previous = (
    system-generations
    | where generation < $current
    | sort-by generation
    | last
  )

  $previous.generation
}

def complete-system-generations [] {
  system-generations
  | reverse
  | each {|row|
    {
      value: ($row.generation | into string)
      description: (if $row.current { "current system generation" } else { $"created ($row.created)" })
    }
  }
}

def complete-nsg-actions [] {
  [
    { value: "list", description: "List NixOS system generations." }
    { value: "rollback", description: "Switch to the previous system generation." }
    { value: "switch", description: "Activate a selected system generation now." }
    { value: "boot", description: "Set a selected system generation for next boot." }
    { value: "test", description: "Activate a selected generation without making it boot default." }
  ]
}

def switch-system-generation [
  mode: string
  generation: int
  dry_run: bool
] {
  let profile = ($system_profile_dir | path join $"system-($generation)-link")
  let switcher = ($profile | path join "bin/switch-to-configuration")

  if not ($switcher | path exists) {
    error make { msg: $"找不到系统 generation ($generation): ($switcher)" }
  }

  print-run-raw $"sudo ($switcher) ($mode)"

  if not $dry_run {
    ^sudo $switcher $mode
  }
}

# Build or activate a NixOS host from nix-config.
export def nrb [
  target?: string # Host first. If omitted, use current hostname.
  action?: string@complete-nixos-rebuild-actions # switch, boot, test, build, or dry-build. Default: test.
  --flake (-f): path = $default_nix_config # Flake directory or flake ref.
  --specialisation (-c): string # Optional NixOS specialisation.
  --build-host: string # Remote builder host for nixos-rebuild.
  --target-host: string # Remote activation host for nixos-rebuild.
  --use-remote-sudo # Ask nixos-rebuild to use sudo on the target host.
  --fast # Pass --fast to nixos-rebuild.
  --accept-flake-config # Accept flake configuration prompts.
  --impure # Pass --impure to nixos-rebuild.
  --no-nom # Do not pipe internal-json logs through nom.
  --dry-run (-n) # Print the command without running it.
] {
  let rebuild_target = (resolve-rebuild-target $target $action)
  let host = $rebuild_target.host
  let action = $rebuild_target.action
  ensure-action $action

  let flake_ref = $"($flake)#($host)"
  let args = (rebuild-args $action $flake_ref {
    specialisation: $specialisation
    build_host: $build_host
    target_host: $target_host
    use_remote_sudo: $use_remote_sudo
    fast: $fast
    accept_flake_config: $accept_flake_config
    impure: $impure
  })
  let use_sudo = ($action not-in [build dry-build])
  let use_nom = ((not $no_nom) and (have-command nom))
  let runner = if $use_sudo { "sudo nixos-rebuild" } else { "nixos-rebuild" }

  let printable = if $use_nom {
    $"(printable-command $runner $args) --log-format internal-json -v o+e>| nom --json"
  } else {
    printable-command $runner $args
  }

  print $"Host: ($host)"
  print-run-raw $printable

  if $dry_run {
    return
  }

  if $use_sudo {
    ^sudo -v
  }

  if $use_nom {
    let log_args = ($args | append [--log-format internal-json -v])

    if $use_sudo {
      ^sudo nixos-rebuild ...$log_args o+e>| ^nom --json
    } else {
      ^nixos-rebuild ...$log_args o+e>| ^nom --json
    }
  } else {
    if $use_sudo {
      ^sudo nixos-rebuild ...$args
    } else {
      ^nixos-rebuild ...$args
    }
  }
}

# List or switch NixOS system generations.
export def nsg [
  action: string@complete-nsg-actions = "list" # list, rollback, switch, boot, or test.
  generation?: int@complete-system-generations # System generation number. Empty rollback uses previous generation.
  --dry-run (-n) # Print the command without switching generations.
] {
  match $action {
    "list" => {
      print $"读取：($system_profile_dir)/system-*-link"
      system-generations
    }
    "rollback" => {
      let gen = if $generation == null { previous-system-generation } else { $generation }
      switch-system-generation switch $gen $dry_run
    }
    "switch" => {
      if $generation == null {
        error make { msg: "请提供系统 generation，例如: nsg switch 27" }
      }
      switch-system-generation switch $generation $dry_run
    }
    "boot" => {
      if $generation == null {
        error make { msg: "请提供系统 generation，例如: nsg boot 27" }
      }
      switch-system-generation boot $generation $dry_run
    }
    "test" => {
      if $generation == null {
        error make { msg: "请提供系统 generation，例如: nsg test 27" }
      }
      switch-system-generation test $generation $dry_run
    }
    _ => {
      error make { msg: $"未知 nsg action: ($action). 可用值: list, rollback, switch, boot, test" }
    }
  }
}
