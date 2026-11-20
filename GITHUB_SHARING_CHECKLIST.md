# GitHub sharing checklist

The package is prepared locally. It has not been uploaded, pushed or submitted to a marketplace.

## Publishable contents

Share the skill, its newly written guidance, empty ledgers, neutral template, helper code, tests and repository documentation. The repository uses the MIT licence for this material. Keep the book and private case records outside it.

## Owner decisions

- Choose repository owner, visibility and a public maintainer identity. Add a public contact only if wanted.
- Confirm the MIT licence is suitable before publishing. Third-party material stays under its own rights.
- Review the README, skill instructions and AI-disclosure behaviour. The skill must describe actual assistance; it must not turn analysis or drafting into a formatting-only declaration.
- Review the evaluation scenarios in `evals/scenarios.md`. Automated helper tests are not a completed independent evaluation of model behaviour.
- If adding your accepted review as an example later, check publisher terms and remove private metadata and contact information. Permission to read a book is not permission to redistribute it. An open-access label alone is not enough to assume unrestricted reuse.

## Local checks

```sh
python -m unittest discover -s tests -v
python scripts/audit_package.py
```

The package audit is a heuristic check, not a guarantee against every secret or rights issue. Inspect all proposed files yourself, including Word metadata. The GitHub workflow repeats tests and the package audit on pushes and pull requests; no workflow uploads book material or generated artifacts.

## Optional manual Git steps

Run these only **inside this directory** when ready. They are instructions, not actions already taken:

```sh
git init
git add README.md LICENSE CITATION.cff CHANGELOG.md ATTRIBUTION.md CONTRIBUTING.md GITHUB_SHARING_CHECKLIST.md requirements.txt .gitignore .github skills scripts tests evals
git diff --cached --stat
git diff --cached
```

Review the staged files before creating a commit. Create a repository under your own GitHub account, then use its actual remote URL. No guessed account, automated push or publishing step is configured. A citation DOI should be added only after a real deposit assigns one.
