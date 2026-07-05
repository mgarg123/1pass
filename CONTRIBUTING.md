# Contributing to 1Pass

We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features

## Development Setup

1. Make sure you have Flutter installed (version 3.22.0 or newer).
2. Clone the repository and run `flutter pub get`.
3. Set up a local Supabase project for testing (see README.md).
4. Do not commit any `.env` files or real credentials.

## Coding Style

This project enforces strict linting rules. 
- Please run `flutter analyze` before committing.
- Ensure your code matches the existing style conventions.
- Avoid introducing new external dependencies unless strictly necessary, especially in the core and crypto layers.

## Testing

Run tests locally with:
```bash
flutter test
```

> **CRITICAL**: Any changes made in the `lib/core/crypto/` directory require extremely careful review. If you touch cryptographic logic, you **must** ensure all crypto verification unit tests pass. Pull requests that alter cryptographic behavior without corresponding test updates and rigorous justification will not be merged.

## Pull Requests

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!
