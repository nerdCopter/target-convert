# AGENTS.md

## Project
`target-convert` converts Betaflight `config.h` board definitions into EmuFlight target files (`target.mk`, `target.h`); timers, named pins and DMA options are copied verbatim from the reference config. See technical details below.

## Scope
Changes are limited to `convert.sh` and the docs. Do not modify EmuFlight source directly.

## Technical Reference
@info/CONVERTER_DESIGN.md

## Testing
Run all five reference targets (without `--force`, an existing target folder aborts the run) and verify output — no aborts, `TIMER_PIN_MAPPING` identical to the reference block, no `timerHardware`/`USED_TIMERS`/`TARGET_IO_PORT`/`notice` in the output:
```
./convert.sh --force FOXEERF722V4 ./test
./convert.sh --force TUNERCF405 ./test
./convert.sh --force TMOTORF7 ./test
./convert.sh --force PYRODRONEF7 ./test
./convert.sh --force SKYSTARSF405AIO ./test
```
