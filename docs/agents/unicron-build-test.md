# Proving a game-library change in game on Unicron (spec #58/#65)

If you're an agent working on Unicron (the Linux host) and your change touches the game library -
anything under `engine/dhewm3-sdk/`, `tools/build-chextrek.sh`, `tools/lib-harness.sh`, or any
`tools/test-*.sh`/scenario script - run the whole suite yourself and get it green **before opening
a PR**. Don't ship a game-library change that wasn't run in game - PR #57 did (see spec #58's
Problem Statement).

## The one command

```
export PATH=/opt/wine-11.0-wow64/bin:$PATH   # the harness's own Wine - see docs/dev-setup.md
bash tools/run-all-tests.sh
```

Run it plain - no `CHEXTREK_SKIP_BUILD` set. That builds `chextrek.dll` with the Unicron
toolchain (msvc-wine, spec #64) and then runs the harness self-test, the main-menu smoke check
and every feature scenario, the same one command as on the Windows dev machine (spec #28 story
38, extended to Unicron by spec #58 story 5). It's mode `100644` in git (a repo convention, not a
mistake) - invoke it with `bash`, not directly.

The `export` matters: the harness's Wine (`/opt/wine-11.0-wow64/bin`, built from source for
new-WoW64 - the distro-packaged Wine can't do this) isn't on `PATH` by default in a fresh shell.
Without it, the suite doesn't report a test failure - it stops at once with `ENVIRONMENT: wine not
found on PATH - dhewm3 runs under Wine on Unicron.` and exit 3, spec #63's environment check
working as designed. That's not a game bug and not something to wait out or retry; put Wine on
`PATH` and run it again.

## Reading the result

- **Exit 0:** every scenario passed. The change is proven in game - safe to open the PR.
- **Exit 1:** at least one scenario failed; the summary lists it as `FAIL: <script>`, with that
  script's own output just above it. Fix the change (or the test, if the test was wrong) and
  rerun - don't open a PR on a red run.
- **Exit 3:** an `ENVIRONMENT:` line names a broken-Unicron-environment blocker (missing
  Wine/`winepath` on `PATH`, an uninitialized Wine prefix, missing Doom 3 data, a missing dhewm3
  engine, or no usable display) - not a test result. Stop; don't wait, poll, or retry. If it's the
  Wine-on-`PATH` case above, fix that and rerun once; any other blocker is an environment problem
  to escalate, not code to change. See `docs/dev-setup.md`'s "Unicron (Linux/Wine)" section for
  what each blocker means and where each piece is supposed to live.

## Iterating quickly

A full suite run rebuilds `chextrek.dll` first every time (clean build ~8s on Unicron, incremental
~1s - see `docs/dev-setup.md`). While iterating on one scenario, run just that scenario's own
`tools/test-<feature>.sh` instead of the whole suite; still run the whole plain
`tools/run-all-tests.sh` once before opening the PR, since that's the one command that proves the
build and every scenario together, the same guarantee the Windows dev machine gives.

## Only one run at a time

Unicron enforces a single-run lock (spec #62) across concurrent worktrees, so two agents' runs
never race on the shared `chextrek` mount or save dir - a second run just waits and prints that
it's waiting. See `docs/dev-setup.md`.
