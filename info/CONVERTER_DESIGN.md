# Converter Design Notes

## Source of truth: betaflight/config

All target definitions are fetched from:
```
https://github.com/betaflight/config/raw/master/configs/<TARGETNAME>/config.h
```

The old `betaflight/unified-targets` repo (`.config` files, `VEND-TARGETNAME` format) is no longer used. The `betaflight/config` repo organizes by bare target name (`TUNERCF405/config.h`), which is why the vendor prefix is no longer required as input.

## Input format

```
./convert.sh <TARGETNAME> [outputFolder]
```

- `TARGETNAME` = bare board name matching a directory in `betaflight/config/configs/`
- `outputFolder` = optional, defaults to `./`
- Previously required `VEND-TARGETNAME` format (e.g. `TURC-TUNERCF405`) — no longer needed

## Lookup tables (lookup/*.csv)

CSV format: comma-separated, `#` comment lines skipped.

### Timer hardware tables (`f4_timer_hw.csv`, `f7_timer_hw.csv`)

```
# pin,occurrence,TIM,CH
PA0,1,TIM2,CH1
PA0,2,TIM5,CH1
```

- `occurrence` = which timer this pin maps to in priority order (matches the occurrence index in Betaflight's `TIMER_PIN_MAP`)
- Generated from `timer_stm32f4xx.c` / `timer_stm32f7xx.c` in the Betaflight source
- Key in associative array: `PIN_occurrence` → `TIMx:CHy`

### DMA tables (`f4f7_dma_adc.csv`, `f4f7_dma_timer.csv`, `f4f7_dma_spi.csv`)

```
# ADCdev,opt,ctrl,stream,channel
1,0,2,0,0
```

- `opt` = dmaopt value from `TIMER_PIN_MAP` or `ADCn_DMA_OPT` in config.h
- `ctrl`/`stream`/`channel` = DMA controller number, stream, channel

### Generating/updating lookup tables

See `tools/gen_lookup_tables.sh` — requires a local Betaflight source tree.

## Timer resolution (TIMER_PIN_MAP)

Betaflight `config.h` contains:
```c
#define TIMER_PIN_MAPPING \
    TIMER_PIN_MAP(0, PA9,  1, -1) \
    TIMER_PIN_MAP(1, PA8,  1,  0)
```

Format: `TIMER_PIN_MAP(index, PIN, occurrence, dmaopt)`

The converter:
1. Parses all `TIMER_PIN_MAP()` entries from `config.h`
2. Looks up `PIN + occurrence` in the timer CSV to get `TIMx:CHy`
3. Determines `TIM_USE_*` role from pin's define in config.h (MOTOR_PIN, PPM_PIN, LED_STRIP_PIN, CAMERA_CONTROL_PIN)
4. Emits `DEF_TIM(TIMx, CHy, PIN, TIM_USE_xxx, 0, dmaopt)` in `target.c`

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

- Dual-gyro targets: GYRO_1/GYRO_2 pin assignments may need validation
- SPI RX (ELRS, FrSky): partially automated, manual completion needed
- VTX RTC6705: skipped entirely, add manually if needed
- GPS: skipped
- ADC DMA streams: computed but marked with "please verify"
- Some rare peripheral combinations not accounted for
- Always search output files for the keyword `notice` to find items needing manual attention
