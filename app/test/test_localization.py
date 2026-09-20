import copy
import base64
import hashlib
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

    def test_android_generation_uses_reviewed_fallback_and_removes_stale_locales(self):
        catalog.write(self.app / "l10n/android.json", {"native_welcome": "welcome"})
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        root = self.app / "android/app/src/main/res"
        spanish = root / "values-b+es/ks_localization.xml"
        self.assertIn('"TEST welcome"', spanish.read_text())
        changed = copy.deepcopy(self.source)
        changed["welcome"] = "Changed English"
        self.write_sources(self.app / "l10n/source", changed)
        catalog.generate(self.app)
        self.assertIn('"Changed English"', spanish.read_text())
        unrelated = root / "values-b+es/unrelated.xml"
        unrelated.write_text("Keep this")
        catalog.generate_android(self.app, {"en": changed})
        self.assertFalse(spanish.exists())
        self.assertEqual(unrelated.read_text(), "Keep this")

    def test_android_generation_rejects_placeholders_and_invalid_names(self):
        for mapping in [{"bad-name": "welcome"}, {"native_response": "response"}, {"native_missing": "missing"}]:
            with self.subTest(mapping=mapping), self.assertRaisesRegex(ValueError, "Android resource"):
                catalog.write(self.app / "l10n/android.json", mapping)
                catalog.generate_android(self.app, {"en": self.source})

    def test_android_xml_preserves_literal_text_and_disables_percent_formatting(self):
        from xml.etree import ElementTree
        catalog.write(self.app / "l10n/android.json", {"native_welcome": "welcome"})
        bundle = {**self.source, "welcome": "  @literal & 100% \"quoted\" 'apostrophe' \\path\nnext  "}
        catalog.generate_android(self.app, {"en": bundle})
        path = self.app / "android/app/src/main/res/values/ks_localization.xml"
        node = ElementTree.parse(path).find("string")
        self.assertEqual(node.attrib["formatted"], "false")
        self.assertTrue(node.text.startswith('"  @literal & 100%'))
        self.assertTrue(node.text.endswith('next  "'))
        self.assertIn(r'\"quoted\"', node.text)
        self.assertIn(r"\'apostrophe\'", node.text)
        self.assertIn(r"\\path\nnext", node.text)

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



