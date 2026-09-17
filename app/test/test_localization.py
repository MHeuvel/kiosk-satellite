import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tool/localization.py"
if not TOOL.exists():
    TOOL = ROOT / "tools/catalog.py"
spec = importlib.util.spec_from_file_location("catalog", TOOL)
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)


def source_catalog():
    return {"@@locale": "en", "welcome": "Welcome", "@welcome": {"context": "Setup:Welcome", "description": "Page heading."},
            "response": "Response: {error}", "@response": {
                "context": "Setup:Connection", "description": "Connection error", "placeholders": {"error": {"type": "String"}}}}


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.source = source_catalog()
        # Test markers exercise the pipeline without supplying Spanish translations.
        self.translation = {"@@locale": "es", "welcome": "TEST welcome", "response": "TEST {error}"}

    def review(self):
        return {key: {"source": catalog.source_digest(self.source, key),
                      "translation": catalog.sha(value.encode()), "author": "Xavier Larrea"}
                for key, value in catalog.messages(self.translation).items()}

    def test_aggregate_review_file_has_a_separate_bounded_limit(self):
        def read_file(path, size):
            with patch.object(catalog.subprocess, "check_output", side_effect=[
                "100644 blob fixture\t" + path, b"x" * size
            ]):
                return catalog.git_file(Path("repo"), "a" * 40, path)
        self.assertEqual(len(read_file("metadata/reviews/es.json", 512_838)), 512_838)
        with self.assertRaisesRegex(ValueError, "too large"):
            read_file("source/common_en.arb", 500_001)
        with self.assertRaisesRegex(ValueError, "too large"):
            read_file("metadata/reviews/es.json", 5_000_001)

    def test_local_review_files_use_the_snapshot_limit(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "metadata/reviews/es.json"
            path.parent.mkdir(parents=True)
            path.write_bytes(b"x" * 512_838)
            self.assertEqual(len(catalog.read_bytes(path)), 512_838)
            path.write_bytes(b"x" * 5_000_001)
            with self.assertRaises(ValueError):
                catalog.read_bytes(path)
            other = Path(root) / "common_en.arb"
            other.write_bytes(b"x" * 500_001)
            with self.assertRaises(ValueError):
                catalog.read_bytes(other)

    def test_duplicate_keys_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            catalog.decode(b'{"welcome":"One","welcome":"Two"}')

    def test_missing_and_extra_placeholders_are_rejected(self):
        for text in ["No placeholder", "{other}", "{error} {other}"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                catalog.validate_translation(self.source, {**self.translation, "response": text}, "es")

    def test_reordered_placeholder_is_valid(self):
        catalog.validate_translation(self.source, {**self.translation, "response": "{error}: TEST"}, "es")

    def test_unknown_keys_and_metadata_are_rejected(self):
        for key in ["unknown", "@welcome", "@@extra"]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                catalog.validate_translation(self.source, {**self.translation, key: "Injected"}, "es")

    def test_empty_markup_controls_and_unsupported_icu_are_rejected(self):
        for text in ["", "  ", "<script>alert(1)</script>", "bad\x00text", "bad\u2014text", "{error, select, other {text}}"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                catalog.validate_translation(self.source, {**self.translation, "response": text}, "es")

    def test_locale_must_match_path(self):
        with self.assertRaises(ValueError):
            catalog.validate_translation(self.source, self.translation, "de")

    def test_urls_must_be_preserved(self):
        source = {**self.source, "welcome": "Open https://example.test."}
        with self.assertRaisesRegex(ValueError, "URLs"):
            catalog.validate_translation(source, self.translation, "es")

    def test_context_changes_invalidate_review(self):
        reviews = self.review()
        self.source["@welcome"]["context"] = "Changed meaning"
        result, counts = catalog.effective(self.source, self.translation, reviews)
        self.assertEqual(result["welcome"], "Welcome")
        self.assertEqual(counts, {"reviewed": 1, "missing": 0, "stale": 1})

    def test_translator_notes_changes_invalidate_review(self):
        reviews = self.review()
        self.source["@welcome"]["x-notes"] = "New translation constraint."
        result, counts = catalog.effective(self.source, self.translation, reviews)
        self.assertEqual(result["welcome"], "Welcome")
        self.assertEqual(counts["stale"], 1)

    def test_source_requires_separate_context_and_description(self):
        for field in ["context", "description"]:
            source = copy.deepcopy(self.source)
            del source["@welcome"][field]
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, field):
                catalog.validate_source(source)

    def test_duplicate_ids_across_source_files_are_rejected(self):
        raw = catalog.encoded(self.source)
        with self.assertRaisesRegex(ValueError, "Duplicate message ID"):
            catalog.source_bundles({"common_en.arb": raw, "setup_en.arb": raw})

    def test_filename_is_not_part_of_review_digest(self):
        reviews = self.review()
        bundles = catalog.source_bundles({"renamed_section_en.arb": catalog.encoded(self.source)})
        _, counts = catalog.effective(catalog.merge_bundles(bundles, "en"), self.translation, reviews)
        self.assertEqual(counts["reviewed"], 2)

    def test_translation_edits_invalidate_review(self):
        reviews = self.review()
        self.translation["welcome"] = "Changed"
        result, _ = catalog.effective(self.source, self.translation, reviews)
        self.assertEqual(result["welcome"], "Welcome")

    def test_missing_translations_fall_back_to_english(self):
        result, counts = catalog.effective(self.source, {"@@locale": "es"}, {})
        self.assertEqual(result["response"], "Response: {error}")
        self.assertEqual(counts["missing"], 2)

    def test_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "actual.json"
            catalog.write(target, self.source)
            link = Path(directory) / "link.json"
            link.symlink_to(target)
            with self.assertRaises(ValueError):
                catalog.read(link)


class SnapshotTests(unittest.TestCase):
    review = CatalogTests.review

    def write_sources(self, directory, source):
        common = {key: value for key, value in source.items() if key not in {"response", "@response"}}
        setup = {key: source[key] for key in ["@@locale", "response", "@response"]}
        catalog.write(directory / "common_en.arb", common)
        catalog.write(directory / "setup_en.arb", setup)

    def commit(self):
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "Fixture")
        return self.git("rev-parse", "HEAD").strip()

    def setUp(self):
        CatalogTests.setUp(self)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.app = self.root / "app"
        self.repo = self.root / "localization"
        self.repo.mkdir()
        (self.app / "remote-ui/static").mkdir(parents=True)
        self.write_sources(self.app / "l10n/source", self.source)
        catalog.write(self.app / "l10n/settings.json", {})
        self.write_sources(self.repo / "source", self.source)
        catalog.write(self.repo / "source/manifest.json", {
            "schema": catalog.SCHEMA, "files": {
                path.name: catalog.sha(path.read_bytes()) for path in (self.repo / "source").glob("*.arb")}})
        catalog.write(self.repo / "translations/es/common_es.arb", {"@@locale": "es", "welcome": self.translation["welcome"]})
        catalog.write(self.repo / "translations/es/setup_es.arb", {"@@locale": "es", "response": self.translation["response"]})
        catalog.write(self.repo / "metadata/reviews/es.json", self.review())
        for path in ["LICENSE", "CREDITS.md", "docs/CONTRIBUTOR-AGREEMENT.md"]:
            target = self.repo / path
            target.parent.mkdir(exist_ok=True)
            target.write_text("Test fixture\n")
        self.git("init", "-q")
        self.revision = self.commit()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], text=True)

    def test_import_reads_the_commit_not_the_working_tree(self):
        catalog.write(self.repo / "translations/es/common_es.arb", {"@@locale": "es", "welcome": "UNCOMMITTED"})
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        result = catalog.read(self.app / "l10n/effective/ui_es.arb")
        self.assertEqual(result["welcome"], "TEST welcome")
        self.assertEqual(result["response"], "TEST {error}")
        lock = catalog.read(self.app / "l10n/localization.lock.json")
        self.assertEqual(lock["revision"], self.revision)
        self.assertTrue((self.app / "l10n/vendor/LICENSE").exists())

    def test_import_rejects_a_moving_revision(self):
        with self.assertRaisesRegex(ValueError, "40-character"):
            catalog.import_catalog(self.app, self.repo, "HEAD", "es")

    def test_import_rejects_mismatched_source_before_writing(self):
        changed = copy.deepcopy(self.source)
        changed["welcome"] = "New welcome"
        self.write_sources(self.app / "l10n/source", changed)
        with self.assertRaisesRegex(ValueError, "Export"):
            catalog.import_catalog(self.app, self.repo, self.revision, "es")
        self.assertFalse((self.app / "l10n/vendor").exists())

    def test_generation_rejects_changed_vendor_files(self):
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        (self.app / "l10n/vendor/LICENSE").write_text("Tampered")
        with self.assertRaisesRegex(ValueError, "outside import"):
            catalog.generate(self.app)

    def test_new_english_messages_fall_back_after_import(self):
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        changed = copy.deepcopy(self.source)
        changed.update(newMessage="New message", **{"@newMessage": {"context": "New screen", "description": "New label"}})
        self.write_sources(self.app / "l10n/source", changed)
        catalog.generate(self.app)
        result = catalog.read(self.app / "l10n/effective/ui_es.arb")
        self.assertEqual(result["newMessage"], "New message")
        self.assertEqual(result["welcome"], "TEST welcome")

    def test_initial_incomplete_language_cannot_activate(self):
        catalog.write(self.repo / "metadata/reviews/es.json", {})
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "-qm", "Remove review")
        revision = self.git("rev-parse", "HEAD").strip()
        with self.assertRaisesRegex(ValueError, "complete and reviewed"):
            catalog.import_catalog(self.app, self.repo, revision, "es")

    def test_messages_in_the_wrong_translation_file_are_rejected(self):
        catalog.write(self.repo / "translations/es/common_es.arb", self.translation)
        with self.assertRaisesRegex(ValueError, "Unknown message"):
            catalog.validate_repository(self.repo)
        revision = self.commit()
        with self.assertRaisesRegex(ValueError, "Unknown message"):
            catalog.import_catalog(self.app, self.repo, revision, "es")

    def test_missing_section_is_valid_but_cannot_initially_activate(self):
        (self.repo / "translations/es/setup_es.arb").unlink()
        catalog.validate_repository(self.repo)
        revision = self.commit()
        with self.assertRaisesRegex(ValueError, "complete and reviewed"):
            catalog.import_catalog(self.app, self.repo, revision, "es")

    def test_later_missing_section_falls_back_to_english(self):
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        (self.repo / "translations/es/setup_es.arb").unlink()
        catalog.import_catalog(self.app, self.repo, self.commit(), "es")
        result = catalog.read(self.app / "l10n/effective/ui_es.arb")
        self.assertEqual(result["response"], "Response: {error}")
        self.assertEqual(result["welcome"], "TEST welcome")

    def test_unknown_translation_sections_are_rejected(self):
        catalog.write(self.repo / "translations/es/unknown_es.arb", {"@@locale": "es"})
        with self.assertRaisesRegex(ValueError, "Unexpected translation path"):
            catalog.validate_repository(self.repo)
        with self.assertRaisesRegex(ValueError, "Unexpected translation path"):
            catalog.import_catalog(self.app, self.repo, self.commit(), "es")

    def test_manifest_requires_all_source_file_hashes(self):
        manifest = catalog.read(self.repo / "source/manifest.json")
        del manifest["files"]["setup_en.arb"]
        catalog.write(self.repo / "source/manifest.json", manifest)
        with self.assertRaisesRegex(ValueError, "manifest"):
            catalog.validate_repository(self.repo)

    def test_manifest_rejects_paths_outside_source_directory(self):
        manifest = catalog.read(self.repo / "source/manifest.json")
        manifest["files"]["../other_en.arb"] = "0" * 64
        catalog.write(self.repo / "source/manifest.json", manifest)
        with self.assertRaisesRegex(ValueError, "manifest"):
            catalog.import_catalog(self.app, self.repo, self.commit(), "es")

    def test_regional_locale_filename_and_marker(self):
        catalog.write(self.repo / "translations/pt-BR/common_pt_BR.arb", {"@@locale": "pt_BR", "welcome": "TEST welcome"})
        catalog.validate_repository(self.repo)

    def test_preview_uses_drafts_without_changing_review_or_lock(self):
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        lock_path = self.app / "l10n/localization.lock.json"
        lock = lock_path.read_bytes()
        reviews = (self.repo / "metadata/reviews/es.json").read_bytes()
        catalog.write(self.repo / "translations/es/common_es.arb", {"@@locale": "es", "welcome": "DRAFT welcome"})
        catalog.generate(self.app, self.repo)
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_es.arb")["welcome"], "DRAFT welcome")
        self.assertEqual(lock_path.read_bytes(), lock)
        self.assertEqual((self.repo / "metadata/reviews/es.json").read_bytes(), reviews)
        catalog.generate(self.app)
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_es.arb")["welcome"], "TEST welcome")

    def test_preview_rejects_a_different_english_source(self):
        changed = copy.deepcopy(self.source)
        changed["welcome"] = "New welcome"
        self.write_sources(self.app / "l10n/source", changed)
        with self.assertRaisesRegex(ValueError, "Export"):
            catalog.generate(self.app, self.repo)

    def test_navigation_mapping_requires_matching_source_text(self):
        catalog.write(self.app / "l10n/navigation.json", {"Different label": "welcome"})
        with self.assertRaisesRegex(ValueError, "navigation message mapping"):
            catalog.generate(self.app)

    def test_generation_rejects_a_broken_setting_mapping(self):
        catalog.write(self.app / "l10n/settings.json", {"device.name": {"title": "unknown", "description": "welcome"}})
        with self.assertRaisesRegex(ValueError, "mapping"):
            catalog.generate(self.app)

    def test_device_mapping_requires_exact_source_wording(self):
        catalog.write(self.app / "l10n/device_text.json", {"Changed heading": "welcome"})
        with self.assertRaisesRegex(ValueError, "device message mapping"):
            catalog.generate(self.app)

    def test_options_and_placeholders_reject_missing_or_parameterized_messages(self):
        for filename in ["setting_options", "setting_placeholders"]:
            for identifier in ["unknown", "response"]:
                value = {"dark": identifier} if filename == "setting_options" else identifier
                path = self.app / f"l10n/{filename}.json"
                catalog.write(path, {"ui.theme": value})
                with self.subTest(filename=filename, identifier=identifier), self.assertRaisesRegex(ValueError, "option or placeholder"):
                    catalog.generate(self.app)
                path.unlink()


if __name__ == "__main__":
    unittest.main()
