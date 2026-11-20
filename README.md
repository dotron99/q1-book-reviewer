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

## Install

The skill itself is `skills/q1-book-reviewer/`. Copy that **whole directory**, including its references, scripts and assets, into the skills location supported by your agent. For a local Codex setup using the personal `.codex/skills` directory:

```sh
mkdir -p ~/.codex/skills
cp -R skills/q1-book-reviewer ~/.codex/skills/
```

Check for an existing directory first; do not merge over a different version. Reload skills in your host if required. This repository is a standalone skill package, not a published marketplace plugin.

Invoke it with a request such as:

> Use $q1-book-reviewer to assess this book and draft a review for my chosen journal. Use my accepted review as the style reference. Save a new version; show unresolved items in red.

The host needs local file access and suitable document/PDF tools for reading and rendering. The helper scripts use Python 3.10+ and `python-docx`. They make no network requests and do not require API keys. The skill can guide a review without the helpers when equivalent tools are available.

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
