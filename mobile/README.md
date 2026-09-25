# HisabSaathi mobile foundation

This is the intended Flutter/Dart client. It is deliberately separate from
the legacy web/PWA client while the migration is validated.

## Local build

The current Replit environment does not include Flutter or Dart, so these
commands cannot be run here yet:

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

The values must be injected from Replit Secrets or a CI secret store. The
Supabase anon key is client-safe, but it still must not be confused with the
service-role key. Never ship the service-role key to this app.

The client uses Supabase Auth for refreshable sessions and `sqflite` for
cached records plus a durable sync queue. It does not mark an operation
`SYNCED` merely because the server accepted it; a server-side processor must
apply the domain operation and update `sync_operations.status` first.