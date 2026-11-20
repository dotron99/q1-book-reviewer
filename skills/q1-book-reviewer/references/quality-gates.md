# Quality gates and limits

Use only the checks relevant to the task. A declaration-only edit need not trigger new literature research, but it does require checking the latest declarations and render.

## Evidence

- Reading log matches actual source coverage.
- Concrete book claims map to the edition and pages; quotations match wording and context.
- Critical claims account for stated scope, limitations and counterexamples.
- External references, where used, have both verified identity and supporting passages; bibliography and in-text citations agree.
- Word count comes from the saved file and states included sections.

## Journal and authorship

- Current verified instructions or the supplied editor brief are distinguished from assumptions.
- Funding and interests are confirmed for this review. Missing values remain red in drafts.
- AI statement describes what occurred. No analysis or drafting is relabelled as formatting-only; no unperformed human review is claimed.
- No unsupported quartile, acceptance, invitation, author identity or affiliation is asserted.

## Word and PDF

Check content in paragraphs, tables, text boxes, headers/footers, comments and tracked changes. For anonymous copies inspect visible content, metadata and indirect identifiers. The helper checks can flag emails, ORCIDs and explicit identity strings, but cannot determine every contextual clue.

Render and inspect every final page. Check title/bibliographic wrapping, font, line spacing, page numbers, split headings, missing glyphs and blank pages. Verify the PDF corresponds to the latest Word version. Keep author questions in the handover, not in a camera-ready manuscript.

The helper's `--mode final` means **structural checks passed** only. Use 'ready for author submission review' only after the applicable evidence, policy, rights, disclosure and layout checks are complete. Submission-system proofs and editor approval are separate.

## Public sharing

The original book, extracted full text, private review, acceptance correspondence, source logs with private paths and credentials stay outside a reusable package unless redistribution is explicitly authorised and lawful. Check Word metadata as well as visible text. `.gitignore` does not remove already tracked files and is not a rights audit. `audit_package.py` is heuristic and must be accompanied by file review.
