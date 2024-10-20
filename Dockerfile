# vim: ft=dockerfile

FROM alpine:latest AS stage

ARG VERSION=1.12.0 //Default value provided

RUN apk --no-cache update && apk --no-cache upgrade \
    && apk --no-cache --update add alpine-sdk linux-headers make clang git \
    && git clone -b ${VERSION} --depth 1 https://github.com/zerotier/ZeroTierOne.git
WORKDIR /ZeroTierOne/tcp-proxy

COPY tcp-proxy/patchMakefile.patch patchMakefile.patch

RUN export VER=$(echo "$VERSION" | sed 's/\.//g'); \
    if [ "$VER" -lt "1140" ]; then \
        patch --verbose -u Makefile -i patchMakefile.patch ; sed -i 's|^#include <bits/types.h>|#include <sys/types.h>|' tcp-proxy.cpp ; /usr/bin/make -j$(nproc) ; \
    else \
        sed -i 's|^#include <bits/types.h>|#include <sys/types.h>|' tcp-proxy.cpp ; /usr/bin/make -j$(nproc) ; \
    fi

FROM alpine:latest

ARG VERSION=1.12.0 //Default value provided

LABEL org.opencontainers.image.title="zerotier-proxy" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.description="ZeroTier Proxy as Docker Image" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/lferrarotti74/ZeroTierOne-Proxy"

COPY --from=stage /ZeroTierOne/tcp-proxy/tcp-proxy /usr/sbin

RUN echo "${VERSION}" > /etc/zerotier-version \
    && rm -rf /var/lib/zerotier-one \
    && apk --no-cache update && apk --no-cache upgrade \
    && apk --no-cache --update add iproute2 net-tools fping iputils-ping iputils-arping procps jq netcat-openbsd mtr musl libstdc++ libgcc

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/healthcheck.sh /healthcheck.sh

RUN chmod 755 /entrypoint.sh ; chmod 755 /healthcheck.sh

# Define a custom healthcheck command
HEALTHCHECK --interval=60s --timeout=5s --retries=3 CMD [ "/healthcheck.sh" ]

EXPOSE 443/tcp

ENTRYPOINT ["/entrypoint.sh"]

CMD []