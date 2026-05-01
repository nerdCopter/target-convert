# Plan: eliminate unified-targets dependency

## Background

`convert.sh` currently downloads two files per target:

| File | Source |
|---|---|
| `config.h` | `https://github.com/betaflight/config/raw/master/configs/<BOARD>/config.h` |
| `<VEND>-<BOARD>.config` | `https://github.com/betaflight/unified-targets/raw/master/configs/default/<VEND>-<BOARD>.config` |

The `unified-targets` repo is **closed and no longer updated**.  The `betaflight/config` repo is the
active source and contains everything needed.

---

## What `$unified` currently provides (19 usages)

All 19 usages fall into four groups:

### 1. Timer / channel discovery (lines 396–398, 1178)

```bash
pinArray   = grep "TIM[0-9]* CH" $unified  col3 (pin)
timerArray = grep "TIM[0-9]* CH" $unified  col4 (TIMx)
channelArray= grep "TIM[0-9]* CH" $unified col5 (CHy)
```

The `.config` file contains human-readable comment lines like:
```
# pin B07: TIM4 CH2 (AF2)
```

**Replacement**: `config.h` `TIMER_PIN_MAP(idx, PIN, occurrence, dmaopt)` + a static lookup table
(`pin + occurrence → TIMx + CHy`) extracted from `timer_stm32f4xx.c` / `timer_stm32f7xx.c` /
`timer_stm32h7xx.c`.

### 2. DMA option per pin (lines 460, 502)

```bash
dma = grep "dma pin <PIN>" $unified  col4  (opt index 0/1/2…)
```

The `.config` file has `dma pin B07 0` meaning "use DMA option 0 for this pin".

**Replacement**: The `dmaopt` value (4th param) of `TIMER_PIN_MAP` in `config.h` **is already this
value**.  No lookup needed — it is directly usable.

### 3. Motor / resource pin assignments (lines 423–424)

```bash
motorsArray    = grep "resource MOTOR " $unified  col3 (motor number)
motorsPINArray = grep "resource MOTOR " $unified  col4 (pin)
```

**Replacement**: `config.h` already defines `MOTOR1_PIN … MOTOR8_PIN` directly.

### 4. Peripheral role detection (lines 503–507)

```bash
ppm  = grep "<PIN>" $unified | grep PPM
led  = grep "<PIN>" $unified | grep LED
cam  = grep "<PIN>" $unified | grep CAMERA
```

Used to assign `TIM_USE_PPM`, `TIM_USE_LED`, `TIM_USE_ANY`, etc.

**Replacement**: `config.h` defines `PPM_PIN`, `LED_STRIP_PIN`, `CAMERA_CONTROL_PIN` etc.
Cross-reference the pin from `TIMER_PIN_MAP` against these `_PIN` defines.

### 5. ADC DMA string (lines 1085, 1087)

```bash
adcDmaString = grep "ADC ${i}: DMA" $unified
```

The `.config` has `dma ADC 1 0` + comment `# ADC 1: DMA2 Stream 0 Channel 0`.

**Replacement**: `config.h` has `ADC1_DMA_OPT N`.  Resolve opt → DMA via static table from
`dma_reqmap_mcu.c`:

```
# F4/F7:
ADC1: opt0=DMA2_Stream0_Ch0, opt1=DMA2_Stream4_Ch0
ADC2: opt0=DMA2_Stream2_Ch1, opt1=DMA2_Stream3_Ch1
ADC3: opt0=DMA2_Stream0_Ch2, opt1=DMA2_Stream1_Ch2
```

### 6. timers.txt reference file (lines 563–566) — informational only

Already supplemented from `config.h`; the `$unified` lines are additive comments.
Can be dropped or replaced with data derived from the lookup tables.

---

## Source of truth: Betaflight codebase

### Pin → TIM + CH (occurrence-indexed)

Files: `src/main/drivers/stm32/timer_stm32f4xx.c`, `timer_stm32f7xx.c`, `timer_stm32h7xx.c`

Each file contains `fullTimerHardware[]`, e.g.:

```c
DEF_TIM(TIM4, CH1, PB6, 0, 0),   // occurrence 1 for PB6 on F4/F7
```

`TIMER_PIN_MAP(idx, PB6, 1, 0)` means: use the **1st** entry matching `PB6` in `fullTimerHardware` →
`TIM4 CH1`.

