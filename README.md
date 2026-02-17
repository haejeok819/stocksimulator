# stocksimulator

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local price assets

Price/meta asset files under `assets/prices/` are generated locally and intentionally excluded from version control.

Before running the app, generate or copy the required files:

- `assets/prices/{market}/_top50_meta.json`
- `assets/prices/{market}/{ticker}/meta.json`
- `assets/prices/{market}/{ticker}/{year}.json.gz`

The repository keeps only `assets/prices/.gitkeep` to preserve the folder structure.
