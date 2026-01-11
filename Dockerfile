# vim: ft=dockerfile

FROM alpine:3 AS stage

# Define an optional build argument to invalidate cache
ARG CACHEBUST=1

# ZeroTier version - Updated to 1.14.2 to support tcpPort configuration in local.conf
ARG VERSION=1.14.2 //Default value provided

RUN apk --no-cache update && apk --no-cache upgrade \
    && apk --no-cache --update add alpine-sdk clang git linux-headers make \
    && rm -rf /var/cache/apk/* \
    && git clone -b "${VERSION}" --depth 1 https://github.com/zerotier/ZeroTierOne.git
WORKDIR /ZeroTierOne/tcp-proxy

COPY tcp-proxy/patchMakefile.patch patchMakefile.patch
COPY tcp-proxy/patchTcpProxy.patch patchTcpProxy.patch

RUN export VER=$(echo "$VERSION" | sed 's/\.//g'); \
    if [ "$VER" -lt "1140" ]; then \
        patch --verbose -u Makefile -i patchMakefile.patch; \
        sed -i 's|^#include <bits/types.h>|#include <sys/types.h>|' tcp-proxy.cpp; \
        /usr/bin/make -j$(nproc); \
    else \
        patch --verbose -u tcp-proxy.cpp -i patchTcpProxy.patch; \
        sed -i 's|^#include <bits/types.h>|#include <sys/types.h>|' tcp-proxy.cpp; \
        /usr/bin/make -j$(nproc); \
    fi

FROM alpine:3

# Define an optional build argument to invalidate cache
ARG CACHEBUST=1

# ZeroTier version - Updated to 1.14.2 to support tcpPort configuration in local.conf
ARG VERSION=1.14.2 //Default value provided

LABEL org.opencontainers.image.title="zerotier-proxy" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.description="ZeroTier Proxy as Docker Image" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/lferrarotti74/ZeroTierOne-Proxy"

COPY --from=stage /ZeroTierOne/tcp-proxy/tcp-proxy /usr/sbin

RUN echo "${VERSION}" > /etc/zerotier-version \
    && rm -rf /var/lib/zerotier-one \
    && apk --no-cache update \
    && apk --no-cache upgrade \
    && apk --no-cache --update add \
        fping \
        iproute2 \
        iputils-arping \
        iputils-ping \
        jq \
        libgcc \
        libstdc++ \
        mtr \
        musl \
        net-tools \
        netcat-openbsd \
        procps \
    && rm -rf /var/cache/apk/* \
    && rm -rf /sbin/apk \
    && rm -rf /etc/apk \
    && rm -f /usr/bin/wget \
    && addgroup -S zerotier \
    && adduser -S zerotier -G zerotier -h /var/lib/zerotier-one -g "zerotier" \
    && echo "export HISTFILE=/dev/null" >> /etc/profile

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/healthcheck.sh /healthcheck.sh

RUN chmod 755 /entrypoint.sh \
    && chmod 755 /healthcheck.sh

EXPOSE 443/tcp
USER zerotier

# Define a custom healthcheck command
HEALTHCHECK --interval=60s --timeout=5s --retries=3 CMD [ "/healthcheck.sh" ]

# Start the entrypoint script for the container image
ENTRYPOINT ["/entrypoint.sh"]

CMD []
