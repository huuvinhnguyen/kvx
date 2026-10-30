import tempfile
import unittest
from pathlib import Path

from relay_smoke_support import assert_original_dependencies, prepare


LOCK = '''packages:
  original:
    dependency: transitive
    description:
      name: original
      sha256: abc123
    source: hosted
    version: "1.0.0"
sdks:
  dart: ">=3.11.5 <4.0.0"
'''
EXTRA = '''  integration_test:
    dependency: "direct dev"
    description: flutter
    source: sdk
    version: "0.0.0"
'''


class SmokeSupportTests(unittest.TestCase):
    def resolved(self):
        return LOCK.replace('sdks:', EXTRA + 'sdks:')

    def test_preserves_existing_dependency_and_records_only_sdk_addition(self):
        result = assert_original_dependencies(LOCK, self.resolved())
        self.assertEqual(result['original_packages_unchanged'], 1)
        self.assertEqual(result['added_test_packages'], ['integration_test'])

    def test_rejects_existing_version_or_source_mutation(self):
        for old, new in [('1.0.0', '2.0.0'), ('abc123', 'def456'), ('source: hosted', 'source: git')]:
            with self.subTest(new=new), self.assertRaises(ValueError):
                assert_original_dependencies(LOCK, self.resolved().replace(old, new))

    def test_rejects_missing_sdk_or_original_package(self):
        for resolved in [LOCK, 'packages:\n' + EXTRA]:
            with self.assertRaises(ValueError):
                assert_original_dependencies(LOCK, resolved)

    def test_prepare_isolated_copy_without_changing_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'source'
            app = root / 'kvx_flutter'
            app.mkdir(parents=True)
            pubspec = 'name: example\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n'
            (app / 'pubspec.yaml').write_text(pubspec)
            (app / 'build').mkdir()
            (app / 'build/private_cache').write_text('do not copy')
            templates = root / 'tool/relay_demo_smoke'
            templates.mkdir(parents=True)
            for name in ['test.dart.template', 'driver.dart.template']:
                (templates / name).write_text('template')
            destination = Path(directory) / 'smoke'
            prepare(root, destination)
            self.assertEqual((app / 'pubspec.yaml').read_text(), pubspec)
            self.assertIn('integration_test:', (destination / 'pubspec.yaml').read_text())
            self.assertFalse((destination / 'build').exists())
            self.assertTrue((destination / 'integration_test/relay_demo_smoke_test.dart').exists())
            with self.assertRaises(ValueError):
                prepare(root, destination)
            with self.assertRaises(ValueError):
                prepare(root, root / 'nested')


if __name__ == '__main__':
    unittest.main()
