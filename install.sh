#!/usr/bin/env bash

set -euo pipefail

PROFILE="${DOTFILES_PROFILE:-personal}"
ASSUME_YES=false
MINIMAL=false
APT_UPDATED=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${DOTFILES:-$SCRIPT_DIR}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

log() {
  echo "==> $*"
}

warn() {
  echo "WARNING: $*" >&2
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --profile <personal|work|server>  Machine profile (default: personal)
  --yes                             Non-interactive installs
  --minimal                         Skip optional extras
  --help                            Show this help
EOF
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_dir() {
  mkdir -p "$1"
}

apt_update_once() {
  if [ "$APT_UPDATED" = false ]; then
    log "Updating apt package index"
    sudo apt-get update
    APT_UPDATED=true
  fi
}

clone_or_update_repo() {
  local url="$1"
  local target="$2"
  local depth="${3:-}"

  if [ ! -d "$target/.git" ]; then
    ensure_dir "$(dirname "$target")"
    if [ -n "$depth" ]; then
      git clone --depth="$depth" "$url" "$target"
    else
      git clone "$url" "$target"
    fi
    return
  fi

  if ! git -C "$target" diff --quiet || ! git -C "$target" diff --cached --quiet; then
    warn "Local changes in $target, skipping update."
    return
  fi

  if ! git -C "$target" pull --ff-only; then
    warn "Failed to update $target, leaving as-is."
  fi
}

install_pkg_if_missing() {
  local package="$1"

  if [ "$PKG_MGR" = "brew" ]; then
    if ! brew list "$package" >/dev/null 2>&1; then
      brew install "$package"
    fi
    return
  fi

  if dpkg -s "$package" >/dev/null 2>&1; then
    return
  fi

  apt_update_once
  sudo apt-get install -y "$package"
}

detect_platform() {
  OS="$(uname | tr '[:upper:]' '[:lower:]')"

  case "$OS" in
    darwin)
      PKG_MGR="brew"
      has_cmd brew || die "Homebrew is required on macOS. Install brew first."
      ;;
    linux)
      PKG_MGR="apt"
      has_cmd apt-get || die "This Linux installer currently supports Ubuntu (apt-get)."
      if [ -r /etc/os-release ]; then
        . /etc/os-release
        if [ "${ID:-}" != "ubuntu" ] && [ "${ID_LIKE:-}" != "ubuntu" ]; then
          die "Linux distro '$ID' is unsupported right now. Expected Ubuntu."
        fi
      else
        die "Cannot detect Linux distribution from /etc/os-release."
      fi
      ;;
    *)
      die "Unsupported OS: $OS"
      ;;
  esac
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --profile)
        [ $# -gt 1 ] || die "Missing value for --profile"
        PROFILE="$2"
        shift 2
        ;;
      --yes)
        ASSUME_YES=true
        shift
        ;;
      --minimal)
        MINIMAL=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  case "$PROFILE" in
    personal|work|server) ;;
    *)
      die "Invalid profile '$PROFILE'. Use personal, work, or server."
      ;;
  esac
}

install_base_packages() {
  log "Installing core packages for profile '$PROFILE' on '$OS'"

  local -a packages=()

  if [ "$OS" = "darwin" ]; then
    packages=(stow bat tmux fd neovim highlight ripgrep)
    if [ "$PROFILE" != "server" ]; then
      packages+=(nvm z tree-sitter-cli)
    fi
    if [ "$PROFILE" = "personal" ] && [ "$MINIMAL" = false ]; then
      packages+=(ghostty)
    fi
  else
    packages=(stow git tmux highlight fd-find ripgrep curl gzip)
    if [ "$PROFILE" != "server" ]; then
      packages+=(npm)
    fi
  fi

  for pkg in "${packages[@]}"; do
    install_pkg_if_missing "$pkg"
  done
}

