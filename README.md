# Dotfiles

Personal/work/server dotfiles for shell, terminal, and AI agent CLI tooling, installed with one script and linked via GNU Stow.

## Quick start

```bash
./install.sh [--profile personal|work|server] [--minimal] [--yes]
```

- `--profile`: defaults to `personal`
- `--minimal`: skips optional extras (like `fzf` and Linux non-server extras)
- `--yes`: non-interactive mode

## Ecosystem installed here

### Shell stack

- **Oh My Zsh** setup with:
  - `powerlevel10k`
  - `zsh-autosuggestions`
  - `zsh-syntax-highlighting`
  - `you-should-use`
- Additional shell/shared repos:
  - `pure` prompt repo (`~/.zsh/pure`)
  - `tpm` (`~/.tmux/plugins/tpm`)
- Base CLI tooling via package manager (`brew`/`apt`), including:
  - `stow`, `tmux`, `ripgrep`, `fd`, `highlight`, and related Unix utilities

### Optional extras (profile/flags)

- Non-`server`: Node tooling (`nvm`/`npm`) and `tree-sitter-cli`
- Non-`server` + non-minimal on Linux: extra binaries + global TypeScript
- Non-`server` + non-minimal: `fzf`

### Agent CLI configs

- `agents/.copilot/config.json`
- `agents/.claude/settings.json`
- `agents/.codex/config.toml`

## How it works

1. Detects platform (`brew` on macOS, `apt` on Ubuntu) and profile.
2. Installs packages, ensures Oh My Zsh is present, and clones/upgrades plugin repos.
3. Runs optional installs based on profile/flags.
4. Uses `stow` to symlink:
   - `zsh/` -> shell config (`.zshrc`, `.zprofile`)
   - `agents/` -> CLI agent config files (`.copilot`, `.claude`, `.codex`)

## How to configure

- **Shell**: edit `zsh/.zshrc` and `zsh/.zprofile` (plugins, aliases, theme, env).
- **Agent CLIs**: edit files under `agents/`:
  - `agents/.copilot/config.json`
  - `agents/.claude/settings.json`
  - `agents/.codex/config.toml`
