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

Run all five reference targets (`--force`: an existing target folder aborts the run) and verify output:
```
./convert.sh --force FOXEERF722V4 ./test
./convert.sh --force TUNERCF405 ./test
./convert.sh --force TMOTORF7 ./test
./convert.sh --force PYRODRONEF7 ./test
./convert.sh --force SKYSTARSF405AIO ./test
```

Check: no aborts; `TIMER_PIN_MAPPING` in `target.h` is identical to the reference block; the output has no `timerHardware`, `USED_TIMERS`, `USABLE_TIMER_CHANNEL_COUNT`, `TARGET_IO_PORT` or `notice`.

## Scope

This repo converts Betaflight `config.h` files to EmuFlight target files. Changes are limited to `convert.sh` and the docs. Do not modify EmuFlight source directly.
