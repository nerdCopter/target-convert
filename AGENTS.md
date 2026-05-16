# AGENTS.md

## Project Overview
`target-convert` converts Betaflight `config.h` files to EmuFlight target files. Source of truth is `https://github.com/betaflight/config/raw/master/configs/<TARGETNAME>/config.h`. The old `betaflight/unified-targets` repo is no longer used.

## Scope
Changes are limited to `convert.sh` and `lookup/*.csv`. Do not modify EmuFlight source directly.

## Key Technical Concepts

### TIMER_PIN_MAP
Betaflight `config.h` defines timers as:
```
TIMER_PIN_MAP(index, PIN, occurrence, dmaopt)
```
- `occurrence` selects which timer this pin maps to (priority order, see `lookup/*.csv`)
- `dmaopt` selects DMA stream; `-1` means no DMA (input capture only)
- Pin values may be macro names (e.g. `MOTOR1_PIN`) that must be resolved via `#define` lookup in config.h before timer table lookup
- Filter comment lines (`^\s*//`) from TIMER_PIN_MAP grep — some targets include a header comment that matches the pattern

### Port Masks
`TARGET_IO_PORTx` bitmasks define which pins are accessible to firmware (DEFIO compile-time safety gate):
- **Multi-pin port (2+ pins used):** always `0xffff`
- **Single-pin port (exactly 1 pin):** `BIT(n)` where n is the pin number
- `0xffff` on a lightly-used port is always safe; extra `ioRec[]` entries go unused at runtime
- See `info/PORT_MASKS.md` for full documentation

### EmuFlight vs Betaflight Naming
| Betaflight | EmuFlight |
|---|---|
| `GYRO_1_SPI_INSTANCE` | `GYRO_1_SPI_BUS` |
| `SPI1`…`SPI4` | `SPIDEV_1`…`SPIDEV_4` |
| `SPIn_SDI_PIN` | `SPIn_MISO_PIN` |
| `SPIn_SDO_PIN` | `SPIn_MOSI_PIN` |

### Lookup Tables (`lookup/*.csv`)
Format: comma-separated, `#` comment lines skipped.

| File | Key | Value |
|---|---|---|
| `f4_timer_hw.csv` | `PIN,occurrence` | `TIM,CH` |
| `f7_timer_hw.csv` | `PIN,occurrence` | `TIM,CH` |
| `h7_timer_hw.csv` | `PIN,occurrence` | `TIM,CH` — H7 has TIM15/16/17 instead of F7's TIM9/10/11 |
| `f4f7_dma_timer.csv` | timer DMA stream assignments | |
| `f4f7_dma_adc.csv` | `ADCdev,opt` | DMA controller/stream |
| `f4f7_dma_spi.csv` | SPI DMA stream assignments | |

### MCU Family Routing
| Betaflight MCU | Timer CSV | `TARGET_BOARD_IDENTIFIER` | Make target group |
|---|---|---|---|
| STM32F405 | f4 | `S405` | `F405_TARGETS` |
| STM32F411 | f4 | `S411` | `F411_TARGETS` |
| STM32F7X2 | f7 | `S7X2` | `F7X2RE_TARGETS` |
| STM32F745 | f7 | `S745` | `F7X5XG_TARGETS` |
| STM32H743 | h7 | `SH74` | `H743_TARGETS` |
| STM32H750 | h7 | `S750` | `H750_TARGETS` |

## Testing
Run all five reference targets and verify output (no aborts, port masks match convention):
```
./convert.sh FOXEERF722V4 ./test
./convert.sh TUNERCF405 ./test
./convert.sh TMOTORF7 ./test
./convert.sh PYRODRONEF7 ./test
./convert.sh SKYSTARSF405AIO ./test
```
Check: port masks are `0xffff` for multi-pin ports and `(BIT(n))` for single-pin ports, timers resolve (no `UNKNOWN_TIM`), no aborts.

## Known Limitations
- H7 ADC DMA streams: not resolved (H7 uses DMAMUX, not fixed assignments); output includes "please verify" notices
- Dual-gyro targets: GYRO_1/GYRO_2 assignments may need post-convert validation
- SPI RX (ELRS, FrSky): partial automation; manual completion needed
- GPS: skipped entirely
- VTX RTC6705: skipped; add manually if needed
- `DEFAULT_VOLTAGE_METER_SCALE` not captured (pre-existing gap)
- `USB_DETECT_PIN` define not emitted alongside `USE_USB_DETECT` (pre-existing gap)
- Always search output files for keyword `notice` to find items needing manual attention
