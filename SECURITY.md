# Security Policy

## Supported Versions

We actively support the following versions of ZeroTier-Proxy with security updates:

| Version | Supported          | Proxy Features | License |
| ------- | ------------------ | -------------- | ------- |
| 2025.x  | :white_check_mark: | TCP Proxy v1.0 | MIT |
| 2024.x  | :x:                | N/A            | N/A |

### Important Licensing Information

- **Current Version**: Available under MIT license for all use cases
- **Commercial Use**: No restrictions for commercial, academic, or personal use
- **TCP Proxy**: Specialized functionality with no licensing limitations

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue in ZeroTier-Proxy, please report it responsibly.

### How to Report

**Email**: luca@ferrarotti.it

**Subject Line**: `[SECURITY] ZeroTier-Proxy Vulnerability Report`

**Encryption**: For sensitive reports, please use PGP encryption. Our public key is available upon request.

### What to Include

Please provide the following information in your report:

1. **Description**: A clear description of the vulnerability
2. **Impact**: Potential impact and attack scenarios
3. **Reproduction**: Step-by-step instructions to reproduce the issue
4. **Environment**: 
   - Docker version
   - Host operating system
   - ZeroTier network configuration
   - TCP proxy configuration
   - Container runtime details
   - Network topology details
5. **Proof of Concept**: If applicable, include a minimal PoC
6. **Suggested Fix**: If you have ideas for remediation

### Response Timeline

| Severity | Initial Response | Status Update | Resolution Target |
|----------|------------------|---------------|-------------------|
| Critical | 24 hours | 48 hours | 7 days |
| High | 48 hours | 72 hours | 14 days |
| Medium | 72 hours | 1 week | 30 days |
| Low | 1 week | 2 weeks | 60 days |

### Vulnerability Severity Guidelines

**Critical**: 
- Remote code execution through TCP proxy
- Container escape via proxy exploitation
- Privilege escalation to host system
- Network segmentation bypass through proxy
- TCP connection hijacking or manipulation

**High**:
- Local privilege escalation within container
- Information disclosure of sensitive proxy data
- Authentication bypass in proxy connections
- ZeroTier network compromise via proxy
- TCP traffic interception or modification

**Medium**:
- Denial of service attacks on proxy
- Information disclosure of non-sensitive data
- Configuration vulnerabilities in proxy setup
- Resource exhaustion through proxy abuse

**Low**:
- Minor information leaks in proxy logs
- Non-exploitable bugs with security implications
- Performance degradation issues

## Security Best Practices

### For Users

1. **Keep Updated**: Always use the latest version of ZeroTier-Proxy
2. **Network Security**: Run containers in isolated networks with proper firewall rules
3. **User Permissions**: Don't run as root unless absolutely necessary
4. **Host Security**: Keep Docker and host OS updated
5. **Resource Limits**: Set appropriate CPU/memory limits for proxy containers
6. **TCP Configuration**: Use secure TCP proxy configurations and port mappings
7. **Connection Monitoring**: Monitor TCP connections and proxy logs regularly
8. **Access Control**: Implement proper access controls for proxy endpoints

### For Contributors

1. **Dependencies**: Keep all dependencies updated and scan for vulnerabilities
2. **Secrets**: Never commit secrets, credentials, or sensitive configuration
3. **Input Validation**: Validate all user inputs and TCP connection parameters
4. **Least Privilege**: Follow principle of least privilege in container design
5. **Security Testing**: Test for common vulnerabilities and TCP-specific attacks
6. **Code Review**: Ensure all TCP proxy code is reviewed for security issues
7. **Logging**: Implement secure logging without exposing sensitive data

## Security Features

### Current Security Measures

- **Multi-stage Builds**: Minimal attack surface with optimized container layers
- **Non-root User**: Container runs as non-privileged user by default
- **TCP Security**: Secure TCP proxy implementation with connection validation
- **Resource Isolation**: Proper container resource limits and isolation
- **Dependency Scanning**: Automated vulnerability scanning with Docker Scout
- **Code Analysis**: SonarQube security analysis
- **Supply Chain**: Dependabot for dependency updates

### Planned Security Enhancements

- Container signing and verification for trusted deployments
- SBOM (Software Bill of Materials) generation for transparency
- Runtime security monitoring integration for TCP connections
- Security policy enforcement for proxy configurations
- Advanced TCP connection filtering and validation
- Encrypted proxy communication channels
- Automated security testing for TCP proxy functionality

## Disclosure Policy

### Coordinated Disclosure

1. **Private Report**: Vulnerability reported privately
2. **Investigation**: We investigate and develop fix
3. **Fix Development**: Patch created and tested
4. **Release**: Security update released
5. **Public Disclosure**: Details published after fix is available
6. **Credit**: Reporter credited (if desired)

### Timeline

- **90 days**: Maximum time before public disclosure
- **Shorter for critical**: Critical issues may be disclosed sooner
- **Extension possible**: If fix requires significant changes

## Security Contact

- **Primary Contact**: Luca Ferrarotti
- **Email**: [luca@ferrarotti.it](mailto:luca@ferrarotti.it)
- **Response Time**: Within 48 hours
- **Timezone**: UTC+1 (CET)

## Acknowledgments

We appreciate security researchers and users who help improve our security:

- Security reports are acknowledged in release notes
- Hall of Fame for significant contributions
- Coordination with CVE assignment when applicable

---

**Last Updated**: January 2024
**Next Review**: Quarterly

*This security policy is subject to updates. Check back regularly for the latest version.*