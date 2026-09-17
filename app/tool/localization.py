#!/usr/bin/env python3
"""Validate catalogs and exchange pinned localization snapshots."""

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


SCHEMA = 2
TAG = re.compile(r"[a-z]{2,3}(?:-[A-Z][a-z]{3})?(?:-(?:[A-Z]{2}|[0-9]{3}))?\Z")
BUNDLE = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*_en\.arb\Z")
KEY = re.compile(r"[a-z][A-Za-z0-9]*\Z")
PARAM = re.compile(r"\{([a-z][A-Za-z0-9]*)\}")
REPOSITORY = "https://github.com/jxlarrea/kiosk-satellite-localization"


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()


def sha(value):
    return hashlib.sha256(value).hexdigest()


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def decode(raw):
    result = json.loads(raw.decode("utf-8"), object_pairs_hook=no_duplicates)
    if not isinstance(result, dict):
        raise ValueError("Catalogs and metadata must be JSON objects")
    return result


def read(path):
    return decode(read_bytes(path))


def file_limit(path):
    # Review records aggregate every section, unlike individual ARB files.
    return 5_000_000 if Path(path).parts[-3:] == ("metadata", "reviews", "es.json") else 500_000


def read_bytes(path):
    limit = file_limit(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > limit:
        raise ValueError(f"Expected a regular file no larger than {limit} bytes: {path}")
    return path.read_bytes()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encoded(value))


def messages(catalog):
    return {key: value for key, value in catalog.items() if not key.startswith("@")}


def parameters(text):
    if "{" in PARAM.sub("", text) or "}" in PARAM.sub("", text):
        raise ValueError("This catalog supports plain text and named placeholders only. ICU plurals and selects need a later formatter update.")
    return set(PARAM.findall(text))


def validate_text(text):
    if not isinstance(text, str) or not text.strip() or len(text) > 8000:
        raise ValueError("Messages must be nonempty strings of at most 8000 characters")
    if re.search(r"[\x00-\x08\x0b\x0c\x0e-\x1f\u2013\u2014]", text):
        raise ValueError("Messages contain a prohibited control character or dash")
    if re.search(r"<[^>]+>", text):
        raise ValueError("HTML and markup are not supported")
    return parameters(text)


def validate_source(source):
    if source.get("@@locale") != "en" or not messages(source):
        raise ValueError("The English source catalog is missing")
    for key, value in messages(source).items():
        if not KEY.fullmatch(key):
            raise ValueError(f"Invalid message ID: {key}")
        params = validate_text(value)
        metadata = source.get("@" + key, {})
        if not isinstance(metadata, dict):
            raise ValueError(f"Invalid message metadata: {key}")
        for field in ("context", "description"):
            if not isinstance(metadata.get(field), str) or not metadata[field].strip():
                raise ValueError(f"Missing {field}: {key}")
        if "x-notes" in metadata and (not isinstance(metadata["x-notes"], str) or not metadata["x-notes"].strip()):
            raise ValueError(f"Invalid translator notes: {key}")
        declared = metadata.get("placeholders", {})
        if not isinstance(declared, dict) or set(declared) != params or any(
            not isinstance(v, dict) or v.get("type") != "String" for v in declared.values()
        ):
            raise ValueError(f"Placeholder definitions do not match: {key}")
    allowed = {"@@locale", *messages(source), *("@" + k for k in messages(source))}
    if set(source) != allowed:
        raise ValueError("Unexpected source metadata")


def validate_translation(source, catalog, locale):
    if not TAG.fullmatch(locale) or locale == "en" or catalog.get("@@locale") != locale.replace("-", "_"):
        raise ValueError(f"Invalid locale marker or language tag: {locale}")
    for key, value in catalog.items():
        if key == "@@locale":
            continue
        if key not in messages(source):
            raise ValueError(f"Unknown message or translator-supplied metadata: {key}")
        if validate_text(value) != parameters(source[key]):
            raise ValueError(f"Placeholders do not match: {key}")
        urls = lambda text: {url.rstrip(".;:!?)]") for url in re.findall(r"https?://[^\s,]+", text)}
        if urls(value) != urls(source[key]):
            raise ValueError(f"Preserve URLs exactly: {key}")


