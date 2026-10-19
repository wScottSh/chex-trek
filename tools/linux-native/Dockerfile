# Pinned native-Linux (x86_64) build toolchain for chex-trek: gcc 11 and the SDL2/OpenAL/zlib dev
# packages of Ubuntu 22.04. tools/build-chextrek.sh (CHEXTREK_PLATFORM=native) builds chextrek.so
# in it and tools/linux-native/build-engine.sh builds the dhewm3 1.5.5 engine in it, so the harness
# tests exactly what tools/package-linux.sh ships. Building on 22.04 rather than on the host is what
# sets the shipped binaries' glibc floor: they only reference glibc <= 2.35 symbols, so they run on
# Ubuntu 22.04, Debian 12, Fedora 36 and anything newer. A host build (Ubuntu 26.04, glibc 2.43)
# would refuse to start on all of those. The base image is pinned by digest; the apt packages are
# a normal, not cryptographically pinned, dependency set.
#
# It also builds the two shared libraries the AppImage bundles, SDL2 and OpenAL Soft, from pinned,
# checksummed upstream release tarballs into /opt/chextrek-libs. Ubuntu's own builds of both link
# X11, Wayland, PulseAudio, libdecor, sndio and more as hard dependencies, so bundling those would
# fail to start on any system missing one. Upstream's default builds dlopen every video/audio
# backend at runtime instead, so the bundled copies need nothing beyond glibc and libstdc++ and
# use whatever X11/Wayland/PipeWire/PulseAudio/ALSA the player's system has. The dev headers below
# are what lets those backends be compiled in at all.
#
# Built once per machine with tools/linux-native/build-image.sh (see docs/dev-setup.md).
FROM ubuntu:22.04@sha256:0a9887931b0e38af2e3487ed39e29436b0535c4f3f52e57745baaf79d1898956

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		g++ cmake ninja-build libsdl2-dev libopenal-dev zlib1g-dev \
		ca-certificates curl bzip2 libpipewire-0.3-dev && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*

ARG SDL2_VERSION=2.32.10
ARG SDL2_SHA256=5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165
ARG OPENAL_VERSION=1.24.3
ARG OPENAL_SHA256=cb5e6197a1c0da0edcf2a81024953cc8fa8545c3b9474e48c852af709d587892

RUN mkdir -p /tmp/libs /opt/chextrek-libs && cd /tmp/libs && \
	curl -fsSLo sdl2.tar.gz "https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz" && \
	echo "${SDL2_SHA256}  sdl2.tar.gz" | sha256sum -c - && \
	curl -fsSLo openal.tar.bz2 "https://github.com/kcat/openal-soft/releases/download/${OPENAL_VERSION}/openal-soft-${OPENAL_VERSION}.tar.bz2" && \
	echo "${OPENAL_SHA256}  openal.tar.bz2" | sha256sum -c - && \
	tar xf sdl2.tar.gz && tar xf openal.tar.bz2 && \
	cmake -S "SDL2-${SDL2_VERSION}" -B sdl2-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
		-DSDL_STATIC=OFF -DSDL_TEST=OFF && \
	cmake --build sdl2-build && \
	cmake -S "openal-soft-${OPENAL_VERSION}" -B openal-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
		-DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF && \
	cmake --build openal-build && \
	cp -L sdl2-build/libSDL2-2.0.so.0 openal-build/libopenal.so.1 /opt/chextrek-libs/ && \
	strip --strip-unneeded /opt/chextrek-libs/*.so.* && \
	cp "SDL2-${SDL2_VERSION}/LICENSE.txt" /opt/chextrek-libs/LICENSE.SDL2.txt && \
	cp "openal-soft-${OPENAL_VERSION}/COPYING" /opt/chextrek-libs/LICENSE.openal-soft.txt && \
	cd / && rm -rf /tmp/libs
