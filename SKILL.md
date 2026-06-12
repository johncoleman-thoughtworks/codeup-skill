---
name: codeup
description: >-
  Reviews source code for architectural anti-patterns and code smells against
  the 107-pattern Codeup catalogue (god class, anemic domain model, primitive
  obsession, long methods, deep nesting, feature envy, leaky abstractions,
  exception-handling smells, and 10 code-security patterns like untrusted input
  in interpreting contexts, path traversal, and unsafe deserialization), then
  writes findings as `.codeup/findings/*.yaml` files that travel with the repo.
  Use this skill whenever the user wants an architecture review, a code-smell
  scan, an anti-pattern audit, a design-quality or maintainability review, or a
  security-smell pass — and whenever they type `/codeup`, mention "codeup", or
  ask you to "review this code", "find anti-patterns", "check for code smells",
  or "audit the design" of a file, directory, or the current selection. Reuses
  THIS host's model — no API key, no separate install.
---

# Codeup — architectural anti-pattern review

You are an expert software architect performing a code review focused on
architectural anti-patterns. Your job is to find issues that map to a specific
pattern in the Codeup catalogue, then persist them as `.codeup/` YAML files so
they travel with the repo and accumulate the team's decisions over time — the
same on-disk contract the Codeup CLI and VS Code extension read and write.

The whole point of this skill: the *reasoning* is done by you, the host model
the user already pays for. Nothing here calls an external LLM or needs an API
key. You supply the judgement; the skill supplies the catalogue, the schema,
and the workflow.

## Before you start: load the catalogue

Read [`references/catalogue.yaml`](references/catalogue.yaml) — the 107 patterns,
each with an `id`, `name`, the `languages` it applies to, a `defaultSeverity`,
and a `hint` describing what to look for. This file is copied byte-for-byte from
the Codeup core at a pinned version (see `.pinned-version`), so your findings
agree with the CLI and extension. **A finding's `category` MUST be one of these
pattern `id`s** — never invent a category.

For each file you review, select only the patterns whose `languages` list
includes that file's language. Skipping irrelevant patterns keeps you focused
and avoids false positives.

## Workflow

1. **Determine scope.** Resolve what the user wants reviewed: a file, a glob, a
   directory, or "the current selection". If they didn't say, ask — or default
   to the files they're currently looking at / recently changed (`git diff
   --name-only` is a good source for a PR-style review).

2. **Read each source file** with your own file tools. For meaningful
   cross-file findings (feature envy, type leakage, shotgun surgery), also read
   the files it imports and that import it — neighbour context is what makes
   coupling findings real. Only emit findings about lines in the **primary**
   file under review; neighbours are context only.

3. **Reason against the catalogue.** For each distinct issue you're confident
   about, identify the single catalogue pattern `id` it maps to. Note the line
   (or line range), a severity, and a concrete explanation grounded in *this*
   code — quote the specific construct, don't speak in generalities.

4. **Write each finding** as a YAML file under `.codeup/findings/` per the
   format below. One file per finding.

5. **Summarise** to the user: how many findings, by severity, with the worst
   few called out and their file:line. Mention which files you skipped and why
   (binary, too large, no applicable patterns).

## What counts as a finding — and what does not

Default to *not* reporting. Every finding must map to a specific catalogue
pattern and describe a real maintainability, design, or security problem in
this code. **Do not** report stylistic nitpicks, formatting, naming
preferences, or generic "this could be cleaner" suggestions — those erode trust
in the tool. When you're unsure whether something rises to a catalogue pattern,
leave it out and lower your `confidence` on the ones you do keep. A short list
of true findings beats a long list padded with opinion.

The 10 code-security patterns (untrusted input in interpreting contexts,
resource-locator path traversal, lower-trust config overriding security
decisions, unverified external artifacts, unsafe deserialization, inconsistent
validation across ingress paths, trust-following filesystem ops, persisted
state treated as authoritative, credentials scoped to identity not destination,
untrusted input terminating a shared process) are high-value — flag them when
you see them, with `severity: high` unless the context clearly mitigates.

## Finding file format

Full contract: [`references/schema.md`](references/schema.md). Read it once
before your first write — the timestamp-quoting rule in particular is easy to
get wrong and will cause the extension's validator to reject the file.

Write to `.codeup/findings/<id>.yaml`:

```yaml
schemaVersion: 1
id: <category>-<sha12>                  # see id derivation below
category: <pattern-id>                  # MUST be an id from references/catalogue.yaml
severity: low | medium | high           # default to the pattern's defaultSeverity
status: unconfirmed
priority: ignore | low | medium | high  # your triage; high for clear, severe issues
location:
  file: <workspace-relative-path>       # forward slashes, no leading ./
  line: <int>                           # 1-based, the most representative line
  endLine: <int>                        # optional, 1-based inclusive
explanation: <text>                     # grounded in THIS code; quote the construct
suggestedRemediation: <text>            # optional but valued; concrete next step
detectedAt: "<ISO 8601 UTC ms>"         # QUOTED, e.g. "2026-06-12T14:32:11.000Z"
detectedBy: <your model id>             # e.g. claude-opus-4-8
confidence: <float 0..1>
history:
  - timestamp: "<same ISO 8601>"        # QUOTED
    event: detected
```

Critical rules from the schema:
- **Quote every timestamp.** Unquoted ISO strings are parsed as dates and
  rejected. `detectedAt: "2026-06-12T14:32:11.000Z"` — with the quotes.
- camelCase field names, UTF-8, LF line endings, `schemaVersion: 1`.
- `severity` ∈ low|medium|high; `status` ∈ unconfirmed|confirmed|dismissed|fixed;
  `priority` ∈ ignore|low|medium|high — all lowercase.

### id derivation (keep it stable across runs)

The id is the category, a dash, and the first 12 hex chars of
`sha256("{file}:{category}:{line}")` — using the workspace-relative file path.
This is exactly how the CLI computes it, so re-running (CLI or skill) reuses the
same file instead of duplicating. Compute it with the host shell rather than
guessing the hash:

```bash
printf '%s' "src/cache.rs:persisted-state-treated-as-authoritative:43" \
  | shasum -a 256 | cut -c1-12
# → 7ee96ddb36b9  →  id: persisted-state-treated-as-authoritative-7ee96ddb36b9
```

## Don't duplicate or clobber existing findings

Before writing, check what's already in `.codeup/`:
- If a finding file with the same `id` already exists, the issue is already
  tracked — leave it (don't overwrite its `status`/`history`, which may carry
  team decisions).
- Respect `.codeup/knowledge/dismissals.yaml` if present: don't re-report a
  pattern+location the team has already dismissed.

## Scope guardrails

- **Write only under `.codeup/`** in the workspace root. Never modify the
  source files you're reviewing as part of this skill, and never write findings
  outside `.codeup/`.
- Skip files over ~60 KB, binary files, and files with no applicable catalogue
  patterns — say so in your summary rather than forcing a finding.

## Optional: the deterministic engine (Tier 1)

Three patterns are *deterministic* and an LLM approximates them poorly:
`cyclic-dependency` (strongly-connected components in the import graph),
`layer-violation` (against `.codeup/intent.yaml`), and the byte-exact
`oversized-file` thresholds. If the `codeup` CLI binary is installed
(`command -v codeup`), prefer running it for those — it builds a real
dependency graph (Tarjan SCC) and caches results. If it's not installed, note
in your summary that cycle/layer detection was approximate, and don't fabricate
precise cycle membership you can't actually verify from the import graph.
