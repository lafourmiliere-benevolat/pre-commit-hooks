# pre-commit-hooks

Shared [prek](https://github.com/j178/prek) / [pre-commit](https://pre-commit.com) hooks for La Fourmilière repos.

## `check-token-limit`

Rejects staged files over a token budget, estimated as bytes / 4, and tells the author how to split them. Keeps every hand-written file small enough for a coding agent to read whole.

```yaml
- repo: https://github.com/lafourmiliere-benevolat/pre-commit-hooks
  rev: <commit sha> # frozen: v1.0.0
  hooks:
    - id: check-token-limit
      args: [--max-tokens=5000]
      exclude: (^|/)[^/]*\.lock$
```

- `--max-tokens`: budget per file. Defaults to 5000.
- `--guide`: optional; where the repo explains how to split its files. Printed with the error.
- `exclude`: files nobody writes by hand, like lockfiles or generated code. Each repo keeps its own.

Pin a commit, not a tag: `prek update --freeze` writes the SHA and its tag.

## Tests

```bash
tests/check-token-limit.sh
```
