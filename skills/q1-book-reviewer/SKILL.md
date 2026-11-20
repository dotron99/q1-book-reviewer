---
name: q1-book-reviewer
description: Draft, revise or audit scholarly book reviews using source-page evidence, a journal brief and an optional accepted style reference. Use for academic book-review manuscripts and their final Word preparation.
---

# Q1 Book Reviewer

Prepare a defensible critical review of a book for the user's chosen journal. Q1 is an aspiration for rigour; do not infer a journal quartile or promise acceptance.

## Start from the actual request

Read the supplied book, brief and latest review version. A style reference controls presentation and voice, not the new review's arguments or declarations. Preserve the requested location and versioning; overwrite only when authorised. If only excerpts are available, state the coverage and limit the assessment accordingly.

For a new or substantial review, read [workflow.md](references/workflow.md). For drafting and template matching, read [writing-style.md](references/writing-style.md). For a final copy or audit, read [quality-gates.md](references/quality-gates.md). Apply the relevant parts rather than restarting a full workflow for a narrow edit.

## Evidence and assessment

- Trace book-specific factual claims and quotations to the exact edition and printed pages. Record the PDF viewer-page mapping rather than assuming an offset.
- Separate what the book reports from the reviewer's judgement. Test a criticism against the author's stated purpose and strongest counterexamples.
- Use external scholarship when it materially positions the contribution or supports a critique. Check the journal brief and the accepted reference's use of literature. Decide and record whether outside references are needed; do not silently drop that aspect of a requested style match. Every independently cited external work needs a verified reference entry; every bibliography entry must be cited. Book-only page citations may be sufficient when appropriate to the brief. Explain that choice in the handover, not in the review prose.
- Verify source passages as well as bibliographic existence. A real DOI does not establish claim support. Never invent metadata, quotations, prices, page numbers, references or claims of novelty.
- Record incomplete access and unresolved facts. Do not turn a sample-chapter assessment into a claim of full-book reading.

## Drafts and final files

Use the supplied template when available. Otherwise the neutral [Word preset](assets/review-template.docx) and [JSON input](assets/review-input.example.json) offer a starting point, not an official journal format. The preset defaults to British English, A4 pages and connected critical prose; adapt it when the brief differs.

Show unresolved fields as **red text** in Word drafts, using `[[TODO: ...]]` or `[[VERIFY: ...]]`. Keep confirmed final text black. Do not mark a document final or camera-ready while placeholders or material checks remain. In plain text, retain the explicit marker and list open items in the handover.

Confirm funding and conflicts for the current review rather than copying earlier declarations. AI disclosure must accurately describe material assistance, including analysis or drafting when performed. Do not reduce it to formatting-only to conceal broader assistance, and do not assert author approval that has not occurred.

The optional `scripts/build_review.py` builds Word files from structured review text; it does not write or verify the criticism. `scripts/check_review.py` checks placeholders, selected structure and some anonymity risks. Run their `--help` for options. The structural checks cannot certify evidence, rights or journal compliance.

Render final Word files with the host's document tools, inspect every page and correct layout defects. Recheck the latest saved file after edits. Use the empty [evidence ledger](assets/evidence-ledger.csv), [reading log](assets/reading-log.csv), [reference check](assets/reference-check.csv), [journal requirements](assets/journal-requirements.md) and [handover form](assets/handover.md) when useful.

## Delivery and sharing

Deliver the requested review and a concise account of checks, source coverage, word count and open decisions. Keep editorial notes out of the review body. For GitHub or other public sharing, package reusable instructions and neutral assets separately from books, private reviews and correspondence. Inspect rights, text and metadata before adding examples. Preparation does not itself authorise submission, publication or messages to others.
