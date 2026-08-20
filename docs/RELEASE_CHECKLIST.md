# Release checklist — Obecno

Use this before every Play Store / App Store build.

## Required

- [ ] `applicationId` is `com.obecno.app` (not `com.example.*`)
- [ ] Copy `android/key.properties.example` → `android/key.properties` and fill real keystore values (**never commit** `key.properties` or `.jks`)
- [ ] Release signing uses the upload keystore (not debug)
- [ ] API logging off: do **not** pass `OBECNO_DEBUG_LOGS=true` for store builds
- [ ] Build with obfuscation:

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info
```

- [ ] Keep `build/debug-info` private for crash symbolication
- [ ] Manager screens must not ship as production truth until live APIs replace `lib/demo/`
- [ ] `flutter test` and `flutter analyze` pass on CI

## Optional / next

- [ ] Crashlytics or Sentry + upload symbols
- [ ] `dev` / `staging` / `prod` flavors with separate base URLs
- [ ] SQLCipher for attendance + queue databases
- [ ] TLS certificate pinning for `app.obecno.com`
- [ ] Backend `/auth/refresh` wired into `TokenService.tryRefreshSession`
