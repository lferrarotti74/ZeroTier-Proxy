# ZeroTier-Proxy

[![GitHub CI](https://github.com/lferrarotti74/ZeroTier-Proxy/workflows/Build%20release%20image/badge.svg)](https://github.com/lferrarotti74/ZeroTier-Proxy/actions/workflows/build.yml)
[![Unit Tests](https://github.com/lferrarotti74/ZeroTier-Proxy/actions/workflows/tests.yml/badge.svg)](https://github.com/lferrarotti74/ZeroTier-Proxy/actions/workflows/tests.yml)
[![Release](https://img.shields.io/github/v/release/lferrarotti74/ZeroTier-Proxy)](https://github.com/lferrarotti74/ZeroTier-Proxy/releases)
[![Docker Hub](https://img.shields.io/docker/pulls/lferrarotti74/zerotier-proxy)](https://hub.docker.com/r/lferrarotti74/zerotier-proxy)
[![Docker Image Size](https://img.shields.io/docker/image-size/lferrarotti74/zerotier-proxy/latest)](https://hub.docker.com/r/lferrarotti74/zerotier-proxy)
[![GitHub](https://img.shields.io/github/license/lferrarotti74/ZeroTier-Proxy)](LICENSE)

<!-- SonarQube Badges -->
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=lferrarotti74_ZeroTier-Proxy&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=lferrarotti74_ZeroTier-Proxy)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=lferrarotti74_ZeroTier-Proxy&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=lferrarotti74_ZeroTier-Proxy)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=lferrarotti74_ZeroTier-Proxy&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=lferrarotti74_ZeroTier-Proxy)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=lferrarotti74_ZeroTier-Proxy&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=lferrarotti74_ZeroTier-Proxy)

A Docker container for the [ZeroTier TCP Proxy](https://github.com/zerotier/ZeroTierOne/tree/dev/tcp-proxy), designed to help ZeroTier peers behind difficult NATs establish connections. This containerized TCP relay server reduces latency and improves connectivity for ZeroTier networks in challenging network environments.

## What is ZeroTier TCP Proxy?

The ZeroTier TCP Proxy is a specialized relay server that helps ZeroTier peers behind difficult NATs (Network Address Translation) establish connections. <mcreference link="https://github.com/zerotier/ZeroTierOne/tree/dev/tcp-proxy" index="0">0</mcreference> When UDP traffic is blocked or heavily restricted, the TCP proxy provides an alternative path for ZeroTier traffic, ensuring network connectivity even in challenging network environments.

Key features include:
- **NAT Traversal**: Helps peers behind restrictive NATs connect to ZeroTier networks
- **TCP Fallback**: Provides TCP-based connectivity when UDP is blocked
- **Low Latency**: Optimized for minimal latency when deployed close to served nodes
- **Enterprise-Friendly**: Works in corporate environments with strict firewall rules
- **Transparent Operation**: Automatically used by ZeroTier clients when needed

## ⚠️ Important Licensing Information

**Current Version**: This Docker image is based on **ZeroTier One v1.14.2**, which is available under the BSL (Business Source License) v1.1.

**Future Considerations**: When upgrading to **ZeroTier One v1.16.0** and later versions, please note:
- The ZeroTier controller functionality has additional **commercial use restrictions**
- **Non-commercial use** remains free for businesses, academic institutions, and personal use
- **Commercial use** of the controller (such as offering ZeroTier network management as a SaaS service) requires a commercial license
- **TCP Proxy functionality** remains freely available for all use cases

For detailed licensing information, please refer to:
- [ZeroTier Pricing Page](https://www.zerotier.com/pricing/)
- [Original ZeroTier Repository](https://github.com/zerotier/ZeroTierOne)
- [LICENSE](LICENSE) in this repository

## Quick Start

### Pull the Docker Image

```bash
docker pull lferrarotti74/zerotier-proxy:latest
```

### Run the TCP Proxy Server

```bash
# Run ZeroTier TCP Proxy server
docker run -d --name zerotier-proxy --restart unless-stopped \
  -p 8443:8443 \
  -e ZT_TCP_PORT=8443 \
  lferrarotti74/zerotier-proxy:latest

# Check if the proxy is running
docker logs zerotier-proxy
```

### Configure ZeroTier Clients to Use Your Proxy

#### Option 1: local.conf Configuration

Create or edit `/var/lib/zerotier-one/local.conf` on your ZeroTier clients:

```json
{
  "settings": {
    "tcpFallbackRelay": "YOUR_PROXY_SERVER_IP/8443",
    "forceTcpRelay": true
  }
}
```

#### Option 2: Network-Level Redirect (Enterprise)

If you control the network infrastructure, redirect the default ZeroTier TCP relay:

```bash
# Example iptables rules (adjust for your environment)
iptables -t nat -A PREROUTING -p tcp -d 204.80.128.1 --dport 443 -j DNAT --to-destination YOUR_PROXY_SERVER_IP:8443
iptables -t nat -A POSTROUTING -p tcp -d YOUR_PROXY_SERVER_IP --dport 8443 -j SNAT --to-source 204.80.128.1
```

## Usage Examples

### Basic TCP Proxy Operations

```bash
# Check proxy status and logs
docker logs zerotier-proxy

# Monitor proxy connections
docker exec zerotier-proxy netstat -tlnp

# View proxy configuration
docker exec zerotier-proxy cat /var/lib/zerotier-one/local.conf

# Restart the proxy service
docker restart zerotier-proxy
```

### Advanced Configuration

```bash
# Run with custom port
docker run -d --name zerotier-proxy --restart unless-stopped \
  -p 9443:9443 \
  -e ZT_TCP_PORT=9443 \
  lferrarotti74/zerotier-proxy:latest

# Run with resource limits
docker run -d --name zerotier-proxy --restart unless-stopped \
  -p 8443:8443 \
  -e ZT_TCP_PORT=8443 \
  --memory=256m \
  --cpus=0.5 \
  lferrarotti74/zerotier-proxy:latest

# Run with custom configuration
docker run -d --name zerotier-proxy --restart unless-stopped \
  -p 8443:8443 \
  -v zerotier-proxy:/var/lib/zerotier-one \
  -e ZT_TCP_PORT=8443 \
  lferrarotti74/zerotier-proxy:latest
```

### Testing Connectivity

```bash
# Test if the proxy is accessible
telnet YOUR_PROXY_SERVER_IP 8443

# Check proxy from ZeroTier client
zerotier-cli info
zerotier-cli peers
```

### Using with Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  zerotier-proxy:
    image: lferrarotti74/zerotier-proxy:latest
    hostname: zerotier-proxy
    container_name: zerotier-proxy
    restart: unless-stopped
    volumes:
      - zerotier-proxy:/var/lib/zerotier-one
    networks:
      - zerotier-proxy
    ports:
      - "8443:8443/tcp"
    environment:
      - ZT_OVERRIDE_LOCAL_CONF=true
      - ZT_TCP_PORT=8443
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'

volumes:
  zerotier-proxy:

networks:
  zerotier-proxy:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.31.251.8/29
```

Run with:

```bash
docker-compose up -d
```

### Interactive Usage

For debugging and monitoring, you can access the container:

```bash
docker exec -it zerotier-proxy /bin/bash
```

Then inside the container:

```bash
# Check proxy process
ps aux | grep tcp-proxy

# Monitor network connections
netstat -tlnp

# View logs
docker logs zerotier-proxy
```

## Available Commands

The TCP proxy server provides several management capabilities:

### Container Management
- `docker logs zerotier-proxy` - View proxy logs and status
- `docker restart zerotier-proxy` - Restart the proxy service
- `docker exec zerotier-proxy <command>` - Execute commands inside the container

### Monitoring Commands
- `netstat -tlnp` - Show listening ports and connections
- `ps aux | grep tcp-proxy` - Check proxy process status
- `docker logs zerotier-proxy` - Monitor real-time logs

### Configuration Commands
- `cat /var/lib/zerotier-one/local.conf` - View proxy configuration
- `systemctl status tcp-proxy` - Check service status (if using systemd)

## Network Requirements

- **Port Access**: TCP port 8443 (or custom port) must be accessible from the internet
- **Firewall Rules**: Ensure incoming TCP connections are allowed on the proxy port
- **Network Placement**: Deploy as close as possible to the nodes it will serve for optimal latency
- **Internet Connectivity**: Stable internet connection for relay functionality
- **Resource Requirements**: Minimal CPU and memory (typically <256MB RAM, <0.5 CPU cores)

## Network Configuration

### Optimal Deployment

**Location Considerations:**
- Deploy in the same datacenter or city as your ZeroTier nodes
- Use cloud providers with good network connectivity
- Consider multiple proxy instances for redundancy

**Performance Tuning:**
```bash
# Run with performance optimizations
docker run -d --name zerotier-proxy --restart unless-stopped \
  -p 8443:8443 \
  -e ZT_TCP_PORT=8443 \
  --memory=512m \
  --cpus=1.0 \
  --ulimit nofile=65536:65536 \
  lferrarotti74/zerotier-proxy:latest
```

### Client Configuration Examples

**Force TCP Relay for Testing:**
```json
{
  "settings": {
    "tcpFallbackRelay": "your-proxy-server.com/8443",
    "forceTcpRelay": true
  }
}
```

**Automatic Fallback (Recommended):**
```json
{
  "settings": {
    "tcpFallbackRelay": "your-proxy-server.com/8443"
  }
}
```

## Building from Source

To build the Docker image yourself:

```bash
git clone https://github.com/lferrarotti74/ZeroTier-Proxy.git
cd ZeroTier-Proxy
docker build -t zerotier-proxy .
```

## Documentation

- **[Contributing Guidelines](CONTRIBUTING.md)** - How to contribute to the project
- **[Code of Conduct](CODE_OF_CONDUCT.md)** - Community standards and behavior expectations
- **[Security Policy](SECURITY.md)** - How to report security vulnerabilities
- **[Changelog](CHANGELOG.md)** - Version history and release notes
- **[Maintainers](MAINTAINERS.md)** - Project governance and maintainer information
- **[Authors](AUTHORS.md)** - Contributors and acknowledgments

## Contributing

We welcome contributions from the community! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

- **Bug Reports**: Use GitHub issues with detailed information
- **Feature Requests**: Propose enhancements via GitHub issues
- **Code Contributions**: Fork, create feature branch, and submit PR
- **Documentation**: Help improve docs and examples

Please follow our [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.

## Support

For issues related to this Docker container, please open an issue on [GitHub](https://github.com/lferrarotti74/ZeroTier-Proxy/issues).

For ZeroTier-specific support, please refer to:
- [ZeroTier Documentation](https://docs.zerotier.com/)
- [ZeroTier Community Forum](https://discuss.zerotier.com/)
- [Original ZeroTier Repository](https://github.com/zerotier/ZeroTierOne)
- [TCP Proxy Documentation](https://github.com/zerotier/ZeroTierOne/tree/dev/tcp-proxy)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Important License Information:**
- This Docker container and its configuration are MIT licensed
- The ZeroTier TCP Proxy functionality is **free for all use cases** (commercial and non-commercial)
- ZeroTier One client (v1.14.2) is currently under BSL v1.1 license
- Future ZeroTier versions (1.16.0+) may have commercial restrictions, but TCP Proxy remains free

For the most current licensing information, please refer to:
- [ZeroTier Licensing FAQ](https://www.zerotier.com/pricing/)
- [ZeroTier One Repository](https://github.com/zerotier/ZeroTierOne)

## Related Links

- **[Original ZeroTier Repository](https://github.com/zerotier/ZeroTierOne)** - The source ZeroTier One project
- **[ZeroTier Official Website](https://www.zerotier.com/)** - Official ZeroTier website and services
- **[ZeroTier Documentation](https://docs.zerotier.com/)** - Comprehensive ZeroTier documentation
- **[ZeroTier Pricing](https://www.zerotier.com/pricing/)** - Licensing and pricing information
- **[Docker Hub Repository](https://hub.docker.com/r/lferrarotti74/zerotier)** - Pre-built Docker images

## Acknowledgments

- **ZeroTier, Inc.** for developing the ZeroTier protocol and TCP Proxy functionality
- **ZeroTier Community** for continuous support and feedback
- **Docker Community** for containerization best practices
- **GitHub** for hosting and CI/CD infrastructure
- **Docker Hub** for image distribution

---

**Maintainer:** Luca Ferrarotti (luca@ferrarotti.it)  
**Last Updated:** January 2025