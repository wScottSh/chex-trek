## Agent skills

### Issue tracker

Issues tracked in GitHub Issues (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage labels, default names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context (`CONTEXT.md` + `docs/adr/` at root). See `docs/agents/domain.md`.

### Proving a game-library change on Unicron

On Unicron, run `bash tools/run-all-tests.sh` and get it green before opening a PR on any
game-library change. See `docs/agents/unicron-build-test.md` (setup: `docs/dev-setup.md`).
