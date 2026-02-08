# Contributing to Milow

First off, thank you for considering contributing to Milow! It's people like you that make Milow such a great tool.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

- **Check if it's already reported**: Search the [Issue Tracker](https://github.com/Maninder-mike/milow/issues).
- **Be specific**: Use the [Bug Report Template](.github/ISSUE_TEMPLATE/bug_report.md).
- **Provide context**: Include OS, Flutter/Dart version, and steps to reproduce.

### Suggesting Enhancements

- **Check if it's already requested**: Search the [Issue Tracker](https://github.com/Maninder-mike/milow/issues).
- **Be clear**: Use the [Feature Request Template](.github/ISSUE_TEMPLATE/feature_request.md).

### Your First Code Contribution

1. **Fork the repository**.
2. **Clone your fork**: `git clone https://github.com/YOUR_USERNAME/milow.git`
3. **Set up the environment**: Follow the [README.md](README.md#getting-started).
4. **Create a branch**: `git checkout -b feature/amazing-feature`
5. **Make your changes**.
6. **Run tests**: `flutter test`
7. **Submit a Pull Request**.

## Pull Request Process

1. Ensure any install or build dependencies are removed before the end of the layer when doing a build.
2. Update the README.md with details of changes to the interface, this includes any new environment variables, exposed ports, or useful file locations.
3. Your PR should ideally be linked to an existing issue.
4. You may merge the Pull Request in once you have the sign-off of at least one maintainer.

## Coding Standards

We follow strict coding standards to ensure the project remains scalable and maintainable.

- **Language**: TypeScript (Strict Mode) for web parts, and Pure Dart/Flutter for apps.
- **Style**: Prefer functional programming patterns, descriptive names, and DRY principles.
- **Architecture**: Enforce boundaries between `apps/` and `packages/`.
- **Error Handling**: Use `Result<T, E>` pattern; no silent failures.
- **Testing**: Target 80% coverage for logic and 100% for critical flows.

Refer to our internal [Project Rules](.github/CODEOWNERS) and documentation for more details.

## Style Guide

- Use `dart format .` for formatting.
- Ensure zero warnings with `flutter analyze`.

## Attribution

This guide was inspired by the [Atom Contributing Guide](https://github.com/atom/atom/blob/master/CONTRIBUTING.md).
