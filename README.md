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

**Claude Code / Claude Desktop:** the installable skill is the **`skill/`
directory only** (112 KB — `SKILL.md` + `references/`). Copy *its contents*
into `.claude/skills/codeup/`:

```bash
cp -R skill/ /path/to/your-repo/.claude/skills/codeup
```

Committing that into a repo gives the whole team `/codeup` with nothing to
install. Do **not** copy the repo root — `vendor/`, `scripts/`, and `evals/`
are dev-only and must not ship to end users. Then run `/codeup` or just ask
Claude to "review this file for anti-patterns".

**GitHub Copilot:** copy [`copilot/codeup.prompt.md`](copilot/codeup.prompt.md)
into your repo's `.github/prompts/`. Invoke it from Copilot Chat.

## Single-sourcing the catalogue (for maintainers)

The catalogue and schema are **never hand-edited here** — they're copied
byte-for-byte from `codeup-cli` at a pinned version so the skill can't drift
from the CLI/extension. The pinned source lives as a git submodule under
`vendor/codeup-cli` (dev-only — it is *outside* the shippable `skill/` dir).

```bash
git clone --recurse-submodules <this repo>
# or, after a plain clone:
git submodule update --init

# To bump to a newer catalogue:
git -C vendor/codeup-cli fetch --tags
git -C vendor/codeup-cli checkout vX.Y.Z
./scripts/sync-from-core.sh          # regenerates skill/references/, updates skill/.pinned-version
git add vendor/codeup-cli skill/references/ skill/.pinned-version
git commit -m "sync catalogue from codeup-cli vX.Y.Z"
```

`skill/.pinned-version` records the tag, commit, pattern count, and SHA-256 of
each generated reference file — the provenance is auditable and tamper-evident.

## Layout

The repo separates the **installable skill** from the **dev tooling** that
maintains it. Only `skill/` ever ships to a user.

```
skill/                      # ← THE INSTALLABLE SKILL (copy only this)
  SKILL.md                  #    the /codeup workflow
  references/
    catalogue.yaml          #    GENERATED — 107 patterns, verbatim from codeup-core
    schema.md               #    GENERATED — the .codeup/ contract, verbatim
  .pinned-version           #    provenance + checksums of references/
copilot/codeup.prompt.md    # Copilot parity (ships separately into .github/prompts/)
scripts/sync-from-core.sh   # regenerates skill/references/ from the pinned submodule
vendor/codeup-cli           # submodule, pinned — DEV ONLY, not needed at runtime
evals/evals.json            # skill-creator test prompts — DEV ONLY
```
