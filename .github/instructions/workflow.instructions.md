---
applyTo: "**"
---

# target-convert Development Rules

## Branches

- Never commit directly to `master`. All changes go on a feature branch.
- One branch per logical concern. MCU family additions get their own branch: `feat/h7-support`, `feat/g4-support`, `feat/at32-support`.
- Stacked PRs: after upstream merges, rebase with `git rebase --onto master <old-base> <branch>`.

## Merging

- Always squash-merge: `gh pr merge <N> --squash`
- Never use `--delete-branch`. GitHub auto-closes any PR whose base branch is deleted.

## .gitignore is a pure whitelist

The root `.gitignore` starts with `/*` (block everything) and uses only `!allowlist` entries. Never add a specific blocklist entry inside it.

- To untrack a file: `git rm --cached <file>` — that is sufficient. Do not add the filename to `.gitignore`.
- To track files in a new directory: add both `!dir/` and `!dir/*` to `.gitignore` (both are required — `/*` blocks the directory itself, preventing git from entering it without the explicit `!dir/` entry).

## Commits

- Format: `type: subject` (~50 chars, imperative mood)
- Types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`, `build`
- Always add: `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

## Testing before merge

Run all five reference targets and verify output:
```
./convert.sh FOXEERF722V4 ./test
./convert.sh TUNERCF405 ./test
./convert.sh TMOTORF7 ./test
./convert.sh PYRODRONEF7 ./test
./convert.sh SKYSTARSF405AIO ./test
```

Check: port masks match convention (`0xffff` multi-pin, `(BIT(n))` single-pin), timers resolve, no aborts.

## Scope

This repo converts Betaflight `config.h` files to EmuFlight target files. Changes are limited to `convert.sh` and `lookup/*.csv`. Do not modify EmuFlight source directly.
