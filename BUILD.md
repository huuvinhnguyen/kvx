# Build va chay KVX bang Bash

Tai lieu nay ghi lai cach build va khoi dong hai phien ban cua KVX tren iOS Simulator.

## Yeu cau

- macOS co Xcode va iOS Simulator
- Flutter SDK cho `kvx_flutter`
- iPhone 16 Pro Simulator co UUID:
  `65A80E5B-E316-471D-9BD7-E1B9D8FF2D01`
- Tai khoan Binblog de lay danh sach thiet bi

## Flutter

Script [run_iphone16pro.sh](run_iphone16pro.sh) se:

1. Kiem tra `BINBLOG_USERNAME` va `BINBLOG_PASSWORD`.
2. Boot iPhone 16 Pro Simulator neu simulator dang tat.
3. Chay `flutter pub get`.
4. Build ung dung bang `flutter build ios --simulator`.
5. Cai `Runner.app` vao simulator.
6. Khoi dong bundle `com.kvx.kvxFlutter`.

Chay tu thu muc goc cua repository:

```bash
cd /Users/vinhnguyen/Documents/kvx
BINBLOG_USERNAME='your-username' \
BINBLOG_PASSWORD='your-password' \
./run_iphone16pro.sh
```

Credentials duoc truyen vao Flutter bang `--dart-define` va khong duoc ghi vao source code.

## Swift native

Script [run_kvx.sh](run_kvx.sh) se:

1. Build scheme `kvx` bang Xcode.
2. Mo Simulator.
3. Tim file `kvx.app` trong DerivedData.
4. Cai app vao simulator dang boot.
5. Khoi dong bundle `com.kvx.kvx`.

Chay:

```bash
cd /Users/vinhnguyen/Documents/kvx
./run_kvx.sh
```

App Swift native doc access token Binblog tu `UserDefaults` voi key:

```text
binblog.accessToken
```

Neu can nap token vao simulator truoc khi chay app:

```bash
xcrun simctl spawn booted defaults write com.kvx.kvx \
  binblog.accessToken 'your-access-token'
```

## Kiem tra nhanh

Kiem tra cu phap Bash:

```bash
bash -n run_kvx.sh
bash -n run_iphone16pro.sh
```

Kiem tra Flutter:

```bash
cd kvx_flutter
flutter pub get
flutter analyze
flutter test
```

Kiem tra build Swift native:

```bash
xcodebuild \
  -project kvx.xcodeproj \
  -scheme kvx \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Xu ly loi thuong gap

### Thieu credentials Flutter

Neu script bao thieu `BINBLOG_USERNAME` hoac `BINBLOG_PASSWORD`, hay export bien truoc khi chay:

```bash
export BINBLOG_USERNAME='your-username'
export BINBLOG_PASSWORD='your-password'
./run_iphone16pro.sh
```

### `xcpretty: command not found`

`run_kvx.sh` khong bat buoc `xcpretty`. Neu may khong co lenh nay, script tu dong dung output mac dinh cua `xcodebuild`.

### Khong tim thay simulator

Kiem tra cac simulator dang co:

```bash
xcrun simctl list devices available
```

Neu UUID iPhone 16 Pro thay doi, cap nhat `SIMULATOR_ID` trong `run_iphone16pro.sh`.

### API tra ve loi 401

Kiem tra credentials Binblog va token. Flutter dang dang nhap qua `POST /api/login`, sau do goi `GET /api/devices` voi header Bearer token.
