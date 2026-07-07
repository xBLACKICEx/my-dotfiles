export const nixos_rebuild_actions = [
  switch
  boot
  test
  build
  dry-build
]

export def complete-nixos-rebuild-actions [] {
  [
    { value: "switch", description: "Build, activate, and make boot default" }
    { value: "boot", description: "Build and make boot default, but do not activate" }
    { value: "test", description: "Build and activate, but do not make boot default" }
    { value: "build", description: "Only build the configuration" }
    { value: "dry-build", description: "Show what would be built" }
  ]
}

export def complete-wipe-older-than [] {
  [
    { value: "7d", description: "Keep the last seven days" }
    { value: "14d", description: "Keep the last fourteen days" }
    { value: "30d", description: "Keep the last thirty days" }
    { value: "90d", description: "Keep the last ninety days" }
  ]
}
