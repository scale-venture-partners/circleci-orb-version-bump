# circleci-orb-version-bump

A [CircleCI orb](https://circleci.com/docs/orbs/use/orb-intro/) that fails a
build when a package manifest's version wasn't bumped relative to the base
branch — with optional CHANGELOG enforcement, a monotonic-increase check,
and exemptions for docs/config-only changes. Supports Python
(`pyproject.toml`) and Node (`package.json`) out of the box, plus a generic
regex-based fallback for anything else.

## Why

Several repos hand-rolled a version of this check directly in
`.circleci/config.yml`, copy-pasted and drifted repo to repo: some check
`pyproject.toml`, one checks Node's `package.json` via inline `python3 -c`
snippets, CHANGELOG enforcement is inconsistent, and two repos each grew
their own ad-hoc exemption for docs-only PRs. This orb is one implementation,
parameterized for those differences, so adopting it is a few lines of YAML
instead of copying and adapting a shell block.

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
