# Changelog

All notable changes to the ZeroTier-Proxy project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial ZeroTier TCP Proxy implementation
- Docker containerization for TCP proxy functionality
- Comprehensive project documentation structure
- Contribution guidelines for TCP proxy development
- Maintainer governance documentation
- Author attribution system
- Multi-architecture support (amd64, arm64, armv7)
- TCP connection monitoring and logging
- Configurable proxy settings and port mapping
- Health check endpoints for container monitoring

### Changed
- Updated project documentation to focus on TCP proxy functionality
- Migrated from ZeroTier client to specialized TCP proxy implementation
- Optimized container size for proxy-specific use cases

### Deprecated

### Removed

### Fixed

### Security
- Implemented secure TCP proxy configurations
- Added container security best practices

## [v2025.01.21] - 2025-01-21

### Added
- Docker image for ZeroTier TCP Proxy implementation
- Multi-architecture support (amd64, amd64/v2, amd64/v3, arm64, armv7)
- Automated CI/CD pipeline with GitHub Actions
- Docker Scout security scanning
- SonarQube code quality analysis
- Dependabot dependency management
- MIT License implementation
- TCP proxy functionality with configurable ports
- Connection monitoring and logging capabilities
- Health check endpoints for container status

### Documentation
- README with ZeroTier TCP Proxy usage instructions
- Docker Hub integration documentation
- Build and deployment workflows
- TCP proxy configuration examples
- Client connection setup guides

### Important Notes
- **Licensing**: Released under MIT License for all use cases
- **Functionality**: Specialized TCP proxy for ZeroTier networks
- **Free Usage**: No restrictions for commercial, academic, or personal use
- **Architecture**: Optimized container design for proxy operations

---

## Release Notes Guidelines

### Version Format
- **vYYYY.MM.DD** (e.g., v2025.01.21)
- Date-based versioning for Docker images
- Optional semantic versioning for major releases

### Change Categories
- **Added**: New TCP proxy features and functionality
- **Changed**: Changes in existing proxy behavior
- **Deprecated**: Soon-to-be removed proxy features
- **Removed**: Removed proxy functionality
- **Fixed**: Bug fixes in TCP proxy operations
- **Security**: Security improvements for proxy connections
- **Documentation**: Documentation updates for TCP proxy usage

### Entry Format
- Use present tense ("Add TCP port mapping" not "Added TCP port mapping")
- Reference issues/PRs when applicable: `- Fix connection timeout (#123)`
- Credit contributors: `- Add ARM64 proxy support (@contributor)`
- Include proxy-specific details: `- Optimize TCP connection pooling`

### Release Process
1. Update CHANGELOG.md with new version
2. Update version in Dockerfile and relevant files
3. Create GitHub release with changelog excerpt
4. Tag release following date-based versioning
5. Build and push multi-architecture Docker images

---

## Contributors

Thanks to all contributors who help improve this project:

- **Luca Ferrarotti** (@lferrarotti74) - Project Creator & Maintainer

*Contributors are automatically added when they make their first contribution.*

---

**Note**: Dates use YYYY-MM-DD format. Unreleased changes are tracked at the top.