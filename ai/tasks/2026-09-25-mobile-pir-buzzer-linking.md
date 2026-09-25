# Mobile PIR ↔ Buzzer linking

Implement backend #105 management endpoints in existing Swift and Flutter Buzzer layers. Use `../ror/binblog/docs/API_BUZZER_MOBILE.md` and `app/javascript/buzzer_links.js` as contract and UX references. Keep Test Buzzer independent. Refresh server state after writes, invalidate stale loads, and block uncertain writes if refresh fails.
