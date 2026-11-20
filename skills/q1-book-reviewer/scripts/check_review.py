#!/usr/bin/env python3
"""Structural DOCX checks. These do not verify evidence or journal compliance."""
import argparse
import json
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
W = "{" + NS["w"] + "}"
MARKER = re.compile(r"\[\[(?:TODO|VERIFY)\b.*?\]\]|\[(?:AUTHOR TO (?:FILL|CONFIRM)|VERIFY)[^\]]*\]|\b(?:TBD|FIXME)\b", re.I | re.S)
DEFAULT_SECTIONS = ["Disclosure statement", "Funding", "Generative AI statement"]


def placeholders(text):
    return [m.group() for m in MARKER.finditer(text)]


def check(path, mode="final", anonymous=False, forbidden=(), required=None):
    errors, warnings, marker_records = [], [], []
    required = DEFAULT_SECTIONS if required is None else required
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read("word/document.xml"))
        paragraphs = root.findall("w:body/w:p", NS)
        body, headings, all_text = [], [], []
        for part in z.namelist():
            if not (part.startswith("word/") and part.endswith(".xml")):
                continue
            xml = ET.fromstring(z.read(part))
            for p in xml.iter(W + "p"):
                text = "".join(t.text or "" for t in p.iter(W + "t"))
                all_text.append(text)
                hits = placeholders(text)
                for hit in hits:
                    # Require each marker to be contained in one red run. The builder does this.
                    red = any(hit in "".join(t.text or "" for t in r.iter(W + "t"))
                              and r.find("w:rPr/w:color", NS) is not None
                              and r.find("w:rPr/w:color", NS).get(W + "val", "").upper() == "FF0000"
                              for r in p.findall("w:r", NS))
                    marker_records.append({"part": part, "marker": hit, "red": red})
                    if mode == "final":
                        errors.append("Unresolved field: " + hit)
                    elif not red:
                        errors.append("Draft marker is not one complete red run: " + hit)
            if mode == "final" and (xml.find(".//w:ins", NS) is not None or xml.find(".//w:del", NS) is not None):
                errors.append("Unaccepted tracked changes in " + part)
            if mode == "final" and part == "word/comments.xml" and list(xml):
                errors.append("Review comments remain")
        for p in paragraphs:
            text = "".join(t.text or "" for t in p.iter(W + "t"))
            headings.append(text)
            style = p.find("w:pPr/w:pStyle", NS)
            if style is not None and style.get(W + "val", "").startswith("Q1Body"):
                body.append(text)
        if not body:
            warnings.append("Body word count unavailable: this file does not use the preset's Q1Body styles")
        for heading in required:
            if heading not in headings:
                errors.append("Missing required section: " + heading)
            else:
                i = headings.index(heading)
                if i + 1 >= len(headings) or not headings[i + 1].strip() or headings[i + 1] in required:
                    errors.append("Empty required section: " + heading)
        if anonymous:
            joined = "\n".join(all_text)
            for word in forbidden:
                if word and word.casefold() in joined.casefold():
                    errors.append("Forbidden author identifier remains: " + word)
            if re.search(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", joined):
                errors.append("Email address remains in anonymous copy")
            if re.search(r"\b\d{4}-\d{4}-\d{4}-\d{3}[\dX]\b", joined):
                errors.append("Possible ORCID remains in anonymous copy")
            if "docProps/core.xml" in z.namelist():
                core = ET.fromstring(z.read("docProps/core.xml"))
                for child in core:
                    if child.tag.rsplit("}", 1)[-1] in {"creator", "lastModifiedBy"} and (child.text or "").strip():
                        errors.append("Identifying core metadata is not empty")
    return {"file": str(path), "mode": mode, "structural_pass": not errors,
            "body_word_count_whitespace": len(" ".join(body).split()) if body else None,
            "body_paragraphs": len(body), "unresolved_fields": marker_records,
            "errors": errors, "warnings": warnings,
            "not_checked": ["source coverage", "claim support", "quote/page accuracy", "reference validity", "rights", "current journal policy", "visual layout", "complete contextual anonymity", "accuracy of AI scope"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("docx", type=Path)
    parser.add_argument("--mode", choices=["draft", "final"], default="final")
    parser.add_argument("--anonymous", action="store_true")
    parser.add_argument("--forbid-author-string", action="append", default=[])
    parser.add_argument("--required-section", action="append", help="Repeat to override preset section headings")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = check(args.docx, args.mode, args.anonymous, args.forbid_author_string, args.required_section)
    text = json.dumps(result, indent=2, ensure_ascii=False)
    if args.report:
        with args.report.open("x", encoding="utf-8") as f:
            f.write(text + "\n")
    print(text)
    raise SystemExit(0 if result["structural_pass"] else 1)


if __name__ == "__main__":
    main()
