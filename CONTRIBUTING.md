# Contributing to davianspace_logging

Thank you for considering a contribution! Please read these guidelines before
opening a pull request.

## Prerequisites

- Dart SDK ≥ 3.0
- `dart pub get` in the package root

## Development workflow

```bash
# Get dependencies
dart pub get

# Run tests
dart test

# Check formatting
dart format --output=none --set-exit-if-changed .

# Run the analyzer
dart analyze
```

## Guidelines

- All new public APIs must include dartdoc comments.
- Every new feature must be covered by tests in `test/`.
- No runtime reflection (`dart:mirrors`) is allowed.
- No external dependencies may be added without discussion.
- Follow the existing code style (strict-mode Dart).

## Submitting a PR

1. Fork the repository.
2. Create a feature branch from `master`.
3. Commit your changes with clear, imperative commit messages.
4. Ensure `dart test` and `dart analyze` pass locally.
5. Open a pull request against `master`.

All contributions are reviewed before merging.
