# KVX GitHub Flow

## Branch Strategy

```
main          ← code đã deploy/production
    │
    ├── feature/xxx    ← features mới
    ├── fix/xxx        ← bug fixes
    ├── refactor/xxx   ← cải thiện code
    └── chore/xxx      ← tasks nhỏ
```

## Quy tắc đặt tên branch

```
feature/device-list
feature/user-authentication
fix/login-crash
refactor/cleanup-models
chore/update-dependencies
```

## Workflow

### 1. Tạo branch mới
```bash
git checkout main
git pull origin main
git checkout -b feature/your-feature
```

### 2. Commit thay đổi
```bash
git add .
git commit -m "feat: add new feature"
git push origin feature/your-feature
```

### 3. Commit message convention
```
feat:     new feature
fix:      bug fix
refactor: code refactoring
chore:    maintenance tasks
docs:     documentation
test:     adding tests
style:    formatting
perf:     performance improvements
```

### 4. Tạo Pull Request
- Đặt tiêu đề rõ ràng
- Mô tả what & why
- Link issues liên quan

### 5. Sau khi merge
```bash
git checkout main
git pull origin main
git branch -d feature/your-feature
```

## Quy tắc

- **main** = production ready, luôn build được
- **Không commit trực tiếp vào main**
- **Mỗi PR = 1 feature/fix**
- **Review trước khi merge** (tự review nếu solo)
