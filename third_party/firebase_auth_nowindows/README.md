This folder should contain a local fork of the corresponding Firebase Flutter plugin with Windows plugin registration removed.

Populate/update it by running:

```bash
./scripts/prepare_firebase_nowindows_overrides.sh
```

The script copies from local Pub cache, removes the `windows:` plugin block in `pubspec.yaml`, and deletes the `windows/` directory.
