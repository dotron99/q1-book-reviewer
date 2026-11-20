#!/usr/bin/env python3
"""Heuristic public-package scan; not a complete secrets, rights or privacy audit."""
import json
import re
import sys
import zipfile
from pathlib import Path

PRIVATE = [re.compile(r"/(?:Users|home)/[^/\s]+/"),
           re.compile("".join(["Cloud", "Storage"]), re.I),
           re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
           re.compile("".join(["BEGIN ", "PRIVATE KEY"]))]
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})")
ALLOWED_EMAIL_DOMAINS = {"example.org", "example.com", "example.net"}
EXCLUDED = {".git", ".venv", "__pycache__"}
ALLOWED_DOCX = Path("skills/q1-book-reviewer/assets/review-template.docx")
BLOCKED_SUFFIX = {".pdf", ".xlsx", ".xls", ".pkl", ".pickle", ".zip", ".pem", ".key", ".csv.gz"}


def audit(root):
    root = Path(root); findings = []; checked = 0
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if any(x in EXCLUDED for x in rel.parts):
            continue
        if path.is_symlink():
            findings.append({"file": str(rel), "problem": "Symlink not allowed in public package"}); continue
        if not path.is_file():
            continue
        checked += 1
        if path.name.lower().endswith(tuple(BLOCKED_SUFFIX)) or path.name.startswith(".env"):
            findings.append({"file": str(rel), "problem": "Potential private source, archive or credential file"}); continue
        if path.suffix.lower() == ".docx":
            if rel != ALLOWED_DOCX:
                findings.append({"file": str(rel), "problem": "Only the neutral Word template is allowlisted"}); continue
            with zipfile.ZipFile(path) as z:
                texts = [z.read(n).decode("utf-8", errors="replace") for n in z.namelist() if n.endswith(".xml")]
            text = "\n".join(texts)
        else:
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeError:
                findings.append({"file": str(rel), "problem": "Unreviewed binary file"}); continue
        for pattern in PRIVATE:
            if pattern.search(text):
                findings.append({"file": str(rel), "problem": "Private path or credential-like content"})
        if any(m.group(1).lower() not in ALLOWED_EMAIL_DOMAINS for m in EMAIL.finditer(text)):
            findings.append({"file": str(rel), "problem": "Non-example email address"})
    return {"checked_files": checked, "heuristic_pass": not findings, "findings": findings,
            "limitation": "Does not establish redistribution rights or detect every private value/secret"}


if __name__ == "__main__":
    result = audit(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1])
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["heuristic_pass"] else 1)
