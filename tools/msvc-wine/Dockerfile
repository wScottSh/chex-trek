# Pinned Linux build toolchain for chex-trek spec #58/#64: MSVC 14.50.18.0 (VS 18), x86-only
# target - the same compiler version tools/build-chextrek.sh's Windows branch gets from the
# "Visual Studio 18 2026" generator. Rebuilding this image later reproduces the same compiler
# byte-for-byte (the MSVC/SDK version is pinned below, not "whatever's current").
#
# This image is built once per Unicron setup (tools/msvc-wine/build-image.sh; see
# docs/dev-setup.md's "Unicron (Linux/Wine)" section), then reused by every
# tools/build-chextrek.sh run - it is never rebuilt as part of an ordinary build.
#
# msvc-wine (https://github.com/mstorsjo/msvc-wine, ISC license) does the actual MSVC
# download/unpack/wine-wrapping; it is a separate upstream project, pinned by commit below and
# fetched at image-build time, not vendored into this repo.
FROM ubuntu:24.04

ARG MSVC_WINE_COMMIT=514f8ea34842cd6d831804d0e9658d3a32870ae1
ARG MSVC_VERSION=18.0
ARG MSVC_ARCH=x86

RUN apt-get update && \
	apt-get install -y wine64 python3 msitools ca-certificates cmake ninja-build winbind && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*

# Initialize the wine environment once at image-build time so every later `docker run` of this
# image starts from an already-booted wine prefix. Wait for wineserver to exit before the layer
# closes, or the prefix can end up corrupted.
RUN $(command -v wine64 || command -v wine || false) wineboot --init && \
	while pgrep wineserver > /dev/null; do sleep 1; done

ADD https://github.com/mstorsjo/msvc-wine/archive/${MSVC_WINE_COMMIT}.tar.gz /tmp/msvc-wine.tar.gz
RUN mkdir -p /opt/msvc-wine-src && \
	tar -xzf /tmp/msvc-wine.tar.gz --strip-components=1 -C /opt/msvc-wine-src && \
	rm /tmp/msvc-wine.tar.gz

# Downloads and unpacks the pinned MSVC/WinSDK (x86 host+target only - this repo never needs
# x64/ARM), then wraps it with wine-invoking cl/link/lib/etc scripts under /opt/msvc/bin/x86.
# --accept-license: see docs/dev-setup.md - the owner has confirmed VS Build Tools' license
# terms allow this use (https://go.microsoft.com/fwlink/?LinkId=2327714 at the time of pinning).
RUN PYTHONUNBUFFERED=1 /opt/msvc-wine-src/vsdownload.py --accept-license \
		--msvc-version "${MSVC_VERSION}" --architecture "${MSVC_ARCH}" --dest /opt/msvc && \
	/opt/msvc-wine-src/install.sh /opt/msvc && \
	rm -rf /opt/msvc-wine-src

ENV PATH="/opt/msvc/bin/x86:${PATH}"
