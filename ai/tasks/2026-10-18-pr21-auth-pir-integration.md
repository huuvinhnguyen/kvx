# PR #21: integrate PIR fan-out with mobile authentication

## Boundary

Merge main `f26d481e348fb996cf82313cfdbe41f52187d6c7` (PIR PR #19)
into feature/mobile-social-login `ff48381e906b552a52ed863bfc2874a2a9d4cf8e`
(including account-auth PR #20). Do not merge PR #21 into main here.

The local reconstruction of the source branch has tree
`833e88c690c07ab7304d05e5d0070cf1a05cd4df`, matching GitHub's source tree.
The published merge must retain the two original remote commits as parents.

## Resolution

- Preserve both the account-methods entry and PIR fan-out navigation.
- Inject the current session's authenticated transport into Swift PIR statistics
  and trigger-action clients through the authenticated root/list/detail graph.
  Remove the incoming trigger client's reference to the deleted UserDefaults
  token provider. Keep PIR endpoint, status, receipt and uncertain-write rules.
- Provide Flutter PIR use cases inside the authenticated generation graph using
  the same datasource. Preserve typed API errors and POST 201 support; route PUT
  through authenticated transport and retain its JSON body/content type.
- Adapt PIR transport fixtures to explicit dummy sessions, retaining payload
  assertions. Swift fixtures accept bounded httpBodyStream data as well as
  httpBody; Flutter assertions check bearer headers, PUT content type and absence
  of hidden login calls.

## Verification

- PASS: all 27 changed Swift/Dart files parsed without syntax errors using
  tree-sitter (not a compiler/type checker).
- PASS: staged/unstaged git diff whitespace checks; no unresolved index entries
  or conflict markers. Reviewed graph wiring and obsolete credential references.
- NOT RUN: Xcode builds/tests, Flutter analyze/test, simulator/manual smoke.
  This execution environment has no Xcode, Swift, Dart or Flutter SDK.
- No real API requests, account mutations or credential access performed.

Before merge, run Swift build/tests and Flutter analyze/test on a configured Mac,
including PIRTriggerActionTests, session/auth suites and
test/pir/pir_trigger_actions_test.dart. Confirm both account methods and PIR
actions are reachable in the same restored/authenticated session.

Existing auth runtime limitations and deferred flows remain unchanged; resolving
Git conflicts does not establish full auth acceptance or an independent review.
