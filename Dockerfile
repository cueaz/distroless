ARG PYTHON_BRANCH=3.11

FROM clearlinux AS builder-base

RUN set -eux; \
    swupd update --no-boot-update; \
    swupd bundle-add mixer c-basic diffutils --no-boot-update;

FROM builder-base AS builder-repo

RUN set -eux; \
    source /usr/lib/os-release; \
    # Customize bundles
    mkdir /repo; \
    pushd /repo; \
    mixer init --no-default-bundles --mix-version "$VERSION_ID"; \
    mixer bundle add os-core; \
    mixer bundle edit os-core; \
    printf '\
glibc-lib-avx2\n\
libgcc1\n\
netbase-data\n\
tzdata-minimal\n\
' > local-bundles/os-core; \
#     mixer bundle add os-core-plus; \
#     mixer bundle edit os-core-plus; \
#     printf '\
# ncurses-data\n\
# ' > local-bundles/os-core-plus; \
    sed -i 's/os-core-update/os-core/' builder.conf; \
    mixer build all; \
    popd;

FROM builder-repo AS builder-core

RUN set -eux; \
    source /usr/lib/os-release; \
    # Install os-core
    mkdir /install_root; \
    swupd os-install --version "$VERSION_ID" \
                     --path /install_root \
                     --statedir /swupd-state \
                     --bundles os-core \
                     --no-boot-update \
                     --no-scripts \
                     --url file:///repo/update/www \
                     --certpath /repo/Swupd_Root.pem; \
    # Print contents
    find /install_root;

FROM builder-core AS builder-cc

RUN set -eux; \
    # Strip out unnecessary files
    find /install_root -name clear -exec rm -rv {} +; \
    find /install_root -name swupd -exec rm -rv {} +; \
    find /install_root -name package-licenses -exec rm -rv {} +; \
    rmdir /install_root/{autofs,boot,media,mnt,srv}; \
    # Add CA certs
    CLR_TRUST_STORE=certs clrtrust generate; \
    install -d /install_root/etc/ssl/certs; \
    install -D -m 644 certs/anchors/ca-certificates.crt /install_root/etc/ssl/certs/ca-certificates.crt; \
    # Create passwd/group files (from distroless, without staff)
    printf '\
root:x:0:0:root:/root:/sbin/nologin\n\
nobody:x:65534:65534:nobody:/nonexistent:/sbin/nologin\n\
nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin\n\
' > /install_root/etc/passwd; \
    printf '\
root:x:0:\n\
nobody:x:65534:\n\
tty:x:5:\n\
nonroot:x:65532:\n\
' > /install_root/etc/group; \
    install -d -m 700 -g 65532 -o 65532 /install_root/home/nonroot; \
    # Print contents
    find /install_root; \
    cat /install_root/etc/passwd; \
    cat /install_root/etc/group; \
    cat /install_root/usr/lib/os-release;

FROM scratch AS cc-latest

COPY --from=builder-cc /install_root /
WORKDIR /root

FROM cc-latest AS cc-debug

COPY --from=busybox:musl /bin /bin/
CMD ["sh"]

FROM cc-latest AS cc-nonroot

USER nonroot
WORKDIR /home/nonroot

FROM cc-debug AS cc-debug-nonroot

USER nonroot
WORKDIR /home/nonroot

FROM builder-base AS builder-python

# Official go distribution
COPY --from=golang /usr/local/go /usr/local/go

RUN set -eux; \
    # Install pythop dependencies (no readline/gdbm)
    mkdir /deps; \
    pushd /deps; \
    export CFLAGS="$CFLAGS -flto=auto"; \
    makeopts="-j$(cat /proc/cpuinfo | grep processor | wc -l)"; \
    # Install bzip2 strip? pic?
    git clone --depth 1 https://sourceware.org/git/bzip2; \
    pushd bzip2; \
    make "$makeopts" install CFLAGS="$CFLAGS" LDFLAGS="${LDFLAGS:-}" PREFIX=/usr/local; \
    popd; \
    # Install zlib
    git clone --depth 1 https://github.com/madler/zlib; \
    pushd zlib; \
    ./configure --static --prefix=/usr/local; \
    make "$makeopts" install; \
    popd; \
    # Install xz
    xz_branch="$(curl https://api.github.com/repos/tukaani-project/xz/tags | jq -r '.[].name' | grep '[0-9]$' | sort -V | tail -1 | cut -d. -f1,2)"; \
    git clone --depth 1 --branch "$xz_branch" https://github.com/tukaani-project/xz; \
    pushd xz; \
    ./autogen.sh; \
    ./configure --disable-shared --prefix=/usr/local \
                                 --disable-xz \
                                 --disable-xzdec \
                                 --disable-lzmadec \
                                 --disable-lzmainfo \
                                 --disable-lzma-links \
                                 --disable-scripts \
                                 --disable-doc; \
    make "$makeopts" install ; \
    popd; \
    # Install ffi
    git clone --depth 1 https://github.com/libffi/libffi; \
    pushd libffi; \
    ./autogen.sh; \
    ./configure --disable-shared --prefix=/usr/local \
                                 --disable-multi-os-directory \
                                 --disable-docs; \
    make "$makeopts" install; \
    popd; \
    # Install boringssl
    git clone --depth 1 https://boringssl.googlesource.com/boringssl; \
    pushd boringssl; \
    mkdir build; \
    pushd build; \
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DCMAKE_BUILD_TYPE=Release \
             -DGO_EXECUTABLE=/usr/local/go/bin/go; \
    make "$makeopts" install; \
    rm -rf /usr/local/go; \
    popd; \
    popd; \
    # Install sqlite
    git clone --depth 1 https://github.com/sqlite/sqlite; \
    pushd sqlite; \
    ./configure --disable-shared --prefix=/usr/local; \
    make "$makeopts" install; \
    popd; \
    # Install uuid
    git clone --depth 1 https://git.kernel.org/pub/scm/utils/util-linux/util-linux; \
    pushd util-linux; \
    ./autogen.sh; \
    ./configure --disable-shared --prefix=/usr/local \
                                 --disable-all-programs \
                                 --enable-libuuid; \
    make "$makeopts" install; \
    popd; \
    # Print contents
    find /usr/local; \
    # Install python
    # Print contents
    popd;
