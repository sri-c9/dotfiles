# dotfiles

My macOS development setup.

## What's Included

| Category | Files | Description |
|----------|-------|-------------|
| **Shell** | `zshrc`, `zprofile` | Oh My Zsh, plugins, zoxide, PATH |
| **Git** | `gitconfig`, `gitignore` | Identity, editor, global ignores |
| **Starship** | `starship.toml` | Prompt |
| **Ghostty** | `config.ghostty` | Terminal (cmux reads it too) |
| **Karabiner** | `karabiner.json` | Caps Lock -> Hyper key |
| **Agents** | `agents/skills/` | Skills shared by Claude Code, Codex and Pi |
| **Helix** | `config.toml` | Editor |
| **Claude Code** | `statusline-command.sh`, `ccstatusline/settings.json` | Statusline script, plus a [ccstatusline](https://github.com/sirmalloc/ccstatusline) layout (`settings.json` deliberately not tracked) |
| **gh** | `config.yml` | GitHub CLI (never `hosts.yml` - auth token) |
| **Pi** | `settings.json` | Agent config |
| **SSH** | `config` | GitHub host block (keys are NOT tracked) |
| **Homebrew** | `Brewfile` | Actively-used packages and casks |

## Not in this repo, on purpose

| Item | Why | How to restore |
|------|-----|----------------|
| `~/.zshenv.local` | API keys | Copy from password manager |
| `~/.gitconfig.local` | Machine-specific git identity (e.g. a work email/name) | Add a `[user]` block; included last by `git/gitconfig`, so it wins |
| `~/.ssh/config.local` | Machine-specific SSH host blocks (e.g. a separate work key) | Add `Host` blocks; included first by `ssh/config`, so it wins |
| `~/.ssh/id_ed25519` | Private key | Transfer, or generate new + add to GitHub |
| `~/.config/gh/hosts.yml` | Auth token | `gh auth login` |
| `~/.oh-my-zsh` + custom plugins | Upstream git repos, not ours to vendor | `install.sh` clones them automatically |
| Agent instructions (`CLAUDE.md`, `AGENTS.md`) and personal skills | Personal | Managed by hand on each machine |
| Claude Code `settings.json`, Codex `config.toml`, Zed config | Starting fresh beats porting stale state | Let each tool regenerate on first run |
| Raycast settings | SQLite DBs with clipboard/AI history and a local auth token | Raycast Cloud Sync, or Settings → Advanced → Export (password-protected) |
| `~/Developer/agent-stuff/superpowers` | Upstream git repo, not ours to vendor | `install.sh` clones it automatically |
| `~/.codex/auth.json` | Auth token | Sign in again |

## Quick Start

```bash
git clone https://github.com/sri-c9/dotfiles.git ~/Developer/config/dotfiles
cd ~/Developer/config/dotfiles
./install.sh
```

The install script will:
1. Ask whether this is a work machine (see below)
2. Install Homebrew if missing
3. Install Oh My Zsh and clone the two custom plugins
4. Back up any existing configs to `~/.dotfiles-backup/<timestamp>/`
5. Create symlinks from `~` to the repo
6. Optionally install Homebrew packages from the `Brewfile`

To push changes later, switch the remote to SSH once a key is set up:
`git remote set-url origin git@github.com:sri-c9/dotfiles.git`.

### Company-managed / work machine

Answering yes to the work-machine prompt:

- Skips every agent config (skills, Claude statusline, ccstatusline, Pi): nothing from a
  personal machine's agent setup is carried over
- Prompts for a work email/name and writes `~/.gitconfig.local`
- Optionally generates a separate `~/.ssh/id_ed25519_work` key and writes
  `~/.ssh/config.local` to use it for `github.com`

For a non-interactive run, `DOTFILES_SKIP_AGENTS=1 ./install.sh` answers that
prompt automatically (git/SSH identity still need to be set up by hand).
Do not copy `~/.zshenv.local` (personal API keys) to this machine.

## Agents

Claude Code, Codex and Pi share one set of skills:

| Source | Each tool reads it as |
|--------|-----------------------|
| `agents/skills/<name>/` plus picked [superpowers](https://github.com/obra/superpowers) skills | `~/.agents/skills/<name>` (Codex, Pi) and `~/.claude/skills/<name>` (Claude Code) |

- **Own skill:** add `agents/skills/<name>/SKILL.md`, rerun `./install.sh`.
- **Superpowers skill:** add its name to `SUPERPOWERS_SKILLS` in `install.sh`, rerun.
  Update them all with `git -C ~/Developer/agent-stuff/superpowers pull`.

## Updating

Edit files directly in the repo — symlinks mean changes take effect immediately. Then:

```bash
cd ~/Developer/config/dotfiles
git add -A && git commit -m "update configs"
git push
```

The Brewfile is curated by hand, not dumped. `brew bundle dump --force` would
overwrite it with every package installed on the machine, which is the thing
this repo exists to avoid. To see what drifted:

```bash
brew bundle cleanup --file=~/Developer/config/dotfiles/Brewfile   # installed but not listed
brew bundle check   --file=~/Developer/config/dotfiles/Brewfile   # listed but not installed
```

Then add or drop lines deliberately.
