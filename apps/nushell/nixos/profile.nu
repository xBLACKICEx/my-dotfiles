use ./common.nu [print-run]

def require-packages [packages: list<string>] {
  if ($packages | is-empty) {
    error make { msg: "请至少提供一个软件包名，例如: npf install ripgrep fd" }
  }
}

# Convert a package name into a nix profile installable.
export def to-installable [package: string] {
  let value = ($package | str trim)

  if ($value | is-empty) {
    error make { msg: "软件包名不能为空" }
  }

  let already_flake_ref = (
    ($value =~ "#")
    or ($value | str starts-with ".")
    or ($value | str starts-with "/")
    or ($value | str starts-with "~")
    or ($value | str starts-with "path:")
    or ($value | str starts-with "git:")
    or ($value | str starts-with "github:")
    or ($value | str starts-with "gitlab:")
    or ($value | str starts-with "sourcehut:")
    or ($value | str starts-with "tarball:")
  )

  if $already_flake_ref {
    $value
  } else {
    $"nixpkgs#($value)"
  }
}

def profile-install [
  packages: list<string>
  dry_run: bool
  impure: bool
  accept_flake_config: bool
] {
  require-packages $packages
  let refs = ($packages | each {|package| to-installable $package })
  mut args = [profile install]

  if $impure {
    $args = ($args | append "--impure")
  }

  if $accept_flake_config {
    $args = ($args | append "--accept-flake-config")
  }

  $args = ($args | append $refs)

  print-run nix $args

  if not $dry_run {
    ^nix ...$args
  }
}

def profile-remove [
  packages: list<string>
  dry_run: bool
] {
  require-packages $packages

  let args = ([profile remove] | append $packages)
  print-run nix $args

  if not $dry_run {
    ^nix ...$args
  }
}

def profile-upgrade [
  packages: list<string>
  dry_run: bool
] {
  let args = if ($packages | is-empty) {
    [profile upgrade --all]
  } else {
    ([profile upgrade] | append $packages)
  }

  print-run nix $args

  if not $dry_run {
    ^nix ...$args
  }
}

def profile-gc [
  older_than: string
  dry_run: bool
] {
  let args = [profile wipe-history --older-than $older_than]
  print-run nix $args

  if not $dry_run {
    ^nix ...$args
  }
}

def complete-npf-actions [] {
  [
    { value: "install", description: "Install packages. Plain names become nixpkgs#name." }
    { value: "remove", description: "Remove packages from the profile." }
    { value: "upgrade", description: "Upgrade the whole profile or selected entries." }
    { value: "list", description: "List profile entries." }
    { value: "history", description: "Show profile generations." }
    { value: "gc", description: "Delete old profile generations." }
    { value: "add", description: "Alias for install." }
    { value: "rm", description: "Alias for remove." }
    { value: "up", description: "Alias for upgrade." }
    { value: "ls", description: "Alias for list." }
    { value: "hist", description: "Alias for history." }
  ]
}

# Manage user packages with nix profile.
export def npf [
  action: string@complete-npf-actions = "list" # install/remove/upgrade/list/history/gc.
  ...items: string # Packages, indexes, or generation depending on the action.
  --older-than (-o): string = "30d" # Delete generations older than this duration.
  --dry-run (-n) # Print the command without changing the profile.
  --impure # Pass --impure to nix profile install.
  --accept-flake-config # Accept flake configuration prompts.
] {
  match $action {
    "install" => { profile-install $items $dry_run $impure $accept_flake_config }
    "add" => { profile-install $items $dry_run $impure $accept_flake_config }
    "remove" => { profile-remove $items $dry_run }
    "rm" => { profile-remove $items $dry_run }
    "upgrade" => { profile-upgrade $items $dry_run }
    "up" => { profile-upgrade $items $dry_run }
    "list" => {
      print-run nix [profile list]
      ^nix profile list
    }
    "ls" => {
      print-run nix [profile list]
      ^nix profile list
    }
    "history" => {
      print-run nix [profile history]
      ^nix profile history
    }
    "hist" => {
      print-run nix [profile history]
      ^nix profile history
    }
    "gc" => { profile-gc $older_than $dry_run }
    _ => {
      error make { msg: $"未知 npf action: ($action). 可用值: install, remove, upgrade, list, history, gc" }
    }
  }
}
