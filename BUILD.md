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

1. Khong yeu cau credentials luc build; dang nhap tu man hinh trong app.
2. Boot iPhone 16 Pro Simulator neu simulator dang tat.
3. Chay `flutter pub get`.
4. Build ung dung bang `flutter build ios --simulator`.
5. Cai `Runner.app` vao simulator.
6. Khoi dong bundle `com.kvx.kvxFlutter`.

Chay tu thu muc goc cua repository:

```bash
cd /Users/vinhnguyen/Documents/kvx
./run_iphone16pro.sh
```

Flutter khong nhung credentials bang `--dart-define`. Nhap tai khoan Binblog trong app. Mat khau khong duoc luu.

## Swift native

Script [run_kvx.sh](run_kvx.sh) se:

1. Build va ad-hoc sign scheme `kvx` vao `build/native-derived` de Keychain hoat dong tren simulator.
2. Boot simulator duoc chon boi `SIMULATOR_ID` (mac dinh iPhone 16 Pro).
3. Cai dung `kvx.app` vua build, khong tim ban cu trong DerivedData.
4. Khoi dong lai bundle `com.kvx.kvx` tren simulator do.

Chay:

```bash
cd /Users/vinhnguyen/Documents/kvx
./run_kvx.sh
```

Trong app, bam **Dang nhap Binblog** va dung cung tai khoan voi Flutter.
Native goi `POST /api/login`, luu access token va tai lai danh sach thiet bi.
Mat khau khong duoc luu. Khi token het han (401), app yeu cau dang nhap lai.
Danh sach mau khong con duoc hien thi khi chua dang nhap.

Co the chon simulator khac bang `SIMULATOR_ID=<UUID> ./run_kvx.sh`.

Hai app luu phien trong secure storage (Swift Keychain, Flutter flutter_secure_storage).
Startup khoi phuc JWT cuc bo, khong goi API de xac thuc phien truoc khi hien thi app.
Request bao ve dau tien tra ve 401 se ket thuc phien chung; loi mang/5xx giu phien.
Menu **Tai khoan** cung cap **Dang xuat** va **Doi tai khoan**.
Neu xoa phien that bai, app bao loi va khong cam ket dang xuat ben vung sau restart.

Swift chi import `binblog.accessToken` tu UserDefaults khi Keychain chua co entry.
Khong tiep tuc nap token vao UserDefaults bang `simctl defaults write` sau migration.
Signed-out Keychain entry ngan viec import lai token cu.

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
  CODE_SIGN_IDENTITY=- \
  build
```

## Xu ly loi thuong gap

### Dang nhap Flutter

Khong can `BINBLOG_USERNAME` / `BINBLOG_PASSWORD` de build hoac khoi dong.
Dang nhap bang man hinh **Dang nhap Binblog**; retry du lieu khong tu dang nhap.

### CocoaPods va secure storage

Plugin secure storage can CocoaPods/Ruby hoat dong khi build iOS.
Neu Flutter bao CocoaPods bi hong, kiem tra `pod --version` va Ruby/gem installation.
Khong dung build thanh cong cua Dart/unit tests de suy ra native plugin da build.

### `xcpretty: command not found`

`run_kvx.sh` khong bat buoc `xcpretty`. Neu may khong co lenh nay, script tu dong dung output mac dinh cua `xcodebuild`.

### Keychain bao loi sau dang xuat

Khong build app smoke test bang `CODE_SIGNING_ALLOWED=NO`. iOS Simulator tra ve
`errSecMissingEntitlement` cho app unsigned, nen khong the ghi signed-out barrier.
`run_kvx.sh` dung ad-hoc signing va tu choi cai app neu `codesign --verify` that bai.

### Khong tim thay simulator

Kiem tra cac simulator dang co:

```bash
xcrun simctl list devices available
```

Neu UUID iPhone 16 Pro thay doi, cap nhat `SIMULATOR_ID` trong `run_iphone16pro.sh`.

### API tra ve loi 401

Dang nhap lai tu UI. 401 cua generation hien tai ket thuc phien; retry khong tu login. 401 cu khong duoc xoa phien tai khoan moi.

Chi tiet: [Mobile auth session](docs/decisions/mobile-auth-session.md).