def source_digest(source, key):
    return sha(encoded({"message": source[key], "metadata": source["@" + key]}))


def merge_bundles(bundles, locale):
    result = {"@@locale": locale.replace("-", "_")}
    for name, bundle in sorted(bundles.items()):
        for key, value in bundle.items():
            if key == "@@locale":
                continue
            if key in result:
                raise ValueError(f"Duplicate message ID across files: {key} in {name}")
            result[key] = value
    return result


def source_bundles(files):
    if not files:
        raise ValueError("The English source catalogs are missing")
    bundles = {}
    for name, raw in sorted(files.items()):
        if not BUNDLE.fullmatch(name):
            raise ValueError(f"Invalid source filename: {name}")
        bundles[name] = decode(raw)
        validate_source(bundles[name])
    merge_bundles(bundles, "en")
    return bundles


def bundle_files(directory, *, source=False):
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError(f"Expected a catalog directory: {directory}")
    return {path.name: read_bytes(path) for path in sorted(directory.iterdir())
            if not (source and path.name == "manifest.json")}


def load_sources(directory):
    return source_bundles(bundle_files(directory, source=True))


def translation_name(source_name, locale):
    return source_name.removesuffix("_en.arb") + f"_{locale.replace('-', '_')}.arb"


def translation_catalog(bundles, files, locale):
    if not TAG.fullmatch(locale) or locale == "en":
        raise ValueError(f"Invalid language tag: {locale}")
    expected = {translation_name(name, locale): source for name, source in bundles.items()}
    translated = {}
    for name, raw in sorted(files.items()):
        if name not in expected:
            raise ValueError(f"Unexpected translation path: {locale}/{name}")
        translated[name] = decode(raw)
        validate_translation(expected[name], translated[name], locale)
    return merge_bundles(translated, locale)


def validate_manifest(manifest, files):
    if manifest.get("schema") != SCHEMA or manifest.get("files") != {
        name: sha(raw) for name, raw in files.items()
    }:
        raise ValueError("Source manifest does not match the English catalogs")


def effective(source, catalog, reviews):
    result = dict(source)
    result["@@locale"] = catalog["@@locale"]
    counts = {"reviewed": 0, "missing": 0, "stale": 0}
    for key in messages(source):
        if key not in catalog:
            counts["missing"] += 1
        elif reviews.get(key) != {
            "source": source_digest(source, key), "translation": sha(catalog[key].encode()),
            "author": "Xavier Larrea",
        }:
            counts["stale"] += 1
        else:
            result[key] = catalog[key]
            counts["reviewed"] += 1
    return result, counts


def validate_repository(root):
    files = bundle_files(root / "source", source=True)
    bundles = source_bundles(files)
    source = merge_bundles(bundles, "en")
    manifest = read(root / "source/manifest.json")
    validate_manifest(manifest, files)
    for directory in sorted((root / "translations").iterdir()):
        locale = directory.name
        files = bundle_files(directory)
        catalog = translation_catalog(bundles, files, locale)
        for name, raw in files.items():
            source_name = next(name_en for name_en in bundles if translation_name(name_en, locale) == name)
            print(f"{locale}/{name}: {len(messages(decode(raw)))}/{len(messages(bundles[source_name]))} translated")
        print(f"{locale}: {len(messages(catalog))}/{len(messages(source))} translated")
    return source


def export_catalog(app, repository):
    bundles = load_sources(app / "l10n/source")
    source = merge_bundles(bundles, "en")
    revision = subprocess.check_output(["git", "-C", str(app), "rev-parse", "HEAD"], text=True).strip()
    dirty = bool(subprocess.check_output(["git", "-C", str(app), "status", "--porcelain", "--", "l10n/source/"]))
    for path in (repository / "source").glob("*.arb"):
        if path.name not in bundles:
            path.unlink()
    for name, bundle in bundles.items():
        write(repository / "source" / name, bundle)
    write(repository / "source/manifest.json", {
        "schema": SCHEMA, "repository": "https://github.com/jxlarrea/kiosk-satellite",
        "revision": revision, "workingTree": dirty,
        "files": {name: sha(encoded(bundle)) for name, bundle in bundles.items()},
        "scope": "setup-settings-navigation-and-device-drawer",
    })
    target = repository / "tools/catalog.py"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(Path(__file__).read_bytes())
    tests = repository / "tests/test_catalog.py"
    tests.parent.mkdir(parents=True, exist_ok=True)
    tests.write_bytes((app / "test/test_localization.py").read_bytes())
    print(f"Exported {len(messages(source))} messages. Source includes uncommitted catalog changes: {dirty}")


