This directory is populated from `firebase_core` and patched to remove Windows platform registration.

Run:

```bash
./scripts/setup_firebase_core_nowindows.sh 4.4.0
```

The script will:
- copy `firebase_core-4.4.0` from your Pub cache,
- remove the `windows:` block in `pubspec.yaml`,
- delete the `windows/` directory.
