#!/bin/bash
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

link() {
  local src="$1"
  local dst="$2"
  local dst_dir="$(dirname "$dst")"

  # Create parent directory if needed
  mkdir -p "$dst_dir"

  # Backup existing file (skip if already a symlink to us)
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "${dst#$HOME/}")"
    mv "$dst" "$BACKUP_DIR/${dst#$HOME/}"
    echo "  backed up $dst"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi

  ln -s "$src" "$dst"
  echo "  linked $dst → $src"
}

echo "=== Dotfiles Installer ==="
echo "Backups will be saved to: $BACKUP_DIR"
echo ""

# Work machine: carry over no agent configs, and set up a separate git/SSH
# identity instead of reusing the personal one. DOTFILES_SKIP_AGENTS=1
# still works non-interactively and skips this prompt.
if [ "${DOTFILES_SKIP_AGENTS:-0}" = "1" ]; then
  WORK_MACHINE=1
else
  read -p "Is this a company-managed / work machine? [y/N] " is_work
  [[ "$is_work" =~ ^[Yy]$ ]] && WORK_MACHINE=1 || WORK_MACHINE=0
fi

if [ "$WORK_MACHINE" = "1" ]; then
  export DOTFILES_SKIP_AGENTS=1
  echo "  agent configs (skills, Claude statusline, ccstatusline, Pi) will be skipped"

  if [ ! -f "$HOME/.gitconfig.local" ] || [ ! -f "$HOME/.ssh/config.local" ]; then
    read -p "  work email (for git identity + SSH key): " work_email
  fi

  if [ ! -f "$HOME/.gitconfig.local" ] && [ -n "$work_email" ]; then
    default_name="$(git config -f "$DOTFILES/git/gitconfig" user.name)"
    read -p "  work git name [$default_name]: " work_name
    work_name="${work_name:-$default_name}"
    printf '[user]\n\tname = %s\n\temail = %s\n' "$work_name" "$work_email" > "$HOME/.gitconfig.local"
    echo "  wrote ~/.gitconfig.local"
  fi

  if [ ! -f "$HOME/.ssh/config.local" ] && [ -n "$work_email" ]; then
    read -p "  generate a separate SSH key for work git hosts? [y/N] " gen_key
    if [[ "$gen_key" =~ ^[Yy]$ ]]; then
      mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
      ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_work" -C "$work_email"
      printf 'Host github.com\n  AddKeysToAgent yes\n  UseKeychain yes\n  IdentityFile ~/.ssh/id_ed25519_work\n' > "$HOME/.ssh/config.local"
      echo "  wrote ~/.ssh/config.local"
      echo "  add this public key to your work git host account:"
      cat "$HOME/.ssh/id_ed25519_work.pub"
    fi
  fi
  echo ""
fi

# Homebrew. Everything below assumes git/curl exist, and the Brewfile step at
# the end is useless without it, so bootstrap it first rather than warn later.
echo "Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "  installing homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Current shell doesn't have brew on PATH yet; the zprofile link handles
  # future shells, this covers the rest of this run.
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "  already present"
fi

# Oh My Zsh + custom plugins.
# Must run BEFORE the zshrc symlink: shell/zshrc sources oh-my-zsh.sh, and the
# upstream installer would otherwise write its own ~/.zshrc over our link.
# KEEP_ZSHRC/RUNZSH keep it from touching .zshrc or spawning a shell.
echo "Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "  installing oh-my-zsh"
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    || echo "  !! oh-my-zsh install failed - zshrc will warn until you rerun this"
else
  echo "  already present"
fi

# Plugins listed in shell/zshrc's plugins=() that are NOT bundled with omz.
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
clone_plugin() {
  local name="$1" url="$2" dest="$ZSH_CUSTOM/plugins/$1"
  if [ -d "$dest" ]; then
    echo "  $name already present"
  else
    git clone --depth=1 "$url" "$dest" && echo "  cloned $name"
  fi
}
clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git

# Shell
echo "Shell..."
link "$DOTFILES/shell/zshrc"    "$HOME/.zshrc"
link "$DOTFILES/shell/zprofile" "$HOME/.zprofile"

