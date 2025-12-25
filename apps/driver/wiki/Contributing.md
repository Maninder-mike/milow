# 🤝 Contributing to Milow

Thank you for your interest in contributing to Milow! This guide will help you get started.

## Code of Conduct

Be respectful, inclusive, and professional. We're all here to build great software together.

## How Can I Contribute?

### Reporting Bugs

**Before submitting a bug report:**

- Check if the bug has already been reported in [Issues](https://github.com/maninder-mike/milow/issues)
- Try to reproduce the bug with the latest version
- Collect relevant information (device, OS version, steps to reproduce)

**Submitting a bug report:**

1. Go to [Issues](https://github.com/maninder-mike/milow/issues)
2. Click "New Issue"
3. Use the bug report template
4. Provide:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Screenshots if applicable
   - Device and OS information
   - App version

### Suggesting Features

**Before suggesting a feature:**

- Check if it's already been suggested
- Consider if it fits Milow's scope and goals

**Submitting a feature request:**

1. Open a new issue with "enhancement" label
2. Describe the feature clearly
3. Explain the use case and benefits
4. Provide examples or mockups if possible

### Contributing Code

#### Getting Started

1. **Fork the repository**

   ```bash
   # Click "Fork" on GitHub
   git clone https://github.com/YOUR_USERNAME/milow.git
   cd milow
   ```

2. **Set up development environment**

   ```bash
   flutter pub get
   cp .env.example .env
   # Edit .env with your Supabase credentials
   ```

3. **Create a feature branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

#### Development Workflow

1. **Make your changes**
   - Follow the [Code Style Guide](Code-Style-Guide)
   - Write clean, documented code
   - Add tests for new features

2. **Test your changes**

   ```bash
   flutter test
   flutter analyze
   ```

3. **Commit your changes**

   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

   **Commit message format:**
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation changes
   - `style:` Code style changes (formatting)
   - `refactor:` Code refactoring
   - `test:` Adding tests
   - `chore:` Maintenance tasks

4. **Push to your fork**

   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request**
   - Go to your fork on GitHub
   - Click "New Pull Request"
   - Fill in the PR template
   - Link related issues

#### Pull Request Guidelines

**Your PR should:**

- Have a clear, descriptive title
- Reference related issues (e.g., "Fixes #123")
- Include a description of changes
- Pass all tests and linting
- Follow the code style guide
- Include screenshots for UI changes
- Update documentation if needed

**PR Review Process:**

1. Maintainer reviews your code
2. Automated tests run
3. Feedback provided if changes needed
4. Once approved, PR is merged

### Improving Documentation

Documentation improvements are always welcome!

**Types of documentation:**

- Code comments
- README updates
- Wiki pages
- API documentation
- User guides

**To contribute documentation:**

1. Fork the repository
2. Make your changes
3. Submit a PR with "docs:" prefix

## Development Guidelines

### Code Style

Follow the [Code Style Guide](Code-Style-Guide) which includes:

- Dart style guide compliance
- Consistent formatting (use `dart format`)
- Meaningful variable names
- Proper documentation
- Error handling

### Testing

**Write tests for:**

- New features
- Bug fixes
- Edge cases

**Test types:**

- Unit tests for business logic
- Widget tests for UI components
- Integration tests for flows

**Run tests:**

```bash
flutter test
flutter test --coverage
```

### Performance

**Consider:**

- List rendering performance
- Image optimization
- Network request efficiency
- Battery usage
- Memory management

### Accessibility

**Ensure:**

- Proper semantic labels
- Sufficient color contrast
- Keyboard navigation support
- Screen reader compatibility

## Project Structure

```
lib/
├── core/               # Shared code
│   ├── constants/     # App constants
│   ├── models/        # Data models
│   ├── services/      # Business logic
│   ├── theme/         # Theming
│   └── widgets/       # Shared widgets
└── features/          # Feature modules
    ├── auth/          # Authentication
    ├── dashboard/     # Dashboard
    ├── explore/       # Explore
    ├── inbox/         # Notifications
    ├── settings/      # Settings
    └── trips/         # Trip management
```

## Communication

### Where to Ask Questions

- **General questions**: [GitHub Discussions](https://github.com/maninder-mike/milow/discussions)
- **Bug reports**: [GitHub Issues](https://github.com/maninder-mike/milow/issues)
- **Feature requests**: [GitHub Issues](https://github.com/maninder-mike/milow/issues)

### Response Times

- Issues: Usually within 48 hours
- Pull Requests: Usually within 1 week
- Discussions: Best effort

## Recognition

Contributors are recognized in:

- GitHub contributors page
- Release notes
- README acknowledgments

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Getting Help

**Need help contributing?**

- Read the [Architecture](Architecture) guide
- Check the [Code Style Guide](Code-Style-Guide)
- Ask in [Discussions](https://github.com/maninder-mike/milow/discussions)
- Review existing PRs for examples

## Thank You

Every contribution, no matter how small, makes Milow better. Thank you for being part of this project! 🙏

---

**Ready to contribute?** Check out [good first issues](https://github.com/maninder-mike/milow/labels/good%20first%20issue) to get started!
