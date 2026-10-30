"""Prepare isolated simulator verification; never modify the application checkout."""
import argparse
import json
from pathlib import Path
import re
import shutil


def lock_packages(text):
    packages = {}
    current = None
    for line in text.splitlines():
        match = re.fullmatch(r"  ([A-Za-z0-9_]+):", line)
        if match:
            current = match.group(1)
            packages[current] = []
        elif current and line.startswith("    "):
            if not line.startswith("    dependency:"):
                packages[current].append(line.rstrip())
        elif line and not line.startswith(" ") and line != "packages:":
            current = None
    return {name: "\n".join(lines) for name, lines in packages.items()}


def assert_original_dependencies(original, resolved):
    before = lock_packages(original)
    after = lock_packages(resolved)
    if not before or "integration_test" not in after:
        raise ValueError("Missing original lock or SDK integration_test dependency")
    changed = sorted(name for name, value in before.items() if after.get(name) != value)
    if changed:
        raise ValueError("Original dependency changed: " + ", ".join(changed))
    return {"original_packages_unchanged": len(before), "added_test_packages": sorted(set(after) - set(before))}


def prepare(root, destination):
    root, destination = root.resolve(), destination.resolve()
    source = root / "kvx_flutter"
    if destination == root or root in destination.parents or destination == source:
        raise ValueError("Smoke copy must be outside the checkout")
    if destination.exists() and any(destination.iterdir()):
        raise ValueError("Refusing a nonempty smoke destination")
    original = (source / "pubspec.yaml").read_text()
    if original.count("dev_dependencies:\n") != 1 or "  integration_test:" in original:
        raise ValueError("Unexpected app pubspec; review SDK test setup")
    shutil.copytree(source, destination, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("build", ".dart_tool", ".gradle", "Pods", ".symlinks", "ephemeral"))
    (destination / "pubspec.yaml").write_text(original.replace(
        "dev_dependencies:\n", "dev_dependencies:\n  integration_test:\n    sdk: flutter\n", 1))
    for folder, template, name in [
        ("integration_test", "test.dart.template", "relay_demo_smoke_test.dart"),
        ("test_driver", "driver.dart.template", "relay_demo_smoke_driver.dart"),
    ]:
        target = destination / folder
        target.mkdir(exist_ok=True)
        shutil.copyfile(root / "tool/relay_demo_smoke" / template, target / name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "check-lock"])
    parser.add_argument("root", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(args.root, args.destination)
    else:
        result = assert_original_dependencies(
            (args.root / "kvx_flutter/pubspec.lock").read_text(),
            (args.destination / "pubspec.lock").read_text())
        print(json.dumps(result))


if __name__ == "__main__":
    main()
