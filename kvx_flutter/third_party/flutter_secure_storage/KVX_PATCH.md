# KVX Android durability patch — REV-01 / REV-02

Upstream: `flutter_secure_storage` **10.0.0**, published package at
https://pub.dev/packages/flutter_secure_storage/versions/10.0.0 .
Source repository: https://github.com/mogol/flutter_secure_storage .
Published archive SHA-256:
`da922f2aab2d733db7e011a6bcc4a825b844892d4edd6df83ff156b09a9b2e40`.

This repository owns the path dependency. The pub cache is not patched or needed
as a source dependency. `UPSTREAM.sha256` records the original bytes of the 40
vendored upstream files. Included: package metadata, LICENSE, docs, Dart library
and upstream unit tests, Android source/build files. Excluded: example app,
generated builds and package-cache metadata. Upstream LICENSE is unchanged.
All Dart and non-Android platform delegation files remain byte-identical.
Federated platform implementations retain their existing locked versions.

## Production patch

- New `DurablePreferences.checkedCommit`: synchronous `Editor.commit()` returning
  false throws a storage error. Production RSA/OAEP initialization and mutations
  run on the plugin's existing worker thread. Method success follows commit.
- `FlutterSecureStorage`: checked encrypted value write/delete/deleteAll, cipher
  metadata and migration-marker writes. Remaining legacy cleanup/copy helpers
  also use checked commits. Initialization failures clear preferences/cipher/
  factory caches; callback completion is guarded; biometric cipher setup cannot
  return success after error. Storage persistence errors never trigger reset.
- `FlutterSecureStoragePlugin`: method exceptions propagate to Dart rather than
  reporting successful destructive reset.
- `StorageCipherFactory`: flush pending in-memory metadata before trusting it;
  remove premature current-profile marker writes. Empty stores select current
  algorithms with checked markers. Nonempty incompatible profiles fail visibly
  without altering their markers or keys. Legacy ESP/algorithm migration is not
  executed automatically; that requires a separate, explicit migration design.
- AES18/GCM/AES23 storage ciphers and AES23 key cipher: checked wrapped-key/IV
  creation and removal. Initialization flushes a possibly memory-only generation
  before reusing a key after earlier commit failure. RSA Keystore operations,
  cipher algorithms, aliases, preference names, ciphertext and wrapped-key
  encodings are unchanged. Completed upstream 10.0.0 OAEP/GCM stores are readable.
- `DurablePreferences.open`: read-only validation of existing session, config
  and wrapped-key preferences XML before Android can silently treat corruption
  as an empty map. Existing `.bak` takes precedence, matching Android recovery.
  Malformed XML, invalid preference types/values and unreadable files raise a
  sanitized error. The guard neither erases data nor creates another store.
- App `SecureSessionStore` explicitly sets `AndroidOptions(resetOnError: false)`.

A false commit can still update preferences memory or have an ambiguous disk
outcome. It is never counted as successful persistence. Checked empty commits
on retry flush outstanding memory before cached prerequisites are trusted.
Each checked commit updates a fixed private nonsecret marker with a fresh value
inside the same preferences file. Android 7 can skip a no-change commit even
when a previous write failed; changing the marker forces a write for retry,
repeated deletion and initialization acknowledgement on the full minSdk24 range.
The marker is excluded by existing session-key prefix filtering, carries no
token or restoration decision, and is not a second authority. It also means
native deleteAll clears application entries while retaining this internal marker.
See the [Android 7 implementation](https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/android-7.0.0_r1/core/java/android/app/SharedPreferencesImpl.java)
and Android's [SharedPreferences implementation](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/app/SharedPreferencesImpl.java)
for the distinction between memory and disk generations.

## Contract and tests

Login publication requires key/metadata prerequisites plus encrypted-record
commit success. Logout fences runtime immediately, then tries a token-free
signedOut write, with checked deletion fallback. Only one successful clear
acknowledgement counts as durable logout. Total failure stays signed out in
memory, surfaces an error and may restore the surviving record after restart.
Account switching cannot authenticate B until A clearing succeeds.

One logical secure store remains; metadata/wrapped-key files are upstream
cryptographic internals, not independent session authorities.

JUnit 4, Mockito and Robolectric additions are test-only. Native tests inject
commit failures and exercise method errors, initialization retry, wrapped keys,
metadata and malformed files. Dart tests cover coordinator ordering and option/
channel propagation. These mocks do not prove physical persistence.

Real emulator evidence is produced by `../../test_support/android_session_restart_test.sh`.
It uses synthetic sessions through the production adapter, waits for native
acknowledgement, force-stops, then restores in a distinct PID. No immediate
readback or hot restart is counted as durability. See task decision documentation
for executed results; no physical-device/power-loss guarantee is inferred.