def review_owner(repository, locale):
    # Community imports need verified PR provenance before they can be enabled.
    if locale != "es":
        raise ValueError("Owner review currently supports Xavier's Spanish catalog only")
    source = validate_repository(repository)
    catalog = translation_catalog(load_sources(repository / "source"),
                                  bundle_files(repository / "translations/es"), locale)
    write(repository / "metadata/reviews/es.json", {
        key: {"source": source_digest(source, key), "translation": sha(value.encode()), "author": "Xavier Larrea"}
        for key, value in messages(catalog).items()
    })
    print("Recorded owner review. Commit the translations and review metadata before importing.")


def git_file(repository, revision, path):
    mode = subprocess.check_output(["git", "-C", str(repository), "ls-tree", revision, "--", path], text=True)
    if not mode.startswith("100644 blob "):
        raise ValueError(f"Snapshot path must be an ordinary file: {path}")
    data = subprocess.check_output(["git", "-C", str(repository), "show", f"{revision}:{path}"])
    limit = file_limit(path)
    if len(data) > limit:
        raise ValueError(f"Snapshot file too large: {path}")
    return data


def import_catalog(app, repository, revision, locale):
    if locale != "es":
        raise ValueError("This first import cycle supports owner-authored Spanish. Community imports require PR provenance support.")
    if not re.fullmatch(r"[a-f0-9]{40}", revision):
        raise ValueError("Import requires a full 40-character commit SHA")
    manifest = decode(git_file(repository, revision, "source/manifest.json"))
    names = manifest.get("files", {})
    if manifest.get("schema") != SCHEMA or not isinstance(names, dict) or not names or any(
        not BUNDLE.fullmatch(name) for name in names
    ):
        raise ValueError("Source manifest is invalid")
    translations = subprocess.check_output([
        "git", "-C", str(repository), "ls-tree", "-r", "--name-only", revision, "--", "translations/es/"
    ], text=True).splitlines()
    expected = {f"translations/es/{translation_name(name, locale)}" for name in names}
    if set(translations) - expected:
        raise ValueError("Unexpected translation path in snapshot")
    paths = ["source/manifest.json", *("source/" + name for name in names), *translations,
             "metadata/reviews/es.json", "LICENSE", "CREDITS.md", "docs/CONTRIBUTOR-AGREEMENT.md"]
    files = {path: git_file(repository, revision, path) for path in paths}
    source_files = {name: files["source/" + name] for name in names}
    validate_manifest(manifest, source_files)
    bundles = source_bundles(source_files)
    source = merge_bundles(bundles, "en")
    if bundles != load_sources(app / "l10n/source"):
        raise ValueError("Export the current app source before importing translations")
    catalog = translation_catalog(bundles, {Path(path).name: files[path] for path in translations}, locale)
    reviews = decode(files["metadata/reviews/es.json"])
    _, counts = effective(source, catalog, reviews)
    lock_path = app / "l10n/localization.lock.json"
    previous = read(lock_path) if lock_path.exists() else {}
    if locale not in previous.get("locales", []) and (counts["missing"] or counts["stale"]):
        raise ValueError("The initial Spanish scope must be complete and reviewed before activation")
    for path, data in files.items():
        target = app / "l10n/vendor" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    write(lock_path, {"schema": SCHEMA, "repository": REPOSITORY, "revision": revision,
                      "locales": [locale], "files": {path: sha(data) for path, data in files.items()}})
    generate(app)


