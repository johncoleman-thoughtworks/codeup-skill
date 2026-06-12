#!/usr/bin/env bash
#
# codeup PostToolUse hook — after Claude edits code, nudge it to hold its own
# diff to the catalogue (the skill's fix-and-verify loop) so a fix can't
# silently trade one anti-pattern for another.
#
# Design constraints (deliberate):
#   - Zero dependencies, no API key, no network. It only injects guidance for
#     the model; it does NOT run an LLM or any analyzer itself.
#   - Gated on a .codeup/ directory, so it stays silent in repos that haven't
#     adopted codeup.
#   - Silent (exit 0, no output) whenever it has nothing to say, so it never
#     adds noise. PostToolUse can't block the edit regardless — this only
#     appends additionalContext.
#
set -euo pipefail

input="$(cat)"

# Pull a field out of the PostToolUse stdin JSON without requiring jq.
# Matches "key": "value" (value may contain escaped quotes). Good enough for
# the flat fields we need (cwd, file_path); we never trust it for anything
# security-sensitive — it only decides whether to print a reminder.
json_str() {
  printf '%s' "$input" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" \
    | head -n1 \
    | sed -E "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"$//"
}

cwd="$(json_str cwd)"
file_path="$(json_str file_path)"

# No file path → nothing to verify.
[ -n "$file_path" ] || exit 0

# Gate: only act in projects that use codeup.
[ -d "${cwd:-.}/.codeup" ] || exit 0

# Don't fire on the skill's own bookkeeping writes (it writes .codeup/ findings).
case "$file_path" in
  */.codeup/*|.codeup/*) exit 0 ;;
esac

# Only nudge for real source files — skip docs, config, lockfiles, data.
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.java|*.kt|*.kts|*.scala|*.py|*.rb|*.go|*.cs|*.rs) ;;
  *) exit 0 ;;
esac

base="$(basename "$file_path")"

# Emit additionalContext (no jq — hand-rolled JSON; base is a filename so no
# escaping hazards in practice).
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "codeup: you just edited ${base}. Before moving on, hold this change to the Codeup catalogue (the codeup skill's fix-and-verify loop): re-read the edited region and confirm (1) it didn't introduce a new catalogue anti-pattern (e.g. extract-method -> god-class/feature-envy, swallowed exception -> error-swallowing, no-behaviour wrapper -> anemic-domain-model, just-in-case interface -> premature-abstraction), and (2) if it was fixing a finding, that the finding is actually resolved. If the change introduced a new smell, fix it or surface the trade-off rather than shipping it."
  }
}
EOF
exit 0