install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh/.git" ]; then
    return
  fi

  log "Installing Oh My Zsh"
  if [ -d "$HOME/.oh-my-zsh" ]; then
    git -C "$HOME/.oh-my-zsh" init -q
    if ! git -C "$HOME/.oh-my-zsh" remote add origin "https://github.com/ohmyzsh/ohmyzsh.git" 2>/dev/null; then
      git -C "$HOME/.oh-my-zsh" remote set-url origin "https://github.com/ohmyzsh/ohmyzsh.git"
    fi
    git -C "$HOME/.oh-my-zsh" fetch --depth=1 origin master
    git -C "$HOME/.oh-my-zsh" checkout -f -B master FETCH_HEAD
    return
  fi

  clone_or_update_repo "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh" "1"
}

install_oh_my_zsh_plugins() {
  log "Installing Oh My Zsh plugins/themes"
  clone_or_update_repo "https://github.com/romkatv/powerlevel10k.git" "$ZSH_CUSTOM/themes/powerlevel10k" "1"
  clone_or_update_repo "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  clone_or_update_repo "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  clone_or_update_repo "https://github.com/MichaelAquilina/zsh-you-should-use.git" "$ZSH_CUSTOM/plugins/you-should-use"
}

install_shared_tools() {
  log "Installing shared shell tools"
  clone_or_update_repo "https://github.com/sindresorhus/pure.git" "$HOME/.zsh/pure"
  clone_or_update_repo "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"
}

install_fzf() {
  if [ -d "$HOME/.fzf/.git" ]; then
    return
  fi

  log "Installing fzf"
  clone_or_update_repo "https://github.com/junegunn/fzf.git" "$HOME/.fzf" "1"
  if [ "$ASSUME_YES" = true ]; then
    "$HOME/.fzf/install" --all
  else
    "$HOME/.fzf/install" --key-bindings --completion --no-update-rc
  fi
}

ensure_fd_alias_on_ubuntu() {
  if [ "$OS" != "linux" ]; then
    return
  fi

  if has_cmd fd; then
    return
  fi

  if has_cmd fdfind; then
    ensure_dir "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
}

install_ubuntu_editor_tools() {
  if [ "$OS" != "linux" ] || [ "$PROFILE" = "server" ] || [ "$MINIMAL" = true ]; then
    return
  fi

  ensure_dir "$HOME/.local/bin"

  log "Installing Neovim binary"
  local arch nvim_arch ts_arch
  arch="$(uname -m)"
  if [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    nvim_arch="arm64"
    ts_arch="arm64"
  else
    nvim_arch="x86_64"
    ts_arch="x64"
  fi

  curl -fsSL "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${nvim_arch}.appimage" -o "$HOME/.local/bin/nvim"
  chmod +x "$HOME/.local/bin/nvim"

  log "Installing tree-sitter-cli binary"
  curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/v0.26.8/tree-sitter-linux-${ts_arch}.gz" | gunzip > "$HOME/.local/bin/tree-sitter"
  chmod +x "$HOME/.local/bin/tree-sitter"
}

install_optional_typescript() {
  if [ "$OS" != "linux" ] || [ "$PROFILE" = "server" ] || [ "$MINIMAL" = true ]; then
    return
  fi

  if ! has_cmd npm; then
    warn "npm is unavailable, skipping TypeScript global install."
    return
  fi

  ensure_dir "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global"
  export PATH="$HOME/.npm-global/bin:$PATH"
  if ! npm install -g typescript; then
    warn "npm install -g typescript failed; continuing."
  fi
}

link_dotfiles() {
  log "Creating symlinks with stow"
  cd "$DOTFILES"
  stow agents
  stow zsh
  stow nvim
}

main() {
  parse_args "$@"
  detect_platform

  install_base_packages
  install_oh_my_zsh
  install_oh_my_zsh_plugins
  install_shared_tools

  if [ "$PROFILE" != "server" ] && [ "$MINIMAL" = false ]; then
    install_fzf
  fi

  ensure_fd_alias_on_ubuntu
  install_ubuntu_editor_tools
  install_optional_typescript
  link_dotfiles

  log "Done (profile=$PROFILE, os=$OS)"
}

main "$@"
