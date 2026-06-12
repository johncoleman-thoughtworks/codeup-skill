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
[`references/schema.md`](references/schema.md)) and the **same catalogue** — so
findings agree regardless of which produced them.

## Install

**Claude Code / Claude Desktop:** install the skill (e.g. via a plugin
marketplace, or drop this directory in `.claude/skills/codeup/` of a repo so
the whole team gets `/codeup` with nothing to install). Then run `/codeup` or
just ask Claude to "review this file for anti-patterns".

**GitHub Copilot:** copy [`copilot/codeup.prompt.md`](copilot/codeup.prompt.md)
into your repo's `.github/prompts/`. Invoke it from Copilot Chat.

## Single-sourcing the catalogue (for maintainers)

The catalogue and schema are **never hand-edited here** — they're copied
byte-for-byte from `codeup-cli` at a pinned version so the skill can't drift
from the CLI/extension. The pinned source lives as a git submodule under
`vendor/codeup-cli`.

```bash
git clone --recurse-submodules <this repo>
# or, after a plain clone:
git submodule update --init

# To bump to a newer catalogue:
git -C vendor/codeup-cli fetch --tags
git -C vendor/codeup-cli checkout vX.Y.Z
./scripts/sync-from-core.sh          # regenerates references/, updates .pinned-version
git add vendor/codeup-cli references/ .pinned-version
git commit -m "sync catalogue from codeup-cli vX.Y.Z"
```

`.pinned-version` records the tag, commit, pattern count, and SHA-256 of each
generated reference file — the provenance is auditable and tamper-evident.

## Layout

```
SKILL.md                  # the skill: frontmatter + /codeup workflow
references/
  catalogue.yaml          # GENERATED — 107 patterns, verbatim from codeup-core
  schema.md               # GENERATED — the .codeup/ contract, verbatim
copilot/codeup.prompt.md  # Copilot parity
scripts/sync-from-core.sh # regenerates references/ from the pinned submodule
.pinned-version           # provenance + checksums of references/
vendor/codeup-cli         # submodule, pinned (dev-only; not needed at runtime)
evals/evals.json          # skill-creator test prompts
```
