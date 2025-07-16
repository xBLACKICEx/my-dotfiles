# nixos-rebuild with nom(nix-output-monitoring) output

def "nu-complete nixos-rebuild actions" [] {
  [
    {value: "switch" description: "Build, activate, and make boot default"}
    {value: "boot" description: "Build and make boot default, but don't activate"}
    {value: "test" description: "Build and activate, but don't make boot default"}
    {value: "build" description: "Only build the configuration"}
  ]
}

def update-nixos [
  action?: string@"nu-complete nixos-rebuild actions" = "test" # Action build to perform
  hostname?: string # hostname override default system hostname
  --specialisation (-c): string # Optional specialisation to use
] {
  # Get current hostname or use provided one
  let host = if $hostname == null {
    sys host | get hostname
  } else {
    $hostname
  }

  # Validate action
  let valid_actions = ["switch" "boot" "test" "build"]
  if ($action not-in $valid_actions) {
    error make {
      msg: $"Invalid action: ($action). Must be one of: ($valid_actions | str join ', ')"
    }
  }

  # Add specialisation if specified (works with switch and test)
  let spec_arg = if $specialisation != null {
    $"--specialisation ($specialisation)"
  } else {
    ""
  }

  # For 'buusing current hostname"ild' action, we don't need sudo
  if $action == "build" {
    print $"Building NixOS configuration for host: ($host)..."
    nixos-rebuild $action $spec_arg --flake $".#($host)" --log-format internal-json -v o+e>| nom --json
    return
  }

  # Pre-heat sudo cache to avoid password prompt in the middle of output
  sudo echo $"Starting NixOS rebuild \e[32m(($action))\e[0m for host: \e[34m($host)\e[0m...\n"

  # Create the full command string including piping to nom
  let cmd = $"sudo nixos-rebuild ($action) ($spec_arg) --flake .#($host) --log-format internal-json -v o+e>| nom --json"
  print $"Running: ($cmd)\n"

  # Execute the command string
  nu -c $cmd
}
