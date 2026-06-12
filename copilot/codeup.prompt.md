---
mode: agent
description: Review code for architectural anti-patterns against the Codeup 107-pattern catalogue and write findings to .codeup/.
---

# /codeup — architectural anti-pattern review

You are an expert software architect reviewing code for architectural
anti-patterns and code smells. Reason with **your own model** — this needs no
API key. Persist findings as `.codeup/findings/*.yaml` so they travel with the
repo, using the same catalogue and on-disk contract as the Codeup CLI and VS
Code extension.

## Steps

1. **Load the catalogue** from `references/catalogue.yaml` (107 patterns; each
   has an `id`, `languages`, `defaultSeverity`, and `hint`). A finding's
   `category` must be one of these `id`s. For each file, use only the patterns
   whose `languages` include that file's language.
2. **Resolve scope** — the file/dir/selection the user named, else the changed
   files (`git diff --name-only`).
3. **Read each file** (and its import neighbours for cross-file findings). Emit
   findings only about the primary file.
4. **Report only real, catalogue-mapped issues.** No stylistic nitpicks,
   formatting, or "could be cleaner". A few true findings beat a padded list.
   Flag the 10 code-security patterns at `severity: high` when present.
5. **Write findings** to `.codeup/findings/<id>.yaml` following the contract in
   `references/schema.md`. Quote every timestamp (`detectedAt: "2026-..Z"`) —
   unquoted ones are rejected. camelCase fields, `schemaVersion: 1`.
   - `id` = `<category>-<first 12 hex of sha256("{file}:{category}:{line}")>`.
     Compute via shell: `printf '%s' "path:category:line" | shasum -a 256 | cut -c1-12`.
6. **Don't duplicate**: skip ids that already exist; respect
   `.codeup/knowledge/dismissals.yaml`.
7. **Write only under `.codeup/`.** Never modify the reviewed source.
8. **Summarise**: counts by severity, worst few with file:line, files skipped.

`cyclic-dependency`, `layer-violation`, and exact `oversized-file` thresholds
are deterministic — if the `codeup` CLI is installed, prefer it for those;
otherwise note that cycle/layer detection was approximate.

> Keep this file in sync with `../SKILL.md` — both describe the same workflow.
