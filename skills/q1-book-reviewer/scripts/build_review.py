#!/usr/bin/env python3
"""Build a review DOCX from checked writing; unresolved draft fields appear red."""
import argparse
import json
import re
import tempfile
from pathlib import Path
from docx import Document
from docx.enum.style import WD_STYLE_TYPE
from docx.shared import Inches, Pt, RGBColor
from check_review import MARKER, check, placeholders

HEADINGS = ["Disclosure statement", "Funding", "Generative AI statement"]


def setup(doc):
    sec = doc.sections[0]
    sec.page_width, sec.page_height = Inches(8.2677), Inches(11.6929)
    sec.top_margin = sec.bottom_margin = sec.left_margin = sec.right_margin = Inches(1)
    normal = doc.styles["Normal"]
    normal.font.name, normal.font.size = "Times New Roman", Pt(12)
    normal.font.color.rgb = RGBColor(0, 0, 0)
    for name in ["Q1Body", "Q1BodyFirst"]:
        style = doc.styles[name] if name in doc.styles else doc.styles.add_style(name, WD_STYLE_TYPE.PARAGRAPH)
        style.base_style = normal
        pf = style.paragraph_format
        pf.line_spacing, pf.space_after = 1.5, Pt(0)
        pf.first_line_indent = Inches(0 if name == "Q1BodyFirst" else 0.3)


def write_runs(p, text, bold=False):
    last = 0
    for m in MARKER.finditer(text):
        if m.start() > last:
            r = p.add_run(text[last:m.start()]); r.bold = bold
            r.font.color.rgb = RGBColor(0, 0, 0)
        r = p.add_run(m.group()); r.bold = bold
        r.font.color.rgb = RGBColor(255, 0, 0)
        last = m.end()
    if last < len(text):
        r = p.add_run(text[last:]); r.bold = bold
        r.font.color.rgb = RGBColor(0, 0, 0)


def build(payload, out, mode="draft", anonymous=False, overwrite=False, template=None):
    out = Path(out)
    if out.exists() and not overwrite:
        raise FileExistsError("Output exists; use a new filename or explicit --overwrite")
    header = payload.get("bibliographic_header", "")
    paragraphs = payload.get("review_paragraphs", [])
    declarations = payload.get("declarations", {})
    refs = payload.get("references", [])
    author = payload.get("author", {})
    if not isinstance(header, str) or not header.strip():
        raise ValueError("A bibliographic_header is required")
    if not isinstance(paragraphs, list) or not paragraphs or any(not isinstance(x, str) or not x.strip() for x in paragraphs):
        raise ValueError("review_paragraphs must contain non-empty strings")
    if not isinstance(refs, list) or any(not isinstance(x, str) for x in refs):
        raise ValueError("references must be a list of formatted reference strings")
    if any(not isinstance(declarations.get(h), str) or not declarations[h].strip() for h in HEADINGS):
        raise ValueError("The preset requires non-empty disclosure, funding and AI statements")
    if not anonymous and not (author.get("name") or "").strip():
        raise ValueError("Supply an author name or a red draft placeholder; use --anonymous when appropriate")
    strings = [header] + paragraphs + refs + list(declarations.values())
    if not anonymous:
        strings += [str(v) for v in author.values()]
    if mode == "final" and any(placeholders(x) for x in strings):
        raise ValueError("Final mode rejects unresolved fields; resolve them or build a draft")
    template = Path(template) if template else Path(__file__).resolve().parents[1] / "assets/review-template.docx"
    doc = Document(template) if template.exists() else Document()
    for child in list(doc._element.body):
        if not child.tag.endswith("}sectPr"):
            doc._element.body.remove(child)
    setup(doc)
    p = doc.add_paragraph()
    p.paragraph_format.line_spacing, p.paragraph_format.space_after = 1.15, Pt(18)
    title = payload.get("book_title", "")
    if title and header.startswith(title) and not placeholders(title):
        write_runs(p, title, True); write_runs(p, header[len(title):])
    else:
        write_runs(p, header, True)
    for i, text in enumerate(paragraphs):
        write_runs(doc.add_paragraph(style="Q1BodyFirst" if i == 0 else "Q1Body"), text)
    if refs:
        h = doc.add_paragraph(); write_runs(h, "References", True)
        h.paragraph_format.keep_with_next = True
        for ref in refs:
            p = doc.add_paragraph(); write_runs(p, ref)
            pf = p.paragraph_format
            pf.line_spacing, pf.space_after = 1.15, Pt(6)
            pf.left_indent, pf.first_line_indent = Inches(0.3), Inches(-0.3)
    for heading in HEADINGS:
        p = doc.add_paragraph(); write_runs(p, heading, True)
        pf = p.paragraph_format
        pf.space_before, pf.space_after, pf.keep_with_next = Pt(18), Pt(6), True
        p = doc.add_paragraph(); write_runs(p, declarations[heading])
        p.paragraph_format.line_spacing, p.paragraph_format.space_after = 1.15, Pt(10)
    if not anonymous:
        p = doc.add_paragraph()
        p.paragraph_format.line_spacing = 1.15
        lines = [str(author.get(k, "")) for k in ["name", "affiliation", "email", "orcid"] if author.get(k)]
        write_runs(p, "\n".join(lines))
    props = doc.core_properties
    props.title = "Scholarly book review"
    props.author = "" if anonymous else str(author.get("name", ""))
    props.last_modified_by = ""
    props.comments, props.subject, props.keywords = "", "", ""
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        staged = Path(tmp) / "review.docx"; doc.save(staged)
        result = check(staged, mode, anonymous, list(author.values()) if anonymous else ())
        if not result["structural_pass"]:
            raise ValueError("; ".join(result["errors"]))
        out.write_bytes(staged.read_bytes())
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--mode", choices=["draft", "final"], default="draft")
    parser.add_argument("--anonymous", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--template", type=Path, help="Use a compatible preset; use host document tools for arbitrary layout matching")
    args = parser.parse_args()
    print(build(json.loads(args.input.read_text(encoding="utf-8")), args.out, args.mode, args.anonymous, args.overwrite, args.template))


if __name__ == "__main__":
    main()
