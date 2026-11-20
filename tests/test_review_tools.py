import importlib.util
import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
HELPERS = ROOT / "skills/q1-book-reviewer/scripts"
sys.path.insert(0, str(HELPERS))
from build_review import build
from check_review import check, NS

spec = importlib.util.spec_from_file_location("audit_package", ROOT / "scripts/audit_package.py")
audit_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit_module)


def fixture():
    # Structural demonstration only, not a real book or scholarly review.
    return {"book_title": "Layout demonstration", "bibliographic_header": "Layout demonstration. No bibliographic claim.",
            "review_paragraphs": ["First demonstration paragraph.", "Second demonstration paragraph."],
            "references": ["Formatting example only, not a bibliographic source."],
            "declarations": {"Disclosure statement": "Demonstration only.", "Funding": "Demonstration only.",
                             "Generative AI statement": "Demonstration only; no claim about a real review."},
            "author": {"name": "Example Reviewer", "affiliation": "Example Institution", "email": "reviewer@example.org", "orcid": ""}}


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.out = self.root / "review.docx"

    def tearDown(self):
        self.tmp.cleanup()

    def test_red_draft_markers_and_final_rejection(self):
        data = fixture(); data["declarations"]["Funding"] = "[[TODO: confirm funding]]"
        build(data, self.out)
        report = check(self.out, "draft")
        self.assertTrue(report["structural_pass"])
        self.assertTrue(all(x["red"] for x in report["unresolved_fields"]))
        self.assertFalse(check(self.out, "final")["structural_pass"])
        with self.assertRaises(ValueError):
            build(data, self.root / "final.docx", "final")
        self.assertFalse((self.root / "final.docx").exists())

    def test_complete_preset_passes_structure_not_evidence(self):
        build(fixture(), self.out, "final")
        result = check(self.out)
        self.assertTrue(result["structural_pass"])
        self.assertEqual(result["body_word_count_whitespace"], 6)
        self.assertIn("claim support", result["not_checked"])

    def test_anonymous_copy_removes_author_and_metadata(self):
        data = fixture(); build(data, self.out, "final", anonymous=True)
        self.assertTrue(check(self.out, anonymous=True, forbidden=[data["author"]["name"]])["structural_pass"])
        with zipfile.ZipFile(self.out) as z:
            xml = z.read("word/document.xml").decode()
            self.assertNotIn("Example Reviewer", xml)
            self.assertNotIn("reviewer@example.org", xml)

    def test_anonymity_flags_identifier_in_body(self):
        data = fixture(); data["review_paragraphs"][0] += " Contact reviewer@example.org."
        with self.assertRaises(ValueError):
            build(data, self.out, "final", anonymous=True)
        self.assertFalse(self.out.exists())

    def test_overwrite_requires_explicit_option(self):
        build(fixture(), self.out); original = self.out.read_bytes()
        with self.assertRaises(FileExistsError):
            build(fixture(), self.out)
        self.assertEqual(original, self.out.read_bytes())
        data = fixture(); data["review_paragraphs"] = ["Changed demonstration."]
        build(data, self.out, overwrite=True)
        self.assertEqual(check(self.out)["body_word_count_whitespace"], 2)

    def test_review_text_and_reference_are_preserved(self):
        data = fixture(); build(data, self.out)
        with zipfile.ZipFile(self.out) as z:
            doc = ET.fromstring(z.read("word/document.xml"))
            texts = ["".join(p.itertext()) for p in doc.findall("w:body/w:p", NS)]
        for text in data["review_paragraphs"] + data["references"]:
            self.assertIn(text, texts)
        self.assertIn("References", texts)

    def test_uncoloured_marker_is_not_a_valid_draft(self):
        from docx import Document
        doc = Document(); doc.add_paragraph("[[TODO: missing red colour]]"); doc.save(self.out)
        self.assertFalse(check(self.out, "draft", required=[])["structural_pass"])

    def test_missing_preset_declarations_are_blocked(self):
        data = fixture(); data["declarations"].pop("Funding")
        with self.assertRaises(ValueError):
            build(data, self.out)


class PackageAuditTests(unittest.TestCase):
    def test_private_path_is_detected(self):
        with tempfile.TemporaryDirectory() as d:
            path = "/".join(["", "home", "reviewer", "private.txt"])
            Path(d, "leak.md").write_text(path)
            self.assertFalse(audit_module.audit(d)["heuristic_pass"])

    def test_non_example_contact_is_detected(self):
        with tempfile.TemporaryDirectory() as d:
            value = "reviewer" + "@" + "private.invalid"
            Path(d, "contact.md").write_text(value)
            self.assertFalse(audit_module.audit(d)["heuristic_pass"])

    def test_pdf_is_not_a_neutral_package_asset(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "book.pdf").write_bytes(b"not a real PDF")
            self.assertFalse(audit_module.audit(d)["heuristic_pass"])

    def test_release_package_scan(self):
        report = audit_module.audit(ROOT)
        self.assertTrue(report["heuristic_pass"], report["findings"])


if __name__ == "__main__":
    unittest.main()
