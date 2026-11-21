# Changelog

## Unreleased

- Added `install.sh` and `install.ps1`, with a one-line install in the README.
- The installer detects Claude Code, Codex, Cursor, Gemini CLI and GitHub Copilot and installs the skill for each tool it finds.

## 0.1.0 — local release candidate

- Added the `q1-book-reviewer` skill and supporting reading, writing and quality guidance.
- Added neutral Word/JSON templates and evidence, reading and requirements forms.
- Added deterministic document construction, placeholder and anonymity checks.
- Added package privacy checks, tests, CI and sharing instructions.
- Excluded book text, actual review drafts and private project materials.

Not yet published or independently evaluated across journals. See `evals/scenarios.md` for behavioural checks to run with an agent.
