FROM ubuntu:18.04 as build
RUN apt-get update && apt-get install -y \
    autoconf \
    autoconf-archive \
    automake \
    build-essential \
    doxygen \
    g++ \
    gcc \
    git \
    gnulib \
    libtool \
    m4 \
    net-tools \
    pkg-config \
    wget \
    libcmocka0 \
    libcmocka-dev \
    libgcrypt20-dev \
    libtool \
    liburiparser-dev \
    uthash-dev \
    autoconf \
    automake \
    libtool \
    gcc \
    libcurl4-gnutls-dev \
    python \
    python-yaml


# OpenSSL
RUN git clone https://github.com/openssl/openssl.git /tmp/openssl
WORKDIR /tmp/openssl
RUN git checkout OpenSSL_1_1_1 \
	&& ./config --prefix=/out --openssldir=/out \
	&& make -j$(nproc) \
	&& make install prefix=/out \
	&& openssl version

# IBM's Software TPM 2.0
ARG ibmtpm_name=ibmtpm1332
WORKDIR /tmp
RUN wget --quiet --show-progress --progress=dot:giga "https://downloads.sourceforge.net/project/ibmswtpm2/$ibmtpm_name.tar.gz" \
	&& sha256sum $ibmtpm_name.tar.gz | grep ^8e8193af3d11d9ff6a951dda8cd1f4693cb01934a8ad7876b84e92c6148ab0fd \
	&& mkdir -p $ibmtpm_name \
	&& tar xvf $ibmtpm_name.tar.gz -C $ibmtpm_name \
	&& rm $ibmtpm_name.tar.gz
WORKDIR $ibmtpm_name/src
RUN sed -i 's|CCFLAGS\s=\s|CCFLAGS = $(CFLAGS) |g;s|LNFLAGS\s=\s|LNFLAGS = $(LDFLAGS) |g' makefile \
	&& CFLAGS="-I/out/include" LDFLAGS="-L/out/lib" make -j$(nproc) \
	&& cp tpm_server /out/bin

# TPM2-TSS
RUN git clone https://github.com/tpm2-software/tpm2-tss.git /tmp/tpm2-tss
WORKDIR /tmp/tpm2-tss
RUN git checkout 2.0.0 \
	&& ./bootstrap -I /usr/share/gnulib/m4 \
	&& ./configure --prefix=/out \
	&& make -j$(nproc) \
	&& make install prefix=/out \
	&& ldconfig

# TPM2-tools
RUN git clone https://github.com/tpm2-software/tpm2-tools.git /tmp/tpm2-tools
WORKDIR /tmp/tpm2-tools
RUN git checkout 3.1.0 \
        && ./bootstrap -I /usr/share/gnulib/m4 \
        && ./configure --prefix=/out PKG_CONFIG_PATH=/out/lib/pkgconfig CFLAGS=-Wno-unused-value \
        && make -j$(nproc) \
        && make install prefix=/out \
        && ldconfig

# we need busybox to run chmod, chown, touch, etc.
RUN apt-get install -y busybox \
	&& mkdir -p /out/var/lib/tpm \
	&& mkdir -p /out/etc \
	&& cp /bin/busybox /out/bin \
	&& ln -s /bin/busybox /out/bin/sh

FROM ubuntu:18.04
WORKDIR /
COPY --from=build /out /

CMD ["/bin/tpm_server"]
