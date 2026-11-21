# Q1 Book Reviewer

A reusable, evidence-led workflow for scholarly book reviews. It supports close reading, balanced criticism, journal-specific drafting and checked Word output. **Q1 describes an aspiration for rigour, not a verified journal ranking or a promise of acceptance.**

## What is included

- An installable `q1-book-reviewer` skill and UI metadata.
- Guidance for full-book reading, claim tracing, criticism and journal checks.
- A neutral Word template and JSON input example; unresolved draft fields appear in red.
- A Word builder and structural checker that refuses unresolved placeholders in final mode.
- Evidence and reading-log templates, a journal checklist and a handover checklist.
- Package privacy checks, automated tests and GitHub CI.

No book text, publisher PDF, unpublished review, correspondence, personal contact details or API keys are included. Everything needed to apply the workflow is here; the user supplies a book they may lawfully use, the journal brief and any style reference locally.

## Installation

macOS or Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/dotron99/q1-book-reviewer/main/install.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/dotron99/q1-book-reviewer/main/install.ps1 | iex
```

The script looks for Claude Code, Codex, Cursor, Gemini CLI and GitHub Copilot on your machine and installs the skill for each one it finds. It does not need administrator rights and does not use sudo. If none of those tools are detected, it installs to the standard Claude Code and Codex personal folders so the skill is ready when you start using them. Start a new session afterwards.

From a local clone you can run `./install.sh` or `.\install.ps1` instead. Add `--symlink` (or `-Symlink` on Windows) if you want the installed skill to point at the checkout. Re-run the same command after `git pull` to update.

### What gets installed where

The installer puts a copy in the personal folder each detected tool actually reads:

| Tool | Personal skill folder |
| --- | --- |
| Claude Code | `~/.claude/skills/` (or `$CLAUDE_CONFIG_DIR/skills` if that variable is set). On Windows this is `%USERPROFILE%\.claude\skills`. |
| Codex | `~/.agents/skills/` (the current official personal path) |
| Cursor | `~/.cursor/skills/` and `~/.agents/skills/` |
| Gemini CLI | `~/.agents/skills/` (official user-skill alias; a separate `~/.gemini/skills/` copy is not required) |
| GitHub Copilot | `~/.copilot/skills/` |

Older Codex builds also load `~/.codex/skills` (or `$CODEX_HOME/skills` if that variable is set). Current Codex documentation recommends `~/.agents/skills`. To install to the older path as well, run `./install.sh --legacy-codex`. Do not install to both Codex paths unless you still need the older one, because current Codex may list the skill twice.

This repository is a standalone skill package, not a published marketplace plugin.

### Quick start

After installation, start a new session. In Claude Code or Cursor:

```text
/q1-book-reviewer
```

In Codex:

```text
$q1-book-reviewer
```

Example request:

> Use /q1-book-reviewer to assess this book and draft a review for my chosen journal. Use my accepted review as the style reference. Save a new version; show unresolved items in red.

The host needs local file access and suitable document or PDF tools for reading and rendering. The helper scripts use Python 3.10+ and `python-docx`. They make no network requests and do not require API keys. The skill can guide a review without the helpers when equivalent tools are available.

### Manual install

If you prefer not to run the script, copy the whole `skills/q1-book-reviewer` directory, including its references, scripts and assets, into the folder for your tool. Replace an existing `q1-book-reviewer` folder rather than merging two versions.

Claude Code, macOS or Linux:

```sh
mkdir -p ~/.claude/skills
cp -R skills/q1-book-reviewer ~/.claude/skills/
```

Claude Code, Windows (PowerShell):

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills" | Out-Null
Copy-Item -Recurse -Force skills\q1-book-reviewer "$env:USERPROFILE\.claude\skills\q1-book-reviewer"
```

Codex (current path), macOS or Linux:

```sh
mkdir -p ~/.agents/skills
cp -R skills/q1-book-reviewer ~/.agents/skills/
```