# Git
echo "Git..."
link "$DOTFILES/git/gitconfig" "$HOME/.gitconfig"
# git reads ~/.config/git/ignore by default, NOT ~/.gitignore - the old
# target meant this file was never applied to anything.
link "$DOTFILES/git/gitignore" "$HOME/.config/git/ignore"

# Starship
echo "Starship..."
link "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"

# Ghostty. XDG path so it sits beside the other configs; the macOS
# Application Support copy would also load, so move that one aside.
echo "Ghostty..."
link "$DOTFILES/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
for legacy in "$HOME/Library/Application Support/com.mitchellh.ghostty/config"{,.ghostty}; do
  if [ -f "$legacy" ] && [ ! -L "$legacy" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$legacy" "$BACKUP_DIR/ghostty-$(basename "$legacy")"
    echo "  moved $legacy to backup"
  fi
done

# Helix
echo "Helix..."
link "$DOTFILES/helix/config.toml" "$HOME/.config/helix/config.toml"

# Karabiner
echo "Karabiner..."
link "$DOTFILES/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"

# Coding agents: Claude Code, Codex and Pi all pull skills from agents/skills/.
# Skills cherry-picked from superpowers are linked out of a clone of the
# upstream repo (same treatment as the omz plugins: not ours to vendor).
# Add a name to SUPERPOWERS_SKILLS and rerun to pick another one.
# Agent instructions (CLAUDE.md / AGENTS.md) are personal and not tracked.
# No agent config goes to a work machine (see the prompt at the top).
if [ "${DOTFILES_SKIP_AGENTS:-0}" = "1" ]; then
  echo "Agents... skipped (work machine)"
else
  echo "Agents..."
  AGENTS="$DOTFILES/agents"
  SUPERPOWERS="$HOME/Developer/agent-stuff/superpowers"
  SUPERPOWERS_SKILLS=(brainstorming systematic-debugging)

  if [ -d "$SUPERPOWERS" ]; then
    echo "  superpowers already present"
  else
    git clone https://github.com/obra/superpowers "$SUPERPOWERS" && echo "  cloned superpowers"
  fi

  # Codex and Pi both read ~/.agents/skills. Claude Code only reads
  # ~/.claude/skills, so every skill is linked into both places.
  link_skill() {
    local name="$1" src="$2"
    link "$src" "$HOME/.agents/skills/$name"
    link "$src" "$HOME/.claude/skills/$name"
  }
  for dir in "$AGENTS"/skills/*/; do
    dir="${dir%/}"
    link_skill "$(basename "$dir")" "$dir"
  done
  for name in "${SUPERPOWERS_SKILLS[@]}"; do
    link_skill "$name" "$SUPERPOWERS/skills/$name"
  done

  # Tool-specific files.
  link "$DOTFILES/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
  link "$DOTFILES/ccstatusline/settings.json" "$HOME/.config/ccstatusline/settings.json"
  link "$DOTFILES/pi/settings.json" "$HOME/.pi/agent/settings.json"
fi

# gh (config only - hosts.yml holds the auth token, never tracked)
echo "gh..."
link "$DOTFILES/gh/config.yml" "$HOME/.config/gh/config.yml"

# SSH
echo "SSH..."
link "$DOTFILES/ssh/config" "$HOME/.ssh/config"
chmod 700 "$HOME/.ssh"

echo ""
echo "=== Symlinks done! ==="
echo ""

# Optional: Install Homebrew packages
read -p "Install Homebrew packages from Brewfile? [y/N] " install_brew
if [[ "$install_brew" =~ ^[Yy]$ ]]; then
  brew bundle --file="$DOTFILES/Brewfile"
fi

echo ""
echo "✓ Done! Restart your shell: exec zsh"

# Reminder: secrets are deliberately NOT tracked in this repo. Personal
# API keys never go to a work machine, so don't nudge it to copy them.
if [ "$WORK_MACHINE" != "1" ] && [ ! -f "$HOME/.zshenv.local" ]; then
  echo ""
  echo "!! ~/.zshenv.local is missing - API keys live there (untracked)."
  echo "   Copy it from your password manager, or exports will be unset."
fi
