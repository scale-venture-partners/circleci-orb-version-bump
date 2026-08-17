# circleci-orb-version-bump

A [CircleCI orb](https://circleci.com/docs/orbs/use/orb-intro/) that fails a
build when a package manifest's version wasn't bumped relative to the base
branch — with optional CHANGELOG enforcement, a monotonic-increase check,
and exemptions for docs/config-only changes. Supports Python
(`pyproject.toml`) and Node (`package.json`) out of the box, plus a generic
regex-based fallback for anything else.

## Why

Versioning and changelogs are only useful if they're actually kept up to
date — and that's exactly the kind of bookkeeping that's easy to skip under
deadline pressure, easy to leave out of a "just this once" PR, and, more and
more, easy for an AI coding agent to skip entirely, since an agent optimizes
for the task it was given and has no built-in reason to also remember "and
now update `CHANGELOG.md`." A CI check is one of the few mechanisms that
enforces this regardless of who — or what — opened the PR, without anyone
having to remember to ask.

### What a changelog actually buys you

A `CHANGELOG.md`, kept in a convention like [Keep a
Changelog](https://keepachangelog.com/), is a curated, per-release,
human-readable summary of what changed — distinct from your commit history,
which is an implementation log, not a communication tool. It answers the
question a consumer actually has before upgrading: "what do I need to know
before I bump this dependency?" — without making them read every commit or
diff since the last release. A good changelog entry calls out breaking
changes, deprecations, and security fixes explicitly, written at the moment
someone has the most context to describe them — not months later, by
someone else, trying to reconstruct intent from `git log`.

### Why this matters more, not less, with agentic development

As more of a codebase's changes come from AI coding agents rather than a
human sitting down to write a PR by hand, two things get worse without a
hard gate:

- **Bookkeeping silently drops.** An agent asked to "add support for X"
  will add support for X. It won't spontaneously decide to also bump the
  version and write a changelog entry unless that's explicitly part of its
  instructions — and even good instructions get missed under context
  pressure, across long sessions, or when an agent is one of several
  running in parallel. A CI check turns "please remember to do this" into
  "the build won't pass until you do" — a hard constraint an agent (or a
  human reviewing an agent's PR) can act on directly and unambiguously,
  instead of a convention that depends on memory.
- **Version collisions get more likely, not less.** Agentic workflows
  increasingly mean several PRs in flight against the same repo at once —
  parallel fan-out agents, background jobs, multiple people each running
  their own assistant. Each one independently bumping "the next version" is
  a much more common failure mode than it used to be, and it's exactly the
  kind of thing that passes every individual PR's CI and then collides on
  merge. Catching a missing bump — or, with `require-increase` turned on, a
  version that regressed instead of advancing — at CI time surfaces that
  collision at the PR itself, not after two branches have already landed.
- **A structured changelog is something an agent can actually use.**
  Free-form commit history is noisy to summarize; a disciplined, per-version
  changelog is exactly the kind of structured artifact an LLM — yours, a
  dependency-upgrade bot, or a teammate's assistant — can read to answer
  "what changed," "is this safe to upgrade," or "what should the PR
  description say," far more reliably than reconstructing it from a diff.

This orb doesn't write your changelog for you or decide what "done" looks
like — it just makes sure the bookkeeping actually happens, on every PR,
regardless of who wrote the code.

## Usage

Compose the `check` command into a job you already have:

```yaml
version: 2.1
orbs:
  version-bump: scale-venture-partners/version-bump@1.0.0
workflows:
  build:
    jobs:
      - test
jobs:
  test:
    docker:
      - image: cimg/python:3.12
    steps:
      - checkout
      - run: pip install -e .
      - run: pytest
      - version-bump/check:
          manifest-type: python-pyproject
```

Or use the standalone job if you don't have one to attach it to (override
`executor` to match your manifest type):

```yaml
orbs:
  node: circleci/node@5
  version-bump: scale-venture-partners/version-bump@1.0.0
workflows:
  build:
    jobs:
      - version-bump/check:
          manifest-type: node-package-json
          executor: node/default
```

Skip the check for docs/config-only PRs, and require the version to
actually increase (not just differ):

```yaml
- version-bump/check:
    manifest-type: python-pyproject
    require-increase: true
    exempt-paths: ".circleci/*,docs/*,*.md,.gitignore,Makefile"
```

See `src/examples/` for the full runnable examples this README pulls from.

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `manifest-type` | *(required)* | `python-pyproject` \| `node-package-json` \| `generic` |
| `manifest-path` | `pyproject.toml` / `package.json` per type | required for `generic`; override for a nested path (e.g. `backend/pyproject.toml`) |
| `version-pattern` | — | only for `generic`: an extended regex (as accepted by `sed -E`) with exactly one capturing group for the version |
| `base-branch` | `main` | branch the version is compared against |
| `require-changelog` | `true` | require a matching heading in `changelog-path` |
| `changelog-path` | `CHANGELOG.md` | |
| `changelog-heading-pattern` | `` ## \[{version}\] `` | extended regex; `{version}` is substituted (regex-escaped) |
| `exempt-paths` | `""` | comma-separated shell glob patterns (e.g. `docs/*,*.md,Makefile`); if every changed file matches one, the check is skipped entirely |
| `require-increase` | `false` | require the new version to be numerically greater, not just different — **off by default** so adopting this orb never tightens behavior relative to a "must differ" check |

`python-pyproject` reads `[project].version` (PEP 621), falling back to
`[tool.poetry].version`, then a bare top-level `version` key.
`node-package-json` reads the top-level `.version` field.

## Development

Requires `git`, [`shellcheck`](https://www.shellcheck.net/),
[`bats-core`](https://bats-core.readthedocs.io/), and the
[`circleci` CLI](https://circleci.com/docs/local-cli/) (`brew install
shellcheck bats-core circleci`).

```bash
./scripts/verify.sh          # shellcheck + bats + orb pack + orb validate
./scripts/install-hooks.sh   # once per clone: installs the pre-commit hook
```

The scripts under `src/scripts/` are the actual logic and are unit- and
integration-tested directly (real temporary git repos, no mocking — this
orb has no external dependencies to fake). `src/commands/`, `src/jobs/`,
`src/executors/`, and `src/examples/` are combined into the published
`orb.yml` via `circleci orb pack src`; `orb.yml` itself is a build artifact
(gitignored), not source.

## Publishing

Not yet published. Publishing needs:

1. A registered CircleCI orb namespace for `scale-venture-partners`
   (`circleci namespace create scale-venture-partners <vcs-type> <org>` —
   needs org-admin access and a CircleCI API token).
2. `circleci orb create scale-venture-partners/version-bump` (one-time, in
   that namespace).
3. `circleci orb publish orb.yml scale-venture-partners/version-bump@1.0.0`
   for a real release, or `@dev:<label>` for a dev build to test against a
   pilot repo first.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
