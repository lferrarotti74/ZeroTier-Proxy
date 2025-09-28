# Contributing to ZeroTier-Proxy

Thank you for considering contributing to ZeroTier-Proxy! We welcome contributions from everyone and appreciate your help in making this Docker container better for the ZeroTier community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Getting Started](#getting-started)
- [Development Guidelines](#development-guidelines)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)
- [Style Guidelines](#style-guidelines)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [luca@ferrarotti.it](mailto:luca@ferrarotti.it).

## How Can I Contribute?

### Reporting Bugs
- Use the GitHub issue tracker
- Check if the bug has already been reported
- Provide detailed information about the bug
- Include steps to reproduce the issue

### Suggesting Enhancements
- Use the GitHub issue tracker with the "enhancement" label
- Provide a clear description of the enhancement
- Explain why this enhancement would be useful

### Contributing Code
- Fork the repository
- Create a feature branch
- Make your changes
- Submit a pull request

### Improving Documentation
- Fix typos, clarify language, or add missing information
- Documentation changes follow the same process as code changes

## Getting Started

### Prerequisites

Before contributing, ensure you have:
- **Docker** (version 20.10 or later)
- **Git** for version control
- **Basic understanding** of ZeroTier TCP Proxy functionality
- **Text editor** or IDE of your choice

### Development Environment Setup

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/lferrarotti74/ZeroTier-Proxy.git
   cd ZeroTier-Proxy
   ```

2. **Build the Image**:
   ```bash
   docker build -t zerotier-proxy:dev .
   ```

3. **Test the Build**:
   ```bash
   # Run the proxy server
   docker run -d --name test-proxy -p 443:443 zerotier-proxy:dev
   
   # Check if it's running
   docker logs test-proxy
   
   # Clean up
   docker stop test-proxy && docker rm test-proxy
   ```

### Local Development Setup

For development and testing:

1. **Create a test environment**:
   ```bash
   # Create a development network
   docker network create zerotier-dev
   
   # Run proxy in development mode
   docker run -d --name zerotier-proxy-dev \
     --network zerotier-dev \
     -p 8443:443 \
     -e DEBUG=1 \
     zerotier-proxy:dev
   ```

2. **Monitor logs during development**:
   ```bash
   docker logs -f zerotier-proxy-dev
   ```

### Testing Changes

Before submitting changes, please test:

1. **Build Test**: Ensure the Docker image builds successfully
2. **Functionality Test**: Verify the TCP proxy starts and accepts connections
3. **Port Test**: Confirm the proxy listens on the expected port
4. **Resource Test**: Check memory and CPU usage are reasonable
5. **Integration Test**: Test with actual ZeroTier clients if possible

## Development Guidelines

### Docker and Infrastructure Standards

- **Multi-stage builds**: Use multi-stage Dockerfiles for smaller final images
- **Security**: Run containers as non-root users when possible
- **Efficiency**: Minimize layers and use appropriate base images
- **Documentation**: Comment complex Dockerfile instructions
- **Testing**: Ensure images work across different architectures

### Commit Messages

We follow conventional commit format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(proxy): add support for custom TCP port configuration
fix(docker): resolve container startup issues on ARM64
docs(readme): update installation instructions
```

### Branch Naming

Use descriptive branch names:
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

**Examples:**
- `feature/custom-port-support`
- `fix/container-startup-issue`
- `docs/update-configuration-guide`

## Submitting Changes

### Pull Request Process

1. **Update Documentation**: Ensure any new features are documented
2. **Test Thoroughly**: All tests should pass and new functionality should be tested
3. **Update Changelog**: Add your changes to the CHANGELOG.md file
4. **Clean History**: Squash commits if necessary for a clean history
5. **Descriptive PR**: Write a clear pull request description

### Pull Request Template

When creating a pull request, please include:

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Built and tested Docker image locally
- [ ] Tested TCP proxy functionality
- [ ] Verified port connectivity
- [ ] Checked resource usage
- [ ] Integration tested with ZeroTier clients (if applicable)

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] Any dependent changes have been merged and published
```

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

1. **Environment Information**:
   - Docker version
   - Host operating system
   - Container image version/tag
   - Hardware architecture (amd64, arm64, etc.)

2. **Problem Description**:
   - What you expected to happen
   - What actually happened
   - Steps to reproduce the issue

3. **Logs and Output**:
   - Container logs (`docker logs <container-name>`)
   - Error messages
   - Network configuration details

4. **Additional Context**:
   - ZeroTier network configuration
   - Firewall settings
   - Network topology

### Feature Requests

For feature requests, please provide:
- **Problem Statement**: What problem does this solve?
- **Proposed Solution**: How should it work?
- **Use Case**: When would this be useful?
- **Alternatives**: What other solutions have you considered?

## Style Guidelines

### Dockerfile Style

- **Comments**: Use clear comments to explain complex operations
- **Ordering**: Group related commands and order them logically
- **Caching**: Structure commands to maximize Docker layer caching
- **Security**: Follow security best practices (non-root user, minimal packages)
- **Size**: Minimize final image size while maintaining functionality

**Example:**
```dockerfile
# Use specific version tags, not 'latest'
FROM alpine:3.18

# Install dependencies in a single layer
RUN apk add --no-cache \
    ca-certificates \
    curl \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN adduser -D -s /bin/sh proxyuser

# Copy application files
COPY --chown=proxyuser:proxyuser . /app

# Switch to non-root user
USER proxyuser

# Document the port
EXPOSE 443

# Use exec form for better signal handling
CMD ["./tcp-proxy"]
```

### Documentation Style

- **Clarity**: Write clear, concise documentation
- **Examples**: Include practical examples for all features
- **Structure**: Use consistent heading structure and formatting
- **Links**: Keep internal links up to date
- **Code Blocks**: Use appropriate syntax highlighting

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and community discussions
- **Pull Requests**: Code contributions and reviews

### Getting Help

If you need help with:
- **Docker Issues**: Check Docker documentation and GitHub issues
- **ZeroTier TCP Proxy**: Refer to [ZeroTier TCP Proxy documentation](https://github.com/zerotier/ZeroTierOne/tree/dev/tcp-proxy)
- **General ZeroTier**: Visit [ZeroTier Community Forum](https://discuss.zerotier.com/)
- **Project Specific**: Open a GitHub issue or discussion

### Acknowledgments

Contributors will be recognized in:
- **AUTHORS.md**: All contributors are listed
- **Release Notes**: Significant contributions are highlighted
- **GitHub**: Automatic contributor recognition

## License

By contributing to ZeroTier-Proxy, you agree that your contributions will be licensed under the MIT License. This ensures that the project remains open and accessible to everyone.

---

**Questions?** Feel free to reach out to [luca@ferrarotti.it](mailto:luca@ferrarotti.it) or open a GitHub discussion.

**Last Updated:** January 2025

---

## Questions?

Don't hesitate to ask! You can reach out through any of our communication channels or open an issue tagged as a question.

Thank you for contributing! 🎉