# Maintainers

This document outlines the maintainer structure and governance for the ZeroTier-Proxy project.

## Table of Contents

- [Current Maintainers](#current-maintainers)
- [Roles and Responsibilities](#roles-and-responsibilities)
- [How to Contact Maintainers](#how-to-contact-maintainers)
- [Response Time Commitments](#response-time-commitments)
- [Becoming a Maintainer](#becoming-a-maintainer)
- [Maintainer Guidelines](#maintainer-guidelines)
- [Decision Making Process](#decision-making-process)
- [Emeritus Maintainers](#emeritus-maintainers)
- [Stepping Down Process](#stepping-down-process)
- [Contact Information](#contact-information)

## Current Maintainers

### Lead Maintainer

**Luca Ferrarotti**
- **Email**: luca@ferrarotti.it
- **GitHub**: [@lferrarotti74](https://github.com/lferrarotti74)
- **Role**: Project founder, lead maintainer, and primary decision maker
- **Responsibilities**: Overall project direction, major decisions, release management
- **Timezone**: UTC+1 (Central European Time)
- **Availability**: Weekdays and weekends (best effort)

## Roles and Responsibilities

### Lead Maintainers
- **Project Vision**: Define and maintain the project's long-term vision and roadmap
- **Major Decisions**: Make final decisions on significant changes and project direction
- **Release Management**: Coordinate releases, versioning, and changelog maintenance
- **Community Leadership**: Foster a welcoming and inclusive community environment
- **Conflict Resolution**: Resolve disputes and conflicts within the community

### Core Maintainers
*Currently seeking core maintainers. This role will be filled as the project grows.*

**Responsibilities will include:**
- **Code Review**: Review and approve pull requests
- **Issue Triage**: Categorize, prioritize, and assign issues
- **Documentation**: Maintain and improve project documentation
- **Community Support**: Help users and contributors in discussions and issues

### Area Maintainers
*Currently seeking area maintainers for specific components.*

**Potential areas:**
- **Docker/Infrastructure**: Container optimization, multi-arch builds
- **Documentation**: User guides, API documentation, examples
- **Testing**: Test automation, CI/CD improvements
- **Security**: Security reviews, vulnerability management

## How to Contact Maintainers

### Preferred Communication Channels

1. **GitHub Issues**: For bug reports, feature requests, and project-related discussions
   - Use appropriate issue templates
   - Tag maintainers only when necessary
   - Provide detailed information and context

2. **GitHub Discussions**: For general questions, ideas, and community discussions
   - Best for open-ended conversations
   - Community members can also help
   - Less formal than issues

3. **Email**: For private matters, security issues, or urgent concerns
   - Use luca@ferrarotti.it for direct contact
   - Include "ZeroTier-Proxy" in the subject line
   - Allow 48-72 hours for response

### When to Contact Maintainers

**Appropriate reasons:**
- Security vulnerabilities (use email)
- Project governance questions
- Contribution guidance for significant changes
- Community conduct issues
- Technical questions that can't be resolved through documentation

**Please avoid:**
- Basic usage questions (use GitHub Discussions first)
- Duplicate issues (search existing issues first)
- Urgent requests without justification
- Off-topic discussions

## Response Time Commitments

### Issue Response Times
- **Critical Issues**: 24-48 hours (security, major bugs)
- **Bug Reports**: 3-7 days
- **Feature Requests**: 1-2 weeks
- **Documentation Issues**: 1 week
- **General Questions**: 3-7 days

### Pull Request Review Times
- **Security Fixes**: 24-48 hours
- **Bug Fixes**: 3-7 days
- **Features**: 1-2 weeks
- **Documentation**: 1 week
- **Refactoring**: 1-2 weeks

*Note: These are target response times. Actual response may vary based on maintainer availability, complexity, and current workload.*

## Becoming a Maintainer

### Path to Maintainership

We welcome new maintainers who demonstrate:

1. **Consistent Contributions**: Regular, high-quality contributions over time
2. **Community Engagement**: Active participation in discussions and helping others
3. **Technical Expertise**: Deep understanding of the project and related technologies
4. **Reliability**: Consistent availability and follow-through on commitments
5. **Alignment**: Shared vision and values with the project goals

### Selection Criteria

**For Core Maintainers:**
- Minimum 6 months of active contribution
- At least 10 merged pull requests
- Demonstrated code review skills
- Active community participation
- Understanding of Docker, ZeroTier, and networking concepts

**For Area Maintainers:**
- Expertise in specific area (Docker, documentation, testing, etc.)
- Minimum 3 months of contributions in that area
- At least 5 merged pull requests in the area
- Willingness to take ownership of the area

### Nomination Process

1. **Self-nomination or nomination by existing maintainer**
2. **Evaluation of contributions and community involvement**
3. **Discussion among current maintainers (when applicable)**
4. **Trial period for new maintainers (if needed)**
5. **Final decision and onboarding process**

## Maintainer Guidelines

### Code Review Standards

**All maintainers should:**
- Review code for functionality, security, and maintainability
- Ensure adherence to project coding standards
- Test changes when possible
- Provide constructive feedback
- Approve only when confident in the changes

**Review Checklist:**
- [ ] Code builds successfully
- [ ] Docker image functions correctly
- [ ] Documentation is updated (if applicable)
- [ ] Security implications are considered
- [ ] Performance impact is acceptable
- [ ] Tests pass (when available)

### Merge Requirements

**Before merging pull requests:**
- At least one maintainer approval required
- All CI checks must pass
- No unresolved review comments
- Documentation updated for user-facing changes
- Changelog updated for significant changes

### Release Process

**For releases:**
1. **Version Planning**: Determine version number (semantic versioning)
2. **Changelog Update**: Document all changes since last release
3. **Testing**: Verify functionality across supported platforms
4. **Docker Build**: Ensure multi-arch builds work correctly
5. **Tagging**: Create and push version tags
6. **Release Notes**: Publish release with detailed notes
7. **Announcement**: Notify community of new release

### Communication Standards

**Maintainers should:**
- Be respectful and professional in all interactions
- Respond to issues and PRs in a timely manner
- Provide clear, actionable feedback
- Help newcomers understand the project
- Escalate conflicts to lead maintainer when needed
- Follow the project's Code of Conduct

## Decision Making Process

### Current Decision Making

As a single-maintainer project, decisions are currently made by the lead maintainer (Luca Ferrarotti). However, community input is always welcome and considered.

### Future Governance

As the project grows and additional maintainers join:

1. **Consensus**: Strive for consensus on major decisions
2. **Majority Vote**: When consensus isn't possible, majority vote among maintainers
3. **Lead Maintainer**: Final decision authority for deadlocks or urgent matters
4. **Community Input**: Consider community feedback for significant changes

### Types of Major Decisions

- **Breaking Changes**: Changes that affect existing functionality
- **New Features**: Significant new capabilities
- **Architecture Changes**: Major structural modifications
- **Policy Changes**: Updates to governance, contribution guidelines, etc.
- **Maintainer Changes**: Adding or removing maintainers

## Emeritus Maintainers

*No emeritus maintainers at this time. This section will be updated as the project evolves.*

*Former maintainers who have made significant contributions will be recognized here, and are always welcome to return to active maintenance.*

## Stepping Down

Maintainers can step down at any time by:
1. Notifying other maintainers of intent
2. Transferring responsibilities and knowledge
3. Removing access permissions
4. Moving to emeritus status (optional)

## Contact Information

For maintainer-specific inquiries or to report issues with the maintenance process:

- **Project Maintainer**: luca@ferrarotti.it
- **GitHub**: [@lferrarotti74](https://github.com/lferrarotti74)
- **Issues**: Use GitHub Issues for project-related matters

---

*This document is reviewed and updated as needed.*

## Acknowledgments

Thanks to all contributors who help make LibHdHomerun-Docker better for the HDHomeRun community. Special recognition goes to Silicondust for creating the original libhdhomerun library that this project containerizes.

*"The best way to find yourself is to lose yourself in the service of others." - Mahatma Gandhi*