# Repository guidance

Context for picking this project back up in a later session — the README
is for users; this file is for whoever (human or agent) works on the repo
next.

## What this is

Echocast: redirect one machine's audio to another machine's speakers over
SSH, with automatic local fallback. A CLI/systemd backend (`echocast`,
`echocast-client.service`) plus an Omarchy quickshell plugin
(`manifest.json`, `Service.qml`, `BarWidget.qml`, `Panel.qml`) that's a
thin UI over that backend. Full mechanism and usage docs live in
[../README.md](../README.md) — don't duplicate that here, this file is
only for what a maintainer/agent needs that isn't already there.

This file used to live at the repo root as `CLAUDE.md`, which meant an
agent-aware tool could auto-load it on anyone's machine the moment the
published repo landed in their working tree — an instruction path outside
the plugin's actual runtime. A marketplace reviewer flagged exactly that
on 2026-09-26, so it now lives here under a name with no agent-auto-load
convention attached. Practical effect: opening this repo root in Claude
Code (or similar) no longer surfaces this file automatically — read it
manually (`docs/MAINTENANCE.md`) when picking this project back up.

## Current status (2026-09-26)

- Repo is **public**: https://github.com/hexploder/echocast
- Marketplace submission open: **issue #8724** on
  `omacom/omarchy-plugin-marketplace`
  (`gh issue view 8724 --repo omacom/omarchy-plugin-marketplace`).
  Timeline so far: automated structure/Quattro-compatibility check passed
  (`validated` label); automated capability scan flagged `remote-build`
  (the `curl | bash` installer), `service-management` (the
  `systemctl --user ...` calls), and `installer` — all expected for what
  this plugin does, but they gate it behind manual maintainer review
  (`security-review-required` label) before `approved-and-verified` gets
  applied; two commits landed after the reviewed one, which the
  marketplace can't approve until re-validated, so the issue got edited
  to re-trigger `validate-submission` against the new HEAD each time
  (see git history of this file at the old `CLAUDE.md` path for exactly
  what changed and why); then the manual reviewer flagged the root
  `CLAUDE.md` itself (see above) — moved here, needs one more
  re-validation pass. This is *listing* review, not a security audit —
  check the issue for maintainer comments before assuming it's still just
  waiting.
- Deployed and working end-to-end on the maintainer's own two machines
  (one server role, one client role) — that's the only real-world testing
  so far. No other users, no CI, no automated tests.
- No git tags / GitHub Releases yet. `manifest.json` version is still
  `1.0.0`, unchanged since the initial push.

## Identity / privacy conventions — read before touching this repo

- This repo is public under the `hexploder` GitHub handle, but the
  **plugin's own identity** (name, description, code comments, README,
  images) must contain no trace of the maintainer's real name or real
  machine hostnames — that was an explicit requirement when this was
  published. The one accepted exception is the reverse-domain namespace
  `io.github.hexploder.echocast` in `manifest.json` (unavoidable — that's
  Omarchy's own plugin-id convention, tied to the GitHub account, not a
  personal detail).
- Any screenshot or example added to the README needs its `user@host`
  (or anything else identifying the maintainer's actual LAN/setup)
  redacted/pixelated first — see the git history around
  `docs/screenshot-client.png` for the pattern (PIL, pixelate just the
  bounding box of the live value, keep everything else legible).
- **git identity for this repo is locally overridden**, not the global
  config: `hexploder <hexploder@users.noreply.github.com>`. The
  maintainer's global `git config user.name`/`user.email` is their real
  name and real work email — check `git config user.email` resolves to
  the noreply address *before* committing here if it's ever unset (e.g.
  fresh clone) or you'll leak that into public history.
- Commits end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
  — keep doing that for consistency unless told otherwise.

## Validate before committing

```bash
export OMARCHY_PATH=/usr/share/omarchy   # wherever Omarchy is installed
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I "$OMARCHY_PATH/shell" *.qml   # not on PATH by default
bash -n echocast install.sh
```

`qmllint` emits a pile of `import`/`unresolved-type`/`unqualified`
warnings for `qs.Ui`/`qs.Commons`/`Panel`/`BarWidget` — that's systemic
noise from linting a third-party plugin in isolation (confirmed by
running the identical command against other, already-published
plugins), not a real problem. The warning class that *is* real:
`property-override`/"shadows member" — `QQuickItem` already has
`enabled`/`state`, which is why this codebase's own properties are named
`passthroughEnabled`/`streamState` instead of the more obvious names.

## Non-obvious things learned building this

- A backgrounded (`cmd &`) command inside a non-interactive bash script
  (e.g. an SSH forced command) gets its stdin silently redirected to
  `/dev/null` unless explicitly reconnected (`cmd <&0 &`) — POSIX's
  "asynchronous command, no job control" rule. Symptom was the server
  accepting a connection, logging it, then instantly and silently playing
  nothing — looked like a network issue for a while.
- `omarchy-refresh-shell` resets the *user's* `shell.json` to Omarchy
  defaults (wipes their whole bar layout) — never suggest it as a way to
  "reload," that's `omarchy-restart-shell`.
- `omarchy-shell shell debugBarGeometry` is ground truth for "did the
  widget actually render, and at what pixel" — far more reliable than
  screenshotting a live desktop and eyeballing a tiny icon.
- PipeWire's default quantum (~20ms) leaves no margin for SSH/network
  jitter, which is why there's a `buffer_ms` config field (default 200,
  `echocast set-buffer-ms <ms>`) requesting `--latency-msec` on both
  `parecord` and `paplay`.

## Install is pinned to a tag, not `main` — bump all 4 spots together

The marketplace review (issue #8724) rejected the original `curl | bash
.../main/install.sh` flow: `main` is mutable, so the reviewed/listed
commit and whatever code actually runs at install time could silently
diverge (`install.sh` cloned `main` again internally, too). Fixed by
pinning everything to the `v1.0.0` tag instead. Cutting a new release
means bumping the version in **all** of these, together, or the trust
boundary reopens:

- `README.md` — the `curl` one-liner and the manual-install `git clone --branch`
- `Service.qml` — `installCommand`
- `install.sh` — `REPO_REF` (what it clones internally when run via curl)
- `manifest.json` — `version`

then tagging that exact commit and pushing the tag + a GitHub Release
before pointing the marketplace issue at it.

## If a "verified" (not just listed) tier ever gets requested

Not started, and nobody's asked for it — don't begin this without an
explicit go-ahead, since it's an ongoing commitment (every release needs
the same treatment), not a one-off task. Based on how another marketplace
plugin documents its own process, it looks like: semantic-versioned,
tagged GitHub Releases (not just commits to `main`), then a *separate*
verification issue on `omacom/omarchy-plugin-marketplace` (its own issue
template, distinct from the submission one already used) targeting the
exact release commit SHA.
