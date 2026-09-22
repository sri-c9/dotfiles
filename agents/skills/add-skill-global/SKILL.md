---
name: add-skill-global
description: Add a skill to the shared agent config so Claude Code, Codex and Pi all get it. Use when Sri says to add, install or save a skill globally, make a skill available to every agent, or pick a skill from superpowers.
---

# Add a skill globally

Every agent pulls from `~/Developer/config/dotfiles/agents/` (see the
"Agents" section of that repo's README). Never write into
`~/.claude/skills`, `~/.agents/skills`, `~/.codex/skills` or
`~/.pi/agent/skills` directly: those hold only symlinks that `install.sh`
creates, and anything put there by hand is lost on the next machine.

## 1. Work out the source

Pick the first that matches. The skill name is the directory name and the
frontmatter `name`; check it doesn't already exist in `agents/skills/` or
in the `SUPERPOWERS_SKILLS` list.

- **A superpowers skill** (a path under
  `~/Developer/agent-stuff/superpowers/skills/<name>`, or a name that
  exists there): add `<name>` to the `SUPERPOWERS_SKILLS` array in
  `install.sh`. Do not copy the files. The link tracks upstream, so
  `git pull` in that clone updates it.
- **A skill directory anywhere else** (contains a `SKILL.md`): copy the
  whole directory to `agents/skills/<name>/`. It becomes a tracked,
  vendored copy; say so, since it will not follow its upstream.
- **A local skill already in `~/.claude/skills/<name>` as a real
  directory** (not a symlink): move it to `agents/skills/<name>/`.
- **No source, only a description**: write
  `agents/skills/<name>/SKILL.md`. Frontmatter needs `name` and a
  `description` that says when to trigger. Keep the body short and
  procedural.

## 2. Install

```bash
cd ~/Developer/config/dotfiles && printf 'n\nn\n' | ./install.sh
```

The two `n`s answer "work machine?" and the Brewfile prompt. Read the `Agents...` block of the
output and confirm the new skill was linked into both
`~/.agents/skills/<name>` (Codex, Pi) and `~/.claude/skills/<name>`
(Claude Code).

## 3. Verify

- `readlink` both links and confirm `SKILL.md` is readable through them.
- If the skill names other skills it hands off to (superpowers skills
  chain, e.g. brainstorming ends by invoking writing-plans), list any
  that are not installed. Do not add them unasked.

## 4. Report, do not commit

Show `git status --short` for the dotfiles repo and leave the change
uncommitted unless Sri asks. Note that Claude Code sees the skill in its
next session, Pi on its next launch, and the Codex app after a restart.