class CommunityTests(unittest.TestCase):
    setUp = SnapshotTests.setUp
    write_sources = SnapshotTests.write_sources
    commit = SnapshotTests.commit
    git = SnapshotTests.git
    review = SnapshotTests.review

    def corrected_fixture(self):
        self.add_language()
        self.approve_fixture()
        target = self.repo / "translations/de/common_de.arb"
        translated = catalog.read(target)
        translated["welcome"] = "DE corrected welcome"
        catalog.write(target, translated)

    def test_maintainer_correction_imports_without_replacing_contributor_evidence(self):
        self.corrected_fixture()
        proof_path = next((self.repo / "metadata/provenance/de").glob("*.json"))
        original = proof_path.read_bytes()
        credits = (self.repo / "metadata/credits.json").read_bytes()
        review_path = self.repo / "metadata/reviews/de.json"
        before = catalog.read(review_path)
        with self.assertRaisesRegex(ValueError, "complete and reviewed"):
            catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        catalog.review_corrections(self.repo, "de", 3, ["welcome"], "Correct the heading", True)
        after = catalog.read(review_path)
        self.assertEqual(after["response"], before["response"])
        self.assertEqual(after["welcome"]["author"], "translator")
        self.assertEqual(after["welcome"]["provenance"], before["welcome"]["provenance"])
        self.assertEqual(after["welcome"]["maintainerCorrection"]["originalTranslation"],
                         catalog.sha(b"DE welcome"))
        self.assertEqual(proof_path.read_bytes(), original)
        self.assertEqual((self.repo / "metadata/credits.json").read_bytes(), credits)
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_de.arb")["welcome"], "DE corrected welcome")

    def test_correction_requires_explicit_review_and_matching_contribution(self):
        self.corrected_fixture()
        path = self.repo / "metadata/reviews/de.json"
        before = path.read_bytes()
        cases = [(3, ["welcome"], "Fix", False), (3, [], "Fix", True),
                 (3, ["welcome"], " ", True), (4, ["welcome"], "Fix", True),
                 (3, ["unknown"], "Fix", True), (3, ["welcome", "response"], "Fix", True)]
        for pr, ids, reason, confirmed in cases:
            with self.subTest(pr=pr, ids=ids, reason=reason, confirmed=confirmed), self.assertRaises(ValueError):
                catalog.review_corrections(self.repo, "de", pr, ids, reason, confirmed)
            self.assertEqual(path.read_bytes(), before)

    def test_invalid_correction_records_cannot_enable_modified_community_text(self):
        self.corrected_fixture()
        catalog.review_corrections(self.repo, "de", 3, ["welcome"], "Correct the heading", True)
        path = self.repo / "metadata/reviews/de.json"
        valid = catalog.read(path)
        for case in ("reviewer", "original", "reason", "missing", "author", "owner", "provenance"):
            reviews = copy.deepcopy(valid)
            item = reviews["welcome"]
            if case == "reviewer": item["maintainerCorrection"]["reviewer"] = "someone else"
            elif case == "original": item["maintainerCorrection"]["originalTranslation"] = "0" * 64
            elif case == "reason": item["maintainerCorrection"]["reason"] = ""
            elif case == "missing": del item["maintainerCorrection"]
            elif case == "author": item["author"] = "Xavier Larrea"
            elif case == "owner": item["ownerAuthored"] = True
            else: item["provenance"] = "0" * 64
            catalog.write(path, reviews)
            with self.subTest(case=case), self.assertRaisesRegex(ValueError, "complete and reviewed"):
                catalog.import_catalog(self.app, self.repo, self.commit(), "de")

    def test_correction_review_expires_when_wording_or_context_changes(self):
        self.corrected_fixture()
        catalog.review_corrections(self.repo, "de", 3, ["welcome"], "Correct the heading", True)
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        target = self.repo / "translations/de/common_de.arb"
        translated = catalog.read(target)
        translated["welcome"] = "DE not reviewed"
        catalog.write(target, translated)
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_de.arb")["welcome"], "Welcome")
        catalog.review_corrections(self.repo, "de", 3, ["welcome"], "Revise the heading again", True)
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        self.source["@welcome"]["context"] = "Different screen"
        self.write_sources(self.app / "l10n/source", self.source)
        catalog.generate(self.app)
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_de.arb")["welcome"], "Welcome")

    def test_owner_additions_do_not_replace_community_provenance(self):
        self.add_language()
        self.approve_fixture()
        path = self.repo / "metadata/reviews/de.json"
        before = path.read_bytes()
        with self.assertRaisesRegex(ValueError, "explicit"):
            catalog.review_owner(self.repo, "de")
        with self.assertRaisesRegex(ValueError, "provenance"):
            catalog.review_owner(self.repo, "de", ["welcome"])
        self.assertEqual(path.read_bytes(), before)
        catalog.write(path, {})
        with self.assertRaisesRegex(ValueError, "provenance"):
            catalog.review_owner(self.repo, "de", ["welcome"])

    def test_explicit_owner_addition_can_be_imported_with_community_messages(self):
        self.add_language()
        self.approve_fixture()
        path = self.repo / "metadata/reviews/de.json"
        reviews = catalog.read(path)
        self.source.update({"credits": "Credits", "@credits": {"context": "About", "description": "Page title"}})
        self.write_sources(self.app / "l10n/source", self.source)
        self.write_sources(self.repo / "source", self.source)
        catalog.write(self.repo / "source/manifest.json", {
            "schema": catalog.SCHEMA, "files": {
                path.name: catalog.sha(path.read_bytes()) for path in (self.repo / "source").glob("*.arb")}})
        target = self.repo / "translations/de/common_de.arb"
        translated = catalog.read(target)
        translated["credits"] = "DE credits"
        catalog.write(target, translated)
        catalog.review_owner(self.repo, "de", ["credits"])
        updated = catalog.read(path)
        self.assertEqual(updated["welcome"], reviews["welcome"])
        self.assertTrue(updated["credits"]["ownerAuthored"])
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_de.arb")["credits"], "DE credits")

    def test_credits_follow_enabled_languages_and_preserve_public_names(self):
        self.add_language()
        self.approve_fixture()
        path = self.repo / "metadata/credits.json"
        credits = catalog.read(path)
        credits["de"]["3"] = {"name": "Zoë $Name", "login": "another"}
        credits["fr"] = {"4": {"name": "Not imported", "login": "inactive"}}
        catalog.write(path, credits)
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        js = (self.app / "remote-ui/static/localization_credits.js").read_text()
        dart = (self.app / "lib/l10n/generated/localization_credits.dart").read_text()
        self.assertIn('"Translator"', js)
        self.assertIn('"Zoë $Name"', js)
        self.assertIn('"Zoë \\$Name"', dart)
        self.assertNotIn("Not imported", js)
        self.assertIn('"login": "another"', js)
        self.assertIn("Xavier Larrea", js)

    def test_credits_reject_a_username_that_could_change_the_profile_url(self):
        self.add_language()
        self.approve_fixture()
        path = self.repo / "metadata/credits.json"
        credits = catalog.read(path)
        credits["de"]["2"]["login"] = "someone/other"
        catalog.write(path, credits)
        with self.assertRaisesRegex(ValueError, "GitHub username"):
            catalog.generate(self.app, self.repo, "de")

    def add_language(self, locale="de"):
        for name, source in catalog.load_sources(self.repo / "source").items():
            catalog.write(self.repo / "translations" / locale / catalog.translation_name(name, locale),
                          {"@@locale": locale.replace("-", "_"),
                           **{key: value.replace("TEST", locale.upper()) for key, value in catalog.messages(self.translation).items()
                              if key in source}})

    def proof(self, locale="de"):
        files, snapshot = [], []
        for path in sorted((self.repo / "translations" / locale).glob("*.arb")):
            raw = path.read_bytes()
            blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
            entry = {"filename": str(path.relative_to(self.repo)), "previous_filename": None,
                     "status": "added", "sha": blob}
            files.append(entry)
            snapshot.append({"file": entry, "after": {"sha": blob, "sha256": catalog.sha(raw),
                                                       "base64": base64.b64encode(raw).decode()}})
        context = {"schema": 1, "number": 3, "author_id": 2, "head": self.revision, "merge_base": "d" * 40,
                   "files": files, "agreement": {"version": "1.1", "commit": "a" * 40,
                                                 "sha256": catalog.sha(b"Agreement"), "url": "https://example.test"}}
        context["id"] = catalog.canonical_digest(context)
        record = {"schema": 1, "kind": "contributor_acceptance", "repository_id": 10,
                  "repository": "jxlarrea/kiosk-satellite-localization", "context": context,
                  "agreement_text": "Agreement", "declaration": f"- [x] {self.revision} {context['id']}",
                  "previous_declaration": "- [ ]", "actor": {"id": 2, "login": "translator", "type": "User"},
                  "event_action": "edited", "snapshot": snapshot}
        outcome = {"kind": "pr_closed", "number": 3, "head": self.revision, "merged": True,
                   "covered": True, "matches_merge": True, "merged_by": 1, "merge_commit": self.revision,
                   "acceptance": {"path": "records/10/3/record.json", "sha256": catalog.canonical_digest(record)}}
        return {"owner_id": 1, "records_revision": "b" * 40, "record": record, "outcome": outcome}

    def approve_fixture(self, locale="de"):
        proof = self.proof(locale)
        identity, author, changed = catalog.verify_provenance(proof, locale)
        catalog.write(self.repo / f"metadata/provenance/{locale}/{identity}.json", proof)
        catalog.write(self.repo / f"metadata/reviews/{locale}.json", {
            key: {"source": catalog.source_digest(self.source, key), "translation": catalog.sha(value.encode()),
                  "author": author, "provenance": identity} for key, value in changed.items()})
        credit_path = self.repo / "metadata/credits.json"
        credits = catalog.read(credit_path) if credit_path.exists() else {}
        credits[locale] = {"2": {"name": "Translator", "login": author}}
        catalog.write(credit_path, credits)
        (self.repo / "CREDITS.md").write_text(f"# Translation credits\n\n- Translator ({locale})\n")
        return proof

    def test_new_language_reports_missing_but_existing_language_allows_small_corrections(self):
        self.add_language()
        (self.repo / "translations/de/setup_de.arb").unlink()
        head = self.commit()
        with self.assertRaisesRegex(ValueError, "New languages must be complete"):
            catalog.validate_pr(self.repo, self.revision, head)
        catalog.write(self.repo / "translations/de/common_de.arb", {"@@locale": "de", "welcome": "Small correction"})
        catalog.validate_pr(self.repo, head, self.commit())

    def test_new_language_can_be_complete(self):
        self.add_language()
        head = self.commit()
        catalog.validate_pr(self.repo, self.revision, head)

    def test_new_language_must_sync_changed_source_context(self):
        self.add_language()
        head = self.commit()
        self.git("checkout", "-q", self.revision)
        self.source["@welcome"]["description"] = "Updated context"
        self.write_sources(self.repo / "source", self.source)
        base = self.commit()
        self.add_language()
        with self.assertRaisesRegex(ValueError, "complete against current main"):
            catalog.validate_pr(self.repo, base, head)
        catalog.validate_pr(self.repo, base, self.commit())

    def test_preview_supports_community_without_approval_or_activation(self):
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        self.add_language()
        lock = (self.app / "l10n/localization.lock.json").read_bytes()
        catalog.generate(self.app, self.repo, "de")
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_de.arb")["welcome"], "DE welcome")
        self.assertEqual((self.app / "l10n/localization.lock.json").read_bytes(), lock)
        self.assertIn('"de": "Deutsch"', (self.app / "lib/l10n/generated/language_codes.dart").read_text())
        self.assertIn('"de"', (self.app / "remote-ui/static/catalogs.js").read_text())
        catalog.generate(self.app)
        self.assertFalse((self.app / "l10n/effective/ui_de.arb").exists())

    def test_community_import_requires_provenance_and_preserves_spanish(self):
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        self.add_language()
        catalog.write(self.repo / "metadata/reviews/de.json", self.review())
        with self.assertRaisesRegex(ValueError, "complete and reviewed"):
            catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        self.approve_fixture()
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        self.assertEqual(catalog.read(self.app / "l10n/localization.lock.json")["locales"], ["de", "es"])
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_es.arb")["welcome"], "TEST welcome")
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_de.arb")["welcome"], "DE welcome")
        self.assertIn("Translator (de)", (self.app / "assets/l10n/CREDITS.md").read_text())
        # A later Spanish import must also retain the community language.
        catalog.import_catalog(self.app, self.repo, self.git("rev-parse", "HEAD").strip(), "es")
        self.assertTrue((self.app / "l10n/effective/ui_de.arb").exists())

    def test_importing_french_preserves_german_and_spanish(self):
        catalog.import_catalog(self.app, self.repo, self.revision, "es")
        for language in ("de", "fr"):
            self.add_language(language)
            self.approve_fixture(language)
            catalog.import_catalog(self.app, self.repo, self.commit(), language)
        self.assertEqual(catalog.read(self.app / "l10n/localization.lock.json")["locales"], ["de", "es", "fr"])
        for language, label in (("de", "DE"), ("fr", "FR"), ("es", "TEST")):
            self.assertEqual(catalog.read(self.app / f"l10n/effective/ui_{language}.arb")["welcome"], label + " welcome")

    def test_community_source_changes_fall_back_until_reviewed(self):
        self.add_language()
        self.approve_fixture()
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")
        self.source["welcome"] = "Updated English"
        self.write_sources(self.app / "l10n/source", self.source)
        catalog.generate(self.app)
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_de.arb")["welcome"], "Updated English")

    def test_unmerged_wrong_author_or_tampered_evidence_is_rejected(self):
        self.add_language()
        for case in ("unmerged", "owner", "actor", "bytes", "incomplete", "digest"):
            proof = self.proof()
            if case == "unmerged": proof["outcome"]["merged"] = False
            elif case == "owner": proof["outcome"]["merged_by"] = 3
            elif case == "actor": proof["record"]["actor"]["id"] = 3
            elif case == "bytes":
                proof["record"]["snapshot"][0]["after"]["base64"] = base64.b64encode(b"changed").decode()
                proof["outcome"]["acceptance"]["sha256"] = catalog.canonical_digest(proof["record"])
            elif case == "incomplete":
                proof["record"]["snapshot"].pop()
                proof["outcome"]["acceptance"]["sha256"] = catalog.canonical_digest(proof["record"])
            else: proof["outcome"]["acceptance"]["sha256"] = "0" * 64
            with self.subTest(case=case), self.assertRaises(ValueError):
                catalog.verify_provenance(proof, "de")

    def test_retained_disclosures_must_match_the_accepted_reference(self):
        self.add_language()
        proof = self.proof()
        context = proof["record"]["context"]
        context["disclosures_sha256"] = catalog.sha(b"Provider: Example")
        context["id"] = catalog.canonical_digest({k: v for k, v in context.items() if k != "id"})
        proof["record"]["declaration"] = f"- [x] {self.revision} {context['id']}"
        proof["record"]["pr_description"] = "Provider: Example"
        proof["outcome"]["acceptance"]["sha256"] = catalog.canonical_digest(proof["record"])
        catalog.verify_provenance(proof, "de")
        proof["record"]["pr_description"] = "Different rights disclosure"
        proof["outcome"]["acceptance"]["sha256"] = catalog.canonical_digest(proof["record"])
        with self.assertRaisesRegex(ValueError, "disclosures"):
            catalog.verify_provenance(proof, "de")

    def test_unchanged_text_does_not_change_authorship(self):
        self.add_language()
        proof = self.proof()
        entry = proof["record"]["snapshot"][0]
        entry["before"] = copy.deepcopy(entry["after"])
        proof["outcome"]["acceptance"]["sha256"] = catalog.canonical_digest(proof["record"])
        _, _, changed = catalog.verify_provenance(proof, "de")
        self.assertNotIn("welcome", changed)
        self.assertIn("response", changed)

    def test_community_review_reads_pinned_evidence_and_generates_credit(self):
        self.add_language()
        proof = self.proof()
        repo = {"id": 10, "owner": {"id": 1}, "default_branch": "main"}
        pr = {"merged": True, "merged_by": {"id": 1}, "merge_commit_sha": self.revision,
              "base": {"ref": "main"}, "head": {"sha": self.revision}}
        outcome_path = "outcomes/10/3/outcome.json"
        with patch.object(catalog, "github_json", side_effect=[repo, pr, {"object": {"sha": "b" * 40}},
                          {"truncated": False, "tree": [{"type": "blob", "path": outcome_path}]}]), \
                patch.object(catalog, "github_record", side_effect=[proof["outcome"], proof["record"]]) as records:
            catalog.review_community(self.repo, "de", 3, "Translator", "Deutsch", True)
        self.assertTrue(all(call.args[1] == "b" * 40 for call in records.call_args_list))
        reviews = catalog.read(self.repo / "metadata/reviews/de.json")
        self.assertEqual(reviews["welcome"]["author"], "translator")
        self.assertEqual(catalog.read(self.repo / "metadata/languages.json")["de"], "Deutsch")
        catalog.import_catalog(self.app, self.repo, self.commit(), "de")

    def test_regional_community_preview_uses_flutter_filename(self):
        self.add_language("pt-BR")
        catalog.generate(self.app, self.repo, "pt-BR")
        self.assertEqual(catalog.read(self.app / "l10n/effective/ui_pt_BR.arb")["@@locale"], "pt_BR")


if __name__ == "__main__":
    unittest.main()
