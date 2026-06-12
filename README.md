# codeup-skill

A **host-native code-review skill**: get Codeup's architectural anti-pattern
review (107 patterns, including 10 code-security patterns) *inside the LLM
host you already use* — Claude Code, Claude Desktop, or GitHub Copilot — with
**no separate install and no LLM API key**. The reasoning runs on the host's
own model; the skill supplies the catalogue, the `.codeup/` schema, and the
workflow.

This is "Tier 0" of the Codeup agent strategy: the binary CLI and the VS Code
extension still exist for heavier use, but this skill needs nothing compiled —
it's configuration the host loads.

## How it relates to the rest of Codeup

| Tool | Install | LLM | Best for |
|---|---|---|---|
| **This skill** | none (config) | the host's model | quick reviews inside Claude/Copilot, zero setup |
| [codeup-cli](https://github.com/johncoleman-thoughtworks/codeup-cli) | binary | Anthropic / GitHub Models key | CI, deterministic graph checks, large repos |
| Codeup VS Code extension | `.vsix` | Anthropic / Copilot | in-editor, persistent panel |

All three read and write the **same `.codeup/` files** (see
[`schema.md`](plugins/codeup/skills/codeup/references/schema.md)) and the **same catalogue** — so
findings agree regardless of which produced them.

## What codeup targets — and what to pair it with

codeup works at **design altitude**: it flags *architectural anti-patterns and
code smells* — the structural causes of trouble (god class, anemic domain
model, primitive obsession, leaky abstractions, layer violations, the
code-security patterns, etc.). It deliberately does **not** hunt line-level
**correctness bugs** — null dereferences / NPEs, off-by-ones, race conditions,
unhandled edge cases, resource leaks. Those are runtime-behaviour defects, a
different kind of analysis, and codeup will *not* report them (a finding must
map to a catalogue pattern, so it never invents bug-level categories).

**Use `/code-review` alongside codeup, not instead of it.** They cover
different layers and complement each other:

| | **codeup** | **`/code-review`** |
|---|---|---|
| Altitude | design / structure (the *cause*) | correctness (the *symptom*) |
| Scope | whole files vs. the 107-pattern catalogue | the current **diff** (your changes) |
| Catches | anti-patterns, design + security smells | NPEs, logic bugs, edge cases, plus reuse/efficiency cleanups |
| Output | `.codeup/findings/*.yaml` that travel with the repo | findings in-session (or inline PR comments / `--fix`) |

Example of the split: codeup flags that a service *returns `null` on miss*
(a design smell — switch to `Optional`/`Result`/a domain exception);
`/code-review` flags that a specific caller *dereferences that result
unguarded* (a live NPE in your diff). Run codeup for the architecture review,
and `/code-review` (and `/security-review`) before merging changes.

## Install

There are two ways to install — a one-command **plugin** install, or a manual
**copy** of the skill directory. Both deliver the same skill; pick based on
whether you want versioned updates **plus the automatic fix-verification hook**
(plugin) or a bare `/codeup` command (copy). See
[Automatic fix verification](#automatic-fix-verification-plugin-only) for what
only the plugin route gives you.

### Option A — plugin (versioned, one command)

This repo is also its own Claude Code plugin **marketplace**:

```text
/plugin marketplace add johncoleman-thoughtworks/codeup-skill
/plugin install codeup@codeup-tools
```

Then **restart `claude`** (quit and relaunch). This matters: plugin **skills
bind at startup**, so `/reload-plugins` alone loads the hook but *not* the
skill — only a restart does. After relaunch, `/plugin details codeup` should
list both `Skills: codeup` and `Hooks: PostToolUse`.

Invoked as `/codeup:codeup` (plugin skills are namespaced `plugin:skill`).

**Updating to a new version:**

```text
/plugin marketplace update codeup-tools
/plugin update codeup@codeup-tools
```

…then **restart `claude`** again. The plugin cache is keyed by *version*, so an
update only takes effect cleanly when the version bumps and the session
restarts — reloading in place can keep serving the old cached skill.

### Option B — copy the skill (bare `/codeup`, zero tooling)

The installable skill is the **`plugins/codeup/skills/codeup/` directory only** (112 KB —
`SKILL.md` + `references/`). Copy it into a skills directory:

```bash
cp -R plugins/codeup/skills/codeup /path/to/your-repo/.claude/skills/codeup   # project (team-wide)
cp -R plugins/codeup/skills/codeup ~/.claude/skills/codeup                    # personal (all projects)
```

Committing it into a repo gives the whole team `/codeup` with nothing to
install. Do **not** copy the repo root — `vendor/`, `scripts/`, and `evals/`
are dev-only and must not ship to end users.

Either way, then run `/codeup` (or `/codeup:codeup`), or just ask Claude to
"review this file for anti-patterns".

## Automatic fix verification (plugin only)

A fix for one anti-pattern can quietly introduce another (extract a long method
→ a god-class helper; swallow an exception → error-swallowing). The skill
already carries a **fix-and-verify loop** that holds a fix to the catalogue, but
the **plugin** install adds a hook so it happens *automatically* — no setup.

`hooks/hooks.json` registers a `PostToolUse` hook (`hooks/verify-fix.sh`) that,
after Claude edits a source file, injects a reminder for Claude to re-check that
change against the catalogue before moving on. It is deliberately quiet and
dependency-free:

- **Nudge only** — it injects guidance for the model; it never runs an LLM or
  analyzer itself, needs no API key, and makes no network calls.
- **Gated on `.codeup/`** — it stays silent in any project that doesn't have a
  `.codeup/` directory, so it only acts where codeup is actually in use.
- **No loops / no noise** — it ignores edits under `.codeup/` and non-source
  files, and emits nothing (exit 0) when it has nothing to say.

This ships **only via the plugin** — a plain skill directory copied into
`.claude/skills/` cannot carry hooks. Plugin hooks activate when the plugin is
enabled (project-scoped plugins require trusting the workspace first).

**GitHub Copilot:** copy [`copilot/codeup.prompt.md`](copilot/codeup.prompt.md)
into your repo's `.github/prompts/`. Invoke it from Copilot Chat.

## Single-sourcing the catalogue (for maintainers)

The catalogue and schema are **never hand-edited here** — they're copied
byte-for-byte from `codeup-cli` at a pinned version so the skill can't drift
from the CLI/extension. The pinned source lives as a git submodule under
`vendor/codeup-cli` (dev-only — it is *outside* the shippable `plugins/codeup/` dir).

```bash
git clone --recurse-submodules <this repo>
# or, after a plain clone:
git submodule update --init

# To bump to a newer catalogue:
git -C vendor/codeup-cli fetch --tags
git -C vendor/codeup-cli checkout vX.Y.Z
./scripts/sync-from-core.sh          # regenerates plugins/codeup/skills/codeup/references/
git add vendor/codeup-cli plugins/codeup/skills/codeup/references/ plugins/codeup/skills/codeup/.pinned-version
git commit -m "sync catalogue from codeup-cli vX.Y.Z"
```

`plugins/codeup/skills/codeup/.pinned-version` records the tag, commit, pattern count, and
SHA-256 of each generated reference file — the provenance is auditable and
tamper-evident.

## Layout

The repo is a **marketplace** (root `.claude-plugin/marketplace.json`) holding
one **plugin** in its own subdirectory (`plugins/codeup/`, canonical layout).
Only `plugins/codeup/` ships to a user; everything else is dev tooling.

```
.claude-plugin/
  marketplace.json          # marketplace catalog (lists the plugin + its path)
plugins/
  codeup/                   # ← THE PLUGIN (this whole dir is what installs)
    .claude-plugin/
      plugin.json           #   plugin manifest
    skills/
      codeup/               #   ← the skill (copy only THIS dir for Option B)
        SKILL.md            #      the /codeup workflow + fix-and-verify loop
        references/
          catalogue.yaml    #      GENERATED — 107 patterns, verbatim from codeup-core
          schema.md         #      GENERATED — the .codeup/ contract, verbatim
        .pinned-version     #      provenance + checksums of references/
    hooks/
      hooks.json            #   PostToolUse auto-verify hook (plugin-only)
      verify-fix.sh
copilot/codeup.prompt.md    # Copilot parity (ships separately into .github/prompts/)
scripts/sync-from-core.sh   # regenerates the skill's references/ from the submodule
LICENSE                     # MIT
vendor/codeup-cli           # submodule, pinned — DEV ONLY, not needed at runtime
evals/evals.json            # skill-creator test prompts — DEV ONLY
```