def generate(app, preview_repo=None):
    source = merge_bundles(load_sources(app / "l10n/source"), "en")
    settings = read(app / "l10n/settings.json")
    for setting, fields in settings.items():
        if not isinstance(fields, dict) or set(fields) != {"title", "description"} or any(
            not isinstance(key, str) or key not in messages(source) or parameters(source[key])
            for key in fields.values()
        ):
            raise ValueError(f"Invalid setting message mapping: {setting}")
    catalogs = {"en": source}
    lock_path = app / "l10n/localization.lock.json"
    if lock_path.exists():
        lock = read(lock_path)
        if lock.get("schema") != SCHEMA or lock.get("locales") != ["es"]:
            raise ValueError("Unsupported localization lock schema or languages")
        for path, digest in lock["files"].items():
            if Path(path).is_absolute() or ".." in Path(path).parts:
                raise ValueError("Invalid vendor path")
            if sha(read_bytes(app / "l10n/vendor" / path)) != digest:
                raise ValueError(f"Vendored file changed outside import: {path}")
        source_files = {Path(path).name: read_bytes(app / "l10n/vendor" / path)
                        for path in lock["files"] if path.startswith("source/") and path.endswith(".arb")}
        validate_manifest(read(app / "l10n/vendor/source/manifest.json"), source_files)
        catalog = translation_catalog(source_bundles(source_files), {
            Path(path).name: read_bytes(app / "l10n/vendor" / path)
            for path in lock["files"] if path.startswith("translations/es/")
        }, "es")
        # Removed IDs belong to the old snapshot and are never generated.
        catalog = {key: value for key, value in catalog.items() if key == "@@locale" or key in messages(source)}
        reviews = read(app / "l10n/vendor/metadata/reviews/es.json")
        catalogs["es"], counts = effective(source, catalog, reviews)
        print(f"es: {counts}")
        notices = app / "assets/l10n"
        notices.mkdir(parents=True, exist_ok=True)
        for name, path in {"LICENSE.txt": "LICENSE", "CREDITS.md": "CREDITS.md",
                           "CONTRIBUTOR-AGREEMENT.md": "docs/CONTRIBUTOR-AGREEMENT.md"}.items():
            (notices / name).write_bytes((app / "l10n/vendor" / path).read_bytes())
    if preview_repo is not None:
        # Drafts are only for a local test build. Never create review evidence.
        validate_repository(preview_repo)
        bundles = load_sources(app / "l10n/source")
        if bundles != load_sources(preview_repo / "source"):
            raise ValueError("Export the current source before previewing translations")
        draft = translation_catalog(bundles, bundle_files(preview_repo / "translations/es"), "es")
        catalogs["es"] = {**source, **draft, "@@locale": "es"}
        print("PREVIEW: includes unreviewed Spanish. Run generate without --preview-repo before committing.")
    out = app / "l10n/effective"
    out.mkdir(parents=True, exist_ok=True)
    for path in out.glob("ui_*.arb"):
        if path.stem[3:] not in catalogs:
            path.unlink()
    for locale, catalog in catalogs.items():
        write(out / f"ui_{locale}.arb", catalog)
    output = app / "lib/l10n/generated"
    viewer_path = app / "l10n/source/camera_view_status_en.arb"
    if viewer_path.exists():
        viewer = read(viewer_path)
        viewer_dir = app / "assets/camera-view"
        viewer_dir.mkdir(parents=True, exist_ok=True)
        (viewer_dir / "messages.js").write_text(
            "// Generated by tool/localization.py. Do not edit.\n"
            + "window.__ksCameraViewEnglish = "
            + json.dumps({key: viewer[key] for key in messages(viewer)}, ensure_ascii=False, indent=2)
            + ";\n")
    output.mkdir(parents=True, exist_ok=True)
    (output / "language_codes.dart").write_text(
        "// Generated by tool/localization.py. Do not edit.\n"
        + "const messageLanguageOptions = <String>[\n"
        + "".join(f"  '{locale.replace('_', '-')}',\n" for locale in catalogs)
        + "];\n")
    for filename, variable in [("navigation", "navigationMessageIds"), ("device_text", "deviceTextMessageIds"), ("ha_text", "haTextMessageIds"), ("screen_audio_text", "screenAudioTextMessageIds"), ("screensaver_text", "screensaverTextMessageIds"), ("camera_text", "cameraTextMessageIds"), ("camera_streams_text", "cameraStreamsTextMessageIds"), ("media_text", "mediaTextMessageIds"), ("intercom_text", "intercomTextMessageIds"), ("kiosk_text", "kioskTextMessageIds"), ("launcher_text", "launcherTextMessageIds"), ("gesture_text", "gestureTextMessageIds"), ("fleet_text", "fleetTextMessageIds"), ("plugin_text", "pluginTextMessageIds"), ("support_text", "supportTextMessageIds")]:
        path = app / f"l10n/{filename}.json"
        mapping = read(path) if path.exists() else {}
        for label, identifier in mapping.items():
            if identifier not in messages(source) or source[identifier] != label or parameters(label):
                raise ValueError(f"Invalid {filename.replace('_text', '')} message mapping: {label}")
        payload = json.dumps(mapping, ensure_ascii=False, indent=2)
        (output / f"{filename}_ids.dart").write_text(
            "// Generated by tool/localization.py. Do not edit.\n"
            + f"const {variable} = <String, String>" + payload.replace('$', r'\$') + ";\n")
        (app / f"remote-ui/static/{filename}_ids.js").write_text(
            "// Generated by tool/localization.py. Do not edit.\n"
            + f"export const {variable} = " + payload + ";\n")
    options_path = app / "l10n/setting_options.json"
    options = read(options_path) if options_path.exists() else {}
    placeholders_path = app / "l10n/setting_placeholders.json"
    placeholders = read(placeholders_path) if placeholders_path.exists() else {}
    ids = [*placeholders.values(), *(identifier for values in options.values() for identifier in values.values())]
    if any(identifier not in messages(source) or parameters(source[identifier]) for identifier in ids):
        raise ValueError("Invalid setting option or placeholder message mapping")
    (output / "setting_option_ids.dart").write_text(
        "// Generated by tool/localization.py. Do not edit.\n"
        + "const settingOptionMessageIds = <String, Map<String, String>>" + json.dumps(options, indent=2) + ";\n"
        + "const settingPlaceholderMessageIds = <String, String>" + json.dumps(placeholders, indent=2) + ";\n")
    setting_lines = ["// Generated by tool/localization.py. Do not edit.",
                     "const settingMessageIds = <String, Map<String, String>>{"]
    for key, fields in settings.items():
        setting_lines.append(f'  "{key}": {{')
        setting_lines.extend(f'    "{field}": "{identifier}",' for field, identifier in fields.items())
        setting_lines.append("  },")
    setting_lines.extend(["};", ""])
    (output / "setting_ids.dart").write_text(
        "\n".join(setting_lines))
    lookup = ["// Generated by tool/localization.py. Do not edit.", "import 'ui_strings.dart';", "",
              "String messageById(UiStrings strings, String? id, String fallback) =>", "    switch (id) {"]
    for key in messages(source):
        if parameters(source[key]):
            continue
        line = f"      '{key}' => strings.{key},"
        lookup.extend([f"      '{key}' =>", f"        strings.{key},"] if len(line) > 80 else [line])
    lookup += ["      _ => fallback,", "    };", ""]
    (output / "message_lookup.dart").write_text("\n".join(lookup))
    remote = app / "remote-ui/static/catalogs.js"
    remote.write_text("// Generated by tool/localization.py. Do not edit.\nexport const catalogs = "
                      + json.dumps({locale: messages(catalog) for locale, catalog in catalogs.items()}, ensure_ascii=False, indent=2)
                      + ";\n")
    print(f"Generated local catalogs: {', '.join(catalogs)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "review-owner"):
        cmd = commands.add_parser(name)
        cmd.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
        if name == "review-owner":
            cmd.add_argument("--locale", default="es")
    for name in ("export", "import", "generate"):
        cmd = commands.add_parser(name)
        cmd.add_argument("--app", type=Path, default=Path(__file__).resolve().parents[1])
        if name == "generate":
            cmd.add_argument("--preview-repo", type=Path, help="Include unreviewed Spanish in a local test build only")
        if name != "generate":
            cmd.add_argument("--repo", type=Path, required=True)
        if name == "import":
            cmd.add_argument("--revision", required=True)
            cmd.add_argument("--locale", default="es")
    args = parser.parse_args()
    if args.command == "validate":
        validate_repository(args.repo)
    elif args.command == "review-owner":
        review_owner(args.repo, args.locale)
    elif args.command == "export":
        export_catalog(args.app, args.repo)
    elif args.command == "import":
        import_catalog(args.app, args.repo, args.revision, args.locale)
    elif args.command == "generate":
        generate(args.app, args.preview_repo)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
