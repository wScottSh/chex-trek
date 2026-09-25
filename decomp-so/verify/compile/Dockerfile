# Toolchain for check 3 (compile). Built and run by verify.py; see its docstring.
#
#   base image   debian:bookworm-slim, pinned by digest below
#   compiler     Debian bookworm g++ (GCC 12) + g++-multilib, used with -m32
#   headers      mesa-common-dev for GL/gl.h (renderer/qgl.h, reached from idlib/precompiled.h)
#   SDK source   id-Software/DOOM-3 at a9c49da5afb18201d31e3f0a429a037e56ce2b9a
#                ("The DOOM 3 source as it was released under the GPL license on
#                November 22, 2011."), unmodified, at /doom3
#
# The exact g++ version is printed by every check-3 run. Recorded when the check was first
# run (2026-09-24): g++ (Debian 12.2.0-14+deb12u1) 12.2.0. The packages come from the live
# bookworm repos, so a later rebuild may get a newer GCC 12 patch level; test_verify.py
# requires GCC 12. The 2005 gamex86.so was built with a GCC 3.x; GCC 12 is used
# because the check only proves the reconstruction is well-formed SDK code.
FROM debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

RUN apt-get update \
 && apt-get install -y --no-install-recommends g++ g++-multilib mesa-common-dev python3 git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG DOOM3_REV=a9c49da5afb18201d31e3f0a429a037e56ce2b9a
RUN git init -q /doom3 \
 && git -C /doom3 fetch -q --depth 1 https://github.com/id-Software/DOOM-3.git "$DOOM3_REV" \
 && git -C /doom3 checkout -q FETCH_HEAD \
 && test "$(git -C /doom3 rev-parse HEAD)" = "$DOOM3_REV"
