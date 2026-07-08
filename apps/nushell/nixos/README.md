# Nushell NixOS tools

这个目录放 NixOS 平台专用的 Nushell 工具。`apps/nushell/nixos` 是新的入口；旧路径
`nixos/nushell/nixos/update.nu` 只做兼容转发。

这里的脚本只负责“提供功能”。是否启用由 `nix-config` 的具体用户配置决定。

## 加载

临时使用：

```nu
use /configs/my-dotfiles/apps/nushell/nixos *
```

在 `nix-config` 管理的 Home Manager 中，可以只给 NixOS 用户加：

```nix
programs.nushell.extraConfig = lib.mkAfter ''
  use ${inputs.dotfiles}/apps/nushell/nixos/mod.nu *
'';
```

不要放进跨平台 common 配置里，这样 Windows 或其他平台就不会加载这些 NixOS 命令。

旧路径仍然可用：

```nu
use /configs/my-dotfiles/nixos/nushell/nixos/update.nu *
```

修改本目录脚本后，当前已经打开的 Nushell 不会自动刷新命令定义。想立刻测试新代码：

```nu
use /configs/my-dotfiles/apps/nushell/nixos/mod.nu *
```

如果是通过 `nix-config` 里的 `${inputs.dotfiles}` 加载，需要先更新 `dotfiles` input 并重新
activate Home Manager / NixOS 配置，因为 `${inputs.dotfiles}` 指向的是 `/nix/store` 里的锁定副本。

## NixOS rebuild

默认 host 使用当前系统 hostname，默认 action 是 `test`：

```nu
nrb
nrb HOST_NAME
nrb HOST_NAME switch
```

指定 host 和 flake：

```nu
nrb HOST_NAME build
nrb laptop switch --flake /configs/nix-config
```

先看命令不执行：

```nu
nrb HOST_NAME build --dry-run --no-nom
```

使用 specialisation：

```nu
nrb HOST_NAME test --specialisation plasma
nrb HOST_NAME switch --specialisation gaming
```

远程构建/远程激活：

```nu
nrb server switch --build-host builder --target-host root@server --use-remote-sudo
```

如果系统里有 `nom`，默认会用 `--log-format internal-json` 接到 `nom --json`。
不想用时加：

```nu
nrb HOST_NAME test --no-nom
```

## nix profile 软件管理

普通包名会自动补成 `nixpkgs#包名`：

```nu
npf install ripgrep fd bat
```

等价于：

```nu
nix profile install nixpkgs#ripgrep nixpkgs#fd nixpkgs#bat
```

已经是 flake ref 的值会原样保留：

```nu
npf install nixpkgs#hello github:NixOS/nixpkgs#jq
```

先看命令不执行：

```nu
npf install --dry-run ripgrep fd
```

删除、升级、查看：

```nu
npf list
npf remove ripgrep
npf upgrade
npf upgrade 0
npf history
```

`npf history` 查看的是用户 profile generation，也就是 `nix profile` 安装的软件历史。
它不是 NixOS 系统 generation。

清理用户 profile 历史：

```nu
npf gc --older-than 14d
```

短别名也可用：`add/rm/up/ls/hist`。

## NixOS system generation

系统 generation 单独用 `nsg`，不要和用户 profile 混在一起：

```nu
nsg list
nsg rollback --dry-run
nsg rollback
```

切到指定 generation：

```nu
nsg switch 27 --dry-run
nsg switch 27
nsg boot 27
nsg test 27
```

`nsg rollback` 默认切到上一代系统 generation，内部执行的是对应 generation 的
`switch-to-configuration switch`。

## flake.lock 更新

`nfu` 操作 `/configs/nix-config`，更改 `flake.lock`，不触发 rebuild。

不带 input 时默认更新 `dotfiles`：

```nu
nfu
```

自定义默认 input：

```nu
$env.NFU_DEFAULT_INPUTS = [dotfiles]
$env.NFU_DEFAULT_INPUTS = [nixpkgs home-manager]
```

查看当前 flake.lock 里的 root inputs：

```nu
nfu list
```

更新整个 lock：

```nu
nfu --all
```

只更新某些 input：

```nu
nfu dotfiles
nfu nixpkgs home-manager
```

等价于在 nix-config 上运行：

```nu
nix flake update dotfiles --flake /configs/nix-config
```

这会刷新 `/configs/nix-config/flake.lock` 里的 `dotfiles` input，但不会执行
`nixos-rebuild`。之后你可以自行决定什么时候：

```nu
nrb HOST_NAME test
nrb HOST_NAME switch
```

先看命令不执行：

```nu
nfu --dry-run
nfu dotfiles --dry-run
```

## 文件分工

- `mod.nu`: 模块入口，导出 `nrb`、`nsg`、`npf`、`nfu`。
- `rebuild.nu`: `nixos-rebuild` 和系统 generation 包装。
- `profile.nu`: `nix profile` 包装，负责默认补 `nixpkgs#`。
- `flake.nu`: `nix flake update` 包装，负责更新 nix-config 的 lock input。
- `common.nu`: 跨模块共用的小工具。
- `completions.nu`: 补全和共享常量。

这里用 `use` 管理模块边界：需要长期复用、希望导出命令的文件用模块；旧路径用
`export use` 转发。`source` 更适合一次性把脚本内容直接注入当前 scope，这里不使用。
