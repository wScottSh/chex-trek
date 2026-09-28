# Pinned Linux build toolchain for chex-trek spec #58/#64: MSVC 14.50.35717 (from VS Build Tools
# product version 18.0, ARG MSVC_VERSION below - vsdownload.py's input is the VS product version,
# not the MSVC toolset number; cl itself reports this as "Version 19.50.35739"), x86-only
# target - the same compiler version tools/build-chextrek.sh's Windows branch gets from the
# "Visual Studio 18 2026" generator. The RUN step below fails the image build outright if
# vsdownload.py doesn't land on that toolset (it falls back to "whatever's latest" instead of
# erroring by default) - see that step's comment. The check is toolset-granularity (MSVC 14.50.x,
# i.e. cl reporting 19.50.x - Microsoft ships several compiler point releases within one toolset),
# not byte-for-byte; the rest of this image (Ubuntu base image, apt packages, the msvc-wine commit)
# is a normal, not cryptographically pinned, dependency set.
#
# This image is built once per Unicron setup (tools/msvc-wine/build-image.sh; see
# docs/dev-setup.md's "Unicron (Linux/Wine)" section), then reused by every
# tools/build-chextrek.sh run - it is never rebuilt as part of an ordinary build. Record the
# resulting `docker image inspect --format '{{.Id}}'` digest alongside the version pin when you
# do a setup (spec #64's AC: "the toolchain is pinned (image and MSVC version recorded)").
#
# msvc-wine (https://github.com/mstorsjo/msvc-wine, ISC license) does the actual MSVC
# download/unpack/wine-wrapping; it is a separate upstream project, pinned by commit below and
# fetched at image-build time, not vendored into this repo.
FROM ubuntu:24.04

ARG MSVC_WINE_COMMIT=514f8ea34842cd6d831804d0e9658d3a32870ae1
ARG MSVC_VERSION=18.0
ARG MSVC_ARCH=x86

RUN apt-get update && \
	apt-get install -y wine64 python3 msitools ca-certificates cmake ninja-build winbind git && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*

# Initialize the wine environment once at image-build time so every later `docker run` of this
# image starts from an already-booted wine prefix. `wineserver -w` blocks until the just-started
# wineserver exits, so the layer never closes over a half-written prefix; wrapped in `timeout` so
# a wedged wineserver fails the image build instead of hanging it forever.
RUN $(command -v wine64 || command -v wine || false) wineboot --init && \
	timeout 120 wineserver -w

ADD https://github.com/mstorsjo/msvc-wine/archive/${MSVC_WINE_COMMIT}.tar.gz /tmp/msvc-wine.tar.gz
RUN mkdir -p /opt/msvc-wine-src && \
	tar -xzf /tmp/msvc-wine.tar.gz --strip-components=1 -C /opt/msvc-wine-src && \
	rm /tmp/msvc-wine.tar.gz

# Downloads and unpacks the pinned MSVC/WinSDK (x86 host+target only - this repo never needs
# x64/ARM), then wraps it with wine-invoking cl/link/lib/etc scripts under /opt/msvc/bin/x86.
# --accept-license: downloading VS Build Tools components requires accepting Microsoft's license
# terms (https://go.microsoft.com/fwlink/?LinkId=2327714 at the time of pinning). Per spec #64's
# AC, the owner must confirm this use is acceptable before this lands - see docs/dev-setup.md and
# record that confirmation on the #64 PR, not here.
RUN PYTHONUNBUFFERED=1 /opt/msvc-wine-src/vsdownload.py --accept-license \
		--msvc-version "${MSVC_VERSION}" --architecture "${MSVC_ARCH}" --dest /opt/msvc && \
	/opt/msvc-wine-src/install.sh /opt/msvc && \
	rm -rf /opt/msvc-wine-src

# vsdownload.py falls back to "whatever's latest" (silently) if the pinned MSVC_VERSION isn't in
# the manifest it fetches live from Microsoft at build time, instead of failing - guard against
# that quietly drifting this "pinned" image onto a different compiler. `cl` itself is a wine
# invocation (msvc-wine's wrapper script); `wineserver -w` waits for it to exit after, same as the
# wineboot step above, or this layer can close with an unflushed prefix. Wrapped in `timeout` so a
# wedged wineserver fails the build instead of hanging it forever - its exit status is captured and
# checked explicitly (not just `&&`-chained) because `cl` with no args, run above to get its version
# banner, always exits non-zero itself, so this whole RUN is deliberately `;`-joined rather than
# `&&`-joined up to that point.
RUN CL_VERSION="$(/opt/msvc/bin/x86/cl 2>&1)"; \
	timeout 120 wineserver -w; WINESERVER_STATUS=$?; \
	echo "$CL_VERSION" | grep -qE "Version 19\.50\." || \
	(echo "error: expected MSVC 14.50.x (cl reporting Version 19.50.x), got:" >&2 && \
	 echo "$CL_VERSION" >&2 && exit 1); \
	[ "$WINESERVER_STATUS" -eq 0 ] || \
	(echo "error: wineserver -w timed out after checking the cl version - wedged wine prefix" >&2 && exit 1)

ENV PATH="/opt/msvc/bin/x86:${PATH}"