If two timers share a pin, occurrence 2 would select the next entry, e.g.:
```c
DEF_TIM(TIM1, CH3N, PB1, …),   // occurrence 1
DEF_TIM(TIM3, CH4,  PB1, …),   // occurrence 2
DEF_TIM(TIM8, CH3N, PB1, …),   // occurrence 3
```

83 entries for F4, 83 for F7, ~84 for H7.  These are small enough for bash associative arrays.

### TIM + CH + dmaopt → DMA stream/channel

File: `src/main/drivers/stm32/dma_reqmap_mcu.c`

F4/F7 table (identical, lines ~431–461):
```c
{ TIM1, CH1, { DMA(2,6,0), DMA(2,1,6), DMA(2,3,6) } },  // opt0, opt1, opt2
{ TIM2, CH1, { DMA(1,5,3) } },
{ TIM3, CH1, { DMA(1,4,5) } },
…
{ TIM8, CH4, { DMA(2,7,7) } },
```

`DMA(controller, stream, channel)` → `DMA<c>_Stream<s>` channel `<ch>` in EmuFlight's `#define`
format.

### ADC opt → DMA stream

F4/F7 (from `dma_reqmap_mcu.c`):
```
ADC1: opt0 → DMA2_Stream0_Ch0,  opt1 → DMA2_Stream4_Ch0
ADC2: opt0 → DMA2_Stream2_Ch1,  opt1 → DMA2_Stream3_Ch1
ADC3: opt0 → DMA2_Stream0_Ch2,  opt1 → DMA2_Stream1_Ch2
```

---

## Proposed lookup table files

These are static files in the `target-convert` repo, derived from the BF codebase.
They are updated only when BF changes these fundamental MCU-level mappings (rare).

```
lookup/
  f4_timer_hw.tsv        # pin, occurrence → TIM, CH  (STM32F405/F446)
  f7_timer_hw.tsv        # pin, occurrence → TIM, CH  (STM32F7x2/F745/F765)
  h7_timer_hw.tsv        # pin, occurrence → TIM, CH  (STM32H7xx)
  f4f7_dma_timer.tsv     # TIM, CH, opt → DMA_ctrl, stream, channel  (F4+F7 identical)
  h7_dma_timer.tsv       # TIM, CH → DMAMUX request  (H7 – DMAMUX, any stream)
  f4f7_dma_adc.tsv       # ADC_dev, opt → DMA_ctrl, stream, channel
  f4f7_dma_spi.tsv       # SPI_dev, dir, opt → DMA_ctrl, stream, channel
```

TSV format example (`f7_timer_hw.tsv`):
```
# pin  occurrence  TIM   CH
PA0    1           TIM2  CH1
PA0    2           TIM5  CH1
PB6    1           TIM4  CH1
PB7    1           TIM4  CH2
…
```

TSV format example (`f4f7_dma_timer.tsv`):
```
# TIM   CH   opt  ctrl  stream  channel
TIM1    CH1  0    2     6       0
TIM1    CH1  1    2     1       6
TIM2    CH1  0    1     5       3
TIM3    CH1  0    1     4       5
TIM4    CH1  0    1     0       2
TIM8    CH4  0    2     7       7
…
```

---

## Revised `convert.sh` algorithm (no unified-targets)

### Input: `config.h` only

```
1. Detect MCU family (STM32F405, STM32F7x2, STM32H7xx, etc.)
2. Load appropriate lookup TSV files into bash associative arrays.
3. Parse TIMER_PIN_MAP entries → array of (pin, occurrence, dmaopt).
4. For each TIMER_PIN_MAP entry:
     a. Look up (pin, occurrence) → (TIM, CH) via timer_hw table.
     b. Determine TIM_USE: cross-ref pin against MOTOR{n}_PIN, PPM_PIN,
        LED_STRIP_PIN, CAMERA_CONTROL_PIN, etc. in config.h.
     c. If dmaopt >= 0: look up (TIM, CH, dmaopt) → (DMA ctrl, stream, ch) via dma_timer table.
     d. Emit: DEF_TIM(TIMx, CHy, Pnn, TIM_USE_xxx, 0, dmaopt), // comment
5. ADC DMA: read ADCn_DMA_OPT → look up dma_adc table → emit comment/define.
6. USED_TIMERS: collect unique TIM numbers from step 4a results.
7. No $unified dependency at all.
```

