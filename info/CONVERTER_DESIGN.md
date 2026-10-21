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
./convert.sh [-f|--force] <TARGETNAME> [outputFolder]
```

- `TARGETNAME` = bare board name; must be unique in `betaflight/config/configs/` (enforced repo-wide by upstream)
- `outputFolder` = optional, defaults to `./`
- An existing `outputFolder/TARGETNAME` aborts the run unless `--force` is given
- Previously required `VEND-TARGETNAME` format (e.g. `TURC-TUNERCF405`) — no longer needed, and not to be confused with the `<MANUFACTURER_ID>` directory betaflight/config now uses internally

## MCU family routing

| Betaflight MCU | `TARGET_BOARD_IDENTIFIER` | Make target group |
|---|---|---|
| STM32F405 | `S405` | `F405_TARGETS` |
| STM32F411 | `S411` | `F411_TARGETS` |
| STM32F446 | `S446` | `F446_TARGETS` |
| STM32F7X2/F722 | `S7X2` | `F7X2RE_TARGETS` |
| STM32F745 | `S745` | `F7X5XG_TARGETS` |
| STM32H723/H725 | `SH72` | `H723_TARGETS` |
| STM32H730 | `S730` | `H730_TARGETS` |
| STM32H743 | `SH74` | `H743_TARGETS` |
| STM32H750 | `S750` | `H750_TARGETS` |

## Timers (TIMER_PIN_MAPPING)

EmuFlight resolves timer and channel at run time from `TIMER_PIN_MAPPING`; the converter does no timer lookup. Betaflight `config.h` contains:
```c
#define TIMER_PIN_MAPPING \
    TIMER_PIN_MAP(0, PA9,  1, -1) \
    TIMER_PIN_MAP(1, PA8,  1,  0)
```

Format: `TIMER_PIN_MAP(index, PIN, occurrence, dmaopt)`. `occurrence` indexes all timer options of that pin on the MCU, not a channel number.

The converter copies into `target.h`:
1. The whole `TIMER_PIN_MAPPING` block, unchanged (`dmaopt` values including `-1`, row comments, continuation lines).
2. The named pin macros the reference defines: `MOTORn_PIN`, `SERVOn_PIN`, `RX_PWMn_PIN`, `RX_PPM_PIN`, `LED_STRIP_PIN`, `TRANSPONDER_PIN`, `CAMERA_CONTROL_PIN`, `GYRO_n_CLKIN_PIN` (a `TIMER_PIN_MAP` row may name it).
3. `TIMUPn_DMA_OPT`, `ADCn_DMA_OPT`, `SPIn_TX_DMA_OPT` and `SPIn_RX_DMA_OPT`.

It writes no `timerHardware[]`, `target.c`, `USED_TIMERS`, `USABLE_TIMER_CHANNEL_COUNT` or `TARGET_IO_PORTx`. EmuFlight master raises `#error` for a positive `USABLE_TIMER_CHANNEL_COUNT` and defaults every port mask to `0xffff`. The reference `dmaopt` values win, including any DMA stream collision they carry.

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
| `TARGETNAME/target.h` | All `#define` pin/feature definitions |
| `TARGETNAME/resources/config.h` | Downloaded Betaflight config (reference) |
| `TARGETNAME/resources/open-items.txt` | Defines to complete or verify by hand (written only when non-empty) |

## Known limitations / manual review required

- Dual-gyro targets: GYRO_1/GYRO_2 pin assignments may need validation; quad-gyro targets (e.g. STELLARH7DEV) require post-convert manual reduction to the one EmuFlight-supported gyro
- DMA options are copied from the reference; check each DMA stream for collisions after conversion
- SPI RX (ELRS, FrSky): partially automated, manual completion needed
- VTX RTC6705: skipped entirely, add manually if needed
- GPS: skipped
- Some rare peripheral combinations not accounted for
- Read `resources/open-items.txt` for items needing manual attention; target files carry no `notice` comments
- `DEFAULT_FEATURES` is copied from the reference only; EmuFlight already adds OSD, telemetry and airmode
