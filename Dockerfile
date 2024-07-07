# vim: ft=dockerfile

FROM debian:stable-backports as stage

ARG VERSION=1.12.0 //Default value provided

RUN apt-get update -qq && apt-get upgrade -qq && apt-get -qq install make clang git -y \
    && git clone -b ${VERSION} --depth 1 https://github.com/zerotier/ZeroTierOne.git
WORKDIR /ZeroTierOne/tcp-proxy

COPY tcp-proxy/patchMakefile.patch patchMakefile.patch

RUN export VER=$(echo "$VERSION" | sed 's/\.//g'); \
    if [ "$VER" -lt "1140" ]; then \
        patch --verbose -u Makefile -i patchMakefile.patch ; /usr/bin/make -j$(nproc) ; \
    else \
        /usr/bin/make -j$(nproc) ; \
    fi
RUN cp tcp-proxy /usr/sbin

FROM debian:stable-backports

ARG VERSION=1.12.0 //Default value provided

COPY --from=stage /ZeroTierOne/tcp-proxy/tcp-proxy /usr/sbin

RUN echo "${VERSION}" > /etc/zerotier-version \
    && rm -rf /var/lib/zerotier-one \
    && apt-get -qq update && apt-get upgrade -qq \
    && apt-get -qq install iproute2 net-tools fping 2ping iputils-ping iputils-arping procps jq netcat-openbsd -y

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod 755 /entrypoint.sh
RUN chmod 755 /healthcheck.sh

# Define a custom healthcheck command
HEALTHCHECK --interval=60s --timeout=5s --retries=3 CMD [ "/healthcheck.sh" ]

CMD []
ENTRYPOINT ["/entrypoint.sh"]