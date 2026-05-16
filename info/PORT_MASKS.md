# TARGET_IO_PORT Masks

## What they are

`TARGET_IO_PORTA`, `TARGET_IO_PORTB`, etc. are bitmasks defined in `target.h`. Each bit N represents whether pin N (0–15) on that port is accessible to the firmware.

```c
#define TARGET_IO_PORTA 0xffff   // all 16 PA pins available
#define TARGET_IO_PORTD (BIT(2)) // only PD2 available
```

`BIT(n)` = `(1 << n)`, defined in EmuFlight/Betaflight common headers.

## How the firmware uses them (DEFIO system)

The Perl script `src/utils/def_generated.pl` generates `io_def_generated.h` at build time. For each port/pin combination it checks the mask:

```c
#if DEFIO_PORT_A_USED_MASK & BIT(5)
  #define DEFIO_TAG__PA5  DEFIO_TAG_MAKE(...)
#else
  #define DEFIO_TAG__PA5  defio_error_PA5_is_not_supported_on_TARGET
#endif
```

**Consequence:** if a pin is referenced anywhere in the target's code but its bit is NOT set in the mask, the build fails with a compile error (`defio_error_Pxx_is_not_supported_on_TARGET` expands as an undefined identifier). This is intentional — it's a compile-time safety gate.

## Convention

- **Multi-pin port (2+ pins used):** always `0xffff`
  - All 16 pins on that port are declared available
  - Future peripheral additions never require mask edits
  - Slight memory overhead (a few bytes in `ioRec[]` array) — irrelevant in practice
- **Single-pin port (exactly 1 pin used):** `(BIT(n))` where n is the pin number
  - Example: PD2 (BEEPER on most F4/F7 boards) → `TARGET_IO_PORTD (BIT(2))`
  - Accurately reflects that the rest of the port isn't routed out on this hardware

## Why 0xffff is always safe

`0xffff` on a port that only has 1–2 pins routed out works fine. The extra pin descriptors in `ioRec[]` simply go unused. No runtime effect. This is why targets with `0xffff` on all ports (including PORTD) have always worked — pilots never noticed because there's no functional difference.

## How convert.sh computes masks

1. Scans `config.h` for all `P[A-K][0-9]{1,2}` tokens (A–K covers H7)
2. Groups by port letter, ORs `(1 << pin_number)` per port
3. Power-of-2 check `(mask & (mask-1)) == 0` → single pin → emit `(BIT(n))`
4. Otherwise emit `0xffff`
5. Loops ports A–K; skips any port with zero mask (so unused H7 ports I/J/K don't appear on F4/F7 targets)

## Port letters by MCU family

- F4, F7: ports A–H (some boards only use A–D or A–E)
- H7: ports A–K (adds I, J, K) — supported
- G4: ports A–G typically
