# AGENTS.md

## Project
`target-convert` converts Betaflight `config.h` board definitions into EmuFlight target files (`target.mk`, `target.c`, `target.h`) using local CSV lookup tables. See technical details below.

## Scope
Changes are limited to `convert.sh` and `lookup/*.csv`. Do not modify EmuFlight source directly.

## Technical Reference
@info/CONVERTER_DESIGN.md
@info/PORT_MASKS.md

## Testing
Run all five reference targets and verify output — no aborts, port masks match convention, timers resolve:
```
./convert.sh FOXEERF722V4 ./test
./convert.sh TUNERCF405 ./test
./convert.sh TMOTORF7 ./test
./convert.sh PYRODRONEF7 ./test
./convert.sh SKYSTARSF405AIO ./test
```