---

## Scope of config.h coverage (verified)

| Data item | `config.h` | `unified .config` | After plan |
|---|---|---|---|
| MCU type | `FC_TARGET_MCU` | header comment | config.h |
| Motor pins | `MOTOR1_PIN…` | `resource MOTOR` | config.h |
| PPM pin | `PPM_PIN` | `resource PPM` | config.h |
| LED strip pin | `LED_STRIP_PIN` | `resource LED_STRIP` | config.h |
| Camera ctrl pin | `CAMERA_CONTROL_PIN` | `resource CAMERA_CONTROL` | config.h |
| Timer/channel | ❌ (TIMER_PIN_MAP occurrence) | `# pin: TIMx CHy` | lookup table |
| DMA option index | `TIMER_PIN_MAP dmaopt` | `dma pin <PIN> N` | same value, already in config.h |
| DMA stream/ch | ❌ | `# pin: DMAx Stream N Ch M` | lookup table |
| ADC DMA option | `ADCn_DMA_OPT` | `dma ADC n M` | lookup table |
| Gyro SPI bus | `GYRO_1_SPI_BUS` | `set gyro_1_spibus` | config.h |
| Flash SPI bus | `FLASH_SPI_INSTANCE` | `set flash_spi_bus` | config.h |
| OSD SPI bus | `MAX7456_SPI_INSTANCE` | `set max7456_spi_bus` | config.h |

**Key finding**: `dmaopt` in `TIMER_PIN_MAP` is identical to the `dma pin <PIN> N` opt value in the
`.config`. The script already had it — it was just extracting it from the wrong source.

---

## Coverage: 593/605 configs already use TIMER_PIN_MAP

The 12 exceptions are: SITL targets (3), AT32F435 targets (2), RP2350B targets (2),
STM32F446 NUCLEO, STM32G474 NUCLEO, STM32N657 — all development/experimental boards, not
production FC hardware.  These can continue to require the unified-targets `.config` as a fallback,
or be out-of-scope for the converter.

---

## Implementation plan (ordered)

1. **Generate lookup TSVs from BF codebase** (one-time script, run from `betaflight/` checkout):
   - Parse `timer_stm32f4xx.c`, `timer_stm32f7xx.c`, `timer_stm32h7xx.c` → `f4/f7/h7_timer_hw.tsv`
   - Parse `dma_reqmap_mcu.c` F4/F7 block → `f4f7_dma_timer.tsv`, `f4f7_dma_adc.tsv`, `f4f7_dma_spi.tsv`
   - Parse H7 block → `h7_dma_timer.tsv`
   - Script: `tools/gen_lookup_tables.sh` (reads BF repo path as arg)

2. **Rewrite `convert.sh` timer/DMA section** to use lookup tables instead of `$unified`.

3. **Remove `$unified` download**.  Replace `wget unified-targets` line with a note.

4. **Update input format**: accept `BOARD` name only (no VEND- prefix needed once unified-targets
   is gone), or keep VEND-BOARD for backwards compat while ignoring the VEND part.

5. **Fallback**: if `TIMER_PIN_MAP` absent → emit a notice and skip `target.c` timer section
   (handles the ~12 non-standard targets gracefully).

---

## Effort estimate

| Task | Complexity |
|---|---|
| gen_lookup_tables.sh for F4/F7 timer hw | Low — grep/awk parse of ~83-line table |
| gen_lookup_tables.sh for F4/F7 DMA timer | Low — parse ~30-entry table |
| gen_lookup_tables.sh for H7 | Medium — DMAMUX model differs |
| Rewrite timer section in convert.sh | Medium — replace ~130 lines |
| Remove $unified wget + update README | Low |
| Testing | Medium — need several targets per MCU |

---

## Notes / open questions

- H7 uses DMAMUX (any DMA stream can service any peripheral). The `dmaopt` in `TIMER_PIN_MAP` for H7
  is a stream index within a configured set; the lookup table approach still works but the table
  structure differs from F4/F7.
- G4 uses similar DMAMUX model to H7.
- For the common case (F405, F7x2, F745), the F4/F7 tables are sufficient and cover the vast
  majority of real FC hardware.
- The `SPI_MOSI` comment block in `$unified` (line 1050) is already handled via config.h directly.
