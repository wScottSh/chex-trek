# Pinned native-Linux (x86_64) build toolchain for chex-trek: gcc 11 and the SDL2/OpenAL/zlib dev
# packages of Ubuntu 22.04. tools/build-chextrek.sh (CHEXTREK_PLATFORM=native) builds chextrek.so
# in it and tools/linux-native/build-engine.sh builds the dhewm3 1.5.5 engine in it, so the harness
# tests exactly what tools/package-linux.sh ships. Building on 22.04 rather than on the host is what
# sets the shipped binaries' glibc floor: they only reference glibc <= 2.35 symbols, so they run on
# Ubuntu 22.04, Debian 12, Fedora 36 and anything newer. A host build (Ubuntu 26.04, glibc 2.43)
# would refuse to start on all of those. The base image is pinned by digest; the apt packages are
# a normal, not cryptographically pinned, dependency set.
#
# Built once per machine with tools/linux-native/build-image.sh (see docs/dev-setup.md).
FROM ubuntu:22.04@sha256:0a9887931b0e38af2e3487ed39e29436b0535c4f3f52e57745baaf79d1898956

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		g++ cmake ninja-build libsdl2-dev libopenal-dev zlib1g-dev && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*