Codex (current path), Windows (PowerShell):

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills" | Out-Null
Copy-Item -Recurse -Force skills\q1-book-reviewer "$env:USERPROFILE\.agents\skills\q1-book-reviewer"
```

Codex (older path, still recognised):

```sh
mkdir -p ~/.codex/skills
cp -R skills/q1-book-reviewer ~/.codex/skills/
```

Cursor:

```sh
mkdir -p ~/.cursor/skills
cp -R skills/q1-book-reviewer ~/.cursor/skills/
```

Gemini CLI:

```sh
mkdir -p ~/.gemini/skills
cp -R skills/q1-book-reviewer ~/.gemini/skills/
```

GitHub Copilot:

```sh
mkdir -p ~/.copilot/skills
cp -R skills/q1-book-reviewer ~/.copilot/skills/
```

Reload skills in your host if it does not pick up the new folder until a new session.

### Uninstall and update

To update from a clone, pull the latest files and run the installer again. To update with the one-liner, run the same `curl` or `irm` command again.

To uninstall on macOS or Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/dotron99/q1-book-reviewer/main/install.sh | bash -s -- --uninstall
```

From a clone, `./install.sh --uninstall` does the same. On Windows, from a clone, run `.\install.ps1 -Uninstall`. From the one-liner:

```powershell
$Q1BookReviewerUninstall = $true; irm https://raw.githubusercontent.com/dotron99/q1-book-reviewer/main/install.ps1 | iex
```

You can also delete the `q1-book-reviewer` folder from the personal skill directory listed above. The installer only removes this skill; it does not delete your Claude, Codex or other config.

### Troubleshooting

- The skill does not appear: start a new session, then check that `SKILL.md` is at `.../skills/q1-book-reviewer/SKILL.md` for the tool you are using. Cursor Cloud Agents only sync `~/.cursor/skills/`, not `~/.agents/skills/`.
- The one-liner always downloads the `main` branch. If you are testing a fork or another branch, clone that branch and run `./install.sh` instead.
- One tool was skipped: the installer only writes to folders for tools it can detect (the app or CLI is on your PATH, or that tool's config folder already exists in your home directory). Run `./install.sh --all` to install for every supported tool.
- Windows would not create a symlink: a copy is installed instead. Creating symlinks on Windows may need Developer Mode. The default one-liner already copies, so this only matters with `-Symlink`.
- Permission errors: the script never uses sudo and only writes under your home directory. Check that your home folder is writable.
- Helper scripts fail: install Python 3.10+ and the packages in `requirements.txt`. See "Try the Word tools" below.
- Current Codex lists the skill twice: you probably also have a copy in `~/.codex/skills`. Remove the older copy, or keep only one of the two Codex folders.

## Try the Word tools

From this repository root, create a Python environment using your normal environment manager and install `requirements.txt`. In Codex, prefer its managed artifact runtime when available.

```sh
python -m pip install -r requirements.txt
python skills/q1-book-reviewer/scripts/build_review.py skills/q1-book-reviewer/assets/review-input.example.json --out /tmp/book-review-draft.docx
python skills/q1-book-reviewer/scripts/check_review.py /tmp/book-review-draft.docx --mode draft
python -m unittest discover -s tests -v
python scripts/audit_package.py
```

The example is an **unfilled template**, not a real review. It deliberately contains red placeholders. Replace them with checked, source-grounded writing before using `--mode final`. Final mode blocks unresolved fields; it does not certify that facts are correct or that a journal will accept the document. Run `check_review.py --help` for custom required sections and anonymous-copy checks. The supplied preset includes disclosure, funding and AI sections; adapt these to the actual journal brief.

Render every final Word document with your document tool and inspect every page. PDF conversion is deliberately left to the host’s installed renderer. Do not mistake successful XML checks for a visual proof check.

## Before sharing on GitHub

Read [GITHUB_SHARING_CHECKLIST.md](GITHUB_SHARING_CHECKLIST.md). The suggested repository name is `q1-book-reviewer`. Publish **only the contents of this `github` directory**, never the surrounding book folder. No remote, GitHub account, DOI, acceptance claim or affiliation has been invented.

The MIT licence covers newly prepared instructions, code and neutral templates. It does not grant rights to source books or review examples that users add later. See [ATTRIBUTION.md](ATTRIBUTION.md). A repository URL and named maintainer can be added after the owner chooses them.

## Limitations

The automated checks identify structural problems, some privacy leaks and unresolved fields. They cannot prove complete reading, quotation fidelity, page accuracy, permission to redistribute, compliance with a publisher’s changing AI policy, or the soundness of an evaluative judgement. Those checks remain part of the documented workflow.
