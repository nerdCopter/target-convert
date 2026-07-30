# Converter Design Notes

## Source of truth: betaflight/config

`betaflight/config` groups boards by manufacturer: `configs/<MANUFACTURER_ID>/<TARGETNAME>/config.h`. Board names are unique across the whole repo, so the converter still only needs the bare board name as input — it resolves `<MANUFACTURER_ID>` itself before downloading:

1. `wget`s the repo's git tree (`https://api.github.com/repos/betaflight/config/git/trees/master?recursive=1`)
2. `grep`s the tree listing for `configs/<MFR>/<TARGETNAME>/config.h` to recover `<MFR>`
3. Downloads `https://github.com/betaflight/config/raw/master/configs/<MFR>/<TARGETNAME>/config.h`

Only `wget`/`grep` are used for this — both are already hard dependencies of `convert.sh`; no `gh`/`curl`/`jq` requirement is introduced.

The tree query is an unauthenticated GitHub REST API call, capped at 60 req/hr per IP — this limits back-to-back batch conversions to roughly that many per hour.

The old `betaflight/unified-targets` repo (`.config` files, `VEND-TARGETNAME` format) is no longer used, and is unrelated to the manufacturer directory above — that vendor prefix is resolved automatically, not supplied by the caller.

## Input format

```
./convert.sh <TARGETNAME> [outputFolder]
```

- `TARGETNAME` = bare board name; must be unique in `betaflight/config/configs/` (enforced repo-wide by upstream)
- `outputFolder` = optional, defaults to `./`
- Previously required `VEND-TARGETNAME` format (e.g. `TURC-TUNERCF405`) — no longer needed, and not to be confused with the `<MANUFACTURER_ID>` directory betaflight/config now uses internally

## Lookup tables (lookup/*.csv)

CSV format: comma-separated, `#` comment lines skipped.

### Timer hardware tables (`f4_timer_hw.csv`, `f7_timer_hw.csv`, `h7_timer_hw.csv`)

```
# pin,occurrence,TIM,CH
PA0,1,TIM2,CH1
PA0,2,TIM5,CH1
```

- `occurrence` = which timer this pin maps to in priority order (matches the occurrence index in Betaflight's `TIMER_PIN_MAP`)
- Generated from `timer_stm32f4xx.c` / `timer_stm32f7xx.c` / `timer_stm32h7xx.c` in the Betaflight source
- Key in associative array: `PIN_occurrence` → `TIMx:CHy`
- H7 note: TIM9/TIM10/TIM11 are absent on H7; TIM15/TIM16/TIM17 are present instead

### DMA tables (`f4f7_dma_adc.csv`, `f4f7_dma_timer.csv`, `f4f7_dma_spi.csv`)

```
# ADCdev,opt,ctrl,stream,channel
1,0,2,0,0
```

- `opt` = dmaopt value from `TIMER_PIN_MAP` or `ADCn_DMA_OPT` in config.h
- `ctrl`/`stream`/`channel` = DMA controller number, stream, channel

### Generating/updating lookup tables

See `tools/gen_lookup_tables.sh` — requires a local Betaflight source tree.

## MCU family routing

| Betaflight MCU | Timer CSV | `TARGET_BOARD_IDENTIFIER` | Make target group |
|---|---|---|---|
| STM32F405 | `f4_timer_hw.csv` | `S405` | `F405_TARGETS` |
| STM32F411 | `f4_timer_hw.csv` | `S411` | `F411_TARGETS` |
| STM32F446 | `f4_timer_hw.csv` | `S446` | `F446_TARGETS` |
| STM32F7X2 | `f7_timer_hw.csv` | `S7X2` | `F7X2RE_TARGETS` |
| STM32F745 | `f7_timer_hw.csv` | `S745` | `F7X5XG_TARGETS` |
| STM32H723/H725 | `h7_timer_hw.csv` | `SH72` | `H723_TARGETS` |
| STM32H730 | `h7_timer_hw.csv` | `S730` | `H730_TARGETS` |
| STM32H743 | `h7_timer_hw.csv` | `SH74` | `H743_TARGETS` |
| STM32H750 | `h7_timer_hw.csv` | `S750` | `H750_TARGETS` |

## Timer resolution (TIMER_PIN_MAP)

Betaflight `config.h` contains:
```c
#define TIMER_PIN_MAPPING \
    TIMER_PIN_MAP(0, PA9,  1, -1) \
    TIMER_PIN_MAP(1, PA8,  1,  0)
```

Format: `TIMER_PIN_MAP(index, PIN, occurrence, dmaopt)`

The converter:
1. Filters comment lines (`^\s*//`) — some configs include a `// TIMER_PIN_MAP(...)` header comment that matches the grep pattern
2. Resolves macro pin names — H7 targets (and some others) use macro names like `MOTOR1_PIN` instead of literal pin values like `PC6`; the converter looks up `#define MACRONAME PIN` in config.h before doing the timer table lookup
3. Looks up `PIN + occurrence` in the timer CSV to get `TIMx:CHy`
4. Determines `TIM_USE_*` role from pin's define in config.h (MOTOR1..8_PIN → `TIM_USE_MOTOR`, SERVO1..4_PIN → `TIM_USE_SERVO`, PPM_PIN → `TIM_USE_PPM`, LED_STRIP_PIN → `TIM_USE_LED`, CAMERA_CONTROL_PIN → `TIM_USE_ANY`)
5. Emits `DEF_TIM(TIMx, CHy, PIN, TIM_USE_xxx, 0, dmaopt)` in `target.c`

## GYRO SPI naming

EmuFlight uses:
- `GYRO_1_SPI_BUS` / `GYRO_2_SPI_BUS` (not `_SPI_INSTANCE`)
- `SPIDEV_1` through `SPIDEV_4` (not `SPI1` through `SPI4`)

Betaflight config.h uses `GYRO_1_SPI_INSTANCE` and `SPI1`. The converter translates automatically via `sed`.

## SPI pin naming

Betaflight config.h uses `SPIn_SDI_PIN` / `SPIn_SDO_PIN` (MISO/MOSI in newer naming).
EmuFlight uses `SPIn_MISO_PIN` / `SPIn_MOSI_PIN`.
The converter translates these automatically.

## Output files

| File | Description |
|------|-------------|
| `TARGETNAME/target.mk` | Build system: MCU target group, VCP/flash features, driver sources |
| `TARGETNAME/target.c` | Timer hardware array (`timerHardware[]`) with `DEF_TIM()` entries |
| `TARGETNAME/target.h` | All `#define` pin/feature definitions |
| `TARGETNAME/resources/config.h` | Downloaded Betaflight config (reference) |
| `TARGETNAME/resources/timers.txt` | Human-readable timer summary (reference) |

## Known limitations / manual review required

- Dual-gyro targets: GYRO_1/GYRO_2 pin assignments may need validation; quad-gyro targets (e.g. STELLARH7DEV) require post-convert manual reduction to the one EmuFlight-supported gyro
- H7 ADC DMA streams: not resolved — H7 uses DMAMUX (no fixed opt→stream mapping); output includes "please verify" notices
- SPI RX (ELRS, FrSky): partially automated, manual completion needed
- VTX RTC6705: skipped entirely, add manually if needed
- GPS: skipped
- Some rare peripheral combinations not accounted for
- Always search output files for the keyword `notice` to find items needing manual attention
