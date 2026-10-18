# z8tvbhtth5 — Mobile Auth Session Foundation

Implement the accepted architecture and targeted follow-up for Swift and Flutter.

- One coordinator owns the Binblog JWT, token-free state, generation and serialized persistence.
- Restore locally from secure storage without validation HTTP. JWT remains opaque.
- Active/signedOut values in one secure store; no policy file, approval IDs or path_provider.
- Explicit password login, logout and account switching; no request-triggered authentication.
- Generation-bound feature graphs and transport discard stale responses and stale 401s.
- Swift imports UserDefaults only when Keychain is absent. Signed-out sentinel blocks reimport.
- No provider SDK or backend changes. Do not commit, push or change ClickUp.

Implementation sequence: domain/coordinator; secure adapters; shared HTTP; session UI/graphs; race and regression tests; verification and scope review.

Verification evidence is recorded in docs/decisions/mobile-auth-session.md after execution.

Targeted Android follow-up scope: REV-01/REV-02 only. Repository-owned pinned
secure-storage fork, checked commit for values/keys/metadata, resetOnError:false,
initialization cache/error fencing and read-only backing-file corruption guard.
Coordinator/Swift/backend/provider behavior remains unchanged. Native injected
failures and real synthetic emulator kill/relaunch checks are recorded separately
from Dart mock coverage in the decision note and fork provenance. No commit,
push, PR, merge or ClickUp mutation is authorized.
